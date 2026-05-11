// grep_rg.go — Grep ripgrep backend: shells out to `rg` to perform the
// actual regex search. Selected at construction time when `rg` is on PATH;
// gives roughly 10×–100× the throughput of the stdlib walker on large
// trees thanks to SIMD + .gitignore-aware filtering.
//
// Output formatting matches what an LLM expects from CC's Grep:
//   - content mode: `<path>:<lineno>:<text>` (or `<path>-<lineno>-<text>`
//     for context lines), one match per line.
//   - files_with_matches mode: one path per line.
//   - count mode: `<path>:<count>` per file.
//
// head_limit is enforced after rg returns (rg's --max-count is per-file).
//
// grep_rg.go — Grep 的 ripgrep 后端：shell out 到 `rg` 完成实际正则搜索。
// 构造时若 PATH 上有 `rg` 则启用；大树上吞吐约 10×–100× stdlib walker
// （SIMD + .gitignore-aware 过滤）。
//
// 输出格式与 CC Grep 对 LLM 的承诺一致；head_limit 在 rg 返回后再切。
package search

import (
	"context"
	"errors"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
)

// execRg runs ripgrep with flags translated from grepArgs and returns the
// output as a single string. Returns a Go error only when rg itself fails
// for an unexpected reason (e.g. not executable); a no-match scan returns
// the empty/“No matches” string with err == nil.
//
// execRg 用从 grepArgs 翻译来的 flag 执行 ripgrep，输出汇成单字符串返回。
// rg 自身异常（如不可执行）才上抛 Go error；无匹配的扫描返空/“No matches”
// 字符串且 err==nil。
func (t *Grep) execRg(ctx context.Context, args grepArgs) (string, error) {
	cmdArgs := buildRgArgs(args)

	cmd := exec.CommandContext(ctx, t.rgPath, cmdArgs...) //nolint:gosec // rgPath came from exec.LookPath; args are constructed from validated grepArgs.
	out, err := cmd.Output()

	// rg exit codes:
	//   0 = matches found
	//   1 = no matches (NOT an error in our model)
	//   2 = real error (bad regex, IO, etc.)
	//
	// rg 退出码：0=有匹配；1=无匹配（我们不当错误）；2=真错误。
	if err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			if ee.ExitCode() == 1 {
				return noMatchesMessage(args), nil
			}
			// Exit 2 = real rg error (bad regex, IO). Don't leak rg's raw
			// stderr to LLM/log — it can contain absolute scanned paths +
			// internal version strings. Caller (grep.go::Execute) falls
			// back to stdlib silently; the exit code in the err message
			// is enough breadcrumb for operator debug.
			//
			// 退出 2 = 真实 rg 错（坏 regex、IO 等）。不向 LLM/log 漏 rg
			// 原始 stderr——含扫描路径与版本串。caller 静默 fallback 到
			// stdlib；err 消息含 exit code 已足够 operator debug。
			return "", fmt.Errorf("Grep.execRg: rg exit %d", ee.ExitCode())
		}
		return "", fmt.Errorf("Grep.execRg: %w", err)
	}

	text := string(out)
	if strings.TrimSpace(text) == "" {
		return noMatchesMessage(args), nil
	}

	// head_limit applies post-hoc: trim to first N lines.
	// head_limit 后处理：只保留前 N 行。
	if args.HeadLimit > 0 {
		text = capLines(text, args.HeadLimit)
	}
	return text, nil
}

// buildRgArgs translates grepArgs into the corresponding rg CLI flags.
// Flag choices:
//   - --color=never: deterministic plain text, no ANSI in tool_result.
//   - --no-heading: each match line carries its own path so files_with_matches
//     and content modes parse uniformly.
//   - -e <pattern>: avoids ambiguity if pattern starts with `-`.
//   - --multiline + --multiline-dotall: makes `.` match newlines so cross-line
//     patterns work; only enabled when caller asked for it.
//
// buildRgArgs 把 grepArgs 翻译成对应的 rg CLI flag。
func buildRgArgs(args grepArgs) []string {
	out := []string{"--color=never", "--no-heading"}

	switch args.OutputMode {
	case OutputModeFilesWithMatches:
		out = append(out, "--files-with-matches")
	case OutputModeCount:
		out = append(out, "--count-matches")
	default: // content
		if args.ShowLines {
			out = append(out, "-n")
		}
		if args.Before > 0 {
			out = append(out, "-B", strconv.Itoa(args.Before))
		}
		if args.After > 0 {
			out = append(out, "-A", strconv.Itoa(args.After))
		}
	}

	if args.IgnoreCase {
		out = append(out, "-i")
	}
	if args.Multiline {
		out = append(out, "--multiline", "--multiline-dotall")
	}
	if args.Glob != "" {
		out = append(out, "--glob", args.Glob)
	}
	if args.Type != "" {
		out = append(out, "--type", args.Type)
	}

	out = append(out, "-e", args.Pattern)
	if args.Path != "" {
		out = append(out, args.Path)
	}
	return out
}

// noMatchesMessage gives a uniform "no results" string per output mode so
// the LLM gets a clear signal instead of empty output.
//
// noMatchesMessage 按 output_mode 返回统一的“无结果”字符串，让 LLM 看到
// 明确信号而不是空输出。
func noMatchesMessage(args grepArgs) string {
	root := args.Path
	if root == "" {
		root = "(cwd)"
	}
	return fmt.Sprintf("No matches for %q in %s.", args.Pattern, root)
}

// capLines returns the first n lines of text (preserving trailing newline
// if present in the truncated portion). Used by execRg/execStdlib to
// honour head_limit.
//
// capLines 截取前 n 行（保留截断段末尾的换行）。execRg/execStdlib 共用以
// 实现 head_limit。
func capLines(text string, n int) string {
	if n <= 0 {
		return text
	}
	count := 0
	for i := 0; i < len(text); i++ {
		if text[i] == '\n' {
			count++
			if count == n {
				return text[:i+1] + fmt.Sprintf("... [truncated at %d lines; raise head_limit to see more]\n", n)
			}
		}
	}
	return text
}

