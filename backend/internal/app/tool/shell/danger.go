package shell

import "regexp"

// dangerRule pairs a precompiled matcher with the reason shown to the LLM when it fires.
//
// dangerRule 把预编译匹配器与命中时回显给 LLM 的原因配对。
type dangerRule struct {
	re     *regexp.Regexp
	reason string
}

// hardBlockRules are the few catastrophic, unattended-accident commands the Bash tool
// refuses outright. This is NOT a security boundary or an allow/deny config system — the
// local single-user model trusts the user, and per-call danger self-report is the real
// control. It's a thin backstop so an autonomous loop can't wipe the disk or hang on a
// sudo password prompt. Kept deliberately small (false positives cost more than the rare
// miss, which the user would have confirmed anyway).
//
// hardBlockRules 是 Bash 工具直接拒绝的极少数灾难性无人值守命令。这不是安全边界、也不是
// allow/deny 配置系统——本地单用户模型信任用户，真正的控制是每次 danger 自报。它只是薄兜底，
// 防自主 loop 抹盘或卡在 sudo 密码提示。刻意保持精简（误伤代价高于偶尔漏网，而漏网命令本就该
// 由用户确认过）。
var hardBlockRules = []dangerRule{
	// rm -r/-f targeting the filesystem root or whole home.
	{regexp.MustCompile(`(?i)\brm\s+(-\S+\s+)*-\S*[rf]\S*\s+(-\S+\s+)*(/|/\*|~|\$home)(\s|$)`), "recursive delete of a root or home path"},
	// Privilege escalation — cannot run non-interactively (hangs on password) or breaches.
	{regexp.MustCompile(`(?i)\b(sudo|doas)\b`), "privilege escalation (sudo/doas) can't run non-interactively"},
	// Filesystem format.
	{regexp.MustCompile(`(?i)\bmkfs(\.\w+)?\b`), "filesystem format (mkfs)"},
	// Raw write to a block device.
	{regexp.MustCompile(`(?i)\bdd\b[^|;&\n]*\bof=/dev/`), "raw write to a block device (dd of=/dev/...)"},
	// Redirect overwrite of a block device.
	{regexp.MustCompile(`(?i)>\s*/dev/(sd|hd|nvme|disk|mmcblk)`), "overwrite of a block device"},
	// Classic fork bomb.
	{regexp.MustCompile(`:\(\)\s*\{\s*:\s*\|\s*:?\s*&\s*\}\s*;\s*:`), "fork bomb"},
}

// checkDangerous reports the first hard-block rule the command trips, if any.
//
// checkDangerous 报告命令触发的第一条硬拦截规则（若有）。
func checkDangerous(command string) (reason string, blocked bool) {
	for _, r := range hardBlockRules {
		if r.re.MatchString(command) {
			return r.reason, true
		}
	}
	return "", false
}
