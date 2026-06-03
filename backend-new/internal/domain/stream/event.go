// Package stream defines the unified streaming-tree protocol shared by the three
// SSE streams (messages / entities / notifications). The design separates transport
// from semantics: all three streams share one envelope + four tree-operation verbs
// (Frame), and each stream only defines what grows on the tree (its Node vocabulary).
// See lab/backendcleaner/target/stream-protocol.md.
//
// Package stream 定义三条 SSE 流（messages / entities / notifications）共享的统一
// 「流式树」协议。设计是传输与语义正交：三流共享一个信封 + 四个树操作动词（Frame），
// 各流只定义树上长什么（自己的 Node 词表）。见 stream-protocol.md。
package stream

// Event is what a producer emits — an unsequenced draft. The producer supplies the
// target Scope, the node ID it operates on, and the Frame; it does not know the seq
// (that is the bus's job — keeping the Event/Envelope split honest at the type level).
//
// Event 是 producer 要发的内容——未编号草稿。producer 提供目标 Scope、所操作的节点
// ID、Frame；它不知道 seq（seq 是 bus 的职责——用类型把"草稿/成品"边界划清）。
type Event struct {
	Scope Scope  `json:"scope"`
	ID    string `json:"id"`
	Frame Frame  `json:"frame"`
}

// Envelope is an Event stamped with the bus-assigned seq (the delivered form).
// Seq is monotonic per stream; ephemeral frames carry Seq 0 (no replay, no id: line).
//
// Envelope 是被 bus 盖了 seq 章的 Event（投递形态）。Seq 每流单调；ephemeral 帧
// Seq 为 0（不 replay、无 id: 行）。
type Envelope struct {
	Seq int64 `json:"seq"`
	Event
}
