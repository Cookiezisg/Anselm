// Package logtail provides a capped in-memory log collector for execution records: an
// io.Writer that keeps the FIRST half and the LAST half of its capacity and drops the
// middle. Execution logs are most valuable at both ends — startup context at the head,
// the failure trace at the tail — so a plain head-only cap (capToolResult style) or a
// tail-only ring (mcp stderr style) would each lose one of them. Used by the function /
// handler / mcp execution chains to persist a bounded `logs` column (D1 log tables stay
// bounded by construction, not by cleanup).
//
// Package logtail 给执行记录提供限长内存日志收集器：一个 io.Writer，保住容量的**前一半与后
// 一半**、丢中间。执行日志的价值在两端——头部是启动上下文、尾部是失败栈——纯保头（capToolResult
// 式）或纯保尾（mcp stderr ring 式）都会丢掉其一。function / handler / mcp 执行链用它落盘有界的
// `logs` 列（D1 log 表靠构造有界、不靠清理）。
package logtail

import (
	"fmt"
	"sync"
)

// DefaultCap is the per-execution log budget. Half head + half tail. One constant for
// every execution chain — a per-entity knob would be configuration theater.
//
// DefaultCap 是单次执行的日志预算。一半头 + 一半尾。所有执行链共用一个常量——per-entity
// 旋钮是配置剧场。
const DefaultCap = 64 * 1024

// Buffer is a concurrency-safe head+tail capped collector. The zero value is not usable;
// construct with New.
//
// Buffer 是并发安全的头+尾限长收集器。零值不可用；用 New 构造。
type Buffer struct {
	mu      sync.Mutex
	capHead int
	capTail int
	head    []byte
	tail    []byte // rolling window; compacted lazily to avoid per-write copies
	total   int
}

// New returns a Buffer that retains the first capBytes/2 and last capBytes/2 written.
//
// New 返回保留首 capBytes/2 与末 capBytes/2 写入的 Buffer。
func New(capBytes int) *Buffer {
	if capBytes < 2 {
		capBytes = 2
	}
	return &Buffer{capHead: capBytes / 2, capTail: capBytes - capBytes/2}
}

// Write implements io.Writer. It always reports the full length consumed and never
// errors, so it composes safely under io.MultiWriter next to live stream writers.
//
// Write 实现 io.Writer。总是报告吃下全长、绝不出错，故可安全与实时流 writer 并排挂在
// io.MultiWriter 下。
func (b *Buffer) Write(p []byte) (int, error) {
	if b == nil || len(p) == 0 {
		return len(p), nil
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	b.total += len(p)
	rest := p
	if len(b.head) < b.capHead {
		n := min(b.capHead-len(b.head), len(rest))
		b.head = append(b.head, rest[:n]...)
		rest = rest[n:]
	}
	if len(rest) == 0 {
		return len(p), nil
	}
	b.tail = append(b.tail, rest...)
	// Compact only past 2× capacity so steady writes stay amortized O(1).
	// 仅超 2 倍容量才压实，使持续写入摊还 O(1)。
	if len(b.tail) > b.capTail*2 {
		keep := b.tail[len(b.tail)-b.capTail:]
		nt := make([]byte, len(keep))
		copy(nt, keep)
		b.tail = nt
	}
	return len(p), nil
}

// Empty reports whether nothing was ever written.
//
// Empty 报是否从未写入。
func (b *Buffer) Empty() bool {
	if b == nil {
		return true
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.total == 0
}

// String renders the retained log: verbatim when nothing was dropped, otherwise
// head + an explicit truncation marker + tail (silent truncation reads as "complete").
//
// String 渲染留存日志：没丢时原样；丢过则 头 + 显式截断标记 + 尾（静默截断会被当成「完整」）。
func (b *Buffer) String() string {
	if b == nil {
		return ""
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	tail := b.tail
	if len(tail) > b.capTail {
		tail = tail[len(tail)-b.capTail:]
	}
	if b.total <= len(b.head)+len(tail) {
		return string(b.head) + string(tail)
	}
	dropped := b.total - len(b.head) - len(tail)
	return string(b.head) +
		fmt.Sprintf("\n…[logs truncated: %d middle bytes dropped of %d total]…\n", dropped, b.total) +
		string(tail)
}
