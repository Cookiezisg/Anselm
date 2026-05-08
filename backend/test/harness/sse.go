//go:build pipeline

// sse.go — SSE collector for pipeline tests. Subscribes to BOTH new endpoints
// and reconstructs Message + Block state in memory:
//
//   - GET /api/v1/eventlog?conversationId=X for the recursive event-log
//     stream (5 events × 6 block types). Reconstructed into message/block
//     snapshots so tests keep working with `LastMessage().Blocks` style.
//
//   - GET /api/v1/notifications for global broadcasts. Conversation snapshots
//     (type="conversation") are merged into a Conversation field so autoTitle
//     tests still work via WaitForConversation.
//
// Old entity-snapshot stream (chat.message / forge / conversation) is gone;
// reconstruction here mirrors what the frontend chat.js does over the wire.
//
// sse.go — pipeline 测试用 SSE 收集器。同时订阅两个新端点：
//
//   - GET /api/v1/eventlog?conversationId=X 走递归事件日志（5 events × 6
//     block types）。在内存里重构 message/block 快照，让测试继续用
//     `LastMessage().Blocks` 风格。
//
//   - GET /api/v1/notifications 走全局广播。type="conversation" 的快照合
//     入 Conversation 字段，autoTitle 测试经 WaitForConversation 仍工作。
//
// 旧 entity-snapshot 流（chat.message / forge / conversation）已废；重构
// 逻辑镜像 frontend chat.js 在 wire 上做的事。
package harness

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"testing"
	"time"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	convdomain "github.com/sunweilin/forgify/backend/internal/domain/conversation"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
)

// RawEvent is one parsed SSE event from either endpoint.
//
// RawEvent 是来自任一端点的一条解析过的 SSE 事件。
type RawEvent struct {
	Source string // "eventlog" | "notifications"
	ID     string
	Type   string
	Data   []byte
	At     time.Time
}

// SSESub holds reconstructed message + block state plus raw event log.
//
// SSESub 持重构出的 message + block 状态以及原始事件日志。
type SSESub struct {
	t              *testing.T
	cancelEventLog context.CancelFunc
	cancelNotif    context.CancelFunc
	respEventLog   *http.Response
	respNotif      *http.Response

	mu sync.Mutex

	raw []RawEvent

	messages      map[string]*chatdomain.Message
	orderedMsgIDs []string

	blocks map[string]*chatdomain.Block

	conv *convdomain.Conversation

	closed       bool
	streamELdone chan struct{}
	streamNFdone chan struct{}
}

// SubscribeSSE opens both eventlog (filtered to conversationID) and
// notifications subscriptions. Cleanup is registered on t.
//
// SubscribeSSE 同时开 eventlog（按 conversationID 过滤）和 notifications
// 订阅。清理注册到 t。
func (h *Harness) SubscribeSSE(t *testing.T, conversationID string) *SSESub {
	t.Helper()
	sub := &SSESub{
		t:            t,
		messages:     map[string]*chatdomain.Message{},
		blocks:       map[string]*chatdomain.Block{},
		streamELdone: make(chan struct{}),
		streamNFdone: make(chan struct{}),
	}

	elCtx, elCancel := context.WithCancel(context.Background())
	sub.cancelEventLog = elCancel
	elReq, err := http.NewRequestWithContext(elCtx, "GET",
		h.URL()+"/api/v1/eventlog?conversationId="+conversationID, nil)
	if err != nil {
		elCancel()
		t.Fatalf("build eventlog SSE request: %v", err)
	}
	elReq.Header.Set("Accept", "text/event-stream")
	noTimeoutClient := &http.Client{}
	elResp, err := noTimeoutClient.Do(elReq)
	if err != nil {
		elCancel()
		t.Fatalf("open eventlog SSE: %v", err)
	}
	if elResp.StatusCode != 200 {
		_ = elResp.Body.Close()
		elCancel()
		t.Fatalf("eventlog SSE: status %d", elResp.StatusCode)
	}
	sub.respEventLog = elResp

	nfCtx, nfCancel := context.WithCancel(context.Background())
	sub.cancelNotif = nfCancel
	nfReq, err := http.NewRequestWithContext(nfCtx, "GET",
		h.URL()+"/api/v1/notifications", nil)
	if err != nil {
		_ = elResp.Body.Close()
		elCancel()
		nfCancel()
		t.Fatalf("build notifications SSE request: %v", err)
	}
	nfReq.Header.Set("Accept", "text/event-stream")
	nfResp, err := noTimeoutClient.Do(nfReq)
	if err != nil {
		_ = elResp.Body.Close()
		elCancel()
		nfCancel()
		t.Fatalf("open notifications SSE: %v", err)
	}
	if nfResp.StatusCode != 200 {
		_ = elResp.Body.Close()
		_ = nfResp.Body.Close()
		elCancel()
		nfCancel()
		t.Fatalf("notifications SSE: status %d", nfResp.StatusCode)
	}
	sub.respNotif = nfResp

	go sub.readLoop(elResp.Body, "eventlog", sub.streamELdone)
	go sub.readLoop(nfResp.Body, "notifications", sub.streamNFdone)
	t.Cleanup(sub.Close)
	return sub
}

