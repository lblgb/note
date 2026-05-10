// 文件说明：HTTP JSON 工具函数，统一请求解码和响应写入。
package httpjson

import (
	"encoding/json"
	"net/http"
)

// ErrorBody 表示统一错误响应结构。
type ErrorBody struct {
	Error ErrorDetail `json:"error"`
}

// ErrorDetail 表示错误编码和可展示消息。
type ErrorDetail struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// DecodeJSON 将请求体解析到目标结构体。
func DecodeJSON(r *http.Request, dst any) error {
	defer r.Body.Close()
	return json.NewDecoder(r.Body).Decode(dst)
}

// WriteJSON 写入 JSON 响应。
func WriteJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

// WriteError 写入统一错误响应。
func WriteError(w http.ResponseWriter, status int, code string, message string) {
	WriteJSON(w, status, ErrorBody{
		Error: ErrorDetail{Code: code, Message: message},
	})
}
