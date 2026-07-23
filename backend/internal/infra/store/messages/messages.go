// Package messages is the orm-backed messagesdomain.Repository: a conversation's content
// journal — the `messages` table (turn records) + `message_blocks` (the Block tree). Both are
// append-only (no deleted_at, D1: a conversation's content is never deleted) and
// workspace-isolated (orm fills/filters workspace_id from ctx via the ,ws tag), so no method
// hand-writes a workspace predicate.
//
// A turn is written in two phases — CreateMessage opens it (and writes a user turn's lone text
// block), FinalizeMessage closes an assistant turn with terminal status + token accounting +
// its blocks — each inside one transaction so the message row and its blocks land atomically.
// Block seq is allocated MAX+1 per conversation inside that transaction; correctness relies on
// chat's per-conversation queue serializing writes (one AI goroutine per conversation), not on
// a DB sequence.
//
// Package messages 是 messagesdomain.Repository 的 orm 实现：一个对话的内容日志——`messages`
// 表（回合记录）+ `message_blocks`（Block 树）。两表皆 append-only（无 deleted_at，D1：对话内容
// 永不删）、按 workspace 隔离（orm 据 ctx 经 ,ws tag 填/过滤），故无方法手写 workspace 谓词。
//
// 回合两段式写——CreateMessage 开（并写 user 回合的单个 text block）、FinalizeMessage 以终态 +
// token 记账 + blocks 收 assistant 回合——各在一个事务内，使 message 行与其 blocks 原子落盘。
// block seq 在该事务内按对话 MAX+1 分配；正确性靠 chat 的 per-conversation 队列串行写
// （每对话一个 AI 协程）、而非 DB 序列。
package messages

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	paginationpkg "github.com/sunweilin/anselm/backend/internal/pkg/pagination"
)

// Schema is the two tables' DDL, exported as ordered idempotent statements for bootstrap to
// collect via db.Migrate. Both are append-only (no deleted_at, D1). message_blocks' UNIQUE
// (conversation_id, seq) is the seq monotonicity guarantee (idx_blocks_conv_seq); type /
// status / context_role are CHECK-closed so a bad value can never reach the LLM history.
//
// Schema 是两表 DDL，按序幂等导出。两表 append-only（无 deleted_at，D1）。message_blocks 的
// UNIQUE(conversation_id, seq) 即 seq 单调保证（idx_blocks_conv_seq）；type / status /
// context_role 用 CHECK 闭合，坏值永不进 LLM 历史。
var Schema = []string{
	`CREATE TABLE IF NOT EXISTS messages (
		id              TEXT PRIMARY KEY,
		workspace_id    TEXT NOT NULL,
		conversation_id TEXT NOT NULL,
		subagent_id     TEXT NOT NULL DEFAULT '',
		role            TEXT NOT NULL CHECK(role IN ('user','assistant')),
		status          TEXT NOT NULL DEFAULT 'completed' CHECK(status IN ('pending','streaming','completed','error','cancelled')),
		stop_reason     TEXT NOT NULL DEFAULT '',
		error_code      TEXT NOT NULL DEFAULT '',
		error_message   TEXT NOT NULL DEFAULT '',
		input_tokens    INTEGER NOT NULL DEFAULT 0,
		output_tokens   INTEGER NOT NULL DEFAULT 0,
		provider        TEXT NOT NULL DEFAULT '',
		model_id        TEXT NOT NULL DEFAULT '',
		attrs           TEXT NOT NULL DEFAULT 'null',
		created_at      DATETIME NOT NULL,
		updated_at      DATETIME NOT NULL
	)`,
	`CREATE INDEX IF NOT EXISTS idx_messages_conv ON messages(workspace_id, conversation_id, created_at, id)`,

	`CREATE TABLE IF NOT EXISTS message_blocks (
		id              TEXT PRIMARY KEY,
		workspace_id    TEXT NOT NULL,
		conversation_id TEXT NOT NULL,
		message_id      TEXT NOT NULL,
		parent_block_id TEXT NOT NULL DEFAULT '',
		seq             INTEGER NOT NULL,
		type            TEXT NOT NULL CHECK(type IN ('text','reasoning','tool_call','tool_result','compaction','progress')),
		attrs           TEXT NOT NULL DEFAULT 'null',
		content         TEXT NOT NULL DEFAULT '',
		status          TEXT NOT NULL CHECK(status IN ('pending','streaming','completed','error','cancelled')),
		error           TEXT NOT NULL DEFAULT '',
		context_role    TEXT NOT NULL DEFAULT 'hot' CHECK(context_role IN ('hot','warm','cold','archived')),
		created_at      DATETIME NOT NULL,
		updated_at      DATETIME NOT NULL
	)`,
	`CREATE UNIQUE INDEX IF NOT EXISTS idx_blocks_conv_seq ON message_blocks(conversation_id, seq)`,
	`CREATE INDEX IF NOT EXISTS idx_blocks_message ON message_blocks(message_id, seq)`,
}

