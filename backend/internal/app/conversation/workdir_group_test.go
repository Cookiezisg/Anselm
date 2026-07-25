package conversation

import (
	"context"
	"errors"
	"testing"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	messagesstore "github.com/sunweilin/anselm/backend/internal/infra/store/messages"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// mkConv creates a conversation and puts it in the requested shape (residency / pin / archive) so a
// grouping test reads as a table rather than as six PATCH calls.
//
// mkConv 建一条对话并把它摆成要求的形状（驻地 / 置顶 / 归档），使分组测试读起来像一张表、而不是六次 PATCH。
func mkConv(t *testing.T, svc *Service, ctx context.Context, title, workDir string, pinned, archived bool) string {
	t.Helper()
	c, err := svc.Create(ctx, title)
	if err != nil {
		t.Fatalf("create %q: %v", title, err)
	}
	in := UpdateInput{}
	if workDir != "" {
		in.WorkDir = &workDir
	}
	if pinned {
		in.Pinned = &pinned
	}
	if archived {
		in.Archived = &archived
	}
	if in.WorkDir != nil || in.Pinned != nil || in.Archived != nil {
		if _, err := svc.Update(ctx, c.ID, in); err != nil {
			t.Fatalf("shape %q: %v", title, err)
		}
	}
	return c.ID
}

func groupsByDir(t *testing.T, svc *Service, ctx context.Context) map[string]conversationdomain.WorkDirGroup {
	t.Helper()
	rows, err := svc.WorkDirGroups(ctx)
	if err != nil {
		t.Fatalf("WorkDirGroups: %v", err)
	}
	out := map[string]conversationdomain.WorkDirGroup{}
	for _, g := range rows {
		out[g.WorkDir] = g
	}
	return out
}

// TestWorkDirGroups_CountsAndOrder: the projection is the batch's anti-drift piece, so what it counts has
// to be pinned down precisely — unmounted threads are not a group, pinned threads are hoisted out of their
// group (they render in the rail's own Pinned section and must appear exactly once), soft-deleted threads
// are gone, and the two archive counts are reported separately so the endpoint needs no parameter.
//
// TestWorkDirGroups_CountsAndOrder：投影是本批的防漂移件，故它到底数什么必须钉死——未挂线程不构成组、置顶线程
// 被提出它的组（它们渲在 rail 自己的置顶段、必须恰好出现一次）、软删线程不算，而两个归档计数分开上报使该端点
// 不需要任何参数。
func TestWorkDirGroups_CountsAndOrder(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	alpha, beta := "/tmp/anselm-alpha", "/tmp/anselm-beta"

	mkConv(t, svc, ctx, "a1", alpha, false, false)
	mkConv(t, svc, ctx, "a2", alpha, false, true) // archived → the second count
	mkConv(t, svc, ctx, "a3", alpha, true, false) // pinned → hoisted out, counted nowhere here
	mkConv(t, svc, ctx, "homeless", "", false, false)
	gone := mkConv(t, svc, ctx, "a4", alpha, false, false)
	mkConv(t, svc, ctx, "b1", beta, false, false) // newest activity → beta must lead
	if err := svc.Delete(ctx, gone); err != nil {
		t.Fatalf("delete: %v", err)
	}

	got := groupsByDir(t, svc, ctx)
	if len(got) != 2 {
		t.Fatalf("want exactly the two mounted residencies, got %d: %+v", len(got), got)
	}
	if _, ok := got[""]; ok {
		t.Fatalf("the unmounted threads are NOT a group — they have no folder head and no ⋯ menu: %+v", got)
	}
	if g := got[alpha]; g.ActiveCount != 1 || g.ArchivedCount != 1 {
		t.Fatalf("alpha counts = %d active / %d archived, want 1/1 (pinned hoisted, deleted gone)", g.ActiveCount, g.ArchivedCount)
	}
	if g := got[beta]; g.ActiveCount != 1 || g.ArchivedCount != 0 {
		t.Fatalf("beta counts = %d/%d, want 1/0", g.ActiveCount, g.ArchivedCount)
	}
	if got[alpha].LastMessageAt.IsZero() {
		t.Fatalf("a group must report when it was last active, got zero")
	}

	// Ordering is by the group's own recency, so the folder you were just in heads the list.
	// 组序按组自身的最近活跃，故你刚待过的那个文件夹领头。
	rows, err := svc.WorkDirGroups(ctx)
	if err != nil {
		t.Fatalf("WorkDirGroups: %v", err)
	}
	if rows[0].WorkDir != beta {
		t.Fatalf("groups must be most-recently-active first, got %q first", rows[0].WorkDir)
	}
}

// TestWorkDirGroups_LastGroupMemberLeavingRemovesTheGroup: a group is a PROJECTION, not an entity — no
// table, no lifecycle. The last thread leaving must make the group vanish on its own, because "empty group
// management" is a thing this design deliberately does not have.
//
// TestWorkDirGroups_LastGroupMemberLeavingRemovesTheGroup：组是**投影、不是实体**——无表、无生命周期。最后一条
// 线程离开必须让组**自行消失**，因为「空组管理」正是本设计刻意没有的东西。
func TestWorkDirGroups_LastGroupMemberLeavingRemovesTheGroup(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	dir := "/tmp/anselm-solo"
	id := mkConv(t, svc, ctx, "only", dir, false, false)
	if _, ok := groupsByDir(t, svc, ctx)[dir]; !ok {
		t.Fatalf("the group must exist while a thread lives in it")
	}
	// Leaving the residency (PATCH workDir="") is the OTHER way out of a group, beside archive/delete — the
	// thread moves back to Recents. 退出驻地（PATCH workDir=""）是离开一个组的**另一**条路，线程移回「最近」。
	empty := ""
	if _, err := svc.Update(ctx, id, UpdateInput{WorkDir: &empty}); err != nil {
		t.Fatalf("unmount: %v", err)
	}
	if g, ok := groupsByDir(t, svc, ctx)[dir]; ok {
		t.Fatalf("the group must vanish with its last member, still got %+v", g)
	}
}

// TestList_WorkDirAndPinnedFilters: the rail's four sections are four server queries, so each filter's
// three states must be exactly what the sections need. The `workDir` pointer's middle state is the one that
// earns it: `&""` means ONLY the unmounted threads (Recents), which a plain string could not distinguish
// from "no filter".
//
// TestList_WorkDirAndPinnedFilters：rail 的四段是四条服务端查询，故每个过滤的三态必须正是各段所需。`workDir`
// 指针的中间态正是它存在的理由:`&""` 意为**仅未挂**的线程（最近），而裸字符串区分不了它与「不过滤」。
func TestList_WorkDirAndPinnedFilters(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	dir := "/tmp/anselm-filters"
	mkConv(t, svc, ctx, "in-dir", dir, false, false)
	mkConv(t, svc, ctx, "in-dir-pinned", dir, true, false)
	mkConv(t, svc, ctx, "homeless", "", false, false)
	mkConv(t, svc, ctx, "homeless-pinned", "", true, false)

	titles := func(f ListFilter) []string {
		t.Helper()
		rows, _, err := svc.List(ctx, f)
		if err != nil {
			t.Fatalf("list %+v: %v", f, err)
		}
		out := make([]string, 0, len(rows))
		for _, c := range rows {
			out = append(out, c.Title)
		}
		return out
	}
	same := func(got, want []string) bool {
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

	empty := ""
	cases := []struct {
		name   string
		filter ListFilter
		want   []string
	}{
		{"no residency filter = every thread (the pre-WD1.5 default)", ListFilter{}, []string{"in-dir", "in-dir-pinned", "homeless", "homeless-pinned"}},
		{"workDir=&\"\" = ONLY the unmounted ones", ListFilter{WorkDir: &empty}, []string{"homeless", "homeless-pinned"}},
		{"workDir=&path = one group", ListFilter{WorkDir: &dir}, []string{"in-dir", "in-dir-pinned"}},
		{"pinned only = the rail's Pinned section, across residencies", ListFilter{Pinned: conversationdomain.PinPinned}, []string{"in-dir-pinned", "homeless-pinned"}},
		{"the Recents section: unmounted AND unpinned", ListFilter{WorkDir: &empty, Pinned: conversationdomain.PinUnpinned}, []string{"homeless"}},
		{"a group's rows: that residency AND unpinned", ListFilter{WorkDir: &dir, Pinned: conversationdomain.PinUnpinned}, []string{"in-dir"}},
	}
	for _, tc := range cases {
		if got := titles(tc.filter); !same(got, tc.want) {
			t.Errorf("%s: got %v, want %v", tc.name, got, tc.want)
		}
	}
}

// TestArchiveWorkDir_ScopeAndCount: the head's number and the confirm dialog's inventory are the SAME
// number, which only works if the action's scope is the group's scope — unpinned, that residency, nothing
// else in the workspace.
//
// TestArchiveWorkDir_ScopeAndCount：组头的数与确认框的盘点是**同一个**数，而这只在动作范围等于组的范围时才成立
// ——未置顶、该驻地、workspace 里别的什么都不碰。
func TestArchiveWorkDir_ScopeAndCount(t *testing.T) {
	svc, em, _, ctx := newSvc(t)
	dir, other := "/tmp/anselm-arch", "/tmp/anselm-other"
	a := mkConv(t, svc, ctx, "a", dir, false, false)
	b := mkConv(t, svc, ctx, "b", dir, false, false)
	pin := mkConv(t, svc, ctx, "pinned", dir, true, false)
	out := mkConv(t, svc, ctx, "elsewhere", other, false, false)
	home := mkConv(t, svc, ctx, "homeless", "", false, false)

	n, err := svc.ArchiveWorkDir(ctx, dir)
	if err != nil {
		t.Fatalf("ArchiveWorkDir: %v", err)
	}
	if n != 2 {
		t.Fatalf("archived %d, want 2 (the group's unpinned threads)", n)
	}
	archived := func(id string) bool {
		c, err := svc.Get(ctx, id)
		if err != nil {
			t.Fatalf("get %s: %v", id, err)
		}
		return c.Archived
	}
	if !archived(a) || !archived(b) {
		t.Fatalf("both group threads must be archived")
	}
	if archived(pin) {
		t.Fatalf("a PINNED thread must survive a folder-wide archive — pinning is the user saying it matters")
	}
	if archived(out) || archived(home) {
		t.Fatalf("the action must not reach outside its own residency")
	}
	// One echo per row that actually changed, on the EXISTING word (E1/E2). 每条真改了的行一条回声、用既有词。
	var echoes int
	for _, e := range em.broadcast {
		if e == "conversation.archived" {
			echoes++
		}
	}
	if echoes != 2 {
		t.Fatalf("conversation.archived echoes = %d, want 2", echoes)
	}

	// Re-running reports 0 and emits nothing: the count says what CHANGED, not what matched.
	// 重跑报 0 且不发任何东西:计数说的是**改变了什么**、不是匹配了什么。
	em.broadcast = nil
	if n, err := svc.ArchiveWorkDir(ctx, dir); err != nil || n != 0 {
		t.Fatalf("re-archive = (%d, %v), want (0, nil)", n, err)
	}
	if len(em.broadcast) != 0 {
		t.Fatalf("a no-op must not echo, got %v", em.broadcast)
	}
}

// TestDeleteWorkDir_SoftDeletesAndCascades: the group delete is a business-table soft delete plus the same
// per-row cascade a single DELETE performs — and it is scope-BLIND across archive states, because a
// destructive action must not depend on which view toggle happens to be on.
//
// TestDeleteWorkDir_SoftDeletesAndCascades：组删除是业务表软删 + 与单条 DELETE 完全相同的逐行级联——且它**跨
// 归档态、对范围盲**，因为破坏性动作不该取决于哪个视图开关正好开着。
func TestDeleteWorkDir_SoftDeletesAndCascades(t *testing.T) {
	svc, em, rel, ctx := newSvc(t)
	tp := &fakeTouchpoints{}
	svc.SetTouchpointPurger(tp)
	dir := "/tmp/anselm-del"
	a := mkConv(t, svc, ctx, "a", dir, false, false)
	b := mkConv(t, svc, ctx, "b", dir, false, true) // archived — deleted all the same
	pin := mkConv(t, svc, ctx, "pinned", dir, true, false)
	keep := mkConv(t, svc, ctx, "homeless", "", false, false)

	n, err := svc.DeleteWorkDir(ctx, dir)
	if err != nil {
		t.Fatalf("DeleteWorkDir: %v", err)
	}
	if n != 2 {
		t.Fatalf("deleted %d, want 2 (unpinned, both archive states)", n)
	}
	for _, id := range []string{a, b} {
		if _, err := svc.Get(ctx, id); !errors.Is(err, conversationdomain.ErrNotFound) {
			t.Fatalf("%s must be gone from every read path, got err=%v", id, err)
		}
	}
	if _, err := svc.Get(ctx, pin); err != nil {
		t.Fatalf("a PINNED thread must survive a folder-wide delete: %v", err)
	}
	if _, err := svc.Get(ctx, keep); err != nil {
		t.Fatalf("an unmounted thread must be untouched: %v", err)
	}
	// The derived indexes of a thread that no longer exists go with it — same cascade as single Delete.
	// 一条已不存在的线程的派生索引随它而去——与单条 Delete 同一级联。
	if len(rel.purged) != 2 || len(tp.purged) != 2 {
		t.Fatalf("cascades = %d relation / %d touchpoint purges, want 2/2", len(rel.purged), len(tp.purged))
	}
	var echoes int
	for _, e := range em.broadcast {
		if e == "conversation.deleted" {
			echoes++
		}
	}
	if echoes != 2 {
		t.Fatalf("conversation.deleted echoes = %d, want 2", echoes)
	}
	// And the group is gone from the projection all by itself (only the pinned thread is left, and pinned
	// threads never count). 而组自行从投影里消失了（只剩那条置顶的，而置顶从不计入）。
	if g, ok := groupsByDir(t, svc, ctx)[dir]; ok {
		t.Fatalf("the group must vanish once its unpinned threads are gone, got %+v", g)
	}
}

// TestWorkDirActions_RejectTheTwoUnnameableSpellings: an EMPTY workDir is a perfectly good list FILTER
// (Recents asks for exactly that) but it is NOT a group, and accepting it would let one request archive or
// delete every thread in the workspace that never picked a directory — an action no surface offers and no
// confirm dialog ever inventoried. A relative path roots nothing (WD1's rule).
//
// TestWorkDirActions_RejectTheTwoUnnameableSpellings：**空** workDir 是一个完全正当的列表**过滤**（「最近」要的
// 正是它），但它**不是一个组**;接受它会让一个请求归档或删除本 workspace 里每一条从未选过目录的线程——那是没有
// 任何界面提供、也从未被任何确认框盘点过的动作。相对路径扎不住任何东西（WD1 的规则）。
func TestWorkDirActions_RejectTheTwoUnnameableSpellings(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	homeless := mkConv(t, svc, ctx, "homeless", "", false, false)

	for _, spelling := range []string{"", "   "} {
		if _, err := svc.ArchiveWorkDir(ctx, spelling); !errors.Is(err, errorspkg.ErrInvalidRequest) {
			t.Fatalf("archive %q: err = %v, want INVALID_REQUEST", spelling, err)
		}
		if _, err := svc.DeleteWorkDir(ctx, spelling); !errors.Is(err, errorspkg.ErrInvalidRequest) {
			t.Fatalf("delete %q: err = %v, want INVALID_REQUEST", spelling, err)
		}
	}
	if _, err := svc.ArchiveWorkDir(ctx, "relative/dir"); !errors.Is(err, conversationdomain.ErrInvalidWorkDir) {
		t.Fatalf("archive relative: err = %v, want CONVERSATION_INVALID_WORK_DIR", err)
	}
	if _, err := svc.DeleteWorkDir(ctx, "relative/dir"); !errors.Is(err, conversationdomain.ErrInvalidWorkDir) {
		t.Fatalf("delete relative: err = %v, want CONVERSATION_INVALID_WORK_DIR", err)
	}
	// The refusal is total: nothing was archived, nothing was deleted. 拒绝是彻底的:什么都没归档、什么都没删。
	c, err := svc.Get(ctx, homeless)
	if err != nil || c.Archived {
		t.Fatalf("the unmounted thread must be untouched, got (%+v, %v)", c, err)
	}
}

// TestDeleteWorkDir_NeverTouchesAMessageRow is the D1 assertion, and it lives here rather than in testend
// because it is NOT observable through the black box: every message read path is parented by a conversation
// existence check, so a tombstoned thread's messages answer 404 by design — the wire cannot distinguish
// "the thread's row is tombstoned" from "its messages were wiped". So the proof is made where both tables
// are visible: stand the `messages` / `message_blocks` schema up in the SAME database, write a real turn
// into a thread of the group, delete the whole group, and read the rows straight back out of the messages
// store.
//
// They MUST still be there. `messages` / `message_blocks` are D1 Log tables — no `deleted_at` column at
// all, so there is no such thing as logically deleting them, and physically deleting them is legislated to
// exactly two places (flowrun `:replay`, run-retention purge), neither of which is here.
//
// TestDeleteWorkDir_NeverTouchesAMessageRow 是那条 D1 断言，而它住在这里、不在 testend，因为它**在黑盒里不可
// 观测**:每条消息读路径都被一次对话存在性检查所辖，故一条已立碑线程的消息按设计答 404——线缆分不清「线程的行被
// 立碑了」与「它的消息被抹了」。故这个证明在**两张表都看得见**的地方做:把 `messages` / `message_blocks` 的 schema
// 立在**同一个**数据库里、往组内一条线程写一个真回合、删掉整个组，再从 messages store 直接把行读回来。
//
// 它们**必须**还在。`messages` / `message_blocks` 是 D1 Log 表——**根本没有** `deleted_at` 列，故不存在「逻辑删
// 它们」这件事，而物理删被立法限定在恰好两处（flowrun `:replay`、run 保留线清理），此处不是其中任何一处。
func TestDeleteWorkDir_NeverTouchesAMessageRow(t *testing.T) {
	svc, _, _, sqlDB, ctx := newSvcDB(t)
	for _, stmt := range messagesstore.Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("messages schema: %v", err)
		}
	}
	msgs := messagesstore.New(ormpkg.Open(sqlDB))

	dir := "/tmp/anselm-d1"
	convID := mkConv(t, svc, ctx, "a real turn", dir, false, false)
	msg := &messagesdomain.Message{
		ID:             "msg_00000000000000d1",
		ConversationID: convID,
		Role:           messagesdomain.RoleUser,
		Status:         messagesdomain.StatusCompleted,
	}
	blocks := []messagesdomain.Block{{
		ID:             "blk_00000000000000d1",
		ConversationID: convID,
		MessageID:      msg.ID,
		Type:           messagesdomain.BlockTypeText,
		Content:        "this sentence must survive the folder-wide delete",
	}}
	if err := msgs.CreateMessage(ctx, msg, blocks); err != nil {
		t.Fatalf("write the turn: %v", err)
	}

	if n, err := svc.DeleteWorkDir(ctx, dir); err != nil || n != 1 {
		t.Fatalf("DeleteWorkDir = (%d, %v), want (1, nil)", n, err)
	}
	if _, err := svc.Get(ctx, convID); !errors.Is(err, conversationdomain.ErrNotFound) {
		t.Fatalf("the thread's own row must be tombstoned, got err=%v", err)
	}

	rows, _, err := msgs.ListMessages(ctx, convID, "", 50)
	if err != nil {
		t.Fatalf("read the messages back: %v", err)
	}
	if len(rows) != 1 || rows[0].ID != msg.ID {
		t.Fatalf("the message row must still be on disk, got %d rows: %+v", len(rows), rows)
	}
	if len(rows[0].Blocks) != 1 || rows[0].Blocks[0].Content != blocks[0].Content {
		t.Fatalf("the block row must still be on disk byte-for-byte, got %+v", rows[0].Blocks)
	}
}

