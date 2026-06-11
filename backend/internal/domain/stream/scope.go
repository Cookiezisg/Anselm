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

// Scope kinds — the anchor-kind vocabulary for the three streams. A scope Kind is
// the RENDERING/ENTITY anchor an event acts on, NOT the event type (the event type
// lives in Node.Type). The three streams use disjoint subsets: messages →
// conversation; entities → the entity kinds; notifications → notification (each
// event anchors one notification entity). Workspace is deliberately NOT a scope kind
// — workspace is the Bus's dispatch axis, taken from ctx, not a rendering anchor. The
// entity kinds overlap relation.EntityKind; folding them to a single source of truth
// (relation reuses these) is a registered follow-up.
//
// Scope kind 全集——三流的「锚点类型」词表。scope.Kind 是事件作用的渲染/实体锚点，
// **不是事件类型**（事件类型在 Node.Type）。三流用不相交子集：messages → conversation；
// entities → 各实体 kind；notifications → notification（每事件锚一个通知实体）。workspace
// **刻意不是** scope kind——它是 Bus 从 ctx 取的分流轴、非渲染锚点。实体 kind 与
// relation.EntityKind 重叠，收成单一事实源（relation 复用之）为登记的后续项。
const (
	KindConversation = "conversation"
	KindFunction     = "function"
	KindHandler      = "handler"
	KindAgent        = "agent"
	KindWorkflow     = "workflow"
	KindDocument     = "document"
	KindMCP          = "mcp"
	KindSkill        = "skill"
	KindControl      = "control"  // SSE-C: entities-stream forge activity
	KindApproval     = "approval" // SSE-C: entities-stream forge activity
	KindTrigger      = "trigger"  // SSE-C: entities-stream fire activity
	KindNotification = "notification"
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
		KindDocument, KindMCP, KindSkill, KindControl, KindApproval, KindTrigger, KindNotification:
		return true
	}
	return false
}
