// Package notifications defines the Node vocabulary for the notifications SSE stream
// — entity-state-change broadcasts that drive list refreshes / toasts / badges. Most
// are durable signals; flowrun ticks are ephemeral (high-frequency, lossy). Unlike
// messages/entities these carry no tree — they are one-shot stream.Signal frames.
// See stream-protocol.md.
//
// Package notifications 定义 notifications SSE 流的 Node 词表——驱动列表刷新 / toast /
// 角标的实体状态变更广播。多数是 durable signal；flowrun tick 是 ephemeral（高频可丢）。
// 与 messages/entities 不同，它们不建树——是一次性的 stream.Signal 帧。
package notifications

// ⚠️ PROVISIONAL — node vocabulary not yet settled.
// The protocol skeleton (stream.Envelope / the 4 Frame verbs / the Node interface) is
// final and stable. The concrete node set below — which node types exist and what fields
// each carries — is a first cut derived from design, NOT a contract. It is re-confirmed
// against real needs when each producer module is wired up (its own wave per order.md).
//
// ⚠️ 暂定——词表未定稿。协议骨架（stream 信封 / 四动词 Frame / Node interface）已定稿
// 稳定；下面具体词表（有哪些 node、各带什么字段）是依设计推演的初版，非契约。到各
// producer 模块接线那一轮（order.md 各自波次）依实际需求重新确定。

// EntityChangedNode broadcasts an entity lifecycle change. Kind is the entity kind,
// Action the verb (created / updated / deleted / version_accepted / ...), Data a slim payload.
//
// EntityChangedNode 广播实体生命周期变更。Kind 是实体种类，Action 是动词，Data 为瘦 payload。
type EntityChangedNode struct {
	Kind   string `json:"kind"`
	Action string `json:"action"`
	Data   any    `json:"data,omitempty"`
}

func (EntityChangedNode) NodeType() string { return "entity_changed" }

// FlowrunTickNode is a high-frequency runtime tick — emit via stream.Signal{Ephemeral: true}
// so it is live-only (no seq, no replay, dropped on a full subscriber).
//
// FlowrunTickNode 是高频运行时 tick——经 stream.Signal{Ephemeral: true} 发，实时投递
// （无 seq、不 replay、满则丢）。
type FlowrunTickNode struct {
	NodeID string `json:"nodeId"`
	Status string `json:"status"`
}

func (FlowrunTickNode) NodeType() string { return "flowrun_tick" }

// FlowrunLifecycleNode broadcasts a durable flowrun lifecycle change (started / completed / failed).
//
// FlowrunLifecycleNode 广播 durable 的 flowrun 生命周期变更（started / completed / failed）。
type FlowrunLifecycleNode struct {
	Status string `json:"status"`
	Error  string `json:"error,omitempty"`
}

func (FlowrunLifecycleNode) NodeType() string { return "flowrun_lifecycle" }
