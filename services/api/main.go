// 文件说明：同步后端服务入口，启动应用 HTTP 服务。
package main

import (
	"log"
	"net/http"

	"github.com/lblgb/note/services/api/internal/server"
)

// main 启动同步后端 HTTP 服务。
func main() {
	addr := ":8080"
	log.Printf("同步后端启动：%s", addr)
	if err := http.ListenAndServe(addr, server.New()); err != nil {
		log.Fatalf("同步后端退出：%v", err)
	}
}
