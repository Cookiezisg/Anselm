// Package idgen mints business entity IDs in the project-standard "<prefix>_<16hex>" form (§S15).
// Pure stdlib.
//
// Package idgen 按项目标准 "<prefix>_<16hex>" 形式生成业务实体 ID（§S15）。纯 stdlib。
package idgen

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
)

// New returns "<prefix>_<16hex>". prefix is the domain's stable short tag (e.g. "wf", "fn").
// It panics on a crypto/rand failure: a broken entropy source would silently mint colliding IDs,
// which is far worse than a loud crash.
//
// New 返回 "<prefix>_<16hex>"。prefix 取 domain 稳定短标签（如 "wf"/"fn"）。
// crypto/rand 失败时 panic——熵源损坏会静默产生碰撞 ID，远比响亮崩溃更糟。
func New(prefix string) string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		panic(fmt.Sprintf("idgen: crypto/rand failed: %v", err))
	}
	return prefix + "_" + hex.EncodeToString(b[:])
}
