package stream

// Scope anchors a stream event to the rendering tree / broadcast space it acts on:
// messages → conversation:<id>, entities → <entityKind>:<id>, notifications → workspace.
// Scope.ID (the anchor) is distinct from Event.ID (the tree node) — different concepts,
// told apart by access path.
//
// Scope 锚定一条流式事件作用的渲染树 / 广播空间：messages → conversation:<id>，
// entities → <实体kind>:<id>，notifications → workspace。Scope.ID（锚点）与 Event.ID
// （树节点）语义不同，靠访问路径区分。
type Scope struct {
	Kind string `json:"kind"`
	ID   string `json:"id,omitempty"`
}

// Scope kinds — the entity-kind vocabulary shared across the three streams.
// (Overlaps the future relation.EntityKind; consolidation deferred to M1.4.)
//
// Scope kind 全集——三流共享的实体-kind 词表。（与未来 relation.EntityKind 重叠，
// M1.4 收口。）
const (
	KindConversation = "conversation"
	KindFunction     = "function"
	KindHandler      = "handler"
	KindAgent        = "agent"
	KindWorkflow     = "workflow"
	KindDocument     = "document"
	KindMCP          = "mcp"
	KindSkill        = "skill"
	KindWorkspace    = "workspace"
)

// String renders "<kind>:<id>" — the form used as a subscription key and ?scope= value.
//
// String 渲染 "<kind>:<id>"——作订阅 key 与 ?scope= 协议形式。
func (s Scope) String() string {
	return s.Kind + ":" + s.ID
}

// IsValidKind reports whether kind is one of the enumerated scope kinds.
//
// IsValidKind 报告 kind 是否枚举之一。
func IsValidKind(kind string) bool {
	switch kind {
	case KindConversation, KindFunction, KindHandler, KindAgent, KindWorkflow,
		KindDocument, KindMCP, KindSkill, KindWorkspace:
		return true
	}
	return false
}
