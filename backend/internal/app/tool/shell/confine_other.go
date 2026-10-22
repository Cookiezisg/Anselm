//go:build !darwin

package shell

import "os/exec"

// confineWritesOS: no OS write sandbox is wired on this platform (Linux Landlock/bubblewrap and
// Windows are not implemented), so the residency's shell protection is the static floor alone. Said
// plainly in the docs rather than implied by a no-op that looks like protection.
//
// confineWritesOS：本平台未接 OS 写沙箱（Linux Landlock/bubblewrap 与 Windows 都没实现），故驻地的 shell
// 保护只有静态下限。在文档里明说，而不是用一个看起来像保护的 no-op 暗示。
func confineWritesOS(*exec.Cmd, string, string) bool { return false }
