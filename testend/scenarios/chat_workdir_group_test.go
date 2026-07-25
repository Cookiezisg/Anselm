// chat_workdir_group_test.go — WRK-077 WD1.5 rail 按驻地分组的黑盒验收。
//
// 本批后端存在的**唯一**理由是「防分组撒谎」:rail 是无限翻页的，若在一窗内做客户端分组，组成员与计数会随翻页
// 漂移。故这些场景全都在追问同一件事的不同侧面——**服务端说的数与真实是否逐字相符，且是否在翻页下不动**。
//
// 五项各自独立场景（每个是隔离宇宙，可 -run 单跑）:
//   - 投影的计数与真实一致（未挂不成组、置顶被提出组、软删不算、两个归档计数分列）+ N4 形状（无游标）
//   - `?workDir=` 过滤两态（**空值 = 仅无驻地**、有值 = 仅该组）× `?pinned=` 三态
//   - 整组归档（组内全归、组外分毫不动、幂等重跑报 0）
//   - 整组删除（软删;**置顶存活**;而「消息行仍在」在黑盒里**不可观测**——见该场景的注释，那条断言在
//     后端单测 TestDeleteWorkDir_NeverTouchesAMessageRow 里，此处断言线缆能证明的部分）
//   - **分组计数跨翻页不漂移**（把组内翻成好几页，每翻一页都重问投影，数必须一模一样）
package scenarios

