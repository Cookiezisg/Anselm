// Package search provides the file-navigation system tools (LS / Glob / Grep)
// for the LLM. They mirror how a person finds files on a machine: open a folder
// and look (LS), find by name pattern (Glob), find by content (Grep) — then
// drill in. A desktop agent navigates the WHOLE filesystem, so a path is normally
// absolute (with ~ expanded by the tool layer); when the conversation has a work
// dir mounted, a still-relative path resolves against it instead of being refused.
// Both rules live in pkg/fspath, which every path here goes through.
//
// The residency never NARROWS these three. They are reads, and reading outside the
// work dir is untouched by design (WD1): mounting a directory says "we are zoomed in
// here", not "this is all you may look at".
//
// Leaf tool adapter: no domain, no store, no handler. All three are read-only,
// share an injected PathGuard, and never touch AgentState.
//
// Package search 提供文件导航的 system tool（LS / Glob / Grep）。它们对应人在机器上
// 找文件的方式:打开文件夹看一眼(LS)/ 按名字找(Glob)/ 按内容找(Grep)——再下钻。桌面
// agent 在**整个**文件系统导航,故路径通常是绝对的(~ 由工具层展开);当对话挂了工作
// 目录时,仍是相对的路径以它解析、而不再被拒。两条规则都住在 pkg/fspath,此处每个路径
// 都经过它。
//
// 驻地从不**收窄**这三个工具。它们是**读**,而按设计往驻地外读分毫不受影响(WD1):挂一个
// 目录说的是「我们 zoom 到这里了」、不是「你只能看这些」。
//
// 叶子工具适配器:无 domain / store / handler。三者皆只读、共享注入的 PathGuard、永不碰 AgentState。
package search

import (
	"os/exec"

	"go.uber.org/zap"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	pathguardpkg "github.com/sunweilin/anselm/backend/internal/pkg/pathguard"
)

// SearchTools constructs the three navigation tools wired with their shared PathGuard.
//
// SearchTools 用共享 PathGuard 装配三件导航 tool。
func SearchTools(pathGuard pathguardpkg.PathGuard, log *zap.Logger) []toolapp.Tool {
	return []toolapp.Tool{
		&LS{pathGuard: pathGuard},
		&Glob{pathGuard: pathGuard},
		newGrep(pathGuard, log),
	}
}

// newGrep probes for ripgrep once at construction; an empty rgPath makes Grep
// fall back to the pure-Go stdlib backend (a desktop user may not have rg).
//
// newGrep 在构造时探测一次 ripgrep;rgPath 为空时 Grep 回落到纯 Go stdlib 后端
// （桌面用户可能没装 rg）。
func newGrep(pathGuard pathguardpkg.PathGuard, log *zap.Logger) *Grep {
	rgPath, _ := exec.LookPath("rg")
	return &Grep{pathGuard: pathGuard, rgPath: rgPath, log: log}
}
