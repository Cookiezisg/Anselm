package spend

import (
	"context"
	"testing"
	"time"

	spenddomain "github.com/sunweilin/anselm/backend/internal/domain/spend"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

type fakeRepo struct {
	got  []spenddomain.Entry
	fail error
}

func (f *fakeRepo) Record(_ context.Context, e *spenddomain.Entry) error {
	if f.fail != nil {
		return f.fail
	}
	f.got = append(f.got, *e)
	return nil
}

func (f *fakeRepo) AggregateDaily(context.Context, time.Time) ([]spenddomain.DayRow, error) {
	return nil, nil
}

// TestRecord_ManagedIsNotDoubleCounted: the gateway journals managed spend authoritatively and the
// desktop already shows it (the free-tier quota card). Booking it here too would count one payment
// twice and make the panel lie in the one direction users notice.
//
// TestRecord_ManagedIsNotDoubleCounted:受管支出由网关权威记账、桌面已在免费档配额卡展示。这儿再记
// 一次等于把同一笔钱数两遍,面板会朝**用户看得出来**的那个方向撒谎。
func TestRecord_ManagedIsNotDoubleCounted(t *testing.T) {
	repo := &fakeRepo{}
	s := New(repo, nil)
	s.Record(context.Background(), spenddomain.CategoryImage, "anselm", "", 1)
	if len(repo.got) != 0 {
		t.Fatalf("managed call was booked: %+v", repo.got)
	}
	s.Record(context.Background(), spenddomain.CategoryImage, "qwen", "qwen-image-2.0", 1)
	if len(repo.got) != 1 {
		t.Fatalf("direct call must be booked, got %d rows", len(repo.got))
	}
}

// TestRecord_UnknownPriceIsZeroNotAGuess: an unlisted model books its TRUE unit count with a zero
// estimate. Zero means "honestly unknown" — the alternative (guessing a neighbouring model's rate)
// would put four significant digits of authority behind a number nobody verified, which is the one
// thing this ledger exists not to do.
//
// TestRecord_UnknownPriceIsZeroNotAGuess:表里没有的模型,照记**真实**用量、估价为 0。0 意味着
// 「诚实的未知」——另一条路(拿邻近模型的价猜一个)会给一个没人核过的数字披上四位有效数字的权威,
// 而那正是本台账存在的意义所要避免的。
func TestRecord_UnknownPriceIsZeroNotAGuess(t *testing.T) {
	repo := &fakeRepo{}
	s := New(repo, nil)
	s.Record(context.Background(), spenddomain.CategoryImage, "qwen", "some-unlisted-model", 3)
	if len(repo.got) != 1 {
		t.Fatalf("rows = %d, want 1", len(repo.got))
	}
	if repo.got[0].Units != 3 {
		t.Fatalf("units = %d, want the true count 3", repo.got[0].Units)
	}
	if repo.got[0].EstPUSD != 0 {
		t.Fatalf("est = %d, want 0 (honestly unknown, never a guess)", repo.got[0].EstPUSD)
	}
}

// TestRecord_PricesMultiplyByUnits pins the arithmetic against the gateway's own cards: the two
// repos speak one currency (pUSD) and the same assumed- numbers, so a reconciliation changes both.
//
// TestRecord_PricesMultiplyByUnits 对着网关自己的卡钉住算术:两仓说同一种货币(pUSD)、同一批
// assumed- 数字,故一次销账两边一起改。
func TestRecord_PricesMultiplyByUnits(t *testing.T) {
	repo := &fakeRepo{}
	s := New(repo, nil)
	// 10,000 characters at 14e6 pUSD/char = 1.4e11 pUSD ≈ $0.14 ≈ ¥1 — the gateway's C2 card.
	s.Record(context.Background(), spenddomain.CategorySpeech, "qwen", "qwen3-tts-flash", 10_000)
	if got := repo.got[0].EstPUSD; got != 140_000_000_000 {
		t.Fatalf("est = %d, want 140000000000 (10k chars × 14e6)", got)
	}
}

// TestRecord_NeverFailsTheGeneration: the artifact exists and the money is spent whether or not the
// bookkeeping row lands, so a ledger error must not propagate. Record returns nothing on purpose —
// there is no error for a caller to mishandle.
//
// TestRecord_NeverFailsTheGeneration:账行落不落地,产物已在、钱已花,故台账错误绝不能冒泡。
// Record **刻意**不返回错误——没有错误可供调用方误处理。
func TestRecord_NeverFailsTheGeneration(t *testing.T) {
	repo := &fakeRepo{fail: context.DeadlineExceeded}
	s := New(repo, nil)
	s.Record(context.Background(), spenddomain.CategoryVideo, "qwen", "wan2.7-t2v", 5) // must not panic
}

// TestRecord_CarriesAttribution: the Router runs inside the tool's execution scope, so conversation
// and tool-call ids ride ctx and land on the row — that is what makes "which turn spent this"
// answerable later without a second ledger.
//
// TestRecord_CarriesAttribution:Router 跑在工具执行作用域内,故对话与工具调用 id 搭 ctx 落到行上
// ——「这笔是哪一轮花的」将来才答得出,而不必再建第二本账。
func TestRecord_CarriesAttribution(t *testing.T) {
	repo := &fakeRepo{}
	s := New(repo, nil)
	ctx := reqctxpkg.SetToolCallID(reqctxpkg.SetConversationID(context.Background(), "cv_1"), "blk_2")
	s.Record(ctx, spenddomain.CategoryImage, "qwen", "qwen-image-2.0", 1)
	if repo.got[0].ConversationID != "cv_1" || repo.got[0].ToolCallID != "blk_2" {
		t.Fatalf("attribution lost: %+v", repo.got[0])
	}
}
