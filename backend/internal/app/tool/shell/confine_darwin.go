//go:build darwin

package shell

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const sandboxExec = "/usr/bin/sandbox-exec"

// cacheDirs under $HOME that ordinary builds write to. Everything else under $HOME — documents, the
// shell rc files, ~/.ssh, and the application-support directory holding Anselm's own database — is
// outside the confinement on purpose.
//
// $HOME 下普通构建会写的缓存目录。$HOME 下其余一切——文档、shell rc、~/.ssh、以及放着 Anselm 自己数据库的
// application-support 目录——都刻意在约束之外。
var cacheDirs = []string{
	"Library/Caches", ".cache", ".npm", ".yarn", ".pnpm-store", ".bun/install/cache",
	".cargo/registry", ".cargo/git", "go/pkg", ".gradle/caches", ".m2/repository", ".gem", ".bundle/cache",
}

// confineWritesOS runs the shell under Seatbelt with a profile that allows everything EXCEPT file writes
// outside workDir, the temp directories and the cache directories above. It is the same mechanism OS-level
// agent sandboxes use: the kernel refuses the write whatever language or tool tries it, so unlike the
// static floor it does not depend on recognising the command.
//
// Paths in a Seatbelt profile must be the real ones: /var is a symlink to /private/var on macOS, so a
// profile naming the symlinked spelling would deny writes even inside the residency.
//
// confineWritesOS 让 shell 在 Seatbelt 下运行，profile 放行一切、**除了**对 workDir、临时目录与上列缓存
// 目录之外的文件写入。这与 OS 级 agent 沙箱用的是同一机制：无论哪种语言或工具来写，内核都拒绝，故不像
// 静态下限那样依赖「认出这条命令」。
//
// Seatbelt profile 里的路径必须是真实路径：macOS 的 /var 是指向 /private/var 的符号链接，profile 写成符号
// 链接拼法会让驻地**之内**的写入也被拒。
func confineWritesOS(cmd *exec.Cmd, workDir, selfPort string) bool {
	if _, err := os.Stat(sandboxExec); err != nil {
		return false
	}
	root, err := filepath.EvalSymlinks(workDir)
	if err != nil {
		return false
	}
	profile := writeProfile(root, os.TempDir(), os.Getenv("HOME"), selfPort)
	// cmd.Args is [/bin/sh -c command]; the sandbox wrapper execs it in place, so the process group and
	// the kill path are unchanged.
	// cmd.Args 是 [/bin/sh -c command]；沙箱包装层原地 exec 它，故进程组与杀进程路径不变。
	cmd.Args = append([]string{sandboxExec, "-p", profile}, cmd.Args...)
	cmd.Path = sandboxExec
	return true
}

func writeProfile(root, tmp, home, selfPort string) string {
	var allow []string
	add := func(kind, p string) {
		if p == "" {
			return
		}
		if real, err := filepath.EvalSymlinks(p); err == nil {
			p = real
		}
		allow = append(allow, fmt.Sprintf("(%s %s)", kind, quote(p)))
	}
	add("subpath", root)
	add("subpath", strings.TrimRight(tmp, "/"))
	add("subpath", "/private/tmp")
	add("subpath", "/private/var/tmp")
	if home != "" {
		for _, d := range cacheDirs {
			add("subpath", filepath.Join(home, d))
		}
	}
	for _, dev := range []string{"/dev/null", "/dev/tty", "/dev/stdout", "/dev/stderr", "/dev/dtracehelper"} {
		allow = append(allow, fmt.Sprintf("(literal %s)", quote(dev)))
	}
	allow = append(allow, `(regex #"^/dev/(fd/|tty|pty)")`)
	profile := "(version 1)\n(allow default)\n(deny file-write* (require-not (require-any\n  " +
		strings.Join(allow, "\n  ") + ")))\n"
	if selfPort != "" {
		profile += fmt.Sprintf("(deny network-outbound (remote ip %s))\n", quote("localhost:"+selfPort))
	}
	return profile
}

// quote renders a path as a Seatbelt string literal.
// quote 把路径渲染为 Seatbelt 字符串字面量。
func quote(p string) string {
	return `"` + strings.NewReplacer(`\`, `\\`, `"`, `\"`).Replace(p) + `"`
}
