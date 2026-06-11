package handlers

import (
	"net/http"
	"strings"
)

// idAndAction splits "<id>:<action>" out of r.PathValue(key); ok=false with no
// colon. Go 1.22+ ServeMux forbids a literal `{id}:action` segment, so action
// routes capture `{idAction}` whole and split here.
//
// idAndAction 把 r.PathValue(key) 拆成 "<id>:<action>"，无冒号 ok=false。Go 1.22+ ServeMux
// 禁止字面 `{id}:action` 分段，故动作路由整体捕获 {idAction} 在此拆分。
func idAndAction(r *http.Request, key string) (id, action string, ok bool) {
	return strings.Cut(r.PathValue(key), ":")
}
