package middleware

import (
	"net/http"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// NotFound is the unmatched-URL fallback returning an N1 error envelope.
//
// NotFound 是 unmatched URL 的兜底，返 N1 错误 envelope。
func NotFound(w http.ResponseWriter, r *http.Request) {
	responsehttpapi.FromDomainError(w, nil, errorspkg.ErrNotFound)
}
