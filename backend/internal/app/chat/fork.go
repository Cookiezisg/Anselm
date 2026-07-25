package chat

import (
	"context"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
)

// Fork branches a conversation into a NEW thread carrying the prefix up to and including
// atMessageID, leaving the source untouched. Empty atMessageID = fork at the latest message (the
// rail's "fork this conversation"); a message-less source yields a config-only copy.
//
// Why a new thread rather than an in-tree branch: messages / message_blocks are D1 Log tables
// (append-only, no deleted_at), so a branch pointer would have to rewrite seq, the three read
// forms, the SSE contract and the frontend reducer. A prefix copy is PURE APPEND — zero deletes,
// zero mutations of the source.
//
// What is NOT copied, on purpose: touchpoints / relations / notifications / flowruns / todos are
// the SOURCE's history, not the fork's, and the humanloop always-allow whitelist is keyed by
// conversation id so the fork re-earns every grant (matching Claude Code's --fork-session
// re-authorization semantics). Attachments ARE shared, not copied: they are content-addressed
// (att_ rows + sha256 blobs, no conversation_id), the user-turn Attrs snapshot carries only ids,
// and GC keeps a sha alive while any workspace row references it.
//
// Fork 把一个对话分叉成一条**新**线程，承载直到 atMessageID（含它）的前缀，源线程分毫不动。
// atMessageID 为空 = 从最新处分叉（左岛 rail 的「分叉对话」）；无消息的源产出纯配置副本。
//
// 为何是新线程而非树内分支：messages / message_blocks 是 D1 Log 表（append-only、无 deleted_at），
// 树内分支得动 seq、三读形态、SSE 契约与前端 reducer。前缀复制是**纯追加**——零删除、对源零改写。
//
// **刻意不复制**：touchpoint / relation / 通知 / flowrun / todos 都是**源**的历史、不是分叉的；人闸
// always-allow 白名单按对话 id 键，故分叉重新赢取每一次授权（与 Claude Code `--fork-session` 的重授权
// 语义一致）。附件是**共享而非复制**：它内容寻址（att_ 行 + sha256 blob、无 conversation_id），user
// 回合 Attrs 快照里只有 id，且 GC 只要还有 workspace 行引用某 sha 就保活它。
func (s *Service) Fork(ctx context.Context, conversationID, atMessageID string) (*conversationdomain.Conversation, error) {
	src, err := s.deps.Conversations.Get(ctx, conversationID)
	if err != nil {
		return nil, err
	}
	// LoadThread (not LoadThreadForLLM) is the read: a fork copies the DURABLE truth, so subagent
	// rows and compaction-folded blocks come along. The LLM view is re-derived from the fork's own
	// summary watermark + subagent filter at assembly time, exactly as it is for the source.
	//
	// 读用 LoadThread（非 LoadThreadForLLM）：分叉复制**耐久真相**，故 subagent 行与已折叠 block 一并
	// 带走。LLM 视图在装配时由分叉自己的摘要水位 + subagent 过滤重新求得，与源一模一样。
	thread, err := s.messages.LoadThread(ctx, conversationID)
	if err != nil {
		return nil, err
	}
	prefix, err := forkPrefix(thread, atMessageID)
	if err != nil {
		return nil, err
	}

	// Mint every copied block's new id BEFORE the first insert: parent_block_id may point at a block
	// in an EARLIER message (a subagent turn hangs off its parent turn's tool_call block), so the
	// whole remap table has to exist before any row lands. The planned new seq rides the same walk —
	// insertBlocks hands out seq contiguously in replay order, so the running index IS the seq the
	// block will get.
	//
	// 在首次插入**之前**铸出每个被复制 block 的新 id：parent_block_id 可能指向**更早**消息里的 block
	// （subagent 回合挂在其父回合的 tool_call block 上），故整张 remap 表必须在任何行落地前就存在。
	// 计划新 seq 随同一次走查得出——insertBlocks 按重放顺序连续发 seq，故这个计数**就是**该 block 将得的 seq。
	// The MESSAGE ids are pre-minted in the same walk, for the same reason: a retried turn's rows point
	// at each other (superseded_by forward, attrs.retryOf back), so a copy that kept the SOURCE's ids
	// would leave the fork's version chain pointing into the source thread — and, worse, would reset
	// every copied superseded_by to '' and hand the model TWO versions of the same turn.
	//
	// **message id 也在同一次走查里预铸**，理由相同：一个被重试过的回合，它的行彼此**互指**（superseded_by
	// 向前、attrs.retryOf 向后），故一份保留**源** id 的复制会让分叉的版本链指进源线程——更糟的是，会把每条
	// 被复制行的 superseded_by 重置成 ''，于是模型拿到同一回合的**两个**版本。
	newMsgID := make(map[string]string, len(prefix))
	newBlockID := make(map[string]string)
	newBlockSeq := make(map[string]int64)
	var plannedSeq int64
	for _, m := range prefix {
		newMsgID[m.ID] = idgenpkg.New("msg")
		for _, b := range m.Blocks {
			newBlockID[b.ID] = idgenpkg.New("blk")
			plannedSeq++
			newBlockSeq[b.ID] = plannedSeq
		}
	}

	summary, watermark := forkSummary(src, prefix, newBlockSeq)
	atID := ""
	if n := len(prefix); n > 0 {
		atID = prefix[n-1].ID
	}
	fork, err := s.deps.Conversations.Fork(ctx, conversationdomain.ForkInput{
		Source:               src,
		AtMessageID:          atID,
		Summary:              summary,
		SummaryCoversUpToSeq: watermark,
	})
	if err != nil {
		return nil, err
	}

	lastMsgID := ""
	for _, m := range prefix {
		row := &messagesdomain.Message{
			ID:             newMsgID[m.ID],
			ConversationID: fork.ID,
			SubagentID:     m.SubagentID,
			Role:           m.Role,
			Status:         m.Status,
			StopReason:     m.StopReason,
			ErrorCode:      m.ErrorCode,
			ErrorMessage:   m.ErrorMessage,
			InputTokens:    m.InputTokens,
			OutputTokens:   m.OutputTokens,
			Provider:       m.Provider,
			ModelID:        m.ModelID,
			// Attrs rides verbatim EXCEPT the version pointer, which is remapped (see forkAttrs): the
			// attachment / mention snapshots inside it are ids and frozen content, both of which the fork
			// legitimately shares with the source.
			// Attrs 逐字带走、**除**版本指针（见 forkAttrs，它被 remap）：里面的附件 / 提及快照是 id 与冻结
			// 内容，两者分叉与源都可正当共享。
			Attrs: forkAttrs(m.Attrs, newMsgID),
			// The version pointer follows the copy: a superseding row cut AWAY by the prefix window leaves
			// the zero value, which is exactly right — inside the fork, with no newer version present, this
			// row IS the current one.
			// 版本指针随复制走：被前缀窗**切掉**的那个取代者留下零值，而这恰好正确——在分叉里，既然更新的版本
			// 根本不在，这一行**就是**现行版。
			SupersededBy: newMsgID[m.SupersededBy],
		}
		blocks := make([]messagesdomain.Block, 0, len(m.Blocks))
		for _, b := range m.Blocks {
			blocks = append(blocks, messagesdomain.Block{
				ID: newBlockID[b.ID],
				// A parent outside the prefix window cannot happen (a child always follows its parent
				// turn), and the zero value degrades such a block to a root-level one rather than to a
				// pointer into the SOURCE's tree — the one outcome that must never occur.
				// 父块落在前缀窗之外不会发生（子回合恒在其父回合之后），而零值把这样的 block 降级为顶层块、
				// 而非指向**源**的树——后者是唯一绝不可发生的结果。
				ParentBlockID: newBlockID[b.ParentBlockID],
				Type:          b.Type,
				Attrs:         b.Attrs,
				Content:       b.Content,
				Status:        b.Status,
				// ContextRole left empty: insertBlocks defaults it to hot, and hot IS the reset — the
				// fork's compaction projection starts over from its own watermark.
				// ContextRole 留空：insertBlocks 默认 hot，而 hot **就是**重置——分叉的压缩投影从它自己的
				// 水位重新开始。
			})
		}
		if err := s.messages.CreateMessage(ctx, row, blocks); err != nil {
			return nil, err
		}
		lastMsgID = row.ID
	}
	// One search notification for the whole fork, after the rows land: conversation.created already
	// fired from the head write, when the thread still had zero messages, so the projection would
	// otherwise index an empty conversation. Anchored at the last row so the indexer reprojects the
	// thread rather than a single message.
	//
	// 行落地后为整个分叉发一次搜索通知：conversation.created 在写头行时就发了、那时线程还零消息，否则
	// 投影会索引一个空对话。锚在最后一行，使索引器重投影整条线程、而非单条消息。
	if lastMsgID != "" {
		s.notifySearchMessage(ctx, fork.ID, lastMsgID)
	}
	return fork, nil
}

