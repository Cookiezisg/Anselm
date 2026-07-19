package scenarios

import (
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// TestMain contains every temp byte this package writes — the compiled server binary (built once per
// run, so no t.Cleanup may own it) and each test's data dir — inside one self-cleaning root. See
// harness.RunTests for why TestMain is the only hook that can do this, and why the next run rather
// than this one is the backstop.
//
// TestMain 把本包写出的每一个临时字节——编译出的 server 二进制（每轮只编一次，故没有 t.Cleanup 有资格
// 拥有它）与各测试的数据目录——收进一个自清的根。为何 TestMain 是唯一能干这事的挂点、以及为何兜底的是
// **下一轮**而非本轮，见 harness.RunTests。
func TestMain(m *testing.M) { harness.RunTests(m) }
