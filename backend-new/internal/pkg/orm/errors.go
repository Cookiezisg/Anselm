package orm

import "errors"

// ErrNotFound is returned by First and Repo.Get when no row matches the query.
// Stores translate it into their own domain not-found error.
//
// ErrNotFound 在 First / Repo.Get 无匹配行时返回。store 把它翻译成各自 domain 的 not-found 错误。
var ErrNotFound = errors.New("orm: record not found")
