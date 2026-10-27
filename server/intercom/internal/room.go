package internal

import (
	"time"
)

// 房间与话权仲裁。所有状态变更均由 Hub 的互斥锁保护（见 hub.go）。

// maxMembers 群组频道人数上限（全网格拓扑约束）。
const maxMembers = 8

// talkTimeout 话权持有上限，超时自动释放。
const talkTimeout = 60 * time.Second

// Room 一个对讲频道：成员注册表 + 半双工话权。
type Room struct {
	name    string
	clients map[string]*Client // key = 客户端自生成 id
	floor   string             // 话权持有者 id，空 = 空闲
	timer   *time.Timer        // 60s 自动释放
}

func newRoom(name string) *Room {
	return &Room{name: name, clients: map[string]*Client{}}
}

// memberList 当前成员快照（id + nick）。
func (r *Room) memberList() []map[string]any {
	out := make([]map[string]any, 0, len(r.clients))
	for _, c := range r.clients {
		out = append(out, map[string]any{"id": c.id, "nick": c.nick})
	}
	return out
}

// broadcast 向房间内所有在线客户端发送 JSON 消息（跳过发送队列已满的慢客户端）。
func (r *Room) broadcast(msg map[string]any) {
	for _, c := range r.clients {
		c.trySend(msg)
	}
}

// broadcastExcept 除 exclude 外广播。
func (r *Room) broadcastExcept(exclude *Client, msg map[string]any) {
	for _, c := range r.clients {
		if c == exclude {
			continue
		}
		c.trySend(msg)
	}
}

// requestFloor 先到先得：空闲（或本人重复请求）则授予，否则拒绝。
func (r *Room) requestFloor(c *Client) {
	if r.floor != "" && r.floor != c.id {
		c.trySend(map[string]any{"t": "talk_denied", "reason": "busy"})
		return
	}
	if r.floor == c.id {
		// 幂等重发（客户端可能因重连丢失 granted 回执）。
		c.trySend(map[string]any{"t": "talk_granted"})
		return
	}
	r.floor = c.id
	if r.timer != nil {
		r.timer.Stop()
	}
	r.timer = time.AfterFunc(talkTimeout, func() {
		h := c.hub
		h.mu.Lock()
		if r.floor == c.id {
			r.releaseFloorLocked()
		}
		h.mu.Unlock()
	})
	c.trySend(map[string]any{"t": "talk_granted"})
	r.broadcastExcept(c, map[string]any{
		"t": "talk_started", "id": c.id, "nick": c.nick,
	})
}

// releaseFloor 释放话权（仅持有者本人可释放）。
func (r *Room) releaseFloor(c *Client) {
	if r.floor != c.id {
		return
	}
	r.releaseFloorLocked()
}

func (r *Room) releaseFloorLocked() {
	id := r.floor
	r.floor = ""
	if r.timer != nil {
		r.timer.Stop()
		r.timer = nil
	}
	if id != "" {
		r.broadcast(map[string]any{"t": "talk_stopped", "id": id})
	}
}
