// Package pagination encodes/decodes opaque base64url(JSON) keyset cursors. Pure stdlib —
// HTTP param parsing and limit policy live in the transport layer, not here.
//
// Package pagination 为 keyset 分页编解码 base64url(JSON) 不透明 cursor。纯 stdlib——
// HTTP 参数解析与 limit 策略在 transport 层，不在这里。
package pagination

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	"time"
)

// ErrMalformedCursor signals an undecodable cursor. Callers map it to their own transport/domain
// error (pagination stays free of any upstream dependency).
//
// ErrMalformedCursor 表示无法解码的 cursor。调用方将其映射到自己的 transport/domain 错误
// （pagination 不依赖任何上层）。
var ErrMalformedCursor = errorspkg.New(errorspkg.KindInvalid, "MALFORMED_CURSOR", "pagination: malformed cursor")

// Cursor is the keyset tuple (sortKey, id); Key holds the value of whatever time column the query
// paginates on (created_at by default, last_message_at for the conversation list, …). Short JSON
// tags keep encoded cursors compact; the wire tag "c" is unchanged for backward compatibility.
//
// Cursor 是 keyset 元组 (sortKey, id)；Key 持查询所按的时间列之值（默认 created_at，对话列表按
// last_message_at…）。短 JSON tag 让编码后 cursor 紧凑；线缆 tag "c" 不变（向后兼容）。
type Cursor struct {
	Key time.Time `json:"c"`
	ID  string    `json:"i"`
}

// StringCursor is the keyset tuple for a STRING-keyed, ascending list (e.g. conversations sorted by
// title A–Z). Same compact wire shape {c, i} as Cursor (c is just a plain string here instead of an
// RFC3339 time) — a cursor minted under one sort is meaningless under another, so callers MUST drop
// the cursor when the sort changes (the existing rule, unchanged).
//
// StringCursor 是**字符串键、升序**列表的 keyset 元组（如 conversations 按 title A–Z）。线缆形状与 Cursor 同
// （{c, i}，c 此处是普通字符串而非 RFC3339 时间）——一种排序下的游标在另一种下无意义，故切换排序时调用方
// **必须丢弃游标**（既有规则，不变）。
type StringCursor struct {
	Key string `json:"c"`
	ID  string `json:"i"`
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