// Store implements messagesdomain.Repository over pkg/orm. It keeps root-bound repos for reads
// and rebuilds tx-bound repos inside Transaction for the atomic two-table writes.
//
// Store 基于 pkg/orm 实现 messagesdomain.Repository。读用根绑定 repo，写在 Transaction 内重建
// tx 绑定 repo 以原子写两表。
type Store struct {
	db     *ormpkg.DB
	msgs   *ormpkg.Repo[messagesdomain.Message]
	blocks *ormpkg.Repo[messagesdomain.Block]
}

// New constructs a Store bound to the messages + message_blocks tables.
//
// New 构造绑定 messages + message_blocks 表的 Store。
func New(db *ormpkg.DB) *Store {
	return &Store{
		db:     db,
		msgs:   ormpkg.For[messagesdomain.Message](db, "messages"),
		blocks: ormpkg.For[messagesdomain.Block](db, "message_blocks"),
	}
}

var _ messagesdomain.Repository = (*Store)(nil)

func (s *Store) CreateMessage(ctx context.Context, m *messagesdomain.Message, blocks []messagesdomain.Block) error {
	return s.db.Transaction(ctx, func(tx *ormpkg.DB) error {
		if err := ormpkg.For[messagesdomain.Message](tx, "messages").Create(ctx, m); err != nil {
			return fmt.Errorf("messagesstore.CreateMessage: insert message: %w", err)
		}
		return insertBlocks(ctx, tx, m, blocks)
	})
}

func (s *Store) FinalizeMessage(ctx context.Context, m *messagesdomain.Message, blocks []messagesdomain.Block) error {
	return s.db.Transaction(ctx, func(tx *ormpkg.DB) error {
		attrs, err := json.Marshal(m.Attrs)
		if err != nil {
			return fmt.Errorf("messagesstore.FinalizeMessage: marshal attrs: %w", err)
		}
		// Partial update of terminal fields only (not Save), so a finalize never touches
		// created_at / role / conversation_id — and Updates' WHERE carries the auto workspace
		// filter, so n==0 means "no such message in this workspace".
		//
		// 仅部分更新终态字段（非 Save），使 finalize 不碰 created_at / role / conversation_id——
		// 且 Updates 的 WHERE 带自动 workspace 过滤，n==0 即「本 workspace 无此 message」。
		n, err := ormpkg.For[messagesdomain.Message](tx, "messages").
			WhereEq("id", m.ID).
			Updates(ctx, map[string]any{
				"status":        m.Status,
				"stop_reason":   m.StopReason,
				"error_code":    m.ErrorCode,
				"error_message": m.ErrorMessage,
				"input_tokens":  m.InputTokens,
				"output_tokens": m.OutputTokens,
				"provider":      m.Provider,
				"model_id":      m.ModelID,
				"attrs":         string(attrs),
			})
		if err != nil {
			return fmt.Errorf("messagesstore.FinalizeMessage: update message: %w", err)
		}
		if n == 0 {
			return messagesdomain.ErrMessageNotFound
		}
		return insertBlocks(ctx, tx, m, blocks)
	})
}

