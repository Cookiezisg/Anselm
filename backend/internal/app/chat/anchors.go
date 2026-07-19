// anchors.go builds the conversation's navigation anchor list (GET /conversations/{id}/anchors)
// — the transcript's 场次条 (scene strip): the sparse rows a reader jumps by. Anchor units follow
// the industry-converged rule: HUMAN content is the primary anchor and the hard boundary; machine
// actions never anchor alone — consecutive tool calls fold into ONE counted cluster row between
// anchors (Linear-style "similar + consecutive"), with three exceptions that surface individually
// because the user must see them: dangerous tool calls, compaction marks, and abnormal terminal
// turns. Pending human gates ride the top of the FIRST page only — they live in the in-memory
// humanloop broker (no DB table, intentionally ephemeral), so they are live state, not journal
// rows, and stay outside the keyset math.
//
// anchors.go 构建对话的导航锚点表（GET /conversations/{id}/anchors）——转录的**场次条**：读者赖以
// 跳转的稀疏行。锚点单位循业界收敛规则：**人类内容是主锚与硬边界**；机器动作从不单独成锚——锚点
// 之间的连续工具调用折叠为**一条带计数的簇行**（Linear 式「相似 + 连续」），仅三类例外逐条露出
// （用户必须看见）：危险工具调用、压缩标记、异常终态回合。待决人闸只骑**首页**顶部——它们活在内存
// humanloop broker（无表、有意 ephemeral），是活状态而非日志行，故置身 keyset 数学之外。

package chat

import (
	"context"
	"strings"
	"time"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	paginationpkg "github.com/sunweilin/anselm/backend/internal/pkg/pagination"
)

// Anchor kinds — the closed set of navigation units the 场次条 renders.
//
// Anchor 种类——场次条渲染的导航单位封闭集。
const (
	AnchorKindUser       = "user"       // a user turn (title = first-line excerpt) 用户回合
	AnchorKindGate       = "gate"       // a pending human interaction (broker, live) 待决人闸
	AnchorKindDanger     = "danger"     // a dangerous tool call 危险工具
	AnchorKindCompaction = "compaction" // a context-compaction mark 压缩标记
	AnchorKindAbnormal   = "abnormal"   // an assistant turn that ended error/cancelled 异常终态
	AnchorKindTools      = "tools"      // N consecutive machine actions, folded 折叠工具簇
)

// anchorExcerptMax caps a user-turn title (first line, runes). 用户回合节选上限（首行、按 rune）。
const anchorExcerptMax = 120

// Anchor is one navigation row. MessageID anchors the jump (?around=); BlockID pins the exact
// block for kinds born from a block (danger / compaction / tools' first call) and carries the
// tool_call id for a gate (whose messageId is unknown — the broker holds no message ref). Count
// is the folded size for tools. At is the source row's createdAt (a gate: now — live state).
//
// Anchor 是一条导航行。MessageID 锚定跳转（?around=）；BlockID 钉住确切 block（danger /
// compaction / tools 簇首个调用），gate 上则携 tool_call id（其 messageId 未知——broker 不持
// message 引用）。Count 是 tools 的折叠数。At 是来源行 createdAt（gate 为 now——活状态）。
type Anchor struct {
	Kind      string    `json:"kind"`
	MessageID string    `json:"messageId,omitempty"`
	BlockID   string    `json:"blockId,omitempty"`
	Title     string    `json:"title,omitempty"`
	Count     int       `json:"count,omitempty"`
	At        time.Time `json:"at"`
}

// ListAnchors returns one keyset page of the conversation's anchors, newest-first (N4:
// ?cursor & ?limit; the cursor keys (at, blockId|messageId)). The full anchor list is built
// from one lean store scan (no tool_result payloads ever read) and paged in memory — a single
// local user's conversation fits. Pending gates prepend the first page only and don't count
// toward limit (few, live). Ownership pre-check mirrors ListMessages (unknown → 404).
//
// ListAnchors 返回对话锚点的一页 keyset（最新在前；N4：?cursor & ?limit，游标键 (at,
// blockId|messageId)）。全量锚点表由一次 lean store 扫描建成（永不读 tool_result 大体）、内存
// 分页——单用户本地一个对话装得下。待决人闸只前置首页、不占 limit（少、活）。归属前置校验同
// ListMessages（未知 → 404）。
func (s *Service) ListAnchors(ctx context.Context, conversationID, cursor string, limit int) ([]Anchor, string, error) {
	if limit <= 0 {
		limit = 50
	}
	if _, err := s.deps.Conversations.Get(ctx, conversationID); err != nil {
		return nil, "", err
	}
	msgs, blocks, err := s.messages.ListAnchorSource(ctx, conversationID)
	if err != nil {
		return nil, "", err
	}
	anchors := buildAnchors(msgs, blocks) // oldest-first
	// Newest-first for the wire (the same ordering rule as every history read).
	// 反转为最新在前（与所有历史读同一排序规则）。
	for i, j := 0, len(anchors)-1; i < j; i, j = i+1, j-1 {
		anchors[i], anchors[j] = anchors[j], anchors[i]
	}

	start := 0
	if cursor != "" {
		var c paginationpkg.Cursor
		if err := paginationpkg.DecodeCursor(cursor, &c); err != nil {
			return nil, "", errorspkg.ErrInvalidRequest
		}
		// Skip until strictly past the cursor tuple in DESC order. 跳过至严格越过游标元组（降序）。
		for start < len(anchors) {
			a := anchors[start]
			if a.At.Before(c.Key) || (a.At.Equal(c.Key) && anchorSourceID(a) < c.ID) {
				break
			}
			start++
		}
	}
	page := anchors[start:]
	next := ""
	if len(page) > limit {
		last := page[limit-1]
		next, err = paginationpkg.EncodeCursor(paginationpkg.Cursor{Key: last.At, ID: anchorSourceID(last)})
		if err != nil {
			return nil, "", err
		}
		page = page[:limit]
	}
	if cursor == "" {
		// Live gates ride the first page's top — outside the keyset (they are broker state with
		// no journal row; a reconnect re-fetches page one anyway).
		// 活人闸骑首页顶——置身 keyset 之外（broker 态、无日志行；重连本就重拉首页）。
		pending := s.PendingInteractions(ctx, conversationID)
		if len(pending) > 0 {
			gates := make([]Anchor, 0, len(pending))
			now := time.Now().UTC()
			for _, req := range pending {
				gates = append(gates, Anchor{Kind: AnchorKindGate, BlockID: req.ToolCallID, Title: req.Tool, At: now})
			}
			page = append(gates, page...)
		}
	}
	return page, next, nil
}

