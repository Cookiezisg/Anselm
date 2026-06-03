// Package pagination encodes/decodes opaque base64url(JSON) keyset cursors. Pure stdlib —
// HTTP param parsing and limit policy live in the transport layer, not here.
//
// Package pagination 为 keyset 分页编解码 base64url(JSON) 不透明 cursor。纯 stdlib——
// HTTP 参数解析与 limit 策略在 transport 层，不在这里。
package pagination

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"time"
)

// ErrMalformedCursor signals an undecodable cursor. Callers map it to their own transport/domain
// error (pagination stays free of any upstream dependency).
//
// ErrMalformedCursor 表示无法解码的 cursor。调用方将其映射到自己的 transport/domain 错误
// （pagination 不依赖任何上层）。
var ErrMalformedCursor = errors.New("pagination: malformed cursor")

// Cursor is the standard (created_at, id) keyset tuple; short JSON tags keep encoded cursors compact.
//
// Cursor 是标准 (created_at, id) keyset 元组；短 JSON tag 让编码后的 cursor 紧凑。
type Cursor struct {
	CreatedAt time.Time `json:"c"`
	ID        string    `json:"i"`
}

// EncodeCursor marshals v as base64url(JSON); a nil v maps to "" (signals no further pages).
//
// EncodeCursor 把 v 编码为 base64url(JSON)；v 为 nil 时返 ""（表示无下一页）。
func EncodeCursor(v any) (string, error) {
	if v == nil {
		return "", nil
	}
	raw, err := json.Marshal(v)
	if err != nil {
		return "", fmt.Errorf("encode cursor: %w", err)
	}
	return base64.RawURLEncoding.EncodeToString(raw), nil
}

// DecodeCursor reverses EncodeCursor into v. An empty cursor is a no-op (first page); a malformed
// one returns ErrMalformedCursor.
//
// DecodeCursor 把 cursor 解码进 v。空 cursor 为 no-op（首页）；格式错返 ErrMalformedCursor。
func DecodeCursor(cursor string, v any) error {
	if cursor == "" {
		return nil
	}
	raw, err := base64.RawURLEncoding.DecodeString(cursor)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrMalformedCursor, err)
	}
	if err := json.Unmarshal(raw, v); err != nil {
		return fmt.Errorf("%w: %v", ErrMalformedCursor, err)
	}
	return nil
}
