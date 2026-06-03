package stream

import (
	"errors"
	"fmt"
)

// ErrInvalidEvent marks a malformed event — a producer bug. Bus implementations call
// ValidateEvent in Publish so the bug surfaces at the boundary instead of on the wire.
//
// ErrInvalidEvent 标记形状错误事件——producer bug。Bus 在 Publish 时调 ValidateEvent，
// 让 bug 在边界暴露而非流到线缆。
var ErrInvalidEvent = errors.New("stream: invalid event")

// ValidateEvent runs the protocol's universal shape invariants: valid scope kind,
// node ID present, and frame-internal consistency. Per-stream node-vocabulary checks
// are layered on by each stream.
//
// ValidateEvent 跑协议通用形状不变量：scope kind 合法、节点 ID 非空、frame 内部一致。
// 各流的 node 词表校验由各流叠加。
func ValidateEvent(e Event) error {
	if !IsValidKind(e.Scope.Kind) {
		return fmt.Errorf("%w: invalid scope kind %q", ErrInvalidEvent, e.Scope.Kind)
	}
	if e.ID == "" {
		return fmt.Errorf("%w: empty node ID", ErrInvalidEvent)
	}
	if e.Frame == nil {
		return fmt.Errorf("%w: nil frame", ErrInvalidEvent)
	}
	switch f := e.Frame.(type) {
	case Open:
		if f.Node == nil {
			return fmt.Errorf("%w: open frame with nil node", ErrInvalidEvent)
		}
	case Delta:
		// An empty chunk is a harmless no-op; nothing to check.
		// 空 chunk 是无害 no-op，无需校验。
	case Close:
		if !IsValidStatus(f.Status) {
			return fmt.Errorf("%w: close frame with invalid status %q", ErrInvalidEvent, f.Status)
		}
	case Signal:
		if f.Node == nil {
			return fmt.Errorf("%w: signal frame with nil node", ErrInvalidEvent)
		}
	default:
		return fmt.Errorf("%w: unknown frame type %T", ErrInvalidEvent, e.Frame)
	}
	return nil
}