// anchorSourceID is the cursor tiebreaker: the anchor's source row id (block-born kinds key by
// BlockID, message-born by MessageID).
//
// anchorSourceID 是游标 tiebreaker：锚的来源行 id（block 生的按 BlockID、message 生的按 MessageID）。
func anchorSourceID(a Anchor) string {
	if a.BlockID != "" {
		return a.BlockID
	}
	return a.MessageID
}

// buildAnchors walks the lean projections oldest-first and emits the anchor timeline. blocks
// arrive seq-ascending (conversation-global), grouped here by message; a running counter folds
// consecutive non-dangerous tool calls and flushes as ONE tools cluster whenever any real anchor
// punctuates the timeline (human content is the hard boundary; danger / compaction / abnormal
// also flush so the cluster always sits chronologically before its boundary).
//
// buildAnchors 以最旧在前走 lean 投影、产出锚点时间线。blocks 按 seq 升序（全对话）到达、在此按
// message 分组；游动计数器折叠连续非危险工具调用，遇任何真锚打点即整簇 flush（人类内容是硬边界；
// danger / compaction / abnormal 同样触发 flush，使簇恒按时序落在其边界之前）。
func buildAnchors(msgs []*messagesdomain.Message, blocks []*messagesdomain.Block) []Anchor {
	byMsg := make(map[string][]*messagesdomain.Block, len(msgs))
	for _, b := range blocks {
		byMsg[b.MessageID] = append(byMsg[b.MessageID], b)
	}
	var out []Anchor
	var cluster struct {
		count int
		first *messagesdomain.Block
	}
	flush := func() {
		if cluster.count == 0 {
			return
		}
		out = append(out, Anchor{
			Kind:      AnchorKindTools,
			MessageID: cluster.first.MessageID,
			BlockID:   cluster.first.ID,
			Count:     cluster.count,
			At:        cluster.first.CreatedAt,
		})
		cluster.count, cluster.first = 0, nil
	}
	for _, m := range msgs {
		if m.Role == messagesdomain.RoleUser {
			flush()
			title := ""
			for _, b := range byMsg[m.ID] {
				if b.Type == messagesdomain.BlockTypeText {
					title = excerptFirstLine(b.Content, anchorExcerptMax)
					break
				}
			}
			out = append(out, Anchor{Kind: AnchorKindUser, MessageID: m.ID, Title: title, At: m.CreatedAt})
			continue
		}
		for _, b := range byMsg[m.ID] {
			switch {
			case b.Type == messagesdomain.BlockTypeCompaction:
				flush()
				out = append(out, Anchor{Kind: AnchorKindCompaction, MessageID: m.ID, BlockID: b.ID, Title: excerptFirstLine(b.Content, anchorExcerptMax), At: b.CreatedAt})
			case b.Type == messagesdomain.BlockTypeToolCall && b.Attrs["danger"] == "dangerous":
				flush()
				title, _ := b.Attrs["tool"].(string)
				if name, _ := b.Attrs["entityName"].(string); name != "" {
					title += " · " + name
				}
				out = append(out, Anchor{Kind: AnchorKindDanger, MessageID: m.ID, BlockID: b.ID, Title: title, At: b.CreatedAt})
			case b.Type == messagesdomain.BlockTypeToolCall:
				if cluster.count == 0 {
					cluster.first = b
				}
				cluster.count++
			}
		}
		if m.Status == messagesdomain.StatusError || m.Status == messagesdomain.StatusCancelled {
			flush()
			title := m.StopReason
			if title == "" {
				title = m.ErrorCode
			}
			if title == "" {
				title = m.Status
			}
			out = append(out, Anchor{Kind: AnchorKindAbnormal, MessageID: m.ID, Title: title, At: m.CreatedAt})
		}
	}
	flush()
	return out
}

// excerptFirstLine returns the first non-empty line, rune-capped with an ellipsis.
//
// excerptFirstLine 返回首个非空行，按 rune 截断加省略号。
func excerptFirstLine(s string, maxRunes int) string {
	for _, line := range strings.Split(s, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		r := []rune(line)
		if len(r) > maxRunes {
			return string(r[:maxRunes]) + "…"
		}
		return line
	}
	return ""
}
