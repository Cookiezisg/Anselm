package handlers

import (
	"encoding/json"
	"net/http"

	errorsdomain "github.com/sunweilin/forgify/backend/internal/domain/errors"
)

// decodeJSON strictly decodes the request body into v (unknown fields rejected).
// A malformed body becomes ErrInvalidRequest wrapping the parse error, so
// response.FromDomainError renders a uniform 400 and handlers never inspect it.
//
// decodeJSON 严格解码请求体到 v（拒绝未知字段）。畸形体变 ErrInvalidRequest（包裹解析错误），
// 由 response.FromDomainError 统一渲染 400，handler 无需检查。
func decodeJSON(r *http.Request, v any) error {
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(v); err != nil {
		return errorsdomain.ErrInvalidRequest.WithCause(err)
	}
	return nil
}
