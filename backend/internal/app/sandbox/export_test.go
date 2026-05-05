// export_test.go — internal-test-only helpers exposing Service state that
// would otherwise require either Bootstrap to run real mise extraction
// or production-only setters. Only compiled into the test binary; no
// runtime exposure. Standard Go pattern (see net/http/export_test.go).
//
// export_test.go ——仅测试期暴露 Service 内部状态的 helper，否则要么真跑
// Bootstrap 抽取 mise，要么暴露生产 setter。仅编入 test binary 不影响生产。
// Go 标准模式（见 net/http/export_test.go）。

package sandbox

// MarkReadyForTest forces IsReady() to return true and sets a fake
// miseBin path. Tests that exercise Spawn / EnsureRuntime / EnsureEnv
// without actually extracting the mise binary use this to skip Bootstrap.
//
// MarkReadyForTest 强制 IsReady() 返 true 并设假 miseBin 路径。不真抽
// mise 的 Spawn / EnsureRuntime / EnsureEnv 测试用它跳过 Bootstrap。
func (s *Service) MarkReadyForTest(miseBin string) {
	s.miseBin = miseBin
	s.bootstrapped.Store(true)
}

// ActiveHandleCountForTest returns the number of LongLived handles
// currently registered. Tests use this to verify Spawn / Wait / Kill
// register and un-register correctly.
//
// ActiveHandleCountForTest 返当前注册的 LongLived handle 数量。测试用它
// 验证 Spawn / Wait / Kill 正确注册 + 反注册。
func (s *Service) ActiveHandleCountForTest() int {
	count := 0
	s.activeHandles.Range(func(_, _ any) bool {
		count++
		return true
	})
	return count
}
