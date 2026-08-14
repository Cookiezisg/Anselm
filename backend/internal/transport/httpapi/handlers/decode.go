package handlers

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
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
		return errorspkg.ErrInvalidRequest.WithCause(err)
	}
	return rejectTrailingJSON(dec)
}

// decodeJSONOptional is decodeJSON for endpoints whose body is OPTIONAL: an empty body leaves v at
// its zero value (no error); a present body is decoded strictly. For :action verbs like :trigger
// where the request payload may be omitted.
//
// decodeJSONOptional 是给「请求体可选」端点的 decodeJSON：空体留 v 为零值（不报错）；有体则严格解码。
// 用于 :trigger 等 payload 可省的 :action 动词。
func decodeJSONOptional(r *http.Request, v any) error {
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(v); err != nil {
		if errors.Is(err, io.EOF) {
			return nil // empty body — leave v zero-valued
		}
		return errorspkg.ErrInvalidRequest.WithCause(err)
	}
	return rejectTrailingJSON(dec)
}

// rejectTrailingJSON makes the one-body-value contract real. Decoder.Decode stops after the first
// value, so without this second read `{"name":"one"}{"name":"two"}` would silently create the
// first resource and discard the caller's trailing bytes.
//
// rejectTrailingJSON 让「body 只能有一个 JSON 值」的契约真正生效。Decoder.Decode 读完第一个值就会
// 返回；没有第二次读取时，尾随 JSON 会被静默丢弃，调用方以为提交了完整请求而服务端只执行第一段。
func rejectTrailingJSON(dec *json.Decoder) error {
	var extra json.RawMessage
	if err := dec.Decode(&extra); err == io.EOF {
		return nil
	} else if err != nil {
		return errorspkg.ErrInvalidRequest.WithCause(err)
	}
	return errorspkg.ErrInvalidRequest.WithCause(errors.New("request body must contain exactly one JSON value"))
}
