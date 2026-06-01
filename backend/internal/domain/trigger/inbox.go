package trigger

import (
	"context"
	"errors"

	"gorm.io/gorm"
)

// ErrFiringNotPending means a ClaimFiring lost the race — the firing was already claimed/terminal.
// The dispatcher treats it as "another claimant won", not an error.
//
// ErrFiringNotPending 表示认领竞争失败(已被认领/终态),派发器视为"别人赢了",非错误。
var ErrFiringNotPending = errors.New("trigger: firing not pending")

// FiringInbox is the durable trigger-firings inbox port (17 §6, ADR-021). The scheduler consumes it
// to drain pending firings via a single-transaction claim. ClaimFiring's create callback carries the
// `*gorm.DB` tx so the claim (pending→claimed) and the flowrun INSERT commit atomically — there is
// never a claimed-firing-without-flowrun strand. The gorm.DB in the callback is the documented
// single-tx trade-off (ADR-021): the firings + flowruns tables share one DB, so one tx spans both.
//
// FiringInbox 是 durable 触发收件箱端口;scheduler 用它单事务认领+建 flowrun(ADR-021,无中间残留态)。
type FiringInbox interface {
	AppendFiring(ctx context.Context, f *TriggerFiring) (*TriggerFiring, error)
	ListPending(ctx context.Context, limit int) ([]TriggerFiring, error)
	ClaimFiring(ctx context.Context, firingID string, create func(tx *gorm.DB) (flowrunID string, err error)) (string, error)
	MarkOutcome(ctx context.Context, firingID, status string) error
}
