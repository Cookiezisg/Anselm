// chat_retry_test.go — WRK-077 CH-c 原地重试 / 编辑重发：POST /conversations/{id}:retry 的黑盒验收。
//
// 工单点名四项 + 一条主会话要求的，各自独立场景（每个是隔离宇宙，可 -run 单跑）：
//   - 重生成（无 content：supersede 末 assistant、不写新 user 回合、旧行仍从三读形态返回）
//   - 编辑重发（有 content：supersede 末 user + assistant 两条、新 user 回合保留原附件引用）
//   - 非终态 409（生成中 :retry 弹回、且什么都不写）
//   - 版本链（旧 → 新 superseded_by 向前、新 → 旧 attrs.retryOf 向后，链在线缆上可走；第二次重试接在最新版上）
//   - **LLM 装配确实只看到现行版**（promptdump = 模型在线缆上真看到什么，是这条的唯一诚实证据；DB 断言证明不了它）
//
// 落盘真相（superseded_by 列）用 sqlite3 直查——线缆能证明的用线缆，只有物理行能证明的才下潜。
package scenarios

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// retryMsg is chatMsg plus the two version fields (chatMsg predates them and is shared by many
// scenarios, so this scenario decodes its own shape rather than widening a fixture everyone uses).
//
// retryMsg 是 chatMsg 加上两个版本字段（chatMsg 早于它们、且被许多场景共用，故本场景解自己的形状、
// 不去加宽一个大家都在用的夹具）。
type retryMsg struct {
	ID           string         `json:"id"`
	Role         string         `json:"role"`
	Status       string         `json:"status"`
	SupersededBy string         `json:"supersededBy"`
	Attrs        map[string]any `json:"attrs"`
	Blocks       []struct {
		Type    string `json:"type"`
		Content string `json:"content"`
	} `json:"blocks"`
}

func (m retryMsg) text() string {
	for _, b := range m.Blocks {
		if b.Type == "text" {
			return b.Content
		}
	}
	return ""
}

func (m retryMsg) retryOf() string {
	s, _ := m.Attrs["retryOf"].(string)
	return s
}

// retryList reads the whole history newest-first with the version fields. 取整份历史（最新在前）带版本字段。
func retryList(t *testing.T, wc *harness.Client, convID string) []retryMsg {
	t.Helper()
	var msgs []retryMsg
	wc.GET("/api/v1/conversations/"+convID+"/messages?limit=50").OK(t, &msgs)
	return msgs
}

// retryFind returns the one row carrying this text. 按文本取行。
func retryFind(t *testing.T, msgs []retryMsg, text string) retryMsg {
	t.Helper()
	for _, m := range msgs {
		if m.text() == text {
			return m
		}
	}
	t.Fatalf("no row with text %q among %d rows", text, len(msgs))
	return retryMsg{}
}

// retryPost fires :retry. An empty content sends NO content key at all, so the regenerate branch is
// exercised through the optional-body path the front end actually uses.
//
// retryPost 打 :retry。content 为空时**完全不发** content 键，故重生成分支走的是前端真正使用的可选 body 路径。
func retryPost(t *testing.T, wc *harness.Client, convID, content string) string {
	t.Helper()
	var body any
	if content != "" {
		body = map[string]any{"content": content}
	}
	r := wc.POST("/api/v1/conversations/"+convID+":retry", body)
	if r.Status != 202 {
		t.Fatalf(":retry must return 202 (the turn streams over the messages SSE, exactly as Send does), got %d %s", r.Status, r.Raw)
	}
	return r.Field(t, "id")
}

// ─────────────────────────────────────────────────────────────────────────────
// ① 重生成
// ─────────────────────────────────────────────────────────────────────────────