func (s *Store) GetMessage(ctx context.Context, id string) (*messagesdomain.Message, error) {
	m, err := s.msgs.Get(ctx, id)
	if errors.Is(err, ormpkg.ErrNotFound) {
		return nil, messagesdomain.ErrMessageNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("messagesstore.GetMessage: %w", err)
	}
	if err := s.hydrate(ctx, []*messagesdomain.Message{m}); err != nil {
		return nil, err
	}
	return m, nil
}

// ListMessages returns one keyset page, newest-first (orm Page is DESC on (created_at, id)) —
// the chat-history fetch pattern: load the most recent turns, page backwards for older ones.
// The front end renders chronologically by reversing a page; LoadThread serves the LLM's
// chronological need separately.
//
// ListMessages 返回一页 keyset，最新在前（orm Page 按 (created_at, id) 降序）——chat 历史拉取范式：
// 取最近回合、向后翻更旧。前端按时序渲染时反转一页；LLM 的时序需求由 LoadThread 另行满足。
func (s *Store) ListMessages(ctx context.Context, conversationID, cursor string, limit int) ([]*messagesdomain.Message, string, error) {
	rows, next, err := s.msgs.WhereEq("conversation_id", conversationID).Page(ctx, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("messagesstore.ListMessages: %w", err)
	}
	if err := s.hydrate(ctx, rows); err != nil {
		return nil, "", err
	}
	return rows, next, nil
}

// ListMessagesNewer returns one keyset page WALKING FORWARD in time from the cursor (orm
// PageTimeAsc, `(created_at, id) > cursor` ascending) — the ?dir=newer continuation of an
// ?around= window. Rows come back oldest-first (the query's natural order); the app layer
// reverses to the wire's single newest-first rule. An empty cursor would mean "everything from
// the dawn of the conversation" — the app layer rejects it before reaching here.
//
// ListMessagesNewer 返回沿时间**向前**走的一页 keyset（orm PageTimeAsc，`(created_at, id) >
// cursor` 升序）——?around= 窗口的 ?dir=newer 续翻。行按查询自然序（最旧在前）返回；app 层反转成
// 线缆唯一的 newest-first 规则。空 cursor 意为「从对话开天辟地起」——app 层在到达此处前拒绝。
func (s *Store) ListMessagesNewer(ctx context.Context, conversationID, cursor string, limit int) ([]*messagesdomain.Message, string, error) {
	rows, next, err := s.msgs.WhereEq("conversation_id", conversationID).PageTimeAsc(ctx, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("messagesstore.ListMessagesNewer: %w", err)
	}
	if err := s.hydrate(ctx, rows); err != nil {
		return nil, "", err
	}
	return rows, next, nil
}

