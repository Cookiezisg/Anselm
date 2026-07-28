// Package spend is the domain layer for the DIRECT-side generation spend ledger (WRK-082 H10).
// One row per paid generation call against the user's OWN key: what was made (category), where
// (provider/model), how much of it (units — the native billing unit of each category), and an
// ESTIMATED price. The managed free tier is deliberately absent: the gateway journals that spend
// authoritatively and the desktop already shows it (freetier quota card) — recording it here too
// would double-count the same money.
//
// Two honesty rules shape every field. UNITS ARE TRUE: images are counted, characters are counted,
// seconds are counted — no estimation anywhere. MONEY IS AN ESTIMATE: EstPUSD comes from a
// hand-written price table that can be wrong or empty (0 = honestly unknown), and every consumer
// must present it as an estimate whose authority lives in the provider's own billing console.
//
// This is a LOG table in the D1 sense (no soft delete) and it deliberately has NO retention line:
// a row is ~a hundred bytes and rows accrue per generation call (a human-scale action), so even
// heavy use is megabytes a year — a retention knob here would be validation theater (原则 #6),
// the same judgement as "attachments are never auto-deleted" (H5.9).
//
// Package spend 是**直连侧**生成支出台账的 domain 层(WRK-082 H10)。用户**自己的 key** 每一次
// 付费生成调用记一行:做了什么(品类)、在哪家(provider/model)、做了多少(units——各品类的原生
// 计费单位)、以及一个**估算**价。受管免费档刻意缺席:网关已权威记账、桌面已在免费档配额卡展示
// ——在这儿再记等于把同一笔钱数两遍。
//
// 两条诚实律塑造每个字段。**用量恒真**:张数是数的、字符是数的、秒是数的——任何地方都没有估算。
// **金额恒为估算**:EstPUSD 出自一张可能错、可能空(0=诚实的未知)的手写价目表,每个消费方都必须
// 把它当估算呈现,权威在供应商自己的账单控制台。
//
// 这是 D1 意义上的 Log 表(无软删),且**刻意不配保留线**:一行约百字节、按生成调用(人的动作尺度)
// 累积,重度使用一年也是 MB 级——在这儿配保留旋钮是校验剧场(原则 #6),与「附件永不自动删」(H5.9)
// 同一判断。
package spend

import (
	"context"
	"time"
)

// Categories — the closed set of generation kinds, each with its native billing unit.
// The set is CHECK-enforced in the table.
//
// 品类——生成种类的封闭集,各带自己的原生计费单位。表 CHECK 强制。
const (
	// CategoryImage bills per image. 图按张。
	CategoryImage = "image"
	// CategorySpeech bills per input character (rune). 语音按输入字符(rune)。
	CategorySpeech = "speech"
	// CategoryVideo bills per second, and the money lands at SUBMIT — a poll that never returns
	// does not un-spend it (same law as the managed route, ADR 0015).
	// 视频按秒,钱**落在提交**——轮询不回来不等于没花(与受管路由同律,ADR 0015)。
	CategoryVideo = "video"
)

// Entry is one recorded generation call.
//
// Entry 是一次已记账的生成调用。
type Entry struct {
	ID          string `db:"id,pk"           json:"id"`
	WorkspaceID string `db:"workspace_id,ws" json:"-"`
	Provider    string `db:"provider"        json:"provider"`
	Model       string `db:"model"           json:"model"`
	Category    string `db:"category"        json:"category"`
	// Units is the true, counted quantity in the category's native unit.
	// Units 是该品类原生单位下**数出来**的真实量。
	Units int64 `db:"units" json:"units"`
	// EstPUSD is the estimated price in pico-USD (1e-12 USD — the gateway's unit, kept identical
	// so the two ledgers speak one currency). 0 means the price table has no entry: honestly
	// unknown, never "free".
	// EstPUSD 是估算价,单位 pico-USD(1e-12 美元——与网关同单位,两本账说同一种货币)。0 表示价目表
	// 无此条:诚实的未知,绝不是「免费」。
	EstPUSD        int64     `db:"est_pusd"        json:"estPUSD"`
	ConversationID string    `db:"conversation_id" json:"conversationId"`
	ToolCallID     string    `db:"tool_call_id"    json:"toolCallId"`
	CreatedAt      time.Time `db:"created_at"      json:"createdAt"`
}

// DayRow is one aggregated cell of the spend projection: one calendar day × category ×
// provider × model.
//
// DayRow 是支出投影的一格聚合:一个日历日 × 品类 × provider × model。
type DayRow struct {
	Date     string
	Category string
	Provider string
	Model    string
	Units    int64
	EstPUSD  int64
}

// Repository is the ledger port.
//
// Repository 是台账端口。
type Repository interface {
	// Record appends one entry. Append-only — there is no update or delete anywhere.
	// Record 追加一行。只追加——任何地方都没有改和删。
	Record(ctx context.Context, e *Entry) error
	// AggregateDaily returns day × category × provider × model sums for entries at or after
	// since, newest day first.
	// AggregateDaily 返回 since 起(含)按 日×品类×provider×model 的聚合,新日在前。
	AggregateDaily(ctx context.Context, since time.Time) ([]DayRow, error)
}