// Close terminates both subscriptions and waits for read loops to exit.
//
// Close 终止两个订阅并等读循环退出。
func (s *SSESub) Close() {
	s.mu.Lock()
	if s.closed {
		s.mu.Unlock()
		return
	}
	s.closed = true
	s.mu.Unlock()
	s.cancelEventLog()
	s.cancelNotif()
	_ = s.respEventLog.Body.Close()
	_ = s.respNotif.Body.Close()
	<-s.streamELdone
	<-s.streamNFdone
}

func (s *SSESub) readLoop(body interface{ Read(p []byte) (int, error) }, source string, done chan struct{}) {
	defer close(done)
	scanner := bufio.NewScanner(body)
	scanner.Buffer(make([]byte, 64*1024), 4*1024*1024)

	var (
		curID, curType string
		dataLines      []string
	)
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			if curType != "" && len(dataLines) > 0 {
				data := strings.Join(dataLines, "\n")
				s.dispatch(RawEvent{
					Source: source,
					ID:     curID,
					Type:   curType,
					Data:   []byte(data),
					At:     time.Now(),
				})
			}
			curID, curType, dataLines = "", "", nil
			continue
		}
		if strings.HasPrefix(line, ":") {
			continue
		}
		if rest, ok := strings.CutPrefix(line, "id: "); ok {
			curID = rest
		} else if rest, ok := strings.CutPrefix(line, "event: "); ok {
			curType = rest
		} else if rest, ok := strings.CutPrefix(line, "data: "); ok {
			dataLines = append(dataLines, rest)
		}
	}
}

func (s *SSESub) dispatch(e RawEvent) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.raw = append(s.raw, e)

	if e.Source == "eventlog" {
		s.applyEventLog(e)
		return
	}
	s.applyNotification(e)
}

func (s *SSESub) applyEventLog(e RawEvent) {
	switch e.Type {
	case "message_start":
		var ev eventlogdomain.MessageStart
		if err := json.Unmarshal(e.Data, &ev); err != nil {
			s.t.Logf("SSE: malformed message_start: %v", err)
			return
		}
		attrsJSON := ""
		if len(ev.Attrs) > 0 {
			if b, err := json.Marshal(ev.Attrs); err == nil {
				attrsJSON = string(b)
			}
		}
		m := &chatdomain.Message{
			ID:             ev.ID,
			ConversationID: ev.ConversationID,
			ParentBlockID:  ev.ParentBlockID,
			Role:           ev.Role,
			Attrs:          attrsJSON,
			Status:         chatdomain.StatusStreaming,
		}
		if _, seen := s.messages[m.ID]; !seen {
			s.orderedMsgIDs = append(s.orderedMsgIDs, m.ID)
		}
		s.messages[m.ID] = m

	case "message_stop":
		var ev eventlogdomain.MessageStop
		if err := json.Unmarshal(e.Data, &ev); err != nil {
			s.t.Logf("SSE: malformed message_stop: %v", err)
			return
		}
		m := s.messages[ev.ID]
		if m == nil {
			return
		}
		m.Status = ev.Status
		m.StopReason = ev.StopReason
		m.ErrorCode = ev.ErrorCode
		m.ErrorMessage = ev.ErrorMessage
		m.InputTokens = ev.InputTokens
		m.OutputTokens = ev.OutputTokens

	case "block_start":
		var ev eventlogdomain.BlockStart
		if err := json.Unmarshal(e.Data, &ev); err != nil {
			s.t.Logf("SSE: malformed block_start: %v", err)
			return
		}
		attrsJSON := ""
		if len(ev.Attrs) > 0 {
			if b, err := json.Marshal(ev.Attrs); err == nil {
				attrsJSON = string(b)
			}
		}
		blk := &chatdomain.Block{
			ID:             ev.ID,
			ConversationID: ev.ConversationID,
			MessageID:      ev.MessageID,
			ParentBlockID:  ev.ParentID,
			Type:           ev.BlockType,
			Attrs:          attrsJSON,
			Status:         chatdomain.StatusStreaming,
		}
		s.blocks[blk.ID] = blk
		if m := s.messages[ev.MessageID]; m != nil {
			m.Blocks = append(m.Blocks, *blk)
		}

	case "block_delta":
		var ev eventlogdomain.BlockDelta
		if err := json.Unmarshal(e.Data, &ev); err != nil {
			s.t.Logf("SSE: malformed block_delta: %v", err)
			return
		}
		blk := s.blocks[ev.ID]
		if blk == nil {
			return
		}
		blk.Content += ev.Delta
		s.syncBlockIntoMessage(blk)

	case "block_stop":
		var ev eventlogdomain.BlockStop
		if err := json.Unmarshal(e.Data, &ev); err != nil {
			s.t.Logf("SSE: malformed block_stop: %v", err)
			return
		}
		blk := s.blocks[ev.ID]
		if blk == nil {
			return
		}
		blk.Status = ev.Status
		blk.Error = ev.Error
		s.syncBlockIntoMessage(blk)
	}
}

