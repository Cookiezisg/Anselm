// chat_fork_test.go — WRK-077 CH-b 对话分叉：POST /conversations/{id}:fork 的黑盒验收。
//
// 五项由工单点名、各自独立场景（每个是隔离宇宙，可 -run 单跑）：
//   - 前缀窗（含 atMessageId 本身、到此为止；空 body = 从最新处；未知 id → 404 身份锚点；源分毫不动）
//   - seq 重排（分叉 block seq 恒 1..N 连续，与源的编号无关）
//   - 嵌套 remap（subagent 回合的 parentBlockId 指向**分叉自己**的 tool_call block，绝不留在源树里）
//   - summary 两分支（切点在水位后 → 摘要 + 重定基水位同抄；切点在水位前 → 两者都不带）
//   - 附件共享（内容寻址零拷贝：同一 att_ id、同一 sha 一行、内容仍可取）
//
// 落盘真相（seq / parent / attachments 行数）用 sqlite3 直查——线缆能证明的用线缆，只有物理行能
// 证明的才下潜。
package scenarios

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// forkAt POSTs :fork and asserts 201 + the new Conversation row. atMessageID "" sends an EMPTY body
// (not `{"atMessageId":""}`) so the optional-body path is exercised too.
//
// forkAt 打 :fork 并断言 201 + 新 Conversation 行。atMessageID 为 "" 时发**空 body**（而非
// `{"atMessageId":""}`），使可选 body 路径也被走到。
func forkAt(t *testing.T, wc *harness.Client, convID, atMessageID string) convRow {
	t.Helper()
	var body any
	if atMessageID != "" {
		body = map[string]any{"atMessageId": atMessageID}
	}
	r := wc.POST("/api/v1/conversations/"+convID+":fork", body)
	if r.Status != 201 {
		t.Fatalf(":fork must return 201 (a fork is a resource, not an awaited async turn), got %d %s", r.Status, r.Raw)
	}
	var row convRow
	r.OK(t, &row)
	return row
}

// forkLineage reads the two lineage columns off a conversation row (they are wire read-only and
// omitted when empty, so a plain struct decode is the honest probe).
//
// forkLineage 读一条对话行上的两个血缘列（线缆只读、空则省略，故朴素 struct 解码即诚实探针）。
type forkLineage struct {
	ID                       string `json:"id"`
	Title                    string `json:"title"`
	AutoTitled               bool   `json:"autoTitled"`
	Archived                 bool   `json:"archived"`
	Pinned                   bool   `json:"pinned"`
	SystemPrompt             string `json:"systemPrompt"`
	Summary                  string `json:"summary"`
	SummaryCoversUpToSeq     int64  `json:"summaryCoversUpToSeq"`
	ForkedFromConversationID string `json:"forkedFromConversationId"`
	ForkedFromMessageID      string `json:"forkedFromMessageId"`
}

func forkGetConv(t *testing.T, wc *harness.Client, convID string) forkLineage {
	t.Helper()
	var c forkLineage
	wc.GET("/api/v1/conversations/"+convID).OK(t, &c)
	return c
}

// forkBlocksOldestFirst flattens a conversation's blocks into replay order (the history endpoint is
// newest-first by contract, so the walk reverses it).
//
// forkBlocksOldestFirst 把一个对话的 block 摊平成重放顺序（历史端点按契约最新在前，故走查反转它）。
func forkBlocksOldestFirst(msgs []chatMsg) []struct {
	MsgID, Content string
} {
	var out []struct{ MsgID, Content string }
	for i := len(msgs) - 1; i >= 0; i-- {
		for _, b := range msgs[i].Blocks {
			out = append(out, struct{ MsgID, Content string }{msgs[i].ID, b.Content})
		}
	}
	return out
}

// ─────────────────────────────────────────────────────────────────────────────
// ① 前缀窗
// ─────────────────────────────────────────────────────────────────────────────

