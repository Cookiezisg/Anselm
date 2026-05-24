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

	// ErrUnauthorizedNoUser: request hit a user-scoped route without a valid
	// X-Forgify-User-ID. Frontend treats this as a cue to clear
	// localStorage.activeUserId and re-onboard / pick a user.
	//
	// ErrUnauthorizedNoUser：请求未携带有效 X-Forgify-User-ID；前端据此清
	// localStorage.activeUserId 并重走 onboarding / 选号。
	ErrUnauthorizedNoUser = errors.New("unauthorized: no valid user id")
)
