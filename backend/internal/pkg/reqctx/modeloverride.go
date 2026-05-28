// Package reqctx — model override propagation helper.
//
// Package reqctx — model override 透传 helper。
package reqctx

import (
	"context"

	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
)

type modelOverrideKey struct{}

// WithModelOverride stashes the effective ModelRef on ctx for downstream readers
// (subagent tool reads to propagate into nested spawns).
//
// WithModelOverride 把 effective ModelRef 塞进 ctx;下游(subagent 工具)读出来
// 传给嵌套 spawn,保证整条链用同一 override。
func WithModelOverride(ctx context.Context, ref *modeldomain.ModelRef) context.Context {
	if ref == nil {
		return ctx
	}
	return context.WithValue(ctx, modelOverrideKey{}, ref)
}

// GetModelOverride returns the effective ModelRef, or nil if unset.
//
// GetModelOverride 返 effective ModelRef,未设返 nil。
func GetModelOverride(ctx context.Context) *modeldomain.ModelRef {
	if v, ok := ctx.Value(modelOverrideKey{}).(*modeldomain.ModelRef); ok {
		return v
	}
	return nil
}
