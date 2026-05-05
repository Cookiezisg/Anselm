// Package errors holds cross-domain sentinels. Per-domain sentinels live
// in their own packages.
//
// Package errors 持有跨 domain sentinel；按 domain 的 sentinel 放在各自包内。
package errors

import "errors"

var (
	// ErrInvalidRequest: malformed / semantically invalid request before domain logic.
	// ErrInvalidRequest：domain 逻辑前发现的格式错误或语义无效。
	ErrInvalidRequest = errors.New("invalid request")

	// ErrInternal: unexpected failure — bug or infra outage.
	// ErrInternal：意外失败——bug 或基础设施故障。
	ErrInternal = errors.New("internal error")
)