// ListMessagesAround returns a window of turns centered on target — the deep-history jump read
// (?around=). The target's (created_at, id) tuple becomes the pivot cursor for BOTH halves:
// the older half rides Page (DESC, `< pivot`), the newer half rides PageTimeAsc (ASC,
// `> pivot`); limit splits limit/2 older + the rest newer (the target itself is extra and
// always included, Matrix /context semantics; limit is clamped to ≥ 2 so both halves get a
// real query). The window is assembled newest-first (the wire's single ordering rule) and
// hydrated in one query. olderCursor/newerCursor are the two continuation cursors ("" =
// that direction is exhausted): older feeds the plain ?cursor= list, newer feeds ?dir=newer.
// A target that does not exist — or belongs to another conversation (identity anchoring: our
// anchor ids all come from within the transcript) — is ErrMessageNotFound.
//
// ListMessagesAround 返回以 target 为中心的一窗回合——深历史跳转读（?around=）。target 的
// (created_at, id) 元组作两半的支点游标：旧半走 Page（降序 `< pivot`）、新半走 PageTimeAsc
// （升序 `> pivot`）；limit 按 limit/2 旧 + 余数新拆分（target 本身额外、恒返回，Matrix
// /context 语义；limit 钳到 ≥ 2 使两半都有真查询）。窗口按 newest-first（线缆唯一排序规则）
// 组装、一次 hydrate。olderCursor/newerCursor 是两枚续翻游标（"" = 该方向已尽）：旧喂普通
// ?cursor=、新喂 ?dir=newer。target 不存在——或属别的对话（身份锚点派：锚 id 全来自转录内）
// ——即 ErrMessageNotFound。
func (s *Store) ListMessagesAround(ctx context.Context, conversationID, targetID string, limit int) (window []*messagesdomain.Message, olderCursor, newerCursor string, hasOlder, hasNewer bool, err error) {
	if limit < 2 {
		limit = 2
	}
	target, err := s.msgs.Get(ctx, targetID)
	if errors.Is(err, ormpkg.ErrNotFound) {
		return nil, "", "", false, false, messagesdomain.ErrMessageNotFound
	}
	if err != nil {
		return nil, "", "", false, false, fmt.Errorf("messagesstore.ListMessagesAround: get target: %w", err)
	}
	if target.ConversationID != conversationID {
		return nil, "", "", false, false, messagesdomain.ErrMessageNotFound
	}
	pivot, err := paginationpkg.EncodeCursor(paginationpkg.Cursor{Key: target.CreatedAt, ID: target.ID})
	if err != nil {
		return nil, "", "", false, false, fmt.Errorf("messagesstore.ListMessagesAround: pivot: %w", err)
	}
	beforeN := limit / 2
	afterN := limit - beforeN
	older, olderNext, err := s.msgs.WhereEq("conversation_id", conversationID).Page(ctx, pivot, beforeN)
	if err != nil {
		return nil, "", "", false, false, fmt.Errorf("messagesstore.ListMessagesAround: older half: %w", err)
	}
	newer, newerNext, err := s.msgs.WhereEq("conversation_id", conversationID).PageTimeAsc(ctx, pivot, afterN)
	if err != nil {
		return nil, "", "", false, false, fmt.Errorf("messagesstore.ListMessagesAround: newer half: %w", err)
	}
	window = make([]*messagesdomain.Message, 0, len(older)+len(newer)+1)
	for i := len(newer) - 1; i >= 0; i-- { // ASC → newest-first
		window = append(window, newer[i])
	}
	window = append(window, target)
	window = append(window, older...) // already newest-first
	if err := s.hydrate(ctx, window); err != nil {
		return nil, "", "", false, false, err
	}
	return window, olderNext, newerNext, olderNext != "", newerNext != "", nil
}

