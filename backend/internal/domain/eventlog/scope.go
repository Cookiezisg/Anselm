// scope.go — Event-stream Scope. D19 (forge_redesign 2026-05-12):
// the recipient of a streaming event is identified by a (kind, id) tuple
// instead of a bare conversation_id, so trinity domains (function /
// handler / workflow) and flowrun execution streams can subscribe at
// the entity level alongside the chat conversation channel.
//
// scope.go —— 事件流 Scope(D19)。把"接收者"从裸 conversation_id 升级到
// (kind, id) 二元组,让 trinity 域 + flowrun 也能用 entity 级订阅。

package eventlog

import (
	"fmt"
	"strings"
)

// Scope identifies the recipient of an event stream. 5 known kinds in V1:
// conversation / flowrun / function / handler / workflow. The kind universe
// is closed (whitelisted by IsValidKind); the id format depends on kind
// (cv_<16hex> / frun_<16hex> / fn_<16hex> / hd_<16hex> / wf_<16hex>).
//
// Scope 标识事件流接收者。V1 已知 5 种 kind;白名单封闭。
type Scope struct {
	Kind string `json:"kind"`
	ID   string `json:"id"`
}

// Known kinds.
const (
	KindConversation = "conversation"
	KindFlowRun      = "flowrun"
	KindFunction     = "function"
	KindHandler      = "handler"
	KindWorkflow     = "workflow"
)

// String returns "<kind>:<id>" form — used as Bridge map key and as the
// canonical HTTP query value for the ?scope=<kind>:<id> param.
//
// String 返 "<kind>:<id>" — Bridge map key + HTTP ?scope= 协议形式。
func (s Scope) String() string {
	return s.Kind + ":" + s.ID
}

// ParseScope parses a "<kind>:<id>" string. The id may itself contain ':',
// so we split on the FIRST ':' only.
//
// ParseScope 解析 "<kind>:<id>"。id 自身可含 ':',只在首个 ':' 切。
func ParseScope(raw string) (Scope, error) {
	i := strings.IndexByte(raw, ':')
	if i < 0 {
		return Scope{}, fmt.Errorf("eventlog.ParseScope: missing ':' in %q", raw)
	}
	kind := raw[:i]
	id := raw[i+1:]
	if kind == "" || id == "" {
		return Scope{}, fmt.Errorf("eventlog.ParseScope: empty kind or id in %q", raw)
	}
	return Scope{Kind: kind, ID: id}, nil
}

// IsValidKind reports whether kind is in the V1 whitelist.
//
// IsValidKind 报告 kind 是否在 V1 白名单。
func IsValidKind(kind string) bool {
	switch kind {
	case KindConversation, KindFlowRun, KindFunction, KindHandler, KindWorkflow:
		return true
	}
	return false
}

// ConversationScope is the most common Scope constructor — wraps a bare
// conversation id. Callers transitioning from the old conversation-id-based
// Bridge API use this.
//
// ConversationScope 是最常用的 Scope 构造函数 —— 裸 conversation id 升级到
// Scope 时用。
func ConversationScope(convID string) Scope {
	return Scope{Kind: KindConversation, ID: convID}
}
