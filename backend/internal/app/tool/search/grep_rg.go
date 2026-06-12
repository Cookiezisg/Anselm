package search

import (
	"context"
	"errors"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
)

// rgOutputCapBytes bounds how much rg output is kept in memory. A head_limit-less content
// search over a big tree can emit hundreds of MB; everything past the cap is discarded while
// rg runs to completion (bounded memory, no broken-pipe kill dance).
//
// rgOutputCapBytes 限定内存里保留多少 rg 输出。不带 head_limit 的大树 content 搜索可吐数百 MB；
// 超出部分在 rg 跑完前直接丢弃（内存有界，免去断管杀进程那套舞步）。
const rgOutputCapBytes = 256 * 1024

// cappedBuffer keeps the first cap bytes and silently discards the rest, recording how much
// was dropped.
//
// cappedBuffer 保留前 cap 字节、静默丢弃其余，并记录丢弃量。
type cappedBuffer struct {
	buf     []byte
	cap     int
	dropped int
}

func (b *cappedBuffer) Write(p []byte) (int, error) {
	if room := b.cap - len(b.buf); room > 0 {
		if len(p) <= room {
			b.buf = append(b.buf, p...)
			return len(p), nil
		}
		b.buf = append(b.buf, p[:room]...)
		b.dropped += len(p) - room
		return len(p), nil
	}
	b.dropped += len(p)
	return len(p), nil
}

// execRg runs ripgrep and returns its output (bounded); no-match returns a friendly
// "No matches" message with err == nil.
//
// execRg 跑 ripgrep 返其输出（有界）；无匹配返友好的 "No matches" 消息，err == nil。
func (t *Grep) execRg(ctx context.Context, args grepArgs) (string, error) {
	cmdArgs := buildRgArgs(args)

	cmd := exec.CommandContext(ctx, t.rgPath, cmdArgs...) //nolint:gosec // rgPath came from exec.LookPath; args are constructed from validated grepArgs.
	out := &cappedBuffer{cap: rgOutputCapBytes}
	cmd.Stdout = out
	err := cmd.Run()

	// rg exit codes: 0=matches, 1=no matches (not an error), 2=real error.
	// rg 退出码：0=有匹配；1=无匹配（非错）；2=真错。
	if err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			if ee.ExitCode() == 1 {
				return noMatchesMessage(args), nil
			}
			return "", fmt.Errorf("Grep.execRg: rg exit %d", ee.ExitCode())
		}
		return "", fmt.Errorf("Grep.execRg: %w", err)
	}

	text := string(out.buf)
	if strings.TrimSpace(text) == "" {
		return noMatchesMessage(args), nil
	}

	if args.HeadLimit > 0 {
		text = capLines(text, args.HeadLimit)
	}
	if out.dropped > 0 {
		text += fmt.Sprintf("\n... [output capped at %d bytes (%d more dropped); narrow with glob/type or use head_limit]\n", rgOutputCapBytes, out.dropped)
	}
	return text, nil
}

// buildRgArgs translates grepArgs into rg CLI flags.
//
// buildRgArgs 把 grepArgs 翻译成 rg CLI flag。
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

func noMatchesMessage(args grepArgs) string {
	root := args.Path
	if root == "" {
		root = "(unspecified)"
	}
	return fmt.Sprintf("No matches for %q in %s.", args.Pattern, root)
}

// capLines truncates text to the first n lines, appending a truncation marker.
//
// capLines 把 text 截到前 n 行，追加截断标记。
func capLines(text string, n int) string {
	if n <= 0 {
		return text
	}
	count := 0
	for i := range len(text) {
		if text[i] == '\n' {
			count++
			if count == n {
				return text[:i+1] + fmt.Sprintf("... [truncated at %d lines; raise head_limit to see more]\n", n)
			}
		}
	}
	return text
}
