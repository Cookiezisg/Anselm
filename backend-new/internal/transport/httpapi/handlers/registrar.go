// Package handlers holds the per-resource HTTP handlers. Each handler registers
// its routes on a Registrar and translates between wire JSON and the app
// services, delegating all error rendering to response.FromDomainError.
//
// Package handlers 持有按资源划分的 HTTP handler。每个 handler 在 Registrar 上注册路由，
// 在线缆 JSON 与 app service 间转换，错误渲染全交给 response.FromDomainError。
package handlers

import "net/http"

// Registrar is the minimal mux surface handlers register against; satisfied by
// *http.ServeMux and the router.Recorder used for route auditing.
//
// Registrar 是 handler 注册路由的最小 mux 接口；*http.ServeMux 与审计用的 router.Recorder 都实现。
type Registrar interface {
	HandleFunc(pattern string, h func(http.ResponseWriter, *http.Request))
	Handle(pattern string, h http.Handler)
}

// Compile-time guard: *http.ServeMux satisfies Registrar.
var _ Registrar = (*http.ServeMux)(nil)