// syncBlockIntoMessage finds the (potentially mutated) block in its parent
// message's Blocks slice and refreshes the entry. Required because Blocks
// stores values, not pointers.
//
// syncBlockIntoMessage 在父 message.Blocks 切片中找到该 block 并刷新该项。
// Blocks 存值非指针，故须同步。
func (s *SSESub) syncBlockIntoMessage(blk *chatdomain.Block) {
	m := s.messages[blk.MessageID]
	if m == nil {
		return
	}
	for i := range m.Blocks {
		if m.Blocks[i].ID == blk.ID {
			m.Blocks[i] = *blk
			return
		}
	}
}

// notification envelope shape: {type, id, data, conversationId?}.
//
// notification envelope 形状: {type, id, data, conversationId?}。
type notificationEnvelope struct {
	Type           string          `json:"type"`
	ID             string          `json:"id"`
	Data           json.RawMessage `json:"data"`
	ConversationID string          `json:"conversationId,omitempty"`
}

func (s *SSESub) applyNotification(e RawEvent) {
	var env notificationEnvelope
	if err := json.Unmarshal(e.Data, &env); err != nil {
		s.t.Logf("SSE: malformed notification: %v", err)
		return
	}
	if env.Type == "conversation" {
		var c convdomain.Conversation
		if err := json.Unmarshal(env.Data, &c); err != nil {
			s.t.Logf("SSE: malformed conversation notification: %v", err)
			return
		}
		s.conv = &c
	}
}

// AllMessages returns reconstructed Message snapshots in arrival order.
//
// AllMessages 按到达顺序返回重构出的 Message 快照。
func (s *SSESub) AllMessages() []*chatdomain.Message {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]*chatdomain.Message, 0, len(s.orderedMsgIDs))
	for _, id := range s.orderedMsgIDs {
		out = append(out, copyMessage(s.messages[id]))
	}
	return out
}

// LastMessage returns the most-recently-started Message, or nil.
//
// LastMessage 返回最近开始的 Message，无则 nil。
func (s *SSESub) LastMessage() *chatdomain.Message {
	s.mu.Lock()
	defer s.mu.Unlock()
	if len(s.orderedMsgIDs) == 0 {
		return nil
	}
	return copyMessage(s.messages[s.orderedMsgIDs[len(s.orderedMsgIDs)-1]])
}

// MessageByID returns the reconstructed Message for id, or nil.
//
// MessageByID 返指定 id 的重构 Message，无则 nil。
func (s *SSESub) MessageByID(id string) *chatdomain.Message {
	s.mu.Lock()
	defer s.mu.Unlock()
	return copyMessage(s.messages[id])
}

// Conversation returns the latest conversation snapshot from notifications,
// or nil if none has arrived.
//
// Conversation 返 notifications 收到的最新 conversation 快照，无则 nil。
func (s *SSESub) Conversation() *convdomain.Conversation {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.conv == nil {
		return nil
	}
	c := *s.conv
	return &c
}