// TestWorkDirActions_AreAllOrNothing: the reason these are endpoints rather than a loop of N PATCHes is that
// a loop can stop half-way, leaving a folder the user asked to file away neither filed nor unfiled. This
// proves the replacement cannot, against BOTH shapes of half-write — and the two shapes lock two different
// guarantees:
//
//   - `RAISE(ABORT)` makes one row error out. The statement fails, the error must reach the caller, and
//     nothing may be announced or torn down.
//   - `RAISE(IGNORE)` is the mean one: a BEFORE trigger silently SKIPS that row, so the UPDATE succeeds
//     having written FEWER rows than the ids the same transaction resolved. Statement-level atomicity alone
//     would happily commit the other row here — only the row-count cross-check inside the transaction turns
//     a silent half-action into a rolled-back error.
//
// TestWorkDirActions_AreAllOrNothing：这两个动作之所以是端点而不是 N 次 PATCH 的循环，正因为循环会半途停下、
// 把用户要收起的一个文件夹留在既非收起也非未收起的状态。本测试对**两种**半写形状都证明替代品不会——而两种形状
// 钉住的是两条**不同**的保证:
//
//   - `RAISE(ABORT)` 让一行**报错**。语句失败、错误必须抵达调用方、且什么都不该被宣告或拆除。
//   - `RAISE(IGNORE)` 是刁的那个:BEFORE 触发器**静默跳过**那一行，于是 UPDATE **成功**了、却写了比同一事务里
//     解出的 id **更少**的行。单靠语句级原子性会在此心满意足地提交另一行——只有事务内的**行数交叉核对**才把一次
//     静默的半个动作变成一次回滚的错误。
func TestWorkDirActions_AreAllOrNothing(t *testing.T) {
	archived := func(s *Service, ctx context.Context, id string) bool {
		c, err := s.Get(ctx, id)
		return err != nil || c.Archived
	}
	deleted := func(s *Service, ctx context.Context, id string) bool {
		_, err := s.Get(ctx, id)
		return err != nil
	}
	run := func(kind string) func(*Service, context.Context, string) (int, error) {
		if kind == "archive" {
			return func(s *Service, ctx context.Context, dir string) (int, error) { return s.ArchiveWorkDir(ctx, dir) }
		}
		return func(s *Service, ctx context.Context, dir string) (int, error) { return s.DeleteWorkDir(ctx, dir) }
	}
	for _, tc := range []struct {
		name   string
		column string
		action string
		raise  string
	}{
		{"archive/one row errors", "archived", "archive", `RAISE(ABORT, 'boom')`},
		{"archive/one row silently skipped", "archived", "archive", `RAISE(IGNORE)`},
		{"delete/one row errors", "deleted_at", "delete", `RAISE(ABORT, 'boom')`},
		{"delete/one row silently skipped", "deleted_at", "delete", `RAISE(IGNORE)`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			svc, em, rel, sqlDB, ctx := newSvcDB(t)
			dir := "/tmp/anselm-atomic"
			a := mkConv(t, svc, ctx, "a", dir, false, false)
			mkConv(t, svc, ctx, "b", dir, false, false)
			trigger := `CREATE TRIGGER boom BEFORE UPDATE OF ` + tc.column +
				` ON conversations WHEN new.title = 'b' BEGIN SELECT ` + tc.raise + `; END`
			if _, err := sqlDB.Exec(trigger); err != nil {
				t.Fatalf("install trigger: %v", err)
			}
			em.broadcast = nil

			if n, err := run(tc.action)(svc, ctx, dir); err == nil {
				t.Fatalf("a half-written group must fail the whole action, got n=%d err=nil", n)
			}
			moved := archived
			if tc.action == "delete" {
				moved = deleted
			}
			if moved(svc, ctx, a) {
				t.Fatalf("row 'a' moved even though row 'b' did not — the group is half-written")
			}
			// No echo, no cascade: nothing happened, so nothing may be announced or torn down.
			// 无回声、无级联:什么都没发生，故什么都不该被宣告或拆除。
			if len(em.broadcast) != 0 || len(rel.purged) != 0 {
				t.Fatalf("a rolled-back action must announce nothing: broadcast=%v purged=%v", em.broadcast, rel.purged)
			}
		})
	}
}
