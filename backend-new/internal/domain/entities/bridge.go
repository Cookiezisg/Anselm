package entities

import streamdomain "github.com/sunweilin/forgify/backend/internal/domain/stream"

// Bridge is the entities-stream dispatch port — a re-declaration of the shared
// stream.Bridge for typed DI, so a producer can't cross-wire it with another stream.
//
// Bridge 是 entities 流的分发端口——共享 stream.Bridge 的再声明，供强类型 DI，
// 防 producer 把它与别的流接错。
type Bridge interface {
	streamdomain.Bridge
}