// forkAttrs copies one row's Attrs with the version pointer re-based onto the fork's own message ids.
// Every other key (attachment ids, frozen @-mention snapshots, contextUsage) rides verbatim, so the map
// is only cloned when there is actually a pointer to rewrite — an ordinary turn keeps sharing the
// loaded map, which is safe because nothing mutates it.
//
// A retryOf whose target fell outside the prefix window is DROPPED rather than left dangling: the front
// end groups versions by that chain, and a pointer to a row the fork does not contain would make this
// version the root of a group of one — which is the truth about it inside the fork.
//
// forkAttrs 复制一行的 Attrs，并把版本指针重定基到分叉自己的 message id 上。其余每个键（附件 id、冻结的 @ 提及
// 快照、contextUsage）逐字带走，故只有**真有指针要改写**时才克隆这个 map——普通回合继续共享加载来的那份，这是
// 安全的，因为没有任何东西改它。
//
// 目标落在前缀窗之外的 retryOf 被**丢弃**、而非留成悬空指针：前端按那条链组版本组，而一个指向分叉根本没有的行的
// 指针会让这个版本成为**只有一个成员的组的根**——那在分叉里正是关于它的事实。
func forkAttrs(attrs map[string]any, newMsgID map[string]string) map[string]any {
	old, ok := attrs[messagesdomain.AttrRetryOf].(string)
	if !ok || old == "" {
		return attrs
	}
	out := make(map[string]any, len(attrs))
	for k, v := range attrs {
		out[k] = v
	}
	if mapped := newMsgID[old]; mapped != "" {
		out[messagesdomain.AttrRetryOf] = mapped
	} else {
		delete(out, messagesdomain.AttrRetryOf)
	}
	return out
}

