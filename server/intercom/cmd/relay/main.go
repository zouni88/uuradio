// relay 是对讲（PTT）信令服务器：只做房间注册、SDP/ICE 定向路由与话权仲裁，
// 不处理任何音频数据（语音经 WebRTC 在设备间点对点直连）。
package main

import (
	"flag"
	"log"
	"net/http"

	"iradio/intercom/internal"
)

func main() {
	addr := flag.String("addr", ":8090", "监听地址")
	flag.Parse()

	hub := internal.NewHub()

	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		internal.ServeConn(hub, w, r)
	})

	log.Printf("intercom signaling relay listening on %s (/ws)", *addr)
	if err := http.ListenAndServe(*addr, nil); err != nil {
		log.Fatal(err)
	}
}
