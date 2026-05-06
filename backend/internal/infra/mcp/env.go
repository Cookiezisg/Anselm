// env.go — host-environment lookup, isolated so tests can override
// without monkey-patching exec.Cmd internals.
//
// env.go ——主机环境读取，独立文件让测试可覆盖而不用 monkey-patch exec.Cmd。
package mcp

import "os"

// defaultOSEnviron returns the process environment. Wrapped so the
// composeEnv test can swap a stub via the package-level osEnviron var.
//
// defaultOSEnviron 返进程 environment。包一层让 composeEnv 测试能通过
// package 级 osEnviron 变量替换 stub。
func defaultOSEnviron() []string {
	return os.Environ()
}
