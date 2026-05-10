// Package ask is the app-layer rendezvous between the AskUserQuestion
// system tool and the HTTP answer-delivery endpoint. The tool blocks on
// a per-tool-call channel; the handler resolves it when the user POSTs
// an answer. No entity, no DB persistence — questions live only in
// memory for the lifetime of one tool call.
//
// Design (decision D11): the question itself rides chat.message SSE
// (the AskUserQuestion tool_call block contains the question text),
// and the answer arrives via POST /api/v1/conversations/{id}/answers.
// We deliberately did NOT mint a new "ask" event family — chat.message
// already streams everything UI needs.
//
// Lifecycle: Wait registers a channel keyed on toolCallID, blocks with
// a timeout, defers cleanup. Resolve closes the loop. Stale entries are
// impossible because Wait owns the lifetime via defer.
//
// Package ask 是 AskUserQuestion 系统工具与 HTTP 答案投递端点之间的 app
// 层会合点。工具在每个 tool call 一根 channel 上阻塞；用户 POST 时 handler
// 投递。无实体、无持久化——问题仅在单次 tool 调用的生命周期内驻留内存。
//
// 设计（决策 D11）：问题本身坐 chat.message SSE 流（AskUserQuestion
// tool_call block 含问题文本）；答案走
// POST /api/v1/conversations/{id}/answers。**故意不**新建 "ask" 事件家族
// ——chat.message 已经流转 UI 需要的一切。
//
// 生命周期：Wait 按 toolCallID 注册 channel、带超时阻塞、defer 清理。
// Resolve 闭合环路。Wait 用 defer 持有生命周期，故无僵尸条目。
package ask

import (
	"context"
	"errors"
	"sync"
	"time"
)

// ── Sentinels ────────────────────────────────────────────────────────────────

var (
	// ErrNoPendingQuestion: Resolve was called for a tool_call ID that
	// has no pending Wait. Typically means the question already timed
	// out, the tool_call ID is bogus, or a second Resolve raced in
	// after the first removed the entry atomically.
	// ErrNoPendingQuestion：Resolve 收到的 tool_call ID 无对应 pending Wait。
	// 通常意味问题已超时、ID 无效，或第二次 Resolve 在首次原子删除后竞争进入。
	ErrNoPendingQuestion = errors.New("ask: no pending question for that tool_call_id")

	// ErrTimeout: Wait blocked past its deadline without an answer.
	// ErrTimeout：Wait 阻塞超过截止时间仍无答案。
	ErrTimeout = errors.New("ask: user did not respond within the timeout")
)

// ── Service ──────────────────────────────────────────────────────────────────

// Service owns the in-memory rendezvous registry. Methods are safe for
// concurrent use.
//
// Service 持有内存会合注册表。方法并发安全。
type Service struct {
	mu      sync.Mutex
	pending map[string]chan string
}

// NewService returns an empty Service ready to register questions.
//
// NewService 返回一个空 Service，可立即注册问题。
func NewService() *Service {
	return &Service{pending: make(map[string]chan string)}
}

// Wait registers a pending question keyed on toolCallID and blocks until
// either the answer arrives, ctx is cancelled, or timeout elapses. The
// registry entry is always cleaned up when Wait returns so a cancelled
// or timed-out tool call cannot block a future Resolve.
//
// Returns:
//   - (answer, nil) on successful resolution
//   - ("", ErrTimeout) when the deadline elapses
//   - ("", ctx.Err()) when ctx is cancelled
//
// Wait 按 toolCallID 注册 pending 问题并阻塞，直至：答案到达 / ctx 取消 /
// 超时。Wait 返回时一定清理注册表，保证已取消 / 已超时的 tool 调用不会
// 阻塞未来的 Resolve。
func (s *Service) Wait(ctx context.Context, toolCallID string, timeout time.Duration) (string, error) {
	ch := make(chan string, 1) // buffered so Resolve never blocks on unbuffered send

	s.mu.Lock()
	if _, exists := s.pending[toolCallID]; exists {
		s.mu.Unlock()
		// Same tool_call_id twice would silently shadow the prior; reject
		// loudly so the wiring bug surfaces.
		// 同一 tool_call_id 注册两次会静默覆盖；显式报错让接线 bug 暴露。
		return "", errors.New("ask: tool_call_id already pending — caller bug")
	}
	s.pending[toolCallID] = ch
	s.mu.Unlock()

	defer s.cleanup(toolCallID)

	timer := time.NewTimer(timeout)
	defer timer.Stop()

	select {
	case ans := <-ch:
		return ans, nil
	case <-timer.C:
		return "", ErrTimeout
	case <-ctx.Done():
		return "", ctx.Err()
	}
}

// Resolve sends the answer to the waiting Wait and atomically removes
// the registry entry — so a second Resolve for the same ID always sees
// ErrNoPendingQuestion (rather than depending on a defer-cleanup race
// in Wait). Returns:
//   - nil on successful delivery
//   - ErrNoPendingQuestion if no Wait registered the ID (or it was
//     already resolved / cleaned up)
//
// Resolve 投递答案并原子地从注册表删条目——第二次 Resolve 必拿到
// ErrNoPendingQuestion，不再依赖 Wait defer-cleanup 的竞态。
func (s *Service) Resolve(toolCallID, answer string) error {
	s.mu.Lock()
	ch, ok := s.pending[toolCallID]
	if ok {
		delete(s.pending, toolCallID)
	}
	s.mu.Unlock()
	if !ok {
		return ErrNoPendingQuestion
	}
	// Buffered channel (cap 1) — send never blocks because we just
	// removed the entry, so no second Resolve can race in.
	// 带缓冲 channel（cap 1）——发送永不阻塞，因刚已删条目，无第二个
	// Resolve 能竞争。
	ch <- answer
	return nil
}

// cleanup removes the entry. Idempotent; safe to call from defer even
// when Resolve already drained the channel and removed the key would
// otherwise have happened.
//
// cleanup 删除条目。幂等；defer 调安全，即便 Resolve 已经走完。
func (s *Service) cleanup(toolCallID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.pending, toolCallID)
}

// pendingCount is exported only for tests verifying cleanup semantics.
//
// pendingCount 仅供测试验清理语义。
func (s *Service) pendingCount() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.pending)
}