// forkPrefix cuts the thread at atMessageID INCLUSIVE (empty = the whole thread, i.e. fork at the
// latest message). An unknown id is MESSAGE_NOT_FOUND — the same identity-anchor 404 the ?around=
// deep-jump read returns, since both take a message id as a coordinate.
//
// forkPrefix 在 atMessageID 处切前缀、**含它**（空 = 整条线程，即从最新处分叉）。未知 id 返
// MESSAGE_NOT_FOUND——与 ?around= 深跳读同一个身份锚点 404，因为两者都拿 message id 当坐标。
func forkPrefix(thread []*messagesdomain.Message, atMessageID string) ([]*messagesdomain.Message, error) {
	if atMessageID == "" {
		return thread, nil
	}
	for i, m := range thread {
		if m.ID == atMessageID {
			return thread[:i+1], nil
		}
	}
	return nil, messagesdomain.ErrMessageNotFound
}

// forkSummary decides whether the source's compaction summary travels, and re-bases its watermark
// onto the fork's numbering.
//
// The summary folds every source block with seq ≤ watermark. Carrying it is truthful ONLY when the
// prefix actually REACHES that line: a cut before the watermark would hand the fork a summary
// describing turns it does not contain — the summary would lie, and the LLM would answer about
// history that is not there. So the two branches are "at-point after the line → carry both" and
// "at-point before the line → carry neither" (empty summary + watermark 0 = no compaction yet,
// which is exactly the truth about a short fork).
//
// The watermark cannot travel verbatim: the fork renumbers blocks from 1, so it is re-derived as
// the highest NEW seq among the folded blocks. `seq > watermark` then hides exactly the rows the
// summary already speaks for.
//
// forkSummary 决定源的压缩摘要是否随行，并把它的水位重定基到分叉的编号上。
//
// 摘要折叠了源里所有 seq ≤ 水位的 block。携带它**只在**前缀真正**到达**那条线时才诚实：切在水位之前
// 会给分叉一份描述它根本没有的回合的摘要——摘要就撒了谎，LLM 会就不存在的历史作答。故两分支是「at 点
// 在线**后** → 两者同抄」与「at 点在线**前** → 两者都不带」（空摘要 + 水位 0 = 尚未压缩，这对一条短
// 分叉正是事实）。
//
// 水位不能逐字带走：分叉把 block 从 1 重排，故它由被折叠 block 中**最大的新 seq** 重新求得。此后
// `seq > 水位` 恰好藏起摘要已代言的那些行。
func forkSummary(src *conversationdomain.Conversation, prefix []*messagesdomain.Message, newBlockSeq map[string]int64) (string, int64) {
	if src.Summary == "" || src.SummaryCoversUpToSeq <= 0 {
		return "", 0
	}
	var maxOldSeq, watermark int64
	for _, m := range prefix {
		for _, b := range m.Blocks {
			if b.Seq > maxOldSeq {
				maxOldSeq = b.Seq
			}
			if b.Seq <= src.SummaryCoversUpToSeq && newBlockSeq[b.ID] > watermark {
				watermark = newBlockSeq[b.ID]
			}
		}
	}
	if maxOldSeq < src.SummaryCoversUpToSeq {
		return "", 0
	}
	return src.Summary, watermark
}
