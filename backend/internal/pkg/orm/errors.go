package orm

import (
	"fmt"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	"strings"
)

// ErrNotFound is returned by First and Repo.Get when no row matches the query.
// Stores translate it into their own domain not-found error.
//
// ErrNotFound 在 First / Repo.Get 无匹配行时返回。store 把它翻译成各自 domain 的 not-found 错误。
var ErrNotFound = errorspkg.New(errorspkg.KindNotFound, "ORM_NOT_FOUND", "orm: record not found")

// ErrConflict is returned by Create/Save when a write violates a UNIQUE
// constraint (a duplicate value on a uniquely-indexed column). Stores translate
// it via errors.Is into their own domain conflict; the driver error is wrapped
// as cause so the original message stays inspectable. The gateway owns both
// common write outcomes — not-found and conflict — so stores never match SQLite
// error strings by hand.
//
// ErrConflict 在 Create/Save 违反 UNIQUE 约束（唯一索引列重值）时返回。store 用
// errors.Is 翻译成各自 domain 的冲突错误；driver error 作 cause 包裹，保留原始信息。
// 网关收口两个最常见的写结果——not-found 与 conflict——store 永不手搓 SQLite 字符串。
var ErrConflict = errorspkg.New(errorspkg.KindConflict, "ORM_CONFLICT", "orm: unique constraint conflict")

// uniqueViolationText is the substring SQLite drivers put in the error message
// on a UNIQUE constraint failure (glebarez/modernc & mattn alike).
//
// uniqueViolationText 是 SQLite driver 在 UNIQUE 约束失败时错误信息必含的子串。
const uniqueViolationText = "UNIQUE constraint failed"

// writeErr maps a driver write error to ErrConflict (wrapping the cause) on a
// UNIQUE violation, else labels it with op. Create/Save funnel their Exec error
// through this so conflict detection lives in one place.
//
// writeErr 把 driver 写错误在 UNIQUE 违例时映射为 ErrConflict(包 cause)，否则按 op 标注。
// Create/Save 的 Exec 错误都经此，使冲突识别只有一处。
func writeErr(op string, err error) error {
	if strings.Contains(err.Error(), uniqueViolationText) {
		return fmt.Errorf("%w: %w", ErrConflict, err)
	}
	return fmt.Errorf("orm: %s: %w", op, err)
}
