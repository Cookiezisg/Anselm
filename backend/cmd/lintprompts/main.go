// Command lintprompts walks the codebase, extracts every LLM-facing prompt string,
// and reports rule violations: length out of [50, 800] / first-person voice /
// weasel words / emoji presence. Non-zero exit on any violation.
//
// 命令 lintprompts 扫所有 LLM-facing prompt 字符串，按规则报告违例：
// 长度 [50, 800] 外 / 第一人称 / weasel word / emoji。任一违例非 0 退出。
//
// §18.3 — see documents/version-1.2/prompt-principles.md for rule rationale.
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"unicode"
)

type rule struct {
	id     string
	check  func(content string) (bool, string)
}

var rules = []rule{
	{
		id: "length",
		check: func(c string) (bool, string) {
			n := len(c)
			if n < 50 {
				return true, fmt.Sprintf("length=%d < 50 (too terse; LLM has to guess intent)", n)
			}
			if n > 800 {
				return true, fmt.Sprintf("length=%d > 800 (attention dilutes; consider splitting)", n)
			}
			return false, ""
		},
	},
	{
		id: "first-person",
		check: func(c string) (bool, string) {
			lower := strings.ToLower(c)
			// "I will / I'll / I am" — model-perspective confusion.
			// "I will / I'll / I am" 第一人称视角混乱。
			for _, kw := range []string{"i will ", "i'll ", "i am ", " i need to "} {
				if strings.Contains(lower, kw) {
					return true, fmt.Sprintf("contains first-person %q (use imperative instead)", strings.TrimSpace(kw))
				}
			}
			return false, ""
		},
	},
	{
		id: "weasel",
		check: func(c string) (bool, string) {
			lower := strings.ToLower(c)
			// "be careful" / "try to" / "when in doubt" — model doesn't take vague directives.
			// 模糊指令 — LLM 不识 "be careful" 之类。
			for _, kw := range []string{"be careful", "try to ", "when in doubt", "as much as possible"} {
				if strings.Contains(lower, kw) {
					return true, fmt.Sprintf("contains weasel phrase %q (be concrete: 'If X, do Y')", kw)
				}
			}
			return false, ""
		},
	},
	{
		id: "emoji",
		check: func(c string) (bool, string) {
			for _, r := range c {
				if r > unicode.MaxASCII && isEmoji(r) {
					return true, fmt.Sprintf("contains emoji %q (eats tokens for no gain in LLM prompts)", string(r))
				}
			}
			return false, ""
		},
	},
}

// isEmoji is a rough check: anything in common emoji blocks.
//
// isEmoji 粗略判断：常见 emoji block。
func isEmoji(r rune) bool {
	switch {
	case r >= 0x1F300 && r <= 0x1FAFF:
		return true
	case r >= 0x2600 && r <= 0x27BF:
		return true
	case r >= 0x1F000 && r <= 0x1F2FF:
		return true
	}
	return false
}

// extractPrompts walks paths and pulls every Description/prompt string constant.
//
// extractPrompts 遍历路径,抽取每个 Description / prompt 常量字符串。
func extractPrompts(root string) []promptHit {
	var hits []promptHit
	// patterns: const fooDescription = `...` OR const someSystemPrompt = `...`
	reConst := regexp.MustCompile(`(?ms)const\s+(\w*[Pp]rompt|\w*[Dd]escription)\s*=\s*` + "`" + `(.*?)` + "`")
	_ = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		if !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return nil
		}
		s := string(data)
		matches := reConst.FindAllStringSubmatchIndex(s, -1)
		for _, m := range matches {
			name := s[m[2]:m[3]]
			content := s[m[4]:m[5]]
			line := 1 + strings.Count(s[:m[0]], "\n")
			hits = append(hits, promptHit{
				file:    path,
				line:    line,
				name:    name,
				content: content,
			})
		}
		return nil
	})
	return hits
}

type promptHit struct {
	file    string
	line    int
	name    string
	content string
}

func main() {
	// Run from backend/ working dir (matches `make lint-prompts`).
	// 在 backend/ cwd 运行（make lint-prompts 即此）。
	roots := []string{"internal/app/tool", "internal/app/chat", "internal/app/catalog",
		"internal/app/contextmgr", "internal/app/subagent"}
	totalHits := 0
	totalViolations := 0
	for _, root := range roots {
		hits := extractPrompts(root)
		totalHits += len(hits)
		for _, h := range hits {
			for _, rl := range rules {
				if violated, reason := rl.check(h.content); violated {
					fmt.Printf("%s:%d  [%s]  %s: %s\n", h.file, h.line, rl.id, h.name, reason)
					totalViolations++
				}
			}
		}
	}
	fmt.Printf("\nScanned %d prompts; %d violations.\n", totalHits, totalViolations)
	if totalViolations > 0 {
		os.Exit(1)
	}
}
