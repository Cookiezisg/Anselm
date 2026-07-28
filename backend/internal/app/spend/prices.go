// prices.go — the hand-written unit-price table for the direct-side spend estimate. Same disease,
// same medicine as the gateway's rate cards: generation prices are NOT discoverable (models.dev's
// chat predicate filters every pure generation model out of the catalog), so the numbers are
// transcribed by hand, each row names its source, and the rows copied from the gateway's two
// `assumed-` cards carry the SAME reconciliation debt — when the user reconciles those against the
// provider console, both repos' numbers change together.
//
// An absent row estimates 0, which the ledger defines as "honestly unknown", never "free". Resist
// the urge to guess a number for an unlisted model: a wrong price wearing four significant digits
// reads as authority, and this whole feature's soul is that units are true and money is labeled
// estimate (WRK-082 H10 诚实律).
//
// prices.go——直连侧支出估算的手写单价表。与网关价格卡同病同药:生成价**不可发现**(models.dev 的
// chat 谓词把纯生成模型整个滤出目录),故数字手抄、每行注明出处;抄自网关两张 `assumed-` 卡的行背着
// **同一笔**对账债——用户对着供应商控制台销账时,两仓的数字一起改。
//
// 缺行估 0,台账定义为「诚实的未知」、绝不是「免费」。忍住给没列的模型猜一个数的冲动:一个带四位
// 有效数字的错价读起来像权威,而本功能的灵魂就是用量恒真、金额恒标估算(H10 诚实律)。
package spend

import spenddomain "github.com/sunweilin/anselm/backend/internal/domain/spend"

// unitPricePUSD returns the estimated price of ONE unit (image / character / second) in pico-USD,
// or 0 when the table honestly does not know. Keyed on exact (provider, model): a prefix or fuzzy
// match would silently price a model the table has never seen.
//
// unitPricePUSD 返回**一个**单位(张/字符/秒)的估算价(pico-USD),表不知道时返 0。键是精确的
// (provider, model):前缀或模糊匹配会给表从没见过的模型静默定价。
func unitPricePUSD(category, provider, model string) int64 {
	if p, ok := prices[priceKey{category, provider, model}]; ok {
		return p
	}
	return 0
}

type priceKey struct{ category, provider, model string }

var prices = map[priceKey]int64{
	// ── qwen / DashScope — mirrored from the gateway's rate cards (billing.go), assumed- debts
	//    included. 抄自网关价格卡,含 assumed- 债。
	// ¥0.25/image ≈ $0.035 (gateway card qwen-image-2.0-assumed-2026-07-27).
	{spenddomain.CategoryImage, "qwen", "qwen-image-2.0"}: 35_000_000_000,
	// ¥1/10K chars ≈ $0.0000139/char (gateway card qwen3-tts-flash-assumed-2026-07-27).
	{spenddomain.CategorySpeech, "qwen", "qwen3-tts-flash"}: 14_000_000,
	// ¥0.6/second at 720P ≈ $0.083 (gateway card wan2.7-t2v-assumed-2026-07-27).
	{spenddomain.CategoryVideo, "qwen", "wan2.7-t2v"}: 83_000_000_000,
	// $0.2 per voice created (gateway card qwen-tts-clone-2026-07-28). The ONE row here that is not
	// a reconciliation debt: this figure is printed verbatim on the official pricing page, which is
	// why its gateway twin carries no `assumed-` marker either.
	// 每创建一个音色 $0.2(网关卡 qwen-tts-clone-2026-07-28)。这里**唯一**一行不是对账债的:这个数字
	// 逐字印在官方价目页上,也正因如此它在网关那边的孪生卡没有 `assumed-` 标记。
	{spenddomain.CategoryVoice, "qwen", "qwen-tts"}: 200_000_000_000,

	// ── zhipu — §2.5 verified against the official docs: cogview-4 系约 ¥0.06/张 ≈ $0.0083.
	//    §2.5 对官方文档核准:约 ¥0.06/张。
	{spenddomain.CategoryImage, "zhipu", "cogview-4"}: 8_300_000_000,

	// ── openai — official list price 2026-07: gpt-image-1 medium 1024² ≈ $0.042/image;
	//    gpt-4o-mini-tts ≈ $0.015/1K chars = 15e6 pUSD/char.
	//    官方价目 2026-07。
	{spenddomain.CategoryImage, "openai", "gpt-image-1"}:      42_000_000_000,
	{spenddomain.CategorySpeech, "openai", "gpt-4o-mini-tts"}: 15_000_000,
}