// TestChatRetry_RegenerateSupersedesTheAnswer: retrying with no content replaces the ANSWER and nothing
// else. The question is not re-asked (no second user row), the old answer keeps its prose and its
// terminal status and keeps coming back from the history read (D1: messages is an append-only Log — a
// retry that deleted or rewrote the old row would be unconstitutional), and the new row carries
// attrs.retryOf so a client can group the two as versions of one turn.
//
// TestChatRetry_RegenerateSupersedesTheAnswer：不带 content 的重试只替换**回答**、别的都不动。问题不被重问
// （无第二条 user 行），旧回答保住它的正文与终态、且继续从历史读返回（D1：messages 是 append-only Log——一次
// 删除或改写旧行的重试即违宪），而新行带 attrs.retryOf，使客户端能把两者组成一个回合的两个版本。
func TestChatRetry_RegenerateSupersedesTheAnswer(t *testing.T) {
	t.Parallel()
	srv, wc, mock, _, _ := chatC_setup(t, false)
	mock.Enqueue(dlgModel,
		harness.LLMTurn{Text: "FIRST-ANSWER"},
		harness.LLMTurn{Text: "SECOND-ANSWER"},
	)
	convID := convCreate(t, wc, "regenerate")
	first := sendMsg(t, wc, convID, "THE-QUESTION")
	waitTurn(t, wc, convID, first, 30000)

	second := retryPost(t, wc, convID, "")
	if turn := waitTurn(t, wc, convID, second, 30000); turn.Status != "completed" {
		t.Fatalf("the regenerated turn must complete, got %s err=%s", turn.Status, turn.ErrorMessage)
	}

	msgs := retryList(t, wc, convID)
	if len(msgs) != 3 {
		t.Fatalf("regenerate appends ONE assistant row (u1 a1 a2), got %d rows", len(msgs))
	}
	users := 0
	for _, m := range msgs {
		if m.Role == "user" {
			users++
		}
	}
	if users != 1 {
		t.Errorf("regenerate must not re-ask the question, got %d user rows", users)
	}

	old, cur := retryFind(t, msgs, "FIRST-ANSWER"), retryFind(t, msgs, "SECOND-ANSWER")
	if old.SupersededBy != cur.ID {
		t.Errorf("old answer supersededBy = %q, want the new row %q", old.SupersededBy, cur.ID)
	}
	if old.Status != "completed" {
		t.Errorf("supersede must not touch status, got %q", old.Status)
	}
	if cur.retryOf() != old.ID {
		t.Errorf("new answer attrs.retryOf = %q, want the old row %q", cur.retryOf(), old.ID)
	}
	if cur.SupersededBy != "" {
		t.Errorf("the new version is current, supersededBy must be empty, got %q", cur.SupersededBy)
	}
	if cur.ID != second {
		t.Errorf(":retry returned %q but the new row is %q", second, cur.ID)
	}

	// The old version is reachable by the ?around= deep-jump read too, not merely present in the page —
	// the version pager needs the row to keep its identity as a coordinate.
	// 旧版**也**能被 ?around= 深跳读到，而不只是「在这一页里」——版本翻页需要该行保住它作为坐标的身份。
	wc.GET("/api/v1/conversations/"+convID+"/messages?around="+old.ID).OK(t, nil)

	// Physical truth: one pointer written, zero rows removed.
	if got := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM messages WHERE conversation_id = '`+convID+`'`); got != "3" {
		t.Errorf("messages rows = %s, want 3 (append-only, D1)", got)
	}
	if got := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM messages `+
		`WHERE conversation_id = '`+convID+`' AND superseded_by != ''`); got != "1" {
		t.Errorf("superseded rows = %s, want exactly 1", got)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// ② 编辑重发
// ─────────────────────────────────────────────────────────────────────────────

// TestChatRetry_EditResendReplacesTheRound: a retry WITH content replaces the whole round — both the
// question and its answer get a superseded_by pointer, a new user row lands with the edited text, and it
// still references the ORIGINAL attachments (an edit-resend is the same message said differently; making
// the reader re-upload the files it referenced would be absurd, and attachments are content-addressed so
// the reference is free).
//
// TestChatRetry_EditResendReplacesTheRound：**带** content 的重试替换整个回合——问句与它的回答都被写上
// superseded_by 指针，一条带编辑后文本的新 user 行落地，且它仍引用**原来那些**附件（编辑重发是同一条消息换个
// 说法；让读者把它引用过的文件重新上传一遍是荒谬的，而附件内容寻址、引用不花钱）。
func TestChatRetry_EditResendReplacesTheRound(t *testing.T) {
	t.Parallel()
	srv, wc, mock, _, _ := chatC_setup(t, false)
	attID := uploadAtt(t, wc, "notes.txt", "text/plain", []byte("RETRYSHARED attachment bytes"))
	mock.Enqueue(dlgModel,
		harness.LLMTurn{Text: "ANSWER-TO-ORIGINAL"},
		harness.LLMTurn{Text: "ANSWER-TO-EDIT"},
	)
	convID := convCreate(t, wc, "edit resend")
	first := sendWith(t, wc, convID, map[string]any{
		"content": "ORIGINAL-QUESTION", "attachmentIds": []string{attID},
	})
	waitTurn(t, wc, convID, first, 60000)
	attRowsBefore := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM attachments`)

	second := retryPost(t, wc, convID, "EDITED-QUESTION")
	if turn := waitTurn(t, wc, convID, second, 60000); turn.Status != "completed" {
		t.Fatalf("the edit-resent turn must complete, got %s err=%s", turn.Status, turn.ErrorMessage)
	}

	msgs := retryList(t, wc, convID)
	if len(msgs) != 4 {
		t.Fatalf("edit-resend appends a user AND an assistant row (u1 a1 u2 a2), got %d rows", len(msgs))
	}
	oldQ := retryFind(t, msgs, "ORIGINAL-QUESTION")
	newQ := retryFind(t, msgs, "EDITED-QUESTION")
	oldA := retryFind(t, msgs, "ANSWER-TO-ORIGINAL")
	newA := retryFind(t, msgs, "ANSWER-TO-EDIT")

	if oldQ.SupersededBy != newQ.ID {
		t.Errorf("old question supersededBy = %q, want %q", oldQ.SupersededBy, newQ.ID)
	}
	if oldA.SupersededBy != newA.ID {
		t.Errorf("old answer supersededBy = %q, want %q", oldA.SupersededBy, newA.ID)
	}
	if newQ.retryOf() != oldQ.ID || newA.retryOf() != oldA.ID {
		t.Errorf("each new row must point back at ITS OWN predecessor, got q=%q a=%q",
			newQ.retryOf(), newA.retryOf())
	}
	if newQ.SupersededBy != "" || newA.SupersededBy != "" {
		t.Errorf("the new round is current: %q / %q", newQ.SupersededBy, newA.SupersededBy)
	}

	// The attachment reference travelled; no second attachments row appeared.
	raw, _ := json.Marshal(newQ.Attrs["attachments"])
	if !strings.Contains(string(raw), attID) {
		t.Errorf("the edited question must keep the original attachment id %q, attrs=%+v", attID, newQ.Attrs)
	}
	if after := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM attachments`); after != attRowsBefore {
		t.Errorf("attachments table grew %s → %s — the resend copied instead of referencing", attRowsBefore, after)
	}
	if r := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil); r.Status != 200 ||
		!strings.Contains(string(r.Raw), "RETRYSHARED") {
		t.Fatalf("the shared attachment must stay fetchable, got %d %q", r.Status, r.Raw)
	}
	// Two of the four rows are superseded — nothing was deleted (D1).
	if got := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM messages `+
		`WHERE conversation_id = '`+convID+`' AND superseded_by != ''`); got != "2" {
		t.Errorf("superseded rows = %s, want exactly 2 (the question AND its answer)", got)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// ③ 非终态 409
// ─────────────────────────────────────────────────────────────────────────────

// TestChatRetry_NonTerminalTailIs409: retry is only meaningful on a round that has finished. While a turn
// is in flight the last round is BY DEFINITION not terminal, and :retry bounces with the existing
// STREAM_IN_PROGRESS 409 (no code of its own — a non-terminal tail IS a turn that is still running).
// Critically, the refusal must be a refusal: no row is written, so the reader who mashes the button
// during a slow reply does not end up with a supersede pointer on a turn that then completes normally.
// Cancelling makes the tail terminal, and the retry is then accepted.
//
// TestChatRetry_NonTerminalTailIs409：重试只在**已结束**的回合上有意义。有回合在飞时，末回合**按定义**非终态，
// :retry 用既有的 STREAM_IN_PROGRESS 409 弹回（不设自己的码——一条非终态的尾巴**就是**一个仍在跑的回合）。要害
// 是：拒绝必须真的是拒绝——**不写任何行**，故在慢回复期间猛点按钮的读者，不会落得一个随后正常完成的回合上挂着
// supersede 指针。取消使尾巴终态化，此后重试即被接受。
func TestChatRetry_NonTerminalTailIs409(t *testing.T) {
	t.Parallel()
	srv, wc, mock, _, _ := chatC_setup(t, false)
	mock.Enqueue(dlgModel,
		harness.LLMTurn{Text: "slow answer coming......", StallMS: 8000},
		harness.LLMTurn{Text: "AFTER-CANCEL"},
	)
	sse := wc.Subscribe(t, "messages")
	convID := convCreate(t, wc, "in flight")
	mid := sendMsg(t, wc, convID, "talk slowly")
	sse.WaitFor(t, 10000, "first text delta streams", "slow answer")

	rowsBefore := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM messages WHERE conversation_id = '`+convID+`'`)
	wc.POST("/api/v1/conversations/"+convID+":retry", nil).Fail(t, 409, "STREAM_IN_PROGRESS")
	wc.POST("/api/v1/conversations/"+convID+":retry", map[string]any{"content": "impatient edit"}).
		Fail(t, 409, "STREAM_IN_PROGRESS")
	if after := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM messages WHERE conversation_id = '`+convID+`'`); after != rowsBefore {
		t.Fatalf("a refused retry must write nothing: %s → %s rows", rowsBefore, after)
	}
	if sup := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM messages `+
		`WHERE conversation_id = '`+convID+`' AND superseded_by != ''`); sup != "0" {
		t.Fatalf("a refused retry must not leave a supersede pointer behind, got %s", sup)
	}

	// Cancel lands the stalled turn on a terminal status; the retry is then legitimate.
	wc.POST("/api/v1/conversations/"+convID+":cancel", nil).OK(t, nil)
	if turn := waitTurn(t, wc, convID, mid, 20000); turn.Status == "streaming" || turn.Status == "pending" {
		t.Fatalf("cancel must land a terminal status, got %q", turn.Status)
	}
	retried := retryPost(t, wc, convID, "")
	if turn := waitTurn(t, wc, convID, retried, 30000); turn.Status != "completed" {
		t.Fatalf("retrying a cancelled round must work, got %s err=%s", turn.Status, turn.ErrorMessage)
	}
	if got := retryFind(t, retryList(t, wc, convID), "AFTER-CANCEL").retryOf(); got != mid {
		t.Errorf("the retry of a cancelled turn must point back at it, got %q want %q", got, mid)
	}

	// A conversation with nothing in it has no round to retry — the same identity-anchor 404 the
	// ?around= read and :fork return.
	empty := convCreate(t, wc, "never spoken in")
	wc.POST("/api/v1/conversations/"+empty+":retry", nil).Fail(t, 404, "MESSAGE_NOT_FOUND")
	wc.POST("/api/v1/conversations/cv_deadbeefdeadbeef:retry", nil).Fail(t, 404, "CONVERSATION_NOT_FOUND")
}

