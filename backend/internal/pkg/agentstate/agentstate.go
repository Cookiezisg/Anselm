// Package agentstate carries per-conversation state shared across tool
// invocations within a single chat agent run — most notably "which files have
// been Read this conversation," consumed by Edit/Write to enforce the
// must-Read-first rule.
//
// The package lives in pkg/ (not app/chat/) so pkg/reqctx can ferry an
// AgentState pointer through ctx without forming the cycle pkg/reqctx →
// app/chat → pkg/reqctx.
//
// Lifecycle: one AgentState per conversation queue (see chat.convQueue);
// garbage-collected when the queue's idle timer fires.
//
// Package agentstate 携带跨 tool 调用、限定在单次 chat agent 运行内的对话级状态——
// 最重要的就是"本对话已 Read 了哪些文件"，被 Edit/Write 用来强制 must-Read-first 规则。
//
// 包放在 pkg/（不是 app/chat/）是为了让 pkg/reqctx 通过 ctx 转运 AgentState 指针时
// 不形成 pkg/reqctx → app/chat → pkg/reqctx 的循环。
//
// 生命周期：每个 conversation queue 一份 AgentState（见 chat.convQueue），
// queue idle 定时器触发时一并 GC。
package agentstate

import "sync"

// AgentState is the per-conversation shared state for tool invocations.
// Methods are safe for concurrent use — backed by sync.Map.
//
// AgentState 是 tool 调用的对话级共享状态。方法并发安全——底层 sync.Map。
type AgentState struct {
	// SeenFiles maps absolute file path → file size at the time it was Read.
	// Edit/Write check membership to enforce must-Read-first; the size lets
	// future code detect external modification between Read and Edit.
	//
	// SeenFiles 把绝对文件路径映射到 Read 时的文件 size。
	// Edit/Write 检查存在性以强制 must-Read-first；size 让后续代码能检测
	// Read 与 Edit 之间的外部修改。
	SeenFiles sync.Map // string → int64
}

// MarkRead records that path has been Read this conversation, capturing its
// current size. Callers (Read tool, future Bash sed/cat detection) invoke
// after a successful read.
//
// MarkRead 记录 path 在本对话中已被 Read，并捕获其当前 size。
// 调用方（Read tool、未来 Bash sed/cat 检测）在成功读取后调用。
func (s *AgentState) MarkRead(path string, size int64) {
	s.SeenFiles.Store(path, size)
}

// WasRead reports whether path has been Read this conversation. The returned
// size is the file size at the time it was first marked; a current-vs-stored
// mismatch can indicate external modification.
//
// WasRead 报告 path 是否在本对话中已被 Read。返回的 size 是首次标记时的文件
// size；当前与存储不一致可能意味着外部修改。
func (s *AgentState) WasRead(path string) (int64, bool) {
	v, ok := s.SeenFiles.Load(path)
	if !ok {
		return 0, false
	}
	return v.(int64), true
}