// TestChatFork_PrefixWindowInclusiveAndSourceUntouched: the prefix copy INCLUDES atMessageId and
// stops dead there; an omitted body forks at the latest message (the rail entry, which holds no
// message id); an id that is not in this thread is the same identity-anchor 404 MESSAGE_NOT_FOUND
// the ?around= read returns; and the source keeps every row (fork is pure append — messages /
// message_blocks are D1 Log tables, so a fork that mutated the source would be unconstitutional).
//
// TestChatFork_PrefixWindowInclusiveAndSourceUntouched：前缀复制**含** atMessageId 且到此为止；缺省
// body 从最新处分叉（左岛入口手上没有 message id）；不属本线程的 id 返与 ?around= 同一个身份锚点
// 404 MESSAGE_NOT_FOUND；且源保留每一行（分叉是纯追加——messages / message_blocks 是 D1 Log 表，
// 改动源即违宪）。
func TestChatFork_PrefixWindowInclusiveAndSourceUntouched(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	mock.Enqueue(dlgModel,
		harness.LLMTurn{Text: "ANSWER-ONE"},
		harness.LLMTurn{Text: "ANSWER-TWO"},
		harness.LLMTurn{Text: "ANSWER-THREE"},
	)
	convID := convCreate(t, wc, "Fork me")
	for _, q := range []string{"ASK-ONE", "ASK-TWO", "ASK-THREE"} {
		waitTurn(t, wc, convID, sendMsg(t, wc, convID, q), 30000)
	}
	src := listMsgs(t, wc, convID) // newest-first: a3 u3 a2 u2 a1 u1
	if len(src) != 6 {
		t.Fatalf("source must have 6 rows (3 turns), got %d", len(src))
	}
	cutAt := src[2].ID // the SECOND assistant turn
	if txt, _ := blockOfType(src[2], "text"); txt != "ANSWER-TWO" {
		t.Fatalf("cut row is not the second assistant turn: %+v", src[2])
	}

	fork := forkAt(t, wc, convID, cutAt)
	if fork.ID == convID {
		t.Fatal(":fork must mint a NEW conversation, not mutate the source")
	}
	head := forkGetConv(t, wc, fork.ID)
	if head.Title != "Fork me (fork)" || head.AutoTitled {
		t.Errorf("title/autoTitled = %q/%v, want %q/false", head.Title, head.AutoTitled, "Fork me (fork)")
	}
	if head.ForkedFromConversationID != convID || head.ForkedFromMessageID != cutAt {
		t.Errorf("lineage = %q/%q, want %q/%q",
			head.ForkedFromConversationID, head.ForkedFromMessageID, convID, cutAt)
	}

	// The window: four rows (u1 a1 u2 a2), inclusive of the cut, and NOTHING from turn 3.
	got := listMsgs(t, wc, fork.ID)
	if len(got) != 4 {
		t.Fatalf("prefix window must be 4 rows (u1 a1 u2 a2, cut inclusive), got %d", len(got))
	}
	flat := forkBlocksOldestFirst(got)
	want := []string{"ASK-ONE", "ANSWER-ONE", "ASK-TWO", "ANSWER-TWO"}
	if len(flat) != len(want) {
		t.Fatalf("want %d blocks, got %d (%+v)", len(want), len(flat), flat)
	}
	for i, w := range want {
		if flat[i].Content != w {
			t.Errorf("block %d = %q, want %q", i, flat[i].Content, w)
		}
	}
	for _, b := range flat {
		if strings.Contains(b.Content, "THREE") {
			t.Fatalf("the cut must exclude turn 3, found %q", b.Content)
		}
	}
	// Fresh ids throughout — no row is shared with the source.
	srcIDs := map[string]bool{}
	for _, m := range src {
		srcIDs[m.ID] = true
	}
	for _, m := range got {
		if srcIDs[m.ID] {
			t.Errorf("copied row reuses the source message id %q", m.ID)
		}
	}

	// The source is byte-for-byte intact: same 6 rows, same title, no lineage of its own.
	if again := listMsgs(t, wc, convID); len(again) != 6 {
		t.Errorf("source must still have 6 rows, got %d", len(again))
	}
	if s := forkGetConv(t, wc, convID); s.Title != "Fork me" || s.ForkedFromConversationID != "" {
		t.Errorf("source must be untouched: %+v", s)
	}
	// The rail grew the fork (conversation.created — no new SSE frame type, E1/E2).
	if _, ok := findConv(listConvs(t, wc), fork.ID); !ok {
		t.Error("the fork must appear in the conversation list")
	}

	// Empty body = fork at the latest message (the left-island rail entry).
	latest := forkAt(t, wc, convID, "")
	if got := listMsgs(t, wc, latest.ID); len(got) != 6 {
		t.Fatalf("an omitted atMessageId must copy the whole thread (6 rows), got %d", len(got))
	}
	if h := forkGetConv(t, wc, latest.ID); h.ForkedFromMessageID != src[0].ID {
		t.Errorf("latest-fork lineage = %q, want the newest row %q", h.ForkedFromMessageID, src[0].ID)
	}

	// A message id that is not in this thread is a 404 identity anchor — and writes nothing.
	other := convCreate(t, wc, "elsewhere")
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "elsewhere reply"})
	foreign := sendMsg(t, wc, other, "a turn in another thread")
	waitTurn(t, wc, other, foreign, 30000)
	before := len(listConvs(t, wc))
	wc.POST("/api/v1/conversations/"+convID+":fork", map[string]any{"atMessageId": foreign}).
		Fail(t, 404, "MESSAGE_NOT_FOUND")
	wc.POST("/api/v1/conversations/"+convID+":fork", map[string]any{"atMessageId": "msg_deadbeefdeadbeef"}).
		Fail(t, 404, "MESSAGE_NOT_FOUND")
	if after := len(listConvs(t, wc)); after != before {
		t.Errorf("a rejected fork must not leave an orphan head: %d → %d conversations", before, after)
	}
	// An unknown conversation is the conversation-level 404.
	wc.POST("/api/v1/conversations/cv_deadbeefdeadbeef:fork", nil).Fail(t, 404, "CONVERSATION_NOT_FOUND")
}