// ListAnchorSource returns the lean projections the anchors builder walks: every turn row
// (oldest-first, NO block hydrate — the whole point is not to pull tool_result payloads) plus
// the anchor-relevant blocks only — machine anchors (tool_call + compaction, whole
// conversation) and the text blocks of user turns (excerpt source), merged seq-ascending.
// Assistant prose / tool_result / progress blocks are never read.
//
// ListAnchorSource 返回 anchors 构建器要走的 lean 投影：全部回合行（最旧在前、**不** hydrate
// block——要义正是不拉 tool_result 大体）+ 仅锚点相关的 block——机器锚（tool_call + compaction，
// 全对话）与 user 回合的 text block（节选来源），按 seq 升序归并。assistant 散文 / tool_result /
// progress 永不读盘。
func (s *Store) ListAnchorSource(ctx context.Context, conversationID string) ([]*messagesdomain.Message, []*messagesdomain.Block, error) {
	msgs, err := s.msgs.WhereEq("conversation_id", conversationID).Order("created_at ASC, id ASC").Find(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("messagesstore.ListAnchorSource: messages: %w", err)
	}
	machine, err := s.blocks.WhereEq("conversation_id", conversationID).
		WhereIn("type", messagesdomain.BlockTypeToolCall, messagesdomain.BlockTypeCompaction).
		Order("seq ASC").Find(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("messagesstore.ListAnchorSource: machine blocks: %w", err)
	}
	var userIDs []any
	for _, m := range msgs {
		if m.Role == messagesdomain.RoleUser {
			userIDs = append(userIDs, m.ID)
		}
	}
	var userText []*messagesdomain.Block
	if len(userIDs) > 0 {
		userText, err = s.blocks.WhereIn("message_id", userIDs...).
			WhereEq("type", messagesdomain.BlockTypeText).
			Order("seq ASC").Find(ctx)
		if err != nil {
			return nil, nil, fmt.Errorf("messagesstore.ListAnchorSource: user text: %w", err)
		}
	}
	// Merge the two seq-sorted streams (seq is conversation-global, so one ordered walk).
	// 归并两条按 seq 有序的流（seq 全对话单调，可单次有序走）。
	blocks := make([]*messagesdomain.Block, 0, len(machine)+len(userText))
	i, j := 0, 0
	for i < len(machine) && j < len(userText) {
		if machine[i].Seq < userText[j].Seq {
			blocks = append(blocks, machine[i])
			i++
		} else {
			blocks = append(blocks, userText[j])
			j++
		}
	}
	blocks = append(blocks, machine[i:]...)
	blocks = append(blocks, userText[j:]...)
	return msgs, blocks, nil
}

// LoadThread returns the whole conversation oldest-first (Find with an ASC order, not Page) —
// the chronological source chat's LoadHistory composes LLM history from. Unpaginated: a single
// local user's thread fits in memory.
//
// LoadThread 返回整个对话、最旧在前（Find + ASC order，非 Page）——chat 的 LoadHistory 据此组装
// LLM 历史的时序来源。不分页：单用户本地一条线程可装进内存。
func (s *Store) LoadThread(ctx context.Context, conversationID string) ([]*messagesdomain.Message, error) {
	rows, err := s.msgs.WhereEq("conversation_id", conversationID).Order("created_at ASC, id ASC").Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("messagesstore.LoadThread: %w", err)
	}
	if err := s.hydrate(ctx, rows); err != nil {
		return nil, err
	}
	return rows, nil
}

// LoadThreadForLLM returns the conversation oldest-first for LLM-history assembly: it drops subagent
// sub-messages at the message level (subagent_id = ”, never part of the parent's LLM history) and
// hydrates each turn with only its blocks past the compaction watermark (seq > minSeq, the folded
// rows whose content now lives in conversation.summary). This is the read-minimized path — the
// folded/subagent rows are never read from disk — replacing the prior full LoadThread + post-read Go
// filtering on the hot LLM-history path. minSeq ≤ 0 reads every block (no compaction yet).
//
// LoadThreadForLLM 返回对话（最旧在前）供组装 LLM 历史：在消息层丢 subagent 子消息（subagent_id = ”、
// 从不属父 LLM 历史），每回合只 hydrate 越过压缩水位的 block（seq > minSeq、内容已并入 conversation.summary
// 的已折叠行）。这是读最小化路径——已折叠/subagent 行从不读盘——替代 LLM-history 热路径上原本的整 LoadThread +
// 读后 Go 过滤。minSeq ≤ 0 读所有 block（尚无压缩）。
func (s *Store) LoadThreadForLLM(ctx context.Context, conversationID string, minSeq int64) ([]*messagesdomain.Message, error) {
	rows, err := s.msgs.
		WhereEq("conversation_id", conversationID).
		WhereEq("subagent_id", "").
		Order("created_at ASC, id ASC").
		Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("messagesstore.LoadThreadForLLM: %w", err)
	}
	if err := s.hydrateMinSeq(ctx, rows, minSeq); err != nil {
		return nil, err
	}
	return rows, nil
}