// ─────────────────────────────────────────────────────────────────────────────
// ④ 版本链
// ─────────────────────────────────────────────────────────────────────────────

// TestChatRetry_VersionChainWalksOnTheWire: three versions of one answer must form a walkable chain on
// the wire — v1 → v2 → v3 forward via supersededBy, v3 → v2 → v1 back via attrs.retryOf, with exactly one
// current version at the end. The second retry is the case a sloppy implementation gets wrong: it must
// replace the NEWEST version, not the original (an ancestor), or the chain forks and the "which version is
// the thread based on" mark would have two answers.
//
// TestChatRetry_VersionChainWalksOnTheWire：一个回答的三个版本必须在线缆上构成一条**可走的链**——经 supersededBy
// 向前 v1 → v2 → v3、经 attrs.retryOf 向后 v3 → v2 → v1，末端**恰好一个**现行版。第二次重试是草率实现会做错的
// 那一格：它必须替换**最新**版、而不是原始那版（一个祖先），否则链会**分叉**，而「后续基于哪一版」这个标记就会有
// 两个答案。
func TestChatRetry_VersionChainWalksOnTheWire(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	mock.Enqueue(dlgModel,
		harness.LLMTurn{Text: "V1"},
		harness.LLMTurn{Text: "V2"},
		harness.LLMTurn{Text: "V3"},
	)
	convID := convCreate(t, wc, "three versions")
	waitTurn(t, wc, convID, sendMsg(t, wc, convID, "answer me"), 30000)
	waitTurn(t, wc, convID, retryPost(t, wc, convID, ""), 30000)
	waitTurn(t, wc, convID, retryPost(t, wc, convID, ""), 30000)

	msgs := retryList(t, wc, convID)
	if len(msgs) != 4 {
		t.Fatalf("one question + three answers, got %d rows", len(msgs))
	}
	v1, v2, v3 := retryFind(t, msgs, "V1"), retryFind(t, msgs, "V2"), retryFind(t, msgs, "V3")

	// Forward: each version points at the one that replaced it; only the last is current.
	if v1.SupersededBy != v2.ID {
		t.Errorf("v1.supersededBy = %q, want v2 %q", v1.SupersededBy, v2.ID)
	}
	if v2.SupersededBy != v3.ID {
		t.Errorf("v2.supersededBy = %q, want v3 %q — the second retry replaced an ANCESTOR, not the newest version", v2.SupersededBy, v3.ID)
	}
	if v3.SupersededBy != "" {
		t.Errorf("v3 must be the current version, got supersededBy = %q", v3.SupersededBy)
	}
	// Back: the chain the front end groups versions by.
	if v2.retryOf() != v1.ID || v3.retryOf() != v2.ID {
		t.Errorf("retryOf chain broken: v2→%q (want %q), v3→%q (want %q)",
			v2.retryOf(), v1.ID, v3.retryOf(), v2.ID)
	}
	current := 0
	for _, m := range msgs {
		if m.Role == "assistant" && m.SupersededBy == "" {
			current++
		}
	}
	if current != 1 {
		t.Errorf("exactly one assistant version may be current, got %d", current)
	}
	// Every version keeps its own prose (the pager reads these).
	if v1.text() != "V1" || v2.text() != "V2" || v3.text() != "V3" {
		t.Errorf("versions must keep their own prose: %q / %q / %q", v1.text(), v2.text(), v3.text())
	}

	// The scene bar must not name a superseded turn: the transcript folds old versions into a version
	// group and shows ONE row, so an anchor for a version would offer a jump to a bubble that is not on
	// screen. One user turn ⇒ exactly one `user` anchor.
	// 场次条不该点名一个已被取代的回合：transcript 把旧版折进版本组、只显一行，故给某个版本建锚点会给出一个跳向
	// 屏幕上并不存在的气泡的跳转。一条 user 回合 ⇒ 恰好一个 `user` 锚点。
	var anchors []struct {
		Kind      string `json:"kind"`
		MessageID string `json:"messageId"`
	}
	wc.GET("/api/v1/conversations/"+convID+"/anchors?limit=50").OK(t, &anchors)
	userAnchors := 0
	for _, a := range anchors {
		if a.Kind == "user" {
			userAnchors++
		}
		if a.MessageID == v1.ID || a.MessageID == v2.ID {
			t.Errorf("anchor points at a superseded version %q", a.MessageID)
		}
	}
	if userAnchors != 1 {
		t.Errorf("user anchors = %d, want 1", userAnchors)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// ⑤ LLM 装配确实只看到现行版（promptdump）
// ─────────────────────────────────────────────────────────────────────────────

// TestChatRetry_LLMSeesOnlyTheCurrentVersion is the assertion the whole column exists for, and the only
// one a DB check cannot make: what the MODEL was handed. `superseded_by = ”` is the third condition of
// the same family as the subagent filter and the compaction watermark in LoadThreadForLLM, so the
// promptdump of the turn AFTER a retry must contain the current version and not one byte of the replaced
// one — for both branches (a regenerate hides an answer, an edit-resend hides a question AND its answer).
//
// The dump is taken from a LATER turn on purpose: the retry's own request is assembled before its own row
// has any content, so it proves nothing. The turn after it is where a leaked version would show up — and
// where it would keep showing up forever.
//
// TestChatRetry_LLMSeesOnlyTheCurrentVersion 是整个列存在的理由，也是 DB 检查唯一做不到的那条断言：**模型被交到
// 手上的是什么**。`superseded_by = ”` 是 LoadThreadForLLM 里与 subagent 过滤、压缩水位**同族的第三个条件**，故一次
// 重试**之后**那个回合的 promptdump 必须含现行版、且不含被替换版的**一个字节**——两个分支都要（重生成藏一个回答，
// 编辑重发藏一个问句**与**它的回答）。
//
// dump 刻意取**更后面**那个回合：重试自己的请求是在它自己那行还没有任何内容时装配的，证明不了什么。它**之后**那个
// 回合才是泄漏的版本会现身的地方——也是它会一直现身下去的地方。
func TestChatRetry_LLMSeesOnlyTheCurrentVersion(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	// The script is consumed in order, ONE sampling request per text-only turn, so each line below is
	// exactly one turn of the walk that follows. Every token is distinct and none is a substring of
	// another — a `Contains` assertion is only as honest as its needles.
	// 脚本按序消费、纯文本回合一次 sampling 请求，故下面每一行恰是随后那趟走查的一个回合。每个 token 互不相同、
	// 且没有一个是另一个的子串——`Contains` 断言的诚实程度不超过它的针。
	mock.Enqueue(dlgModel,
		harness.LLMTurn{Text: "A-GHOST"},  // ① the first answer — the regenerate supersedes it
		harness.LLMTurn{Text: "A-LIVE"},   // ② the regenerate's own answer (current)
		harness.LLMTurn{Text: "A-DOOMED"}, // ③ answers Q-DOOMED — the edit-resend supersedes both
		harness.LLMTurn{Text: "A-EDITED"}, // ④ the edit-resend's own answer (current)
		harness.LLMTurn{Text: "A-PROBE"},  // ⑤ the last turn; ITS request is branch B's dump
	)
	convID := convCreate(t, wc, "model view")
	waitTurn(t, wc, convID, sendMsg(t, wc, convID, "Q-KEPT"), 30000)   // ①
	waitTurn(t, wc, convID, retryPost(t, wc, convID, ""), 30000)       // ② regenerate
	waitTurn(t, wc, convID, sendMsg(t, wc, convID, "Q-DOOMED"), 30000) // ③ ← branch A's dump

	// Branch A — regenerate: the replaced ANSWER is gone from the model's view, while the question, which
	// was never replaced, is still there. The dump is turn ③'s request, i.e. the first prompt assembled
	// AFTER the retry — the retry's own request predates its own content and would prove nothing.
	// 分支 A——重生成：被替换的**回答**从模型视图消失，而从未被替换的问句仍在。dump 取回合③的请求，即重试**之后**
	// 装配的第一个 prompt——重试自己的请求早于它自己的内容，什么都证明不了。
	dumps := mock.DumpsFor(dlgModel)
	last := string(dumps[len(dumps)-1].Raw)
	if strings.Contains(last, "A-GHOST") {
		t.Errorf("branch A: the regenerated-away answer reached the model:\n%s", last)
	}
	if !strings.Contains(last, "A-LIVE") {
		t.Errorf("branch A: the current answer is missing from the model's view:\n%s", last)
	}
	if !strings.Contains(last, "Q-KEPT") {
		t.Errorf("branch A: regenerate must not hide the question, which was never replaced:\n%s", last)
	}

	// Branch B — edit-resend: BOTH halves of the replaced round leave the model's view, and the edited
	// question takes their place.
	waitTurn(t, wc, convID, retryPost(t, wc, convID, "Q-EDITED"), 30000) // ④ edit-resend
	waitTurn(t, wc, convID, sendMsg(t, wc, convID, "Q-PROBE"), 30000)    // ⑤ ← branch B's dump
	dumps = mock.DumpsFor(dlgModel)
	last = string(dumps[len(dumps)-1].Raw)
	if strings.Contains(last, "Q-DOOMED") {
		t.Errorf("branch B: the edited-away question reached the model:\n%s", last)
	}
	if strings.Contains(last, "A-DOOMED") {
		t.Errorf("branch B: the edited-away answer reached the model:\n%s", last)
	}
	if !strings.Contains(last, "Q-EDITED") || !strings.Contains(last, "A-EDITED") {
		t.Errorf("branch B: the edited round is missing from the model's view:\n%s", last)
	}
	if strings.Contains(last, "A-GHOST") {
		t.Errorf("branch B: an earlier round's superseded answer came back:\n%s", last)
	}
	// Every ghost is still on disk and still on the wire — hidden from the model, never deleted (D1).
	// 每一个幽灵都还在盘上、还在线缆上——只对模型隐身，从不删除（D1）。
	msgs := retryList(t, wc, convID)
	for _, want := range []string{"A-GHOST", "Q-DOOMED", "A-DOOMED"} {
		if got := retryFind(t, msgs, want); got.SupersededBy == "" {
			t.Errorf("row %q must be marked superseded", want)
		}
	}
}