import (
	"fmt"
	"net/url"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// wdGroupRow mirrors one row of `GET /conversations/workdir-groups`.
//
// wdGroupRow 镜像 `GET /conversations/workdir-groups` 的一行。
type wdGroupRow struct {
	WorkDir       string `json:"workDir"`
	ActiveCount   int    `json:"activeCount"`
	ArchivedCount int    `json:"archivedCount"`
	LastMessageAt string `json:"lastMessageAt"`
}

func wdGroups(t *testing.T, wc *harness.Client) []wdGroupRow {
	t.Helper()
	var rows []wdGroupRow
	wc.GET("/api/v1/conversations/workdir-groups").OK(t, &rows)
	return rows
}

func wdGroup(t *testing.T, wc *harness.Client, dir string) (wdGroupRow, bool) {
	t.Helper()
	for _, g := range wdGroups(t, wc) {
		if g.WorkDir == dir {
			return g, true
		}
	}
	return wdGroupRow{}, false
}

// wdSetPinned / wdSetArchived shape a thread the way the rail's own ⋯ menu does.
//
// wdSetPinned / wdSetArchived 用 rail 自己 ⋯ 菜单的同一手法摆好一条线程。
func wdSetPinned(t *testing.T, wc *harness.Client, id string, v bool) {
	t.Helper()
	wc.PATCH("/api/v1/conversations/"+id, map[string]any{"pinned": v}).OK(t, nil)
}

func wdSetArchived(t *testing.T, wc *harness.Client, id string, v bool) {
	t.Helper()
	wc.PATCH("/api/v1/conversations/"+id, map[string]any{"archived": v}).OK(t, nil)
}

// wdList lists conversations under an arbitrary query string and returns the rows plus the page cursor.
//
// wdList 按任意 query 列对话，返回行与页游标。
func wdList(t *testing.T, wc *harness.Client, query string) ([]convRow, string) {
	t.Helper()
	var rows []convRow
	resp := wc.GET("/api/v1/conversations?" + query).OK(t, &rows)
	return rows, resp.NextCursor
}

func wdTitles(rows []convRow) []string {
	out := make([]string, 0, len(rows))
	for _, r := range rows {
		out = append(out, r.Title)
	}
	return out
}

func wdSameSet(got, want []string) bool {
	if len(got) != len(want) {
		return false
	}
	seen := map[string]int{}
	for _, g := range got {
		seen[g]++
	}
	for _, w := range want {
		seen[w]--
	}
	for _, n := range seen {
		if n != 0 {
			return false
		}
	}
	return true
}

// ─────────────────────────────────────────────────────────────────────────────
// ① 投影的计数与真实一致
// ─────────────────────────────────────────────────────────────────────────────

// TestChatWorkDirGroups_ProjectionMatchesReality: the projection is the anti-drift piece, so every rule about
// WHAT it counts is asserted against a hand-built reality — five threads in two directories plus one that
// never picked a directory, one pinned, one archived, one deleted.
//
// N4 shape too: it is a BOUNDED PROJECTION in the zero-parameter form, so it takes no cursor and reports no
// `nextCursor`, and (per standard HTTP) pagination parameters thrown at it are simply ignored rather than
// rejected.
//
// TestChatWorkDirGroups_ProjectionMatchesReality：投影是防漂移件，故关于它**数什么**的每条规则都对着一份手搭的
// 真实来断言——两个目录里五条线程，加一条从未选过目录的，其中一条置顶、一条归档、一条被删。
//
// N4 形状同断:它是**有界投影**的零参数形，故不收游标、不报 `nextCursor`，且（按标准 HTTP）扔给它的分页参数被
// **忽略**、而不是被拒。
func TestChatWorkDirGroups_ProjectionMatchesReality(t *testing.T) {
	t.Parallel()
	wc, _ := chatSetup(t, false)
	alpha, beta := t.TempDir(), t.TempDir()

	a1 := convCreate(t, wc, "a1")
	wdMount(t, wc, a1, alpha)
	a2 := convCreate(t, wc, "a2")
	wdMount(t, wc, a2, alpha)
	wdSetArchived(t, wc, a2, true)
	a3 := convCreate(t, wc, "a3")
	wdMount(t, wc, a3, alpha)
	wdSetPinned(t, wc, a3, true)
	a4 := convCreate(t, wc, "a4")
	wdMount(t, wc, a4, alpha)
	homeless := convCreate(t, wc, "homeless")
	b1 := convCreate(t, wc, "b1")
	wdMount(t, wc, b1, beta)
	wc.DELETE("/api/v1/conversations/" + a4).OK(t, nil)

	groups := wdGroups(t, wc)
	if len(groups) != 2 {
		t.Fatalf("only the two MOUNTED residencies are groups, got %d: %+v", len(groups), groups)
	}
	for _, g := range groups {
		if g.WorkDir == "" {
			t.Fatalf("the unmounted threads are NOT a group — no folder head, no ⋯ menu: %+v", groups)
		}
	}
	byDir := map[string]wdGroupRow{}
	for _, g := range groups {
		byDir[g.WorkDir] = g
	}
	// alpha holds a1 (active) + a2 (archived); a3 is pinned → hoisted into the rail's Pinned section and
	// counted nowhere here; a4 is deleted → gone.
	// alpha 里是 a1（活跃）+ a2（已归档）;a3 置顶 → 被提到 rail 的置顶段、在此不计入任何地方;a4 已删 → 不算。
	if g := byDir[alpha]; g.ActiveCount != 1 || g.ArchivedCount != 1 {
		t.Fatalf("alpha = %d active / %d archived, want 1/1", g.ActiveCount, g.ArchivedCount)
	}
	if g := byDir[beta]; g.ActiveCount != 1 || g.ArchivedCount != 0 {
		t.Fatalf("beta = %d/%d, want 1/0", g.ActiveCount, g.ArchivedCount)
	}
	if byDir[alpha].LastMessageAt == "" {
		t.Fatalf("a group must say when it was last active")
	}
	// Most-recently-active first: beta's only thread was created last. 最近活跃在前:beta 那条建得最晚。
	if groups[0].WorkDir != beta {
		t.Fatalf("groups must lead with the most recently active, got %q", groups[0].WorkDir)
	}

	// N4: no cursor on the way out, and pagination parameters on the way in are ignored (not 422 — this is
	// the zero-parameter form, there is no window to clamp). N4:出无游标、入的分页参数被忽略（非 422）。
	resp := wc.GET("/api/v1/conversations/workdir-groups?cursor=whatever&limit=1").OK(t, nil)
	if resp.NextCursor != "" || resp.HasMore {
		t.Fatalf("a bounded projection must carry no cursor, got nextCursor=%q hasMore=%v", resp.NextCursor, resp.HasMore)
	}
	var clamped []wdGroupRow
	wc.GET("/api/v1/conversations/workdir-groups?limit=1").OK(t, &clamped)
	if len(clamped) != 2 {
		t.Fatalf("limit must be IGNORED on a bounded projection, got %d rows", len(clamped))
	}

	// Leaving the residency is the other way out of a group: the thread moves back to Recents and, being the
	// last unpinned member, takes the group with it.
	// 退出驻地是离开组的另一条路:线程移回「最近」，而它作为最后一个未置顶成员会把组一并带走。
	wc.PATCH("/api/v1/conversations/"+b1, map[string]any{"workDir": ""}).OK(t, nil)
	if g, ok := wdGroup(t, wc, beta); ok {
		t.Fatalf("a group must vanish with its last unpinned member, still got %+v", g)
	}
	if _, ok := wdGroup(t, wc, alpha); !ok {
		t.Fatalf("alpha must still be a group")
	}
	_ = homeless
}

// ─────────────────────────────────────────────────────────────────────────────
// ② `?workDir=` 两态 + `?pinned=` 三态
// ─────────────────────────────────────────────────────────────────────────────

// TestChatWorkDirGroups_ListFilters: the rail's four sections are four server queries, and the one that
// cannot be faked client-side is `?workDir=` with an EMPTY value — "only the threads that live in no
// directory". The key being PRESENT is what says it: absent means no residency filter at all. If the backend
// read those two the same way, the Recents section would silently list the whole workspace.
//
// TestChatWorkDirGroups_ListFilters：rail 的四段是四条服务端查询，而其中客户端伪造不了的那一条是**空值**的
// `?workDir=`——「只要不住在任何目录里的线程」。**键出现**才是它的意思:键缺席意为完全不按驻地过滤。若后端把这
// 两者读成同一件事，「最近」段会静默地列出整个 workspace。
func TestChatWorkDirGroups_ListFilters(t *testing.T) {
	t.Parallel()
	wc, _ := chatSetup(t, false)
	dir := t.TempDir()

	inDir := convCreate(t, wc, "in-dir")
	wdMount(t, wc, inDir, dir)
	inDirPinned := convCreate(t, wc, "in-dir-pinned")
	wdMount(t, wc, inDirPinned, dir)
	wdSetPinned(t, wc, inDirPinned, true)
	convCreate(t, wc, "homeless")
	homelessPinned := convCreate(t, wc, "homeless-pinned")
	wdSetPinned(t, wc, homelessPinned, true)

	esc := url.QueryEscape(dir)
	for _, tc := range []struct {
		name  string
		query string
		want  []string
	}{
		{"no residency filter = every thread", "limit=50", []string{"in-dir", "in-dir-pinned", "homeless", "homeless-pinned"}},
		{"?workDir= (present, EMPTY) = only the unmounted ones", "limit=50&workDir=", []string{"homeless", "homeless-pinned"}},
		{"?workDir=<path> = one group", "limit=50&workDir=" + esc, []string{"in-dir", "in-dir-pinned"}},
		{"?pinned=true = the Pinned section, across residencies", "limit=50&pinned=true", []string{"in-dir-pinned", "homeless-pinned"}},
		{"the Recents section", "limit=50&workDir=&pinned=false", []string{"homeless"}},
		{"a group's rows", "limit=50&workDir=" + esc + "&pinned=false", []string{"in-dir"}},
	} {
		rows, _ := wdList(t, wc, tc.query)
		if got := wdTitles(rows); !wdSameSet(got, tc.want) {
			t.Errorf("%s (?%s): got %v, want %v", tc.name, tc.query, got, tc.want)
		}
	}

	// The four sections partition the workspace exactly once each — that is the whole point of "pinned wins,
	// never duplicated in its group". 四段恰好把 workspace 划分一次——那正是「置顶赢、绝不在组里重复」的全部意义。
	pinned, _ := wdList(t, wc, "limit=50&pinned=true")
	recents, _ := wdList(t, wc, "limit=50&workDir=&pinned=false")
	group, _ := wdList(t, wc, "limit=50&workDir="+esc+"&pinned=false")
	seen := map[string]int{}
	for _, rows := range [][]convRow{pinned, recents, group} {
		for _, r := range rows {
			seen[r.ID]++
		}
	}
	if len(seen) != 4 {
		t.Fatalf("the sections must cover all 4 threads, covered %d", len(seen))
	}
	for id, n := range seen {
		if n != 1 {
			t.Fatalf("%s appears in %d sections — every thread must render exactly once", id, n)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// ③ 整组归档
// ─────────────────────────────────────────────────────────────────────────────

// TestChatWorkDirGroups_ArchiveWholeGroup: one request files away a folder's worth of threads. The count it
// reports is what CHANGED, so re-running on an already-filed group answers 0 rather than claiming it did the
// work twice. Nothing outside the group moves, and a PINNED thread of that residency survives — pinning is
// the user saying "this one matters", and a folder-wide sweep must not carry it off.
//
// TestChatWorkDirGroups_ArchiveWholeGroup：一个请求收起一个文件夹量的线程。它报的数是**改变了什么**，故在一个
// 已收起的组上重跑答 0、而不是声称自己又干了一遍。组外分毫不动，且该驻地的**置顶**线程存活——置顶是用户在说
// 「这条我在意」，一次目录级清扫不该把它带走。
func TestChatWorkDirGroups_ArchiveWholeGroup(t *testing.T) {
	t.Parallel()
	wc, _ := chatSetup(t, false)
	dir, other := t.TempDir(), t.TempDir()

	a := convCreate(t, wc, "a")
	wdMount(t, wc, a, dir)
	b := convCreate(t, wc, "b")
	wdMount(t, wc, b, dir)
	pin := convCreate(t, wc, "pinned")
	wdMount(t, wc, pin, dir)
	wdSetPinned(t, wc, pin, true)
	out := convCreate(t, wc, "elsewhere")
	wdMount(t, wc, out, other)
	home := convCreate(t, wc, "homeless")

	// The head's count and the confirm dialog's inventory are the SAME number, so assert they agree with
	// what the action then does. 组头的数与确认框的盘点是**同一个**数，故断言它与动作随后所做的事一致。
	g, ok := wdGroup(t, wc, dir)
	if !ok || g.ActiveCount+g.ArchivedCount != 2 {
		t.Fatalf("group inventory = %+v, want 2 threads (the pinned one is hoisted out)", g)
	}

	var res struct {
		WorkDir  string `json:"workDir"`
		Archived int    `json:"archived"`
	}
	wc.POST("/api/v1/conversations:archive-workdir", map[string]any{"workDir": dir}).OK(t, &res)
	if res.Archived != 2 || res.WorkDir != dir {
		t.Fatalf("archive-workdir = %+v, want 2 in %q", res, dir)
	}

	all, _ := wdList(t, wc, "limit=50&archived=all")
	for _, r := range all {
		want := r.ID == a || r.ID == b
		if r.Archived != want {
			t.Fatalf("%q archived=%v, want %v", r.Title, r.Archived, want)
		}
	}
	if _, err := wc.Try("GET", "/api/v1/conversations/"+pin, nil); err != nil {
		t.Fatalf("the pinned thread must still be readable: %v", err)
	}
	_, _ = out, home

	// Idempotent: nothing left to change. 幂等:没有什么剩下可改。
	wc.POST("/api/v1/conversations:archive-workdir", map[string]any{"workDir": dir}).OK(t, &res)
	if res.Archived != 0 {
		t.Fatalf("re-archive reported %d, want 0 — the count says what CHANGED", res.Archived)
	}

	// The two spellings that cannot name a group. An EMPTY workDir is a legitimate list FILTER but NOT a
	// group, and accepting it would let one request file away every thread that never picked a directory.
	// 两种点不出组的拼法。**空** workDir 是正当的列表**过滤**、但**不是组**;接受它会让一个请求收起每一条从未
	// 选过目录的线程。
	wc.POST("/api/v1/conversations:archive-workdir", map[string]any{"workDir": ""}).Fail(t, 400, "INVALID_REQUEST")
	wc.POST("/api/v1/conversations:archive-workdir", map[string]any{"workDir": "relative/dir"}).
		Fail(t, 422, "CONVERSATION_INVALID_WORK_DIR")
	if r, _ := wdList(t, wc, "limit=50&workDir=&pinned=false"); len(r) != 1 || r[0].Archived {
		t.Fatalf("the refusals must change nothing, got %+v", r)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// ④ 整组删除
// ─────────────────────────────────────────────────────────────────────────────

// TestChatWorkDirGroups_DeleteWholeGroup: one request deletes a folder's worth of threads — soft, business
// table only, across archive states (a destructive action must not depend on which view toggle is on), and
// the residency's PINNED threads survive.
//
// ⚠️ ON "断言消息行仍在": that assertion is NOT observable through the black box and this scenario does not
// pretend otherwise. Every message read path is parented by a conversation existence check, so a tombstoned
// thread's `GET /{id}/messages` answers 404 by design — the wire cannot tell "the thread's row is
// tombstoned" from "its messages were wiped". The D1 proof is therefore made where both tables ARE visible,
// in the backend unit test `TestDeleteWorkDir_NeverTouchesAMessageRow` (writes a real turn, deletes the
// group, reads the message + block rows straight back out of the messages store). What this scenario asserts
// instead is the strongest thing the wire CAN prove: the thread's own row is tombstoned (404, not
// 200-empty), a surviving sibling's transcript is still readable byte-for-byte, and the group is gone from
// the projection.
//
// TestChatWorkDirGroups_DeleteWholeGroup：一个请求删掉一个文件夹量的线程——软删、只碰业务表、跨归档态（破坏性
// 动作不该取决于哪个视图开关开着），且该驻地的**置顶**线程存活。
//
// ⚠️ 关于「断言消息行仍在」:那条断言**在黑盒里不可观测**，本场景**不假装**它可以。每条消息读路径都被一次对话
// 存在性检查所辖，故一条已立碑线程的 `GET /{id}/messages` 按设计答 404——线缆分不清「线程的行被立碑了」与
// 「它的消息被抹了」。故 D1 的证明在**两张表都看得见**的地方做:后端单测
// `TestDeleteWorkDir_NeverTouchesAMessageRow`（写一个真回合、删掉组、再从 messages store 把 message 与 block 行
// 直接读回来）。本场景转而断言线缆**能**证明的最强那些:线程自己的行被立碑（404、非 200-空）、一条存活的兄弟线程
// 的逐字记录仍可读、组已从投影里消失。
func TestChatWorkDirGroups_DeleteWholeGroup(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	dir := t.TempDir()

	doomed := convCreate(t, wc, "doomed")
	wdMount(t, wc, doomed, dir)
	archived := convCreate(t, wc, "archived-but-doomed")
	wdMount(t, wc, archived, dir)
	wdSetArchived(t, wc, archived, true)
	pin := convCreate(t, wc, "pinned-survivor")
	wdMount(t, wc, pin, dir)
	wdSetPinned(t, wc, pin, true)

	// A real turn in the surviving thread, so "the transcript is still there" is a claim about real rows.
	// 存活线程里跑一个真回合，使「逐字记录还在」是一句关于真行的断言。
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "I am still here."})
	waitTurn(t, wc, pin, sendMsg(t, wc, pin, "are you still there?"), 30000)

	var res struct {
		WorkDir string `json:"workDir"`
		Deleted int    `json:"deleted"`
	}
	wc.POST("/api/v1/conversations:delete-workdir", map[string]any{"workDir": dir}).OK(t, &res)
	if res.Deleted != 2 || res.WorkDir != dir {
		t.Fatalf("delete-workdir = %+v, want 2 in %q (unpinned, BOTH archive states)", res, dir)
	}

	// The threads' OWN rows are tombstoned — 404, never 200-empty. 线程**自己的行**被立碑——404、绝非 200-空。
	for _, id := range []string{doomed, archived} {
		wc.GET("/api/v1/conversations/" + id).Fail(t, 404, "CONVERSATION_NOT_FOUND")
		wc.GET("/api/v1/conversations/" + id + "/messages").Fail(t, 404, "CONVERSATION_NOT_FOUND")
	}
	// The pinned survivor kept its whole transcript. 置顶存活者留住了它的整份逐字记录。
	var msgs []chatMsg
	wc.GET("/api/v1/conversations/" + pin + "/messages?limit=50").OK(t, &msgs)
	if len(msgs) < 2 {
		t.Fatalf("the surviving thread's transcript must be intact, got %d messages", len(msgs))
	}
	// And the group is gone all by itself: only the pinned thread is left, and pinned threads never count.
	// 而组自行消失了:只剩那条置顶的，而置顶从不计入。
	if g, ok := wdGroup(t, wc, dir); ok {
		t.Fatalf("the group must vanish once its unpinned threads are gone, got %+v", g)
	}

	wc.POST("/api/v1/conversations:delete-workdir", map[string]any{"workDir": ""}).Fail(t, 400, "INVALID_REQUEST")
	wc.POST("/api/v1/conversations:delete-workdir", map[string]any{"workDir": "relative/dir"}).
		Fail(t, 422, "CONVERSATION_INVALID_WORK_DIR")
	if _, err := wc.Try("GET", "/api/v1/conversations/"+pin, nil); err != nil {
		t.Fatalf("the refusals must change nothing: %v", err)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// ⑤ 分组计数跨翻页不漂移
// ─────────────────────────────────────────────────────────────────────────────

// TestChatWorkDirGroups_CountsDoNotDriftAcrossPaging is the scenario the whole backend half exists for.
//
// A rail that grouped ONE PAGE client-side would state a number that changes as you scroll: page 1 sees 3 of
// the group's threads, page 2 sees 3 more, and the head would count 3, then 6, then 9 — a number that moves
// while nothing about the workspace moved. So the group is walked to its end one small page at a time, and
// the projection is re-asked after EVERY page: it must answer the identical numbers every single time, and
// the pages must together enumerate exactly the count it claims.
//
// TestChatWorkDirGroups_CountsDoNotDriftAcrossPaging 是整个后端半边**为之存在**的那个场景。
//
// 一个在**一窗内**做客户端分组的 rail 会报出一个随你滚动而变的数:第 1 页看见组里 3 条、第 2 页再看见 3 条，于是
// 组头会数出 3、再 6、再 9——一个在 workspace 什么都没动时自己在动的数。故本场景以很小的页把一个组翻到尾，并在
// **每翻一页之后**重问投影:它必须每一次都答出**一模一样**的数，且各页合起来必须恰好枚举出它宣称的那个数。
func TestChatWorkDirGroups_CountsDoNotDriftAcrossPaging(t *testing.T) {
	t.Parallel()
	wc, _ := chatSetup(t, false)
	dir, other := t.TempDir(), t.TempDir()

	const inGroup, inOther = 7, 3
	for i := 0; i < inGroup; i++ {
		id := convCreate(t, wc, fmt.Sprintf("grouped-%02d", i))
		wdMount(t, wc, id, dir)
	}
	for i := 0; i < inOther; i++ {
		id := convCreate(t, wc, fmt.Sprintf("other-%02d", i))
		wdMount(t, wc, id, other)
	}
	// One pinned + one archived member, because the count's rules must hold across paging too, not only on
	// page one. 一条置顶 + 一条归档的成员，因为计数的规则也必须跨翻页成立、而不只在首页成立。
	pin := convCreate(t, wc, "grouped-pinned")
	wdMount(t, wc, pin, dir)
	wdSetPinned(t, wc, pin, true)
	arch := convCreate(t, wc, "grouped-archived")
	wdMount(t, wc, arch, dir)
	wdSetArchived(t, wc, arch, true)

	want, ok := wdGroup(t, wc, dir)
	if !ok || want.ActiveCount != inGroup || want.ArchivedCount != 1 {
		t.Fatalf("baseline group = %+v, want %d active / 1 archived", want, inGroup)
	}

	// Walk the group to its end, two rows at a time, re-asking the projection after every page.
	// 每次两行把组翻到尾，每翻一页之后都重问投影。
	esc := url.QueryEscape(dir)
	seen := map[string]bool{}
	cursor, pages := "", 0
	for {
		q := "limit=2&archived=all&pinned=false&workDir=" + esc
		if cursor != "" {
			q += "&cursor=" + url.QueryEscape(cursor)
		}
		rows, next := wdList(t, wc, q)
		for _, r := range rows {
			if seen[r.ID] {
				t.Fatalf("page %d returned %q twice — the keyset page is not stable under the residency filter", pages, r.Title)
			}
			seen[r.ID] = true
		}
		pages++
		got, ok := wdGroup(t, wc, dir)
		if !ok || got != want {
			t.Fatalf("after page %d the projection said %+v, want %+v — the count DRIFTED with paging", pages, got, want)
		}
		if next == "" {
			break
		}
		cursor = next
		if pages > 20 {
			t.Fatalf("the group never ran out of pages — paging is not terminating")
		}
	}
	if pages < 4 {
		t.Fatalf("the group must really have taken several pages to walk, took %d", pages)
	}
	// The pages together enumerate exactly what the head claims — count and membership agree.
	// 各页合起来恰好枚举出组头宣称的那个数——计数与成员一致。
	if len(seen) != want.ActiveCount+want.ArchivedCount {
		t.Fatalf("walked %d rows but the head claims %d — the count and the rows disagree",
			len(seen), want.ActiveCount+want.ArchivedCount)
	}
	if seen[pin] {
		t.Fatalf("the pinned member must not appear in the group's own pages")
	}
	// And the OTHER group was never disturbed by any of this. 而**另一个**组从未被这一切扰动。
	if g, ok := wdGroup(t, wc, other); !ok || g.ActiveCount != inOther {
		t.Fatalf("the other group = %+v, want %d active", g, inOther)
	}
}