// SumTokens totals a conversation's input + output tokens. It loads the turn rows (no blocks)
// and sums in Go — a single conversation's turns fit in memory, and the orm workspace filter
// keeps it scoped. Empty conversation → (0, 0).
//
// SumTokens 求和一个对话的 input + output token。加载回合行（不取 block）在 Go 里累加——单对话回合
// 可装进内存、orm workspace 过滤限定范围。空对话 → (0, 0)。
func (s *Store) SumTokens(ctx context.Context, conversationID string) (int, int, error) {
	rows, err := s.msgs.WhereEq("conversation_id", conversationID).Find(ctx)
	if err != nil {
		return 0, 0, fmt.Errorf("messagesstore.SumTokens: %w", err)
	}
	var in, out int
	for _, m := range rows {
		in += m.InputTokens
		out += m.OutputTokens
	}
	return in, out, nil
}

// UpdateBlocksContextRole batch-updates context_role for the given block ids (one statement via
// WhereIn). Mirrors FinalizeMessage's partial Updates (auto workspace filter in the WHERE); the
// stored content is never touched — only the projection role.
//
// UpdateBlocksContextRole 按给定 block id 批量更新 context_role（WhereIn 一条语句）。镜像
// FinalizeMessage 的部分 Updates（WHERE 带自动 workspace 过滤）；落库 content 永不动——只改投影角色。
func (s *Store) UpdateBlocksContextRole(ctx context.Context, blockIDs []string, role string) error {
	if len(blockIDs) == 0 {
		return nil
	}
	ids := make([]any, len(blockIDs))
	for i, id := range blockIDs {
		ids[i] = id
	}
	if _, err := s.blocks.WhereIn("id", ids...).Updates(ctx, map[string]any{"context_role": role}); err != nil {
		return fmt.Errorf("messagesstore.UpdateBlocksContextRole: %w", err)
	}
	return nil
}

// hydrate loads every block of the given messages in one query and attaches each message's
// blocks (seq-ordered) to its Blocks field. A message with no blocks gets a nil slice.
//
// hydrate 一次查出给定 messages 的所有 block，把每个 message 的 block（按 seq 排序）挂到其
// Blocks 字段。无 block 的 message 得 nil 切片。
func (s *Store) hydrate(ctx context.Context, msgs []*messagesdomain.Message) error {
	return s.hydrateMinSeq(ctx, msgs, 0)
}

// hydrateMinSeq is hydrate with an optional block-level watermark filter: when minSeq > 0 only blocks
// with seq > minSeq are read from disk (the compaction-folded rows are never pulled). minSeq ≤ 0 is
// the full hydrate. Both load all blocks of the given messages in ONE query.
//
// hydrateMinSeq 是带可选 block 级水位过滤的 hydrate：minSeq > 0 时只从盘读 seq > minSeq 的 block
// （压缩已折叠行从不拉取）。minSeq ≤ 0 即全量 hydrate。两者都用一条查询取给定 messages 的全部 block。
func (s *Store) hydrateMinSeq(ctx context.Context, msgs []*messagesdomain.Message, minSeq int64) error {
	if len(msgs) == 0 {
		return nil
	}
	ids := make([]any, len(msgs))
	for i, m := range msgs {
		ids[i] = m.ID
	}
	q := s.blocks.WhereIn("message_id", ids...)
	if minSeq > 0 {
		q = q.Where("seq > ?", minSeq)
	}
	blocks, err := q.Order("seq ASC").Find(ctx)
	if err != nil {
		return fmt.Errorf("messagesstore.hydrate: %w", err)
	}
	byMsg := make(map[string][]messagesdomain.Block, len(msgs))
	for _, b := range blocks {
		byMsg[b.MessageID] = append(byMsg[b.MessageID], *b)
	}
	for _, m := range msgs {
		m.Blocks = byMsg[m.ID]
	}
	return nil
}

