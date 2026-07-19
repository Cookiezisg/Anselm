import 'dart:async';

import 'package:super_editor/super_editor.dart';

// Global test bootstrap (flutter_test discovers this file automatically and wraps every test binary
// in the directory). The vendored presenter (ADR 0009) self-verifies in tests: every incremental
// layout pass re-runs the full upstream rebuild inside an assert and compares field by field — every
// test that mounts an editor is thereby also a differential test of the incremental surgery. Zero
// cost outside tests (the flag defaults off; the check is assert-stripped in release).
// 全局测试引导(flutter_test 自动发现并包裹本目录所有测试)。vendored presenter(ADR 0009)在测试里
// 自校验:每次增量布局都在 assert 里按上游全量重算并逐字段比对——凡挂载编辑器的测试同时就是增量手术的
// 差分测试。测试之外零成本(默认关,release 剥 assert)。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AnPresenterFlags.debugVerifyDefault = true;
  await testMain();
}
