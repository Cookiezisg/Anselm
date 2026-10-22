package shell

import (
	"os/exec"
	"strings"

	fspathpkg "github.com/sunweilin/anselm/backend/internal/pkg/fspath"
)

// confineNote is appended to a confined command's result when it failed with the OS's "not permitted":
// without it the model sees a bare EPERM, cannot tell a sandbox refusal from a broken script, and tends
// to retry the same write with another tool or another spelling.
//
// confineNote 附加在一条受约束命令失败于 OS 的「不允许」时的结果里：没有它，模型只看到一个光秃秃的
// EPERM，分不清是沙箱拒绝还是脚本坏了，往往会换个工具或换种写法重试同一个写入。
const confineNote = "\n[sandbox] This command is confined to the conversation's working directory: it can write " +
	"inside it and to temp/cache directories, nowhere else, and it cannot call this app's own local API. " +
	"To write elsewhere or change entities, use the Write/Edit tool or the entity tools (they ask the user " +
	"to confirm), or ask the user. Do not retry through another route."

// confinementHint returns confineNote when a confined command FAILED and either its output says the OS
// refused or the command itself names a path outside the residency. The second test is needed because
// tools word the refusal differently (awk says "can't open file", with no errno text at all).
//
// confinementHint 在受约束命令**失败**、且其输出说 OS 拒绝、或命令本身点名了驻地之外的路径时返回
// confineNote。第二个判据是必要的：各工具对拒绝的措辞不一（awk 只说「can't open file」，完全没有 errno 文字）。
func confinementHint(confined, failed bool, output, command, workDir, selfPort string) bool {
	if !confined || !failed {
		return false
	}
	if strings.Contains(output, "Operation not permitted") || (selfPort != "" && strings.Contains(command, ":"+selfPort)) {
		return true
	}
	for _, m := range rePathLiteral.FindAllStringSubmatch(command, -1) {
		abs, err := fspathpkg.ExpandIn(workDir, strings.Trim(m[1], `'"`))
		if err == nil && !fspathpkg.Inside(workDir, abs) && !harmlessSink[abs] {
			return true
		}
	}
	return false
}

// confineWrites rewrites cmd so the shell runs under the OS write sandbox for workDir. It reports whether
// confinement is actually in force; false (unsupported platform, tool missing, profile could not be
// built) leaves cmd untouched and means the static floor (callfloor.go) is the only net.
//
// confineWrites 改写 cmd，使 shell 在 workDir 的 OS 写沙箱下运行。它报告约束是否真的生效；false（平台
// 不支持、工具缺失、profile 构造失败）不改动 cmd，意味着唯一的网是静态下限（callfloor.go）。
func confineWrites(cmd *exec.Cmd, workDir, selfPort string) bool {
	return confineWritesOS(cmd, workDir, selfPort)
}