// insertBlocks assigns each block a fresh id (if empty), the turn's conversation + message ids,
// a monotonic per-conversation seq, and default status / context_role, then inserts it. It
// mutates the caller's slice in place so the caller sees the assigned ids / seq (orm also fills
// workspace_id + timestamps). The MAX+1 read happens once, before the loop.
//
// insertBlocks 给每个 block 赋新 id（若空）、回合的 conversation + message id、对话内单调 seq、
// 默认 status / context_role，然后插入。原地改 caller 切片，使 caller 看到分配的 id / seq
// （orm 还填 workspace_id + 时间戳）。MAX+1 在循环前读一次。
func insertBlocks(ctx context.Context, tx *ormpkg.DB, m *messagesdomain.Message, blocks []messagesdomain.Block) error {
	if len(blocks) == 0 {
		return nil
	}
	blockRepo := ormpkg.For[messagesdomain.Block](tx, "message_blocks")
	seq, err := nextSeq(ctx, blockRepo, m.ConversationID)
	if err != nil {
		return err
	}
	for i := range blocks {
		if blocks[i].ID == "" {
			blocks[i].ID = idgenpkg.New("blk")
		}
		blocks[i].ConversationID = m.ConversationID
		blocks[i].MessageID = m.ID
		blocks[i].Seq = seq
		seq++
		if blocks[i].Status == "" {
			blocks[i].Status = messagesdomain.StatusCompleted
		}
		if blocks[i].ContextRole == "" {
			blocks[i].ContextRole = messagesdomain.ContextRoleHot
		}
		if err := blockRepo.Create(ctx, &blocks[i]); err != nil {
			return fmt.Errorf("messagesstore: insert block %d: %w", i, err)
		}
	}
	return nil
}

// nextSeq returns MAX(seq)+1 for the conversation (1 when none yet). The orm auto workspace
// filter applies, but conversation_id is globally unique so it only ever sees one workspace's
// rows anyway.
//
// nextSeq 返回该对话的 MAX(seq)+1（无则 1）。orm 自动 workspace 过滤生效，但 conversation_id
// 全局唯一、本就只见一个 workspace 的行。
func nextSeq(ctx context.Context, blockRepo *ormpkg.Repo[messagesdomain.Block], conversationID string) (int64, error) {
	var seqs []int64
	if err := blockRepo.WhereEq("conversation_id", conversationID).Order("seq DESC").Limit(1).Pluck(ctx, "seq", &seqs); err != nil {
		return 0, fmt.Errorf("messagesstore.nextSeq: %w", err)
	}
	if len(seqs) == 0 {
		return 1, nil
	}
	return seqs[0] + 1, nil
}

// SweepNonTerminal force-finalizes orphaned non-terminal turns (boot reconciliation after a
// hard crash). Messages stuck pending/streaming become cancelled with stop_reason=cancelled;
// their streaming blocks close the same way. Workspace-scoped via ctx like every other method.
//
// SweepNonTerminal 强制收尾孤儿非终态回合（硬崩溃后的 boot 对账）。卡在 pending/streaming 的
// message 置 cancelled + stop_reason=cancelled；其 streaming block 同步收尾。与其它方法一样经
// ctx 按 workspace 隔离。
func (s *Store) SweepNonTerminal(ctx context.Context) (int, error) {
	n, err := s.msgs.WhereIn("status", messagesdomain.StatusPending, messagesdomain.StatusStreaming).
		Updates(ctx, map[string]any{
			"status":      messagesdomain.StatusCancelled,
			"stop_reason": messagesdomain.StopReasonCancelled,
		})
	if err != nil {
		return 0, fmt.Errorf("messagesstore.SweepNonTerminal: %w", err)
	}
	if _, err := s.blocks.WhereIn("status", messagesdomain.StatusStreaming).
		Updates(ctx, map[string]any{"status": messagesdomain.StatusCancelled}); err != nil {
		return 0, fmt.Errorf("messagesstore.SweepNonTerminal: blocks: %w", err)
	}
	return int(n), nil
}
