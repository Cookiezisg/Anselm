// Package spend is the app service for the direct-side generation spend ledger (WRK-082 H10):
// Record estimates + appends, Daily projects. The generation Router calls Record at its
// chokepoints; the HTTP face calls Daily.
//
// Package spend 是直连侧生成支出台账的 app 服务(H10):Record 估价并追加,Daily 投影。生成
// Router 在咽喉处调 Record,HTTP 面调 Daily。
package spend

import (
	"context"
	"time"

	"go.uber.org/zap"

	spenddomain "github.com/sunweilin/anselm/backend/internal/domain/spend"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// Service records and projects generation spend.
//
// Service 记录并投影生成支出。
type Service struct {
	repo spenddomain.Repository
	log  *zap.Logger
}

// New builds the service.
//
// New 构造服务。
func New(repo spenddomain.Repository, log *zap.Logger) *Service {
	if log == nil {
		log = zap.NewNop()
	}
	return &Service{repo: repo, log: log}
}

// Record books one paid generation call: units are the TRUE counted quantity, the price is an
// estimate from the hand-written table (0 = honestly unknown). Managed calls (provider "anselm")
// are skipped — the gateway journals that money authoritatively and the desktop already shows it;
// booking it here would double-count.
//
// It NEVER fails the generation: the artifact exists and the money is spent whether or not the
// bookkeeping row lands, so a ledger error is logged and swallowed. Conversation and tool-call
// attribution ride ctx when present (the Router runs inside the tool's execution scope) and stay
// empty otherwise (read-aloud, HTTP invokes).
//
// Record 记一次付费生成调用:units 是**数出来**的真实量,价是手写表的估算(0=诚实的未知)。受管调用
// (provider "anselm")跳过——网关已权威记账、桌面已展示,这儿再记就是数两遍。
//
// 它**绝不**让生成失败:产物已在、钱已花,账行落不落地都改变不了,故台账错误记日志后吞掉。对话与
// 工具调用归属在 ctx 有时捎带(Router 跑在工具执行作用域内)、没有时留空(朗读、HTTP 调用)。
func (s *Service) Record(ctx context.Context, category, provider, model string, units int64) {
	if provider == "anselm" || units <= 0 {
		return
	}
	convID, _ := reqctxpkg.GetConversationID(ctx)
	toolCallID, _ := reqctxpkg.GetToolCallID(ctx)
	e := &spenddomain.Entry{
		ID:             idgenpkg.New("gsp"),
		Provider:       provider,
		Model:          model,
		Category:       category,
		Units:          units,
		EstPUSD:        unitPricePUSD(category, provider, model) * units,
		ConversationID: convID,
		ToolCallID:     toolCallID,
		CreatedAt:      time.Now().UTC(),
	}
	if err := s.repo.Record(ctx, e); err != nil {
		s.log.Warn("spend: ledger write failed (generation unaffected)",
			zap.String("category", category), zap.String("provider", provider), zap.Error(err))
	}
}

// Daily returns the day × category × provider × model aggregation for the last `days` days.
//
// Daily 返回近 `days` 天按 日×品类×provider×model 的聚合。
func (s *Service) Daily(ctx context.Context, days int) ([]spenddomain.DayRow, error) {
	since := time.Now().UTC().AddDate(0, 0, -days).Truncate(24 * time.Hour)
	return s.repo.AggregateDaily(ctx, since)
}
