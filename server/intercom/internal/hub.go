package internal

import (
	"encoding/json"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// Hub 信令中枢：房间表 + 消息路由。纯 JSON 控制面，不经手任何音频。

const (
	writeWait  = 10 * time.Second
	pongWait   = 30 * time.Second // 读超时：客户端 heartbeat 间隔 20s
	readLimit  = 64 << 10         // 单条信令上限 64KB（SDP 足够）
	sendBuffer = 256
)

var upgrader = websocket.Upgrader{
	// 对讲客户端为原生 App（无浏览器同源语义），放开跨域。
	CheckOrigin: func(r *http.Request) bool { return true },
}

// Client 一条 WebSocket 连接。
type Client struct {
	hub  *Hub
	conn *websocket.Conn
	send chan map[string]any

	mu     sync.Mutex // 保护 send 通道与 closed 标志
	closed bool

	id   string // 客户端自生成 UUID，join 时上报
	nick string
	room *Room
}

// Hub 全部房间。
type Hub struct {
	mu    sync.Mutex
	rooms map[string]*Room
}

func NewHub() *Hub {
	return &Hub{rooms: map[string]*Room{}}
}

// ServeConn 升级连接并进入读写循环。
func ServeConn(h *Hub, w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	c := &Client{hub: h, conn: conn, send: make(chan map[string]any, sendBuffer)}
	go c.writePump()
	c.readPump()
	c.disconnect()
}

// trySend 入队；慢客户端队列满时标记关闭（写循环随后断开，避免阻塞房间广播）。
func (c *Client) trySend(msg map[string]any) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closed {
		return
	}
	select {
	case c.send <- msg:
	default:
		c.closed = true
		close(c.send)
	}
}

func (c *Client) writePump() {
	for msg := range c.send {
		data, err := json.Marshal(msg)
		if err != nil {
			continue
		}
		c.conn.SetWriteDeadline(time.Now().Add(writeWait))
		if err := c.conn.WriteMessage(websocket.TextMessage, data); err != nil {
			return
		}
	}
	c.conn.WriteControl(websocket.CloseMessage,
		websocket.FormatCloseMessage(websocket.CloseNormalClosure, ""),
		time.Now().Add(writeWait))
	c.conn.Close()
}

func (c *Client) readPump() {
	c.conn.SetReadLimit(readLimit)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})
	for {
		_, data, err := c.conn.ReadMessage()
		if err != nil {
			return
		}
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		var msg map[string]any
		if err := json.Unmarshal(data, &msg); err != nil {
			c.trySend(map[string]any{"t": "error", "code": "bad_json", "msg": "invalid json"})
			continue
		}
		c.hub.handle(c, msg)
	}
}

// disconnect 清理：退房、释放话权、广播成员变化。
func (c *Client) disconnect() {
	h := c.hub
	h.mu.Lock()
	defer h.mu.Unlock()
	if c.room == nil {
		return
	}
	room := c.room
	c.room = nil
	delete(room.clients, c.id)
	room.releaseFloor(c)
	if len(room.clients) == 0 {
		delete(h.rooms, room.name)
		return
	}
	room.broadcast(map[string]any{"t": "members", "members": room.memberList()})
}

// handle 分发一条控制消息（type 字段 "t"）。
func (h *Hub) handle(c *Client, msg map[string]any) {
	t, _ := msg["t"].(string)
	h.mu.Lock()
	defer h.mu.Unlock()

	switch t {
	case "join":
		h.handleJoin(c, msg)
	case "leave":
		h.handleLeave(c)
	case "offer", "answer", "ice":
		h.handleRoute(c, msg)
	case "talk_req":
		if c.room != nil {
			c.room.requestFloor(c)
		}
	case "talk_released":
		if c.room != nil {
			c.room.releaseFloor(c)
		}
	case "heartbeat":
		// 读循环已刷新超时，无需回复。
	default:
		c.trySend(map[string]any{"t": "error", "code": "unknown_type", "msg": "unsupported t: " + t})
	}
}

func (h *Hub) handleJoin(c *Client, msg map[string]any) {
	ch, _ := msg["ch"].(string)
	nick, _ := msg["nick"].(string)
	id, _ := msg["id"].(string)
	if ch == "" || id == "" {
		c.trySend(map[string]any{"t": "error", "code": "bad_join", "msg": "ch and id required"})
		return
	}
	if c.room != nil {
		h.handleLeave(c)
	}
	room, ok := h.rooms[ch]
	if !ok {
		room = newRoom(ch)
		h.rooms[ch] = room
	}
	if len(room.clients) >= maxMembers && room.clients[id] == nil {
		c.trySend(map[string]any{"t": "error", "code": "room_full", "msg": "channel is full (max 8)"})
		return
	}
	if old := room.clients[id]; old != nil && old != c {
		// 同 id 顶号（重装 App 后旧连接残留场景）。
		old.room = nil
		old.trySend(map[string]any{"t": "error", "code": "replaced", "msg": "same id joined elsewhere"})
	}
	c.id, c.nick, c.room = id, nick, room
	room.clients[id] = c
	c.trySend(map[string]any{"t": "joined", "members": room.memberList()})
	room.broadcastExcept(c, map[string]any{"t": "members", "members": room.memberList()})
}

func (h *Hub) handleLeave(c *Client) {
	if c.room == nil {
		return
	}
	room := c.room
	c.room = nil
	delete(room.clients, c.id)
	room.releaseFloor(c)
	if len(room.clients) == 0 {
		delete(h.rooms, room.name)
		return
	}
	room.broadcast(map[string]any{"t": "members", "members": room.memberList()})
}

// handleRoute 定向路由 offer/answer/ice：查同房间目标，附 from 转发。
func (h *Hub) handleRoute(c *Client, msg map[string]any) {
	if c.room == nil {
		c.trySend(map[string]any{"t": "error", "code": "not_joined", "msg": "join a channel first"})
		return
	}
	to, _ := msg["to"].(string)
	target, ok := c.room.clients[to]
	if !ok {
		return // 目标已离开：静默丢弃（重连后 members 会纠正）
	}
	forward := map[string]any{}
	for k, v := range msg {
	 forward[k] = v
	}
	forward["from"] = c.id
	target.trySend(forward)
}