// ─────────────────────────────────────────────────────────────────────────────
// ② seq 重排 + ③ 嵌套 remap
// ─────────────────────────────────────────────────────────────────────────────

// TestChatFork_SeqRenumberedAndNestedParentRemapped: a subagent turn hangs off its PARENT turn's
// tool_call block, so parent_block_id points ACROSS messages — the one shape that makes a naive
// copy silently corrupt a tree. This pins both physical invariants: the fork's block seq restarts
// at 1 and is contiguous (its own numbering, independent of the source's), and every
// parentBlockId resolves inside the FORK's own blocks — never into the source tree.
//
// TestChatFork_SeqRenumberedAndNestedParentRemapped：subagent 回合挂在其**父**回合的 tool_call block
// 上，故 parent_block_id **跨消息**指——正是让朴素复制静默腐坏树的那个形状。本测钉住两条物理不变量：
// 分叉的 block seq 从 1 重启且连续（它自己的编号、与源无关），且每个 parentBlockId 都落在**分叉自己**
// 的 block 里——绝不指进源树。
func TestChatFork_SeqRenumberedAndNestedParentRemapped(t *testing.T) {
	t.Parallel()
	srv, wc, mock, _, _ := chatC_setup(t, false)

	// Turn 1 is plain, so the fork's numbering cannot accidentally coincide with the source's.
	// 第 1 回合朴素，使分叉的编号不会与源的偶然重合。
	mock.Enqueue(dlgModel,
		harness.LLMTurn{Text: "warm-up reply"},
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "Subagent",
			Args: fw(map[string]any{"subagent_type": "general-purpose", "prompt": "Reply exactly SUBWORK."})}}},
		harness.LLMTurn{Text: "SUBWORK"},                       // the sub-run's own turn
		harness.LLMTurn{Text: "the subagent reported SUBWORK"}, // parent finalize
	)
	convID := convCreate(t, wc, "nested")
	waitTurn(t, wc, convID, sendMsg(t, wc, convID, "warm up"), 30000)
	mid := sendMsg(t, wc, convID, "delegate then report")
	if turn := waitTurn(t, wc, convID, mid, 40000); turn.Status != "completed" {
		t.Fatalf("subagent parent turn must complete, got %s err=%s", turn.Status, turn.ErrorMessage)
	}

	// The source really has a cross-message parent link (else this test proves nothing).
	srcParents := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM message_blocks `+
		`WHERE conversation_id = '`+convID+`' AND parent_block_id != ''`)
	if srcParents == "0" {
		t.Fatal("fixture did not produce a nested (parent_block_id) block — nothing to remap")
	}
	// Source seq must NOT start the fork's way, so a "forgot to renumber" bug is visible.
	if minSeq := chatC_sqlite(t, srv.DataDir, `SELECT MIN(seq) FROM message_blocks `+
		`WHERE conversation_id = '`+convID+`' AND parent_block_id != ''`); minSeq == "1" {
		t.Fatalf("fixture too weak: the nested block already sits at seq 1 in the source (%s)", minSeq)
	}

	fork := forkAt(t, wc, convID, "")

	// seq: 1..N contiguous in the fork, by its own numbering.
	seqs := chatC_sqlite(t, srv.DataDir, `SELECT group_concat(seq, ',') FROM (`+
		`SELECT seq FROM message_blocks WHERE conversation_id = '`+fork.ID+`' ORDER BY seq)`)
	parts := strings.Split(seqs, ",")
	for i, p := range parts {
		if p != itoaFork(i+1) {
			t.Fatalf("fork block seq must renumber 1..N contiguously, got %q", seqs)
		}
	}
	if len(parts) < 4 {
		t.Fatalf("expected ≥4 copied blocks, got %q", seqs)
	}

	// Nested remap: every non-empty parentBlockId in the fork resolves to a FORK block.
	orphans := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM message_blocks c `+
		`WHERE c.conversation_id = '`+fork.ID+`' AND c.parent_block_id != '' AND NOT EXISTS (`+
		`SELECT 1 FROM message_blocks p WHERE p.id = c.parent_block_id AND p.conversation_id = '`+fork.ID+`')`)
	if orphans != "0" {
		t.Fatalf("%s fork block(s) still point at a parent outside the fork (remap broken)", orphans)
	}
	forkParents := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM message_blocks `+
		`WHERE conversation_id = '`+fork.ID+`' AND parent_block_id != ''`)
	if forkParents != srcParents {
		t.Fatalf("nested block count = %s, want the source's %s (nesting must survive the copy)", forkParents, srcParents)
	}
	// context_role reset: the fork's compaction projection starts over.
	if cold := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM message_blocks `+
		`WHERE conversation_id = '`+fork.ID+`' AND context_role != 'hot'`); cold != "0" {
		t.Errorf("%s fork block(s) did not reset context_role to hot", cold)
	}
	// The source's numbering is untouched (append-only, D1).
	if again := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM message_blocks `+
		`WHERE conversation_id = '`+convID+`' AND parent_block_id != ''`); again != srcParents {
		t.Errorf("source nesting changed: %s → %s", srcParents, again)
	}
	// The subagent row travelled (LLM assembly excludes it by subagent_id, so the copy need not).
	if subs := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM messages `+
		`WHERE conversation_id = '`+fork.ID+`' AND subagent_id != ''`); subs == "0" {
		t.Error("subagent rows must travel with the prefix (LLM assembly filters them, the copy does not)")
	}
}

