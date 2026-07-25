package chat

import (
	"context"
	"strings"
	"time"

	"go.uber.org/zap"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// RetryInput is the two-branch payload of POST /conversations/{id}:retry. An empty Content is
// REGENERATE (supersede the last assistant turn, answer the same question again); a non-empty
// Content is EDIT-RESEND (supersede the last user turn AND its answer, land a new user turn with the
// edited text, answer that). ModelOverride is optional and applies to THIS TURN ONLY — it is
// deliberately not written to the conversation head, because "answer that again with a bigger model"
// is a statement about one answer, not a change to the thread's setting (which has its own PATCH).
//
// RetryInput 是 `POST /conversations/{id}:retry` 的两分支载荷。Content 为空 = **重生成**（supersede 末
// assistant 回合、把同一个问题再答一次）；Content 非空 = **编辑重发**（supersede 末 user 回合**与**它的回答、
// 落一条带编辑后文本的新 user 回合、答它）。ModelOverride 可选、**只作用于本回合**——刻意不写进对话头，因为
// 「用更大的模型再答一遍」是对**一个回答**的表态、不是改线程设置（那有它自己的 PATCH）。
type RetryInput struct {
	Content       string
	ModelOverride *modeldomain.ModelRef
}

// Retry replaces the conversation's last round with a new version, appending only. It returns the new
// assistant message id (202 semantics — the turn streams over the messages SSE, exactly as Send's
// does, over the SAME frame types: the new turn's message_start / deltas / message_stop, with
// `retryOf` riding the message node's content so a client that did not initiate the retry still groups
// the versions. No new stream, no new frame type (E1/E2)).
//
// Nothing is ever deleted or rewritten (D1 — messages / message_blocks are append-only Log tables).
// "Replace" is a POINTER: the old row gets superseded_by = <new row id> and stays on disk, stays in
// all three REST read forms, and stays readable in the UI's version pager. Only LoadThreadForLLM
// filters on it, so the model sees exactly one version of the round.
//
// The gate is "the last round must already be terminal", read from TWO sources because they answer
// two different questions: the in-memory queue (IsGenerating — is a turn running or queued right now)
// and the durable status of the last row (is the thread's own tail terminal — a pending/streaming row
// left by a hard crash is not something to retry on top of). Both bounce with the existing
// STREAM_IN_PROGRESS 409; a non-terminal tail IS a turn that, as far as durable truth goes, is still
// running, so it needs no code of its own.
//
// Retry 把对话的**末回合**换成一个新版本，且**只追加**。返回新 assistant message id（202 语义——回合经
// messages SSE 流式，与 Send 一模一样、走**同样的帧型**：新回合的 message_start / delta / message_stop，
// `retryOf` 搭在 message 节点的 content 上，故一个**不是**发起方的客户端也能把版本组起来。不加新流、不加新
// 帧型（E1/E2））。
//
// 从不删除、从不改写（D1——messages / message_blocks 是 append-only Log 表）。「替换」是一个**指针**：旧行被
// 写上 superseded_by = <新行 id>，然后留在盘上、留在三种 REST 读形态里、留在 UI 的版本翻页里可读。只有
// LoadThreadForLLM 按它过滤，故模型恰好看到该回合的一个版本。
//
// 闸是「末回合必须已终态」，读**两个**来源，因为它们回答两个不同的问题：内存队列（IsGenerating——此刻是否有
// 回合在跑或在排）与末行的耐久状态（线程自己的尾巴是否终态——硬崩溃留下的 pending/streaming 行不是可以叠着
// 重试的东西）。两者都用既有的 STREAM_IN_PROGRESS 409 弹回；一条非终态的尾巴**就是**一个（就耐久真相而言）
// 仍在跑的回合，故它不需要自己的码。
func (s *Service) Retry(ctx context.Context, conversationID string, in RetryInput) (string, error) {
	conv, err := s.deps.Conversations.Get(ctx, conversationID)
	if err != nil {
		return "", err
	}
	// A retry is a send-shaped act, so it un-archives like Send does (soft-fail: a stuck flag must not
	// block the turn). 重试是发送形状的动作，故与 Send 一样解档（软失败：卡住的标志不该挡回合）。
	if conv.Archived {
		if err := s.deps.Conversations.Unarchive(ctx, conversationID); err != nil {
			s.log.Warn("chatapp.Retry: auto-unarchive failed", zap.String("conversationId", conversationID), zap.Error(err))
		}
	}
	if s.IsGenerating(conversationID) {
		return "", ErrStreamInProgress
	}
	thread, err := s.messages.LoadThread(ctx, conversationID)
	if err != nil {
		return "", err
	}
	oldUser, oldAsst, err := retryTargets(thread)
	if err != nil {
		return "", err
	}

	edit := strings.TrimSpace(in.Content) != ""
	newAsstID := idgenpkg.New("msg")

	// Edit-resend's user half. The new row lands BEFORE the old one is superseded so that a failure
	// between the two leaves a visible duplicate question rather than a silently vanished round: two
	// current versions are self-correcting (the next retry supersedes both spellings) and honest on
	// screen, whereas superseding first and then failing to write would delete an exchange from the
	// model's view with nothing to show for it.
	//
	// 编辑重发的 user 半。新行**先**落地、旧行**后**被 supersede，使两步之间的失败留下一个**看得见的重复
	// 问句**、而不是一个悄悄消失的回合：两个现行版是自我修正的（下次重试把两种写法一起 supersede）且在屏幕上
	// 诚实，而先 supersede 再写失败会从模型视图里删掉一次交流、且什么都不留下。
	newUserID := ""
	if edit {
		newUserID = idgenpkg.New("msg")
		userMsg := &messagesdomain.Message{
			ID:             newUserID,
			ConversationID: conversationID,
			Role:           messagesdomain.RoleUser,
			Status:         messagesdomain.StatusCompleted,
			Attrs:          retryUserAttrs(oldUser),
		}
		if err := s.messages.CreateMessage(ctx, userMsg, []messagesdomain.Block{
			{Type: messagesdomain.BlockTypeText, Content: in.Content},
		}); err != nil {
			return "", err
		}
		if oldUser != nil {
			if err := s.messages.MarkSuperseded(ctx, oldUser.ID, newUserID); err != nil {
				return "", err
			}
		}
		s.notifySearchMessage(ctx, conversationID, newUserID)
		s.emitUserMessage(ctx, conversationID, userMsg, in.Content)
		// Re-anchor the attachment touches on the row that is now current: the ledger's lastMessageId is
		// a jump target, and pointing it at a superseded row would land the reader on a bubble the
		// transcript has folded into a version group. Mentions are NOT re-recorded — they are not carried
		// (see retryUserAttrs).
		// 把附件触碰重锚到现在是现行版的那一行：台账的 lastMessageId 是跳转目标，指向一条已被取代的行会把读者
		// 送到一个已被 transcript 折进版本组的气泡上。提及**不**重记——它本就不带（见 retryUserAttrs）。
		s.recordSendTouches(ctx, conversationID, newUserID, nil, attachmentIDsOf(userMsg))
		if err := s.deps.Conversations.TouchLastMessage(ctx, conversationID, time.Now().UTC(), false); err != nil {
			s.log.Warn("chatapp.Retry: touch last_message_at failed", zap.String("conversation", conversationID), zap.Error(err))
		}
	}

	// The assistant half, identical in shape to Send's: open a streaming row to mint the stream anchor,
	// push message_start, enqueue. retryOf rides Attrs so it survives into the REST projection AND the
	// stream frame; processTask re-seeds it onto the host's message so WriteFinalize (a full Attrs
	// rewrite) cannot drop it.
	//
	// assistant 半，形状与 Send 的一致：开一条 streaming 行以 mint 流锚点、推 message_start、入队。retryOf 走
	// Attrs，故它同时活到 REST 投影与流帧里；processTask 会把它重新种到 host 的 message 上，使 WriteFinalize
	// （整体重写 Attrs）不可能把它丢掉。
	retryOf := ""
	if oldAsst != nil {
		retryOf = oldAsst.ID
	}
	asstMsg := &messagesdomain.Message{
		ID:             newAsstID,
		ConversationID: conversationID,
		Role:           messagesdomain.RoleAssistant,
		Status:         messagesdomain.StatusStreaming,
	}
	if retryOf != "" {
		asstMsg.Attrs = map[string]any{messagesdomain.AttrRetryOf: retryOf}
	}
	if err := s.messages.CreateMessage(ctx, asstMsg, nil); err != nil {
		return "", err
	}
	if oldAsst != nil {
		if err := s.messages.MarkSuperseded(ctx, oldAsst.ID, newAsstID); err != nil {
			return "", err
		}
	}
	s.emitMessageStart(ctx, conversationID, asstMsg)

	wsID, _ := reqctxpkg.GetWorkspaceID(ctx)
	t := task{
		assistantMsgID: newAsstID,
		workspaceID:    wsID,
		locale:         reqctxpkg.GetLocale(ctx),
		modelOverride:  in.ModelOverride,
		retryOf:        retryOf,
	}
	if err := s.enqueue(conversationID, t); err != nil {
		// Same rollback as Send: an assistant row that never got a runner must not stay a permanent
		// streaming orphan. 与 Send 同款回滚：没等到 runner 的 assistant 行不能成永久 streaming 孤儿。
		asstMsg.Status = messagesdomain.StatusError
		asstMsg.StopReason = messagesdomain.StopReasonError
		asstMsg.ErrorCode = "STREAM_IN_PROGRESS"
		_ = s.messages.FinalizeMessage(ctx, asstMsg, nil)
		return "", err
	}
	return newAsstID, nil
}

// retryTargets picks the two rows a retry replaces out of a whole thread: the last CURRENT user turn
// and, when the thread's tail is an assistant turn, that answer.
//
// Only current, top-level rows count. Superseded rows are earlier versions (a second retry must
// replace the newest version, not an ancestor), and subagent rows are a nested run's internals — they
// are not turns of this thread at all.
//
// The tail may legitimately be a USER row with no answer: a crash-swept thread ends that way, and so
// does an edit-resend whose generation never started. Then oldAsst is nil and "regenerate" degrades to
// "produce the answer that is missing" — which is what the reader means by the button, and requires no
// special case anywhere else.
//
// retryTargets 从整条线程里挑出重试要替换的两行：最后一条**现行** user 回合，以及——当线程尾巴是 assistant
// 回合时——那个回答。
//
// 只有**现行**且**顶层**的行算。已被取代的行是更早的版本（第二次重试必须替换**最新**版、不是某个祖先），而
// subagent 行是一次嵌套运行的内部——它们根本不是本线程的回合。
//
// 尾巴合法地可以是一条**没有回答**的 user 行：被崩溃清扫过的线程就是这样结尾的，一次生成从未开始的编辑重发也
// 是。此时 oldAsst 为 nil，「重生成」自然降级为「把缺的那个回答产出来」——那正是读者按那个按钮的意思，且别处
// 不需要任何特例。
func retryTargets(thread []*messagesdomain.Message) (oldUser, oldAsst *messagesdomain.Message, err error) {
	current := make([]*messagesdomain.Message, 0, len(thread))
	for _, m := range thread {
		if m.SubagentID == "" && m.SupersededBy == "" {
			current = append(current, m)
		}
	}
	if len(current) == 0 {
		// Nothing to retry. A message id is the coordinate here just as it is for ?around= and :fork,
		// so the absence of the turn is the same identity-anchor 404.
		// 无可重试。message id 在此与 ?around=、:fork 一样是坐标，故「那个回合不存在」是同一个身份锚点 404。
		return nil, nil, messagesdomain.ErrMessageNotFound
	}
	last := current[len(current)-1]
	if !isRetryTerminal(last.Status) {
		return nil, nil, ErrStreamInProgress
	}
	if last.Role == messagesdomain.RoleAssistant {
		oldAsst = last
	}
	for i := len(current) - 1; i >= 0; i-- {
		if current[i].Role == messagesdomain.RoleUser {
			oldUser = current[i]
			break
		}
	}
	return oldUser, oldAsst, nil
}

// isRetryTerminal reports whether a turn has stopped. Mirrors the three terminal statuses
// messagesdomain declares; pending / streaming are the two that are still in motion.
//
// isRetryTerminal 报告一个回合是否已停下。对应 messagesdomain 声明的三个终态；pending / streaming 是仍在
// 动的那两个。
func isRetryTerminal(status string) bool {
	switch status {
	case messagesdomain.StatusCompleted, messagesdomain.StatusError, messagesdomain.StatusCancelled:
		return true
	}
	return false
}

// retryAttrs is the assistant side's Attrs seed: the version pointer alone, or nil for an ordinary
// turn. Returning nil (rather than an empty map) keeps `attrs` absent from an ordinary turn's wire
// shape, which is what every existing consumer already expects.
//
// retryAttrs 是 assistant 侧的 Attrs 种子：只有版本指针，普通回合则为 nil。返回 nil（而非空 map）使普通回合
// 的线缆形状里 `attrs` 照旧缺席——那正是所有既有消费方已经预期的。
func retryAttrs(retryOf string) map[string]any {
	if retryOf == "" {
		return nil
	}
	return map[string]any{messagesdomain.AttrRetryOf: retryOf}
}

// retryUserAttrs builds the edited user turn's Attrs: the ORIGINAL attachment ids (an edit-resend is
// the same message said differently — re-uploading the files it referenced would be absurd, and
// attachments are content-addressed so the reference costs nothing) plus the version pointer.
//
// @-mention snapshots are deliberately NOT carried. They are frozen CONTENT, not references, and the
// edited text is free to have dropped the @ that justified them — injecting a snapshot for a mention
// the reader just deleted would feed the model something the message no longer says. The retry body
// carries no `mentions` field (the contract is `{content?, modelOverride?}`), so re-resolving is not
// on the table either; an edited sentence simply mentions nothing until Send is used again.
//
// retryUserAttrs 造编辑后 user 回合的 Attrs：**原来的**附件 id（编辑重发是同一条消息换个说法——让它引用的文件
// 重新上传一遍是荒谬的，而附件内容寻址、引用不花钱）+ 版本指针。
//
// @ 提及快照**刻意不带**。它们是冻结的**内容**、不是引用，而编辑后的文本完全可能已经删掉了那个让它们成立的
// @——为一个读者刚删掉的提及注入快照，等于把消息已经不再说的话喂给模型。retry body 没有 `mentions` 字段
// （契约是 `{content?, modelOverride?}`），故重新解析也不在桌面上；一条编辑过的句子就是不提及任何东西，直到
// 再走一次 Send。
func retryUserAttrs(oldUser *messagesdomain.Message) map[string]any {
	if oldUser == nil {
		return nil
	}
	attrs := map[string]any{messagesdomain.AttrRetryOf: oldUser.ID}
	if ids := attachmentIDsOf(oldUser); len(ids) > 0 {
		attrs[attrAttachments] = ids
	}
	return attrs
}