// RawEvents returns a copy of every event seen across both streams.
//
// RawEvents 返两条流上每条事件的拷贝。
func (s *SSESub) RawEvents() []RawEvent {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]RawEvent, len(s.raw))
	copy(out, s.raw)
	return out
}

// WaitForMessage polls the reconstructed messages until predicate is true.
// Fails the test on timeout.
//
// WaitForMessage 轮询重构的 messages 直到 predicate 真；超时 fail。
func (s *SSESub) WaitForMessage(predicate func(*chatdomain.Message) bool, timeout time.Duration) *chatdomain.Message {
	s.t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		s.mu.Lock()
		for _, id := range s.orderedMsgIDs {
			if m := s.messages[id]; m != nil && predicate(m) {
				out := copyMessage(m)
				s.mu.Unlock()
				return out
			}
		}
		s.mu.Unlock()
		time.Sleep(20 * time.Millisecond)
	}
	s.t.Fatalf("WaitForMessage: timed out after %s; saw %d messages, %d raw events",
		timeout, len(s.orderedMsgIDs), len(s.raw))
	return nil
}

// WaitForMessageStatus waits for a specific id to reach status. status="" means
// any non-streaming terminal status.
//
// WaitForMessageStatus 等指定 id 的 message 达到 status；status="" 任意终态。
func (s *SSESub) WaitForMessageStatus(id, status string, timeout time.Duration) *chatdomain.Message {
	s.t.Helper()
	return s.WaitForMessage(func(m *chatdomain.Message) bool {
		if m.ID != id {
			return false
		}
		if status == "" {
			return m.Status != "" &&
				m.Status != chatdomain.StatusStreaming &&
				m.Status != chatdomain.StatusPending
		}
		return m.Status == status
	}, timeout)
}

// WaitForAssistantTerminal waits for any assistant message to reach a
// non-streaming terminal status.
//
// WaitForAssistantTerminal 等任意 assistant 消息进入非 streaming 终态。
func (s *SSESub) WaitForAssistantTerminal(timeout time.Duration) *chatdomain.Message {
	s.t.Helper()
	return s.WaitForMessage(func(m *chatdomain.Message) bool {
		return m.Role == chatdomain.RoleAssistant &&
			(m.Status == chatdomain.StatusCompleted ||
				m.Status == chatdomain.StatusError ||
				m.Status == chatdomain.StatusCancelled)
	}, timeout)
}

// WaitForConversation polls for a conversation snapshot matching predicate.
// Conversation snapshots arrive via the notifications stream (autoTitle
// completion, future Create/Update/Delete).
//
// WaitForConversation 等满足 predicate 的 conversation 快照。conversation
// 快照走 notifications 流（autoTitle 完成、未来 Create/Update/Delete）。
func (s *SSESub) WaitForConversation(predicate func(*convdomain.Conversation) bool, timeout time.Duration) *convdomain.Conversation {
	s.t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		s.mu.Lock()
		if s.conv != nil && predicate(s.conv) {
			out := *s.conv
			s.mu.Unlock()
			return &out
		}
		s.mu.Unlock()
		time.Sleep(20 * time.Millisecond)
	}
	s.t.Fatalf("WaitForConversation: timed out after %s; saw %d raw events",
		timeout, len(s.raw))
	return nil
}

func copyMessage(m *chatdomain.Message) *chatdomain.Message {
	if m == nil {
		return nil
	}
	c := *m
	if len(m.Blocks) > 0 {
		c.Blocks = make([]chatdomain.Block, len(m.Blocks))
		copy(c.Blocks, m.Blocks)
	}
	return &c
}

// FormatRawEvents returns a multi-line debug string of every raw event seen,
// truncated for readability.
//
// FormatRawEvents 返多行 debug 字符串列每条原始事件（适当截断）。
func (s *SSESub) FormatRawEvents() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	var b strings.Builder
	for i, e := range s.raw {
		dataPreview := string(e.Data)
		if len(dataPreview) > 200 {
			dataPreview = dataPreview[:200] + "…"
		}
		fmt.Fprintf(&b, "  [%d] %s/%s id=%s data=%s\n",
			i, e.Source, e.Type, e.ID, dataPreview)
	}
	return b.String()
}