// itoaFork is strconv.Itoa without the import (the file otherwise needs no strconv).
func itoaFork(n int) string {
	if n == 0 {
		return "0"
	}
	var b []byte
	for n > 0 {
		b = append([]byte{byte('0' + n%10)}, b...)
		n /= 10
	}
	return string(b)
}

// ─────────────────────────────────────────────────────────────────────────────
// ④ summary 两分支
// ─────────────────────────────────────────────────────────────────────────────

// TestChatFork_SummaryTwoBranches is the honesty test. The summary folds every source block with
// seq ≤ watermark, so:
//   - cut AT/AFTER the line → the summary travels, with the watermark RE-BASED onto the fork's own
//     1..N numbering (carrying the source's number verbatim would hide the wrong rows);
//   - cut BEFORE the line → NEITHER half travels, because the summary describes turns the fork does
//     not contain; inheriting it would make the model answer about history that is not there.
//
// Both branches ride ONE (expensive) compaction setup: earning a soft budget from a real
// provider-confirmed overflow is how production learns one, and it is the only way a durable tail
// compaction has a line to cross.
//
// TestChatFork_SummaryTwoBranches 是诚实性测试。摘要折叠了源里所有 seq ≤ 水位的 block，故：切点在线
// **上/后** → 摘要随行，且水位**重定基**到分叉自己的 1..N 编号（逐字带走源的数字会藏错行）；切点在线
// **前** → 两半都不带，因为摘要描述的是分叉根本没有的回合，继承它会让模型就不存在的历史作答。两分支
// 共用**一次**（昂贵的）压缩布置：从真实的 provider 确认溢出中赚到软预算正是生产学到它的方式，也是耐久
// 尾压缩唯一能有线可越的办法。
func TestChatFork_SummaryTwoBranches(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, true)
	wc.PATCH("/api/v1/limits", map[string]any{"context": map[string]any{"triggerRatio": 0.1}}).OK(t, nil)

	utilTurns := make([]harness.LLMTurn, 12)
	for i := range utilTurns {
		utilTurns[i] = harness.LLMTurn{Text: "FORK-SUMMARY-MARK"}
	}
	mock.Enqueue(utilModel, utilTurns...)
	filler := strings.Repeat("filler words about the ancient topic. ", 800)
	mock.Enqueue(dlgModel,
		harness.LLMTurn{Text: "noted 1"},
		harness.LLMTurn{Text: "noted 2"},
		harness.LLMTurn{Text: "noted 3"},
		// Overflow + in-step recovery: the pair teaches the runtime profile a soft budget, which is
		// the only thing that gives the durable tail compaction a line to cross.
		harness.LLMTurn{Status: 400, ErrorMessage: "context length exceeded"},
		harness.LLMTurn{Text: "noted 4"},
		harness.LLMTurn{Text: "noted 5", PromptTokens: 60000},
	)
	convID := convCreate(t, wc, "compacted")
	var early string // the FIRST turn's user row — far before any watermark
	for i := 1; i <= 5; i++ {
		mid := sendMsg(t, wc, convID, "TURN-MARKER "+filler)
		waitTurn(t, wc, convID, mid, 30000)
		if i == 1 {
			rows := listMsgs(t, wc, convID)
			early = rows[len(rows)-1].ID // oldest row = turn 1's user message
		}
	}
	harness.Eventually(t, 20000, "rolling summary + watermark persist on the source", func() bool {
		c := forkGetConv(t, wc, convID)
		return strings.Contains(c.Summary, "FORK-SUMMARY-MARK") && c.SummaryCoversUpToSeq > 0
	})
	src := forkGetConv(t, wc, convID)

	// Branch A — cut at the LATEST row, i.e. at/after the watermark: both halves travel, with the
	// watermark re-based onto the fork's own numbering.
	after := forkAt(t, wc, convID, "")
	ha := forkGetConv(t, wc, after.ID)
	if ha.Summary != src.Summary {
		t.Fatalf("branch A: summary must travel verbatim, got %q want %q", ha.Summary, src.Summary)
	}
	if ha.SummaryCoversUpToSeq <= 0 {
		t.Fatalf("branch A: watermark must travel, got %d", ha.SummaryCoversUpToSeq)
	}
	// Re-based, not copied: the fork renumbers from 1, so its line must sit inside its own block range.
	forkBlocks := 0
	for _, m := range listMsgs(t, wc, after.ID) {
		forkBlocks += len(m.Blocks)
	}
	if ha.SummaryCoversUpToSeq > int64(forkBlocks) {
		t.Errorf("branch A: watermark %d exceeds the fork's %d blocks — it was copied, not re-based",
			ha.SummaryCoversUpToSeq, forkBlocks)
	}

	// Branch B — cut at turn 1's user row, far BEFORE the watermark: neither half travels.
	before := forkAt(t, wc, convID, early)
	hb := forkGetConv(t, wc, before.ID)
	if hb.Summary != "" || hb.SummaryCoversUpToSeq != 0 {
		t.Fatalf("branch B: a cut before the watermark must carry NEITHER half, got %q / %d",
			hb.Summary, hb.SummaryCoversUpToSeq)
	}
	if got := listMsgs(t, wc, before.ID); len(got) != 1 {
		t.Fatalf("branch B: cutting at the first user row must copy exactly that row, got %d", len(got))
	}

	// The model's-eye proof for branch B: with no inherited summary, the next turn's prompt carries
	// the fork's own (short) history and no summary marker.
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "fresh branch reply"})
	waitTurn(t, wc, before.ID, sendMsg(t, wc, before.ID, "what do you know?"), 30000)
	dumps := mock.DumpsFor(dlgModel)
	last := string(dumps[len(dumps)-1].Raw)
	if strings.Contains(last, "FORK-SUMMARY-MARK") {
		t.Fatal("branch B: the fork must NOT feed the model a summary it did not inherit")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// ⑤ 附件共享
// ─────────────────────────────────────────────────────────────────────────────

// TestChatFork_AttachmentsSharedNotCopied: attachments are content-addressed (att_ row + sha256
// blob, NO conversation_id), so a fork REFERENCES them — the user turn's Attrs snapshot carries the
// same ids, no second att_ row appears, and the bytes are still fetchable from the fork's side. GC
// keeps a sha alive while any workspace row references it, so sharing is safe.
//
// TestChatFork_AttachmentsSharedNotCopied：附件内容寻址（att_ 行 + sha256 blob，**无** conversation_id），
// 故分叉**引用**它们——user 回合的 Attrs 快照带同样的 id、不多出第二条 att_ 行、且从分叉侧仍能取到字节。
// GC 只要还有 workspace 行引用某 sha 就保活它，故共享是安全的。
func TestChatFork_AttachmentsSharedNotCopied(t *testing.T) {
	t.Parallel()
	srv, wc, mock, _, _ := chatC_setup(t, false)
	attID := uploadAtt(t, wc, "notes.txt", "text/plain", []byte("FORKSHARED attachment bytes"))

	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "read it"})
	convID := convCreate(t, wc, "with attachment")
	mid := sendWith(t, wc, convID, map[string]any{
		"content": "see the file", "attachmentIds": []string{attID},
	})
	waitTurn(t, wc, convID, mid, 60000)

	rowsBefore := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM attachments`)
	fork := forkAt(t, wc, convID, "")

	// Same ids on the wire: the fork's user turn references the very same attachment.
	var msgs []struct {
		Role  string         `json:"role"`
		Attrs map[string]any `json:"attrs"`
	}
	wc.GET("/api/v1/conversations/"+fork.ID+"/messages?limit=50").OK(t, &msgs)
	found := false
	for _, m := range msgs {
		if m.Role != "user" {
			continue
		}
		raw, _ := json.Marshal(m.Attrs["attachments"])
		if strings.Contains(string(raw), attID) {
			found = true
		}
	}
	if !found {
		t.Fatalf("the fork's user turn must reference the SAME attachment id %q, attrs=%+v", attID, msgs)
	}
	// No duplicate row: zero copy, not "copy the metadata too".
	if after := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM attachments`); after != rowsBefore {
		t.Fatalf("attachments table grew %s → %s — the fork copied instead of referencing", rowsBefore, after)
	}
	// The row is still resolvable and the bytes still fetchable (shared, not orphaned).
	wc.GET("/api/v1/attachments/"+attID).OK(t, nil)
	if r := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil); r.Status != 200 ||
		!strings.Contains(string(r.Raw), "FORKSHARED") {
		t.Fatalf("shared attachment content must stay fetchable, got %d %q", r.Status, r.Raw)
	}
	// The source still references it too — sharing is bidirectional, nothing was moved.
	var srcMsgs []struct {
		Role  string         `json:"role"`
		Attrs map[string]any `json:"attrs"`
	}
	wc.GET("/api/v1/conversations/"+convID+"/messages?limit=50").OK(t, &srcMsgs)
	stillThere := false
	for _, m := range srcMsgs {
		raw, _ := json.Marshal(m.Attrs["attachments"])
		if m.Role == "user" && strings.Contains(string(raw), attID) {
			stillThere = true
		}
	}
	if !stillThere {
		t.Fatal("the source must keep its attachment reference (fork moves nothing)")
	}
}
