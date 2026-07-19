package flowrun

import (
	"context"
	"database/sql"
	"encoding/hex"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// The load-bearing invariant under every BARE time window in this package: the started_at window
// (工单⑥), the completed_at window (工单⑮), and RunStats' `since` FILTERs, which 工单⑮ unwrapped
// from julianday(). All four rest on one claim — a stored DATETIME and a bound time.Time are the
// same text format, so SQLite's text comparison IS chronological comparison.
//
// That claim was ASSERTED in three places and CONTRADICTED in two others ("julianday normalizes the
// format drift ... which raw string comparison would mis-order at the margins"), so it is pinned
// here by measurement instead of by comment. If Go or the driver ever changes how a time renders —
// a space to a `T`, `+00:00` to `Z`, trailing zeros in the fraction — every one of those windows
// silently starts answering the wrong question, and this test is what says so.
//
// 本包每一个**裸**时间窗底下那条承重不变式：started_at 窗（工单⑥）、completed_at 窗（工单⑮）、以及 RunStats
// 被工单⑮ 从 julianday() 里拆出来的 `since` FILTER。四者都压在同一条断言上——落库的 DATETIME 与绑定的
// time.Time 是**同一种文本格式**，故 SQLite 的文本比较**就是**时间比较。
//
// 这条断言曾在三处被**断言**、又在另两处被**反驳**（「julianday 归一格式漂移……裸字符串比较会在边缘错序」），
// 故在此用**实测**钉死、而非用注释。若 Go 或驱动哪天改了时间的渲染——空格变 `T`、`+00:00` 变 `Z`、小数补尾零
// ——上面每一个窗都会**静默地**开始回答错误的问题，而本测试就是那个出声的东西。
func TestTimeText_OrdersChronologically(t *testing.T) {
	db, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer db.Close()
	db.SetMaxOpenConns(1)
	for _, stmt := range Schema {
		if _, err := db.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	st := New(ormpkg.Open(db))
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")

	// The precision spread retention.go names as the danger: "second-precision legacy rows against
	// nanosecond ones". Written through the real path, so the bytes are the product's bytes.
	// retention.go 点名的那个危险：「秒精度旧行 vs 纳秒行」。走真写入路径，故字节即产品的字节。
	base := time.Date(2026, 7, 17, 10, 0, 0, 0, time.UTC)
	spread := []struct {
		id string
		at time.Time
	}{
		{"fr_sec", base},                                // second precision, no fraction at all
		{"fr_ns", base.Add(1 * time.Nanosecond)},        // 1ns later — the tightest possible margin
		{"fr_us", base.Add(1 * time.Microsecond)},       // sub-millisecond: julianday() CANNOT see this
		{"fr_halfms", base.Add(400 * time.Microsecond)}, // the exact gap that made the card say 4 and the list 2
		{"fr_ms", base.Add(1 * time.Millisecond)},       // millisecond
		{"fr_tenth", base.Add(100 * time.Millisecond)},  // .1 — a fraction Go prints with ONE digit
		{"fr_half", base.Add(500 * time.Millisecond)},   // .5 — trailing-zero territory
		{"fr_sec2", base.Add(1 * time.Second)},          // next whole second (no fraction again)
		{"fr_min", base.Add(1 * time.Minute)},           // separator/offset region unaffected
		{"fr_neg", base.Add(-1 * time.Nanosecond)},      // 1ns EARLIER — crosses the whole-second text
		{"fr_negms", base.Add(-400 * time.Microsecond)}, // the other side of the julianday rounding
		{"fr_day", base.Add(-25 * time.Hour)},           // yesterday — the 24h card's real neighbour
		{"fr_future", base.Add(90 * 24 * time.Hour)},    // far future
		{"fr_old", base.Add(-400 * 24 * time.Hour)},     // far past (year rolls)
	}
	for _, s := range spread {
		at := s.at
		run := &flowrundomain.FlowRun{
			ID: s.id, WorkflowID: "wf_1", VersionID: "wfv_1", Status: "failed",
			StartedAt: at, UpdatedAt: at, CompletedAt: &at,
		}
		if err := st.runs.Create(ctx, run); err != nil {
			t.Fatalf("create %s: %v", s.id, err)
		}
	}

	// 1. ONE canonical format on disk — the premise. hex() so no driver scan-conversion can dress it
	//    up (reading completed_at back as a string shows RFC3339 that is NOT what is stored).
	//    磁盘上只有一种规范格式——大前提。用 hex() 使驱动的 scan 转换无法给它化妆。
	var boundHex string
	if err := db.QueryRow(`SELECT hex(?)`, base).Scan(&boundHex); err != nil {
		t.Fatalf("bound hex: %v", err)
	}
	boundTxt, _ := hex.DecodeString(boundHex)
	var storedHex string
	if err := db.QueryRow(`SELECT hex(completed_at) FROM flowruns WHERE id='fr_sec'`).Scan(&storedHex); err != nil {
		t.Fatalf("stored hex: %v", err)
	}
	storedTxt, _ := hex.DecodeString(storedHex)
	if string(storedTxt) != string(boundTxt) {
		t.Fatalf("the premise of every bare window is broken — a stored instant and a bound instant\n"+
			"must render identically, else text comparison is not chronological comparison:\n"+
			"  stored: %q\n  bound : %q", storedTxt, boundTxt)
	}
	// The precondition, made explicit: text order = chronological order ONLY within UTC. The driver
	// renders `2026-07-17 18:00:00+08:00` for the same instant as `2026-07-17 10:00:00+00:00`, and
	// text-compares them wrong (`18` > `10`). This is why every window's comment says "(UTC — the
	// handler normalizes)" and why parseListTime / parseSince call .UTC() and stamp() uses
	// time.Now().UTC(): the normalization is load-bearing, not decoration. Proven here so the claim
	// is a fact, not a hope.
	// 前提，写明：文本序 = 时间序**只在 UTC 内**成立。驱动把同一时刻渲成 `+08:00` 与 `+00:00` 两种、且文本
	// 比错（`18` > `10`）。这正是每个窗的注释都写「(UTC——handler 归一)」、parseListTime / parseSince 都调
	// .UTC()、stamp() 用 time.Now().UTC() 的原因：这个归一是**承重**的、不是装饰。在此证明，使断言成为事实。
	shifted := base.In(time.FixedZone("x", 8*3600))
	var wrong bool
	if err := db.QueryRow(`SELECT ? > ?`, shifted, base).Scan(&wrong); err != nil {
		t.Fatalf("zone probe: %v", err)
	}
	if !wrong {
		t.Fatalf("EXPECTED a non-UTC bound to text-compare wrong against its own UTC instant — if it " +
			"no longer does, the .UTC() normalization guarding every window may be removable, but that " +
			"is a measurement, not an assumption")
	}

	// 2. For EVERY pair, SQLite's `>=` on the column must agree with Go's chronology — this is what
	//    the windows actually run. 对**每一对**，SQLite 在列上的 `>=` 必须与 Go 的时序一致——窗口跑的就是它。
	for _, a := range spread {
		for _, b := range spread {
			var got bool
			if err := db.QueryRow(
				`SELECT EXISTS(SELECT 1 FROM flowruns WHERE id = ? AND completed_at >= ?)`, a.id, b.at,
			).Scan(&got); err != nil {
				t.Fatalf("compare %s >= %s: %v", a.id, b.id, err)
			}
			want := !a.at.Before(b.at)
			if got != want {
				t.Fatalf("text order must equal chronological order (the bare-window premise):\n"+
					"  %s (%s) >= %s (%s)\n  sqlite=%v  go=%v",
					a.id, a.at.Format(time.RFC3339Nano), b.id, b.at.Format(time.RFC3339Nano), got, want)
			}
		}
	}

	// 3. And the counter-example that justifies the repeal: julianday() does NOT have this property.
	//    It resolves to milliseconds, so it calls a run that landed 400µs BEFORE the bound "inside
	//    the window" — the disagreement that made the card count 4 while its list held 2.
	//    而这就是拆掉它的理由：julianday() **没有**这条性质。它只到毫秒，故把一个在界前 400µs 落定的 run
	//    判成「在窗内」——正是这个分歧让牌数 4、列表装 2。
	var bare, jd int
	if err := db.QueryRow(
		`SELECT COUNT(*) FROM flowruns WHERE id='fr_negms' AND completed_at >= ?`, base,
	).Scan(&bare); err != nil {
		t.Fatalf("bare: %v", err)
	}
	if err := db.QueryRow(
		`SELECT COUNT(*) FROM flowruns WHERE id='fr_negms' AND julianday(completed_at) >= julianday(?)`, base,
	).Scan(&jd); err != nil {
		t.Fatalf("julianday: %v", err)
	}
	if bare != 0 {
		t.Fatalf("a run 400µs BEFORE the bound is outside the window; bare comparison said inside")
	}
	if jd != 1 {
		t.Fatalf("this test's reason to exist is that julianday() rounds this row INTO the window "+
			"(got %d). If that stopped being true, the repeal's counter-example needs re-measuring, "+
			"not deleting", jd)
	}
}
