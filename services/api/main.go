// 文件说明：同步后端服务入口，提供基础 HTTP 服务和健康检查。
package main

import (
	"encoding/json"
	"log"
	"net/http"
)

// healthResponse 表示健康检查接口的响应内容。
type healthResponse struct {
	Status string `json:"status"`
}

// healthHandler 返回服务健康状态。
func healthHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(healthResponse{Status: "ok"})
}

// newServer 创建后端 HTTP 路由。
func newServer() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", healthHandler)
	return mux
}

// main 启动同步后端 HTTP 服务。
func main() {
	addr := ":8080"
	log.Printf("同步后端启动：%s", addr)
	if err := http.ListenAndServe(addr, newServer()); err != nil {
		log.Fatalf("同步后端退出：%v", err)
	}
}
