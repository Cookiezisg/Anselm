package chat

import (
	"context"
	"encoding/json"
	"iter"
	"strings"
	"sync"
	"testing"

	"go.uber.org/zap"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

// versionedClient answers with a DIFFERENT text each time it is streamed, so a test can tell version 1
// from version 2 by content instead of by id bookkeeping alone. Past the last script it repeats the
// last answer (a turn that runs one more time than expected must not deadlock the test).
//
// versionedClient 每次被流式调用都答**不同的**文本，使测试能靠内容而非仅靠 id 记账分辨第 1 版与第 2 版。用完脚本
// 后重复最后一条（多跑一回合不该让测试死锁）。
type versionedClient struct {
	mu      sync.Mutex
	answers []string
	n       int
}

func (c *versionedClient) Stream(_ context.Context, _ llminfra.Request) iter.Seq[llminfra.StreamEvent] {
	c.mu.Lock()
	text := c.answers[min(c.n, len(c.answers)-1)]
	c.n++
	c.mu.Unlock()
	return func(yield func(llminfra.StreamEvent) bool) {
		if !yield(llminfra.StreamEvent{Type: llminfra.EventText, Delta: text}) {
			return
		}
		yield(llminfra.StreamEvent{Type: llminfra.EventFinish, FinishReason: "stop", InputTokens: 3, OutputTokens: 4})
	}
}

// recordingResolver captures the override each generation actually resolved with — the only way to
// prove a Retry's per-turn model reached the resolver AND that the next ordinary turn went back to the
// thread's own setting.
//
// recordingResolver 捕获每次生成**实际**用哪个 override 去解析——这是唯一能证明「Retry 的逐回合模型确实到了
// resolver」且「下一个普通回合又回到线程自己的设置」的办法。
type recordingResolver struct {
	client llminfra.Client
	mu     sync.Mutex
	seen   []*modeldomain.ModelRef
}

func (r *recordingResolver) ResolveChat(_ context.Context, override *modeldomain.ModelRef) (Bundle, error) {
	r.mu.Lock()
	r.seen = append(r.seen, override)
	r.mu.Unlock()
	id := "fake-model"
	if override != nil {
		id = override.ModelID
	}
	return Bundle{Client: r.client, Request: llminfra.Request{ModelID: id}, Provider: "fake"}, nil
}

func (r *recordingResolver) ResolveUtility(_ context.Context) (Bundle, error) {
	return Bundle{Client: r.client, Request: llminfra.Request{ModelID: "fake-utility"}, Provider: "fake"}, nil
}

func (r *recordingResolver) overrides() []*modeldomain.ModelRef {
	r.mu.Lock()
	defer r.mu.Unlock()
	return append([]*modeldomain.ModelRef(nil), r.seen...)
}

// retryFixture wires a service over the REAL messages store (superseded_by and the assembly filter are
// physical facts — a fake repo would let a broken predicate pass) with a scripted client and a recording
// resolver.
//
// retryFixture 在**真** messages store 上装配 service（superseded_by 与装配过滤是物理事实——fake repo 会让坏掉的
// 谓词蒙混过关），配脚本化 client 与记录型 resolver。
func retryFixture(t *testing.T, answers ...string) (*Service, messagesdomain.Repository, *recordBridge, *recordingResolver) {
	t.Helper()
	store := newStore(t)
	bridge := newRecordBridge()
	resolver := &recordingResolver{client: &versionedClient{answers: answers}}
	svc := NewService(store, Deps{
		Conversations: fakeConvs{conv: &conversationdomain.Conversation{SystemPrompt: "be concise"}},
		Resolver:      resolver,
		Bridge:        bridge,
	}, zap.NewNop())
	t.Cleanup(func() { svc.Shutdown(context.Background()) })
	return svc, store, bridge, resolver
}

// retryRow reads one turn back with its blocks. 读回一个回合（带 blocks）。
func retryRow(t *testing.T, store messagesdomain.Repository, id string) *messagesdomain.Message {
	t.Helper()
	m, err := store.GetMessage(ctxWS("ws_1"), id)
	if err != nil {
		t.Fatalf("GetMessage %s: %v", id, err)
	}
	return m
}

// retryRoleIDs returns the ids of one role's turns, oldest-first. 按角色取回合 id（最旧在前）。
func retryRoleIDs(t *testing.T, store messagesdomain.Repository, convID, role string) []string {
	t.Helper()
	thread, err := store.LoadThread(ctxWS("ws_1"), convID)
	if err != nil {
		t.Fatalf("LoadThread: %v", err)
	}
	var out []string
	for _, m := range thread {
		if m.Role == role {
			out = append(out, m.ID)
		}
	}
	return out
}

// llmText flattens what the model would actually be fed, so a test asserts on the ASSEMBLED history
// rather than on the DB rows (the point of the filter is what reaches the model).
//
// llmText 把模型**实际**会被喂到的东西摊平，使测试断言**装配后的历史**而非 DB 行（过滤的要义是什么到了模型那里）。
func llmText(t *testing.T, store messagesdomain.Repository, convID string) string {
	t.Helper()
	rows, err := store.LoadThreadForLLM(ctxWS("ws_1"), convID, 0)
	if err != nil {
		t.Fatalf("LoadThreadForLLM: %v", err)
	}
	var b strings.Builder
	for _, m := range rows {
		b.WriteString(m.Role)
		b.WriteString(":")
		for _, blk := range m.Blocks {
			b.WriteString(blk.Content)
		}
		b.WriteString("\n")
	}
	return b.String()
}

// TestRetry_RegenerateSupersedesTheAnswerAndKeepsItReadable is the core of CH-c: retrying without a
// content replaces the ANSWER only. The old row keeps existing, keeps its prose, and keeps coming back
// from the store — it merely stops being what the model sees. No second user turn is written (the
// question was never re-asked).
//
// TestRetry_RegenerateSupersedesTheAnswerAndKeepsItReadable 是 CH-c 的核心：不带 content 的重试只替换**回答**。
// 旧行继续存在、保住它的正文、继续能从 store 读回——它只是不再是模型看到的东西。**不写第二条 user 回合**（那个问题
// 从未被重新问过）。
func TestRetry_RegenerateSupersedesTheAnswerAndKeepsItReadable(t *testing.T) {
	svc, store, bridge, _ := retryFixture(t, "FIRST ANSWER", "SECOND ANSWER")
	ctx := ctxWS("ws_1")

	first, err := svc.Send(ctx, "cv_1", SendInput{Content: "the question"})
	if err != nil {
		t.Fatalf("Send: %v", err)
	}
	waitClose(t, bridge, first)

	second, err := svc.Retry(ctx, "cv_1", RetryInput{})
	if err != nil {
		t.Fatalf("Retry: %v", err)
	}
	waitClose(t, bridge, second)

	// Exactly one user turn: regenerate does not re-ask.
	if users := retryRoleIDs(t, store, "cv_1", messagesdomain.RoleUser); len(users) != 1 {
		t.Fatalf("regenerate must not write a new user turn, got %d user rows", len(users))
	}
	// The pointer pair: old → new via superseded_by, new → old via attrs.retryOf.
	old := retryRow(t, store, first)
	if old.SupersededBy != second {
		t.Errorf("old answer supersededBy = %q, want %q", old.SupersededBy, second)
	}
	if txt, _ := blockText(old); txt != "FIRST ANSWER" {
		t.Errorf("the superseded row must keep its prose verbatim, got %q", txt)
	}
	if old.Status != messagesdomain.StatusCompleted {
		t.Errorf("supersede must not touch status, got %q", old.Status)
	}
	newRow := retryRow(t, store, second)
	if got := retryOfOf(newRow); got != first {
		t.Errorf("new version attrs.retryOf = %q, want %q (survives WriteFinalize's wholesale Attrs write)", got, first)
	}
	if newRow.SupersededBy != "" {
		t.Errorf("the new version is current, supersededBy must be empty, got %q", newRow.SupersededBy)
	}

	// The LLM sees ONE version. This is the assertion the whole column exists for.
	assembled := llmText(t, store, "cv_1")
	if strings.Contains(assembled, "FIRST ANSWER") {
		t.Errorf("the retried-away answer reached LLM history:\n%s", assembled)
	}
	if !strings.Contains(assembled, "SECOND ANSWER") || !strings.Contains(assembled, "the question") {
		t.Errorf("LLM history lost the current round:\n%s", assembled)
	}
	// Both versions still come back from the durable read the version pager uses (D1: zero deletion).
	thread, err := store.LoadThread(ctx, "cv_1")
	if err != nil {
		t.Fatalf("LoadThread: %v", err)
	}
	if len(thread) != 3 {
		t.Fatalf("durable thread must keep every version (u1 a1 a2), got %d rows", len(thread))
	}
}

// TestRetry_EditResendReplacesBothHalves: an edited resend supersedes the question AND its answer, lands
// the edited sentence as a new user turn that still references the original attachments, and leaves the
// model reading only the edited version.
//
// TestRetry_EditResendReplacesBothHalves：编辑重发 supersede 问句**与**它的回答、把编辑后的句子落成一条仍引用
// **原来那些附件**的新 user 回合，并使模型只读到编辑后的版本。
func TestRetry_EditResendReplacesBothHalves(t *testing.T) {
	svc, store, bridge, _ := retryFixture(t, "ANSWER TO ORIGINAL", "ANSWER TO EDIT")
	ctx := ctxWS("ws_1")

	firstAsst, err := svc.Send(ctx, "cv_1", SendInput{
		Content:       "original question",
		AttachmentIDs: []string{"att_1111111111111111", "att_2222222222222222"},
	})
	if err != nil {
		t.Fatalf("Send: %v", err)
	}
	waitClose(t, bridge, firstAsst)
	firstUser := retryRoleIDs(t, store, "cv_1", messagesdomain.RoleUser)[0]

	secondAsst, err := svc.Retry(ctx, "cv_1", RetryInput{Content: "edited question"})
	if err != nil {
		t.Fatalf("Retry: %v", err)
	}
	waitClose(t, bridge, secondAsst)

	users := retryRoleIDs(t, store, "cv_1", messagesdomain.RoleUser)
	if len(users) != 2 {
		t.Fatalf("edit-resend must land a new user turn, got %d user rows", len(users))
	}
	newUser := retryRow(t, store, users[1])
	if txt, _ := blockText(newUser); txt != "edited question" {
		t.Errorf("new user turn text = %q, want the edited sentence", txt)
	}
	if got := attachmentIDsOf(newUser); len(got) != 2 || got[0] != "att_1111111111111111" {
		t.Errorf("edit-resend must keep the original attachment references, got %v", got)
	}
	if got := retryOfOf(newUser); got != firstUser {
		t.Errorf("new user attrs.retryOf = %q, want %q", got, firstUser)
	}
	// @-mention snapshots are deliberately not carried (see retryUserAttrs) — assert the absence so a
	// future "just copy Attrs" shortcut trips here rather than in front of a reader.
	// @ 提及快照刻意不带（见 retryUserAttrs）——把这个**缺席**钉住，使日后「Attrs 整体照抄」的捷径栽在这里、
	// 而不是栽在读者面前。
	if _, ok := newUser.Attrs[attrMentions]; ok {
		t.Errorf("edit-resend must not carry frozen mention snapshots: %+v", newUser.Attrs)
	}

	// Both halves of the old round now point forward.
	if got := retryRow(t, store, firstUser).SupersededBy; got != users[1] {
		t.Errorf("old question supersededBy = %q, want %q", got, users[1])
	}
	if got := retryRow(t, store, firstAsst).SupersededBy; got != secondAsst {
		t.Errorf("old answer supersededBy = %q, want %q", got, secondAsst)
	}

	assembled := llmText(t, store, "cv_1")
	if strings.Contains(assembled, "original question") || strings.Contains(assembled, "ANSWER TO ORIGINAL") {
		t.Errorf("the superseded round reached LLM history:\n%s", assembled)
	}
	if !strings.Contains(assembled, "edited question") || !strings.Contains(assembled, "ANSWER TO EDIT") {
		t.Errorf("LLM history lost the edited round:\n%s", assembled)
	}
	// Four rows on disk, two visible to the model: zero deletion (D1).
	if thread, _ := store.LoadThread(ctx, "cv_1"); len(thread) != 4 {
		t.Fatalf("durable thread must keep both versions of both halves, got %d rows", len(thread))
	}
}

// TestRetry_PerTurnModelOverrideDoesNotStickToTheThread: `modelOverride` governs the ONE answer being
// regenerated. The generation resolves with it, the row records which model produced that version, and
// the NEXT ordinary turn resolves with the thread's own setting again (the head was never written).
//
// TestRetry_PerTurnModelOverrideDoesNotStickToTheThread：`modelOverride` 统辖**正在被重生成的那一个**回答。本次
// 生成用它解析、行记下是哪个模型产出了该版本，而**下一个**普通回合又用线程自己的设置解析（头行从未被写过）。
func TestRetry_PerTurnModelOverrideDoesNotStickToTheThread(t *testing.T) {
	svc, store, bridge, resolver := retryFixture(t, "a", "b", "c")
	ctx := ctxWS("ws_1")

	first, err := svc.Send(ctx, "cv_1", SendInput{Content: "q"})
	if err != nil {
		t.Fatalf("Send: %v", err)
	}
	waitClose(t, bridge, first)

	retried, err := svc.Retry(ctx, "cv_1", RetryInput{
		ModelOverride: &modeldomain.ModelRef{APIKeyID: "aki_1", ModelID: "bigger-model"},
	})
	if err != nil {
		t.Fatalf("Retry: %v", err)
	}
	waitClose(t, bridge, retried)

	after, err := svc.Send(ctx, "cv_1", SendInput{Content: "next"})
	if err != nil {
		t.Fatalf("Send after retry: %v", err)
	}
	waitClose(t, bridge, after)

	seen := resolver.overrides()
	if len(seen) != 3 {
		t.Fatalf("want 3 resolutions, got %d", len(seen))
	}
	if seen[0] != nil {
		t.Errorf("the first turn must resolve with the thread's own override (nil), got %+v", seen[0])
	}
	if seen[1] == nil || seen[1].ModelID != "bigger-model" {
		t.Errorf("the retry must resolve with its per-turn override, got %+v", seen[1])
	}
	if seen[2] != nil {
		t.Errorf("the per-turn override must NOT stick to the thread, got %+v", seen[2])
	}
	if got := retryRow(t, store, retried).ModelID; got != "bigger-model" {
		t.Errorf("the retried version must record which model produced it, got %q", got)
	}
}

// TestRetry_RejectsWhatCannotBeRetried covers the two refusals. A thread with no turn to retry is the
// same identity-anchor 404 the ?around= read and :fork return; a tail that is not terminal — whether
// because a turn is in flight or because a crash left a `streaming` row behind — is the existing
// STREAM_IN_PROGRESS 409, because a non-terminal tail IS a turn that, as far as durable truth goes, is
// still running.
//
// TestRetry_RejectsWhatCannotBeRetried 覆盖两种拒绝。无回合可重试 = 与 ?around= 读、:fork 同一个身份锚点 404；
// 尾巴非终态——无论因为有回合在飞，还是因为崩溃留下了一行 `streaming`——都是既有的 STREAM_IN_PROGRESS 409，因为
// 一条非终态的尾巴**就是**一个（就耐久真相而言）仍在跑的回合。
func TestRetry_RejectsWhatCannotBeRetried(t *testing.T) {
	svc, store, _, _ := retryFixture(t, "answer")
	ctx := ctxWS("ws_1")

	if _, err := svc.Retry(ctx, "cv_empty", RetryInput{}); err != messagesdomain.ErrMessageNotFound {
		t.Errorf("retry on a thread with no turns = %v, want MESSAGE_NOT_FOUND", err)
	}

	// A crash-shaped tail: a streaming assistant row with no runner behind it (SweepOrphans has not run
	// yet). Retrying on top of it would append a second answer to a round that never closed.
	// 崩溃形状的尾巴：一条身后没有 runner 的 streaming assistant 行（SweepOrphans 还没跑）。在它之上重试会给一个
	// 从未收尾的回合再追加一个回答。
	if err := store.CreateMessage(ctx, &messagesdomain.Message{
		ID: "msg_stuckuser0000001", ConversationID: "cv_stuck",
		Role: messagesdomain.RoleUser, Status: messagesdomain.StatusCompleted,
	}, []messagesdomain.Block{{Type: messagesdomain.BlockTypeText, Content: "q"}}); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	if err := store.CreateMessage(ctx, &messagesdomain.Message{
		ID: "msg_stuckasst0000001", ConversationID: "cv_stuck",
		Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusStreaming,
	}, nil); err != nil {
		t.Fatalf("seed streaming assistant: %v", err)
	}
	if _, err := svc.Retry(ctx, "cv_stuck", RetryInput{}); err != ErrStreamInProgress {
		t.Errorf("retry on a non-terminal tail = %v, want STREAM_IN_PROGRESS", err)
	}
	// Nothing was written by the refusal.
	if thread, _ := store.LoadThread(ctx, "cv_stuck"); len(thread) != 2 {
		t.Errorf("a refused retry must write nothing, thread has %d rows", len(thread))
	}
}

// TestRetryTargets_PicksTheCurrentTailOnly pins the selection rule directly, because the three shapes it
// has to get right are exactly the ones an end-to-end test would take three generations to reach:
// a SECOND retry must replace the newest version (not an ancestor), a subagent row is not a turn of this
// thread at all, and a tail that is a bare user turn means "produce the answer that is missing" rather
// than an error.
//
// TestRetryTargets_PicksTheCurrentTailOnly 直接钉住选取规则，因为它必须答对的三种形状，正是端到端测试要跑三次
// 生成才能到达的那三种：**第二次**重试必须替换最新版（不是某个祖先）、subagent 行根本不是本线程的回合、而一条
// 光秃秃的 user 尾巴意味着「把缺的那个回答产出来」而不是报错。
func TestRetryTargets_PicksTheCurrentTailOnly(t *testing.T) {
	msg := func(id, role, subagentID, supersededBy string) *messagesdomain.Message {
		return &messagesdomain.Message{
			ID: id, Role: role, SubagentID: subagentID, SupersededBy: supersededBy,
			Status: messagesdomain.StatusCompleted,
		}
	}
	// u1 → a1(superseded by a2) → sub(a subagent's own row) → a2(current)
	thread := []*messagesdomain.Message{
		msg("u1", messagesdomain.RoleUser, "", ""),
		msg("a1", messagesdomain.RoleAssistant, "", "a2"),
		msg("sub", messagesdomain.RoleAssistant, "sub_1", ""),
		msg("a2", messagesdomain.RoleAssistant, "", ""),
	}
	user, asst, err := retryTargets(thread)
	if err != nil {
		t.Fatalf("retryTargets: %v", err)
	}
	if asst == nil || asst.ID != "a2" {
		t.Errorf("a second retry must replace the NEWEST version, got %+v", asst)
	}
	if user == nil || user.ID != "u1" {
		t.Errorf("user target = %+v, want u1", user)
	}

	// A bare user tail (crash-swept, or an edit-resend whose generation never started): nothing to
	// supersede on the assistant side, and that is not an error.
	bare := []*messagesdomain.Message{msg("u1", messagesdomain.RoleUser, "", "")}
	user, asst, err = retryTargets(bare)
	if err != nil {
		t.Fatalf("retryTargets(bare user tail): %v", err)
	}
	if asst != nil {
		t.Errorf("a bare user tail has no answer to supersede, got %+v", asst)
	}
	if user == nil || user.ID != "u1" {
		t.Errorf("user target = %+v, want u1", user)
	}

	// A thread whose only rows are a subagent's internals has no turn of its own to retry.
	onlySub := []*messagesdomain.Message{msg("sub", messagesdomain.RoleAssistant, "sub_1", "")}
	if _, _, err := retryTargets(onlySub); err != messagesdomain.ErrMessageNotFound {
		t.Errorf("retryTargets(subagent rows only) = %v, want MESSAGE_NOT_FOUND", err)
	}
}

// TestRetry_CloseSnapshotCarriesTheVersionPointer — the version pointer must survive the turn's END on
// the WIRE, not only in the store (WRK-083 L6).
//
// `retryOf` rode message_start alone. But E2 makes Close the durable frame WITH A SNAPSHOT, precisely so
// a client that missed the open (replay after 410, a second window that connected mid-turn, a reconnect)
// can still render the turn — and every such client rebuilds the node from that snapshot. A snapshot
// that omits the pointer tells them "this turn FOLLOWS the one above it" when the truth is "this turn
// REPLACES it": they render the superseded version and its replacement as two consecutive rounds, the
// same question answered twice, with no version pager. Real machine: after a retry the failed attempt
// stayed on screen as its own round; only a restart (REST, where attrs.retryOf is projected) folded them.
//
// The store side already learned this exact lesson one file over — runner.go re-seeds retryOf because
// WriteFinalize writes Attrs WHOLESALE and would otherwise drop a pointer written only at create time.
// The wire has the same wholesale-overwrite shape (the client replaces content from the close snapshot)
// and needed the same completeness. The user half already carried it (messageUserContent.RetryOf, for
// edit-resend); only the assistant half did not.
//
// TestRetry_CloseSnapshotCarriesTheVersionPointer——版本指针必须在**线缆**上活过回合的**结束**,而不只是在库里
// (WRK-083 L6)。
//
// `retryOf` 只搭了 message_start。但 E2 规定 Close 是**带快照的** durable 帧,正是为了让错过 open 的客户端
// (410 后 replay、中途连上的第二个窗口、重连)仍能渲这个回合——而每一个这样的客户端都从那份快照重建节点。缺了指针的
// 快照告诉它们「本回合**接在**上面那条后面」,而真相是「本回合**取代**它」:于是被取代的版本与它的替代者被渲成两个
// 连续回合、同一个问题答了两遍、且没有版本翻页。真机:重试之后,失败的那次尝试作为独立一轮留在屏幕上,只有重启
// (走 REST,attrs.retryOf 在那儿被投影)才折叠。
//
// 库那一侧在隔壁文件里已经学过一模一样的教训——runner.go 重新种 retryOf,因为 WriteFinalize **整体**写 Attrs、
// 否则只在创建时写的指针会掉。线缆是同一种整体覆写形状(客户端从 close 快照替换 content),需要同一种完整性。
// user 半本来就带着它(messageUserContent.RetryOf,编辑重发用);唯独 assistant 半没有。
func TestRetry_CloseSnapshotCarriesTheVersionPointer(t *testing.T) {
	svc, _, bridge, _ := retryFixture(t, "FIRST ANSWER", "SECOND ANSWER")
	ctx := ctxWS("ws_1")

	first, err := svc.Send(ctx, "cv_1", SendInput{Content: "the question"})
	if err != nil {
		t.Fatalf("Send: %v", err)
	}
	waitClose(t, bridge, first)
	second, err := svc.Retry(ctx, "cv_1", RetryInput{})
	if err != nil {
		t.Fatalf("Retry: %v", err)
	}
	waitClose(t, bridge, second)

	// Assert on the CLOSE, standalone: this is exactly what a replaying client has and all it has.
	// 断言落在 close 上、且**孤立地**看它:那正是一个 replay 客户端手里的全部东西。
	if got := closeRetryOf(t, bridge, second); got != first {
		t.Errorf("message_stop snapshot retryOf = %q, want %q — a client that replays from the close "+
			"snapshot renders the superseded version as a separate round (WRK-083 L6)", got, first)
	}
	// An ordinary turn must stay clean: `omitempty` means no key at all, so a version pager never
	// appears where nothing was retried. 普通回合必须干净:omitempty=键都不出现,没重试过的地方绝不冒出翻页。
	if got := closeRetryOf(t, bridge, first); got != "" {
		t.Errorf("an ordinary turn's close snapshot must carry no retryOf, got %q", got)
	}
}

// TestRetry_OpenFramesCarryTheVersionPointer pins the live half of the same contract. The user echo is
// especially important here: edit-resend publishes it before the new assistant starts, so an open frame
// without retryOf briefly renders the edited sentence as a separate round while the answer streams.
// TestRetry_OpenFramesCarryTheVersionPointer 钉住同一契约的实时半边。user 回声尤其重要:编辑重发先发布它、再启动
// 新 assistant；open 缺 retryOf 会在回答流入时先把编辑句渲成独立新回合。
func TestRetry_OpenFramesCarryTheVersionPointer(t *testing.T) {
	svc, store, bridge, _ := retryFixture(t, "ANSWER TO ORIGINAL", "ANSWER TO EDIT")
	ctx := ctxWS("ws_1")

	firstAsst, err := svc.Send(ctx, "cv_1", SendInput{Content: "original question"})
	if err != nil {
		t.Fatalf("Send: %v", err)
	}
	waitClose(t, bridge, firstAsst)
	firstUser := retryRoleIDs(t, store, "cv_1", messagesdomain.RoleUser)[0]

	secondAsst, err := svc.Retry(ctx, "cv_1", RetryInput{Content: "edited question"})
	if err != nil {
		t.Fatalf("Retry: %v", err)
	}
	waitClose(t, bridge, secondAsst)
	users := retryRoleIDs(t, store, "cv_1", messagesdomain.RoleUser)
	if len(users) != 2 {
		t.Fatalf("edit-resend must create two user versions, got %d", len(users))
	}
	secondUser := users[1]
	if got := openRetryOf(t, bridge, secondUser); got != firstUser {
		t.Errorf("edited user open retryOf = %q, want %q", got, firstUser)
	}
	if got := closeRetryOf(t, bridge, secondUser); got != firstUser {
		t.Errorf("edited user close retryOf = %q, want %q", got, firstUser)
	}
	if got := openRetryOf(t, bridge, secondAsst); got != firstAsst {
		t.Errorf("retried assistant open retryOf = %q, want %q", got, firstAsst)
	}
	if got := closeRetryOf(t, bridge, secondAsst); got != firstAsst {
		t.Errorf("retried assistant close retryOf = %q, want %q", got, firstAsst)
	}
}

// closeRetryOf reads `retryOf` out of a turn's message_stop snapshot — through the JSON the client
// actually receives, not through the Go struct, so a field that never marshals cannot pass.
// closeRetryOf 从某回合的 message_stop 快照里读 `retryOf`——**穿过客户端真正收到的那份 JSON**、而不是 Go
// 结构体,故一个永远不会被序列化的字段无法蒙混过关。
func closeRetryOf(t *testing.T, b *recordBridge, id string) string {
	t.Helper()
	b.mu.Lock()
	defer b.mu.Unlock()
	for _, e := range b.events {
		if e.ID != id {
			continue
		}
		c, ok := e.Frame.(streamdomain.Close)
		if !ok || c.Result == nil {
			continue
		}
		raw, err := json.Marshal(c.Result.Content)
		if err != nil {
			t.Fatalf("marshal close snapshot: %v", err)
		}
		var got struct {
			RetryOf string `json:"retryOf"`
		}
		if err := json.Unmarshal(raw, &got); err != nil {
			t.Fatalf("unmarshal close snapshot: %v", err)
		}
		return got.RetryOf
	}
	t.Fatalf("no close frame for %s", id)
	return ""
}

// openRetryOf reads `retryOf` through the JSON payload of a message_start event, not the Go value.
// openRetryOf 穿过 message_start 的真实 JSON 读取 retryOf，而不是读取 Go 值。
func openRetryOf(t *testing.T, b *recordBridge, id string) string {
	t.Helper()
	b.mu.Lock()
	defer b.mu.Unlock()
	for _, e := range b.events {
		if e.ID != id {
			continue
		}
		o, ok := e.Frame.(streamdomain.Open)
		if !ok {
			continue
		}
		raw, err := json.Marshal(o.Node.Content)
		if err != nil {
			t.Fatalf("marshal open snapshot: %v", err)
		}
		var got struct {
			RetryOf string `json:"retryOf"`
		}
		if err := json.Unmarshal(raw, &got); err != nil {
			t.Fatalf("unmarshal open snapshot: %v", err)
		}
		return got.RetryOf
	}
	t.Fatalf("no open frame for %s", id)
	return ""
}

// blockText returns a turn's first block content. 取一个回合首个 block 的内容。
func blockText(m *messagesdomain.Message) (string, bool) {
	if len(m.Blocks) == 0 {
		return "", false
	}
	return m.Blocks[0].Content, true
}
