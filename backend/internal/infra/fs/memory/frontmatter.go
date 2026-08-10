package memory

import (
	"fmt"
	"strconv"
	"strings"

	memorydomain "github.com/sunweilin/anselm/backend/internal/domain/memory"
)

// parseFile splits an optional YAML-ish frontmatter (--- … ---) from the body and
// reads the three scalar keys (description / pinned / source). Deliberately a minimal
// line-based parser — no yaml dependency for three scalar fields. A file without
// frontmatter is all body (empty meta).
//
// parseFile 把可选的类 YAML frontmatter（--- … ---）与正文分开，读三个标量键
// （description / pinned / source）。刻意用极简逐行解析——三个标量不值得引 yaml 依赖。
// 无 frontmatter 的文件整体即正文（meta 为空）。
func parseFile(raw, name string) *memorydomain.Memory {
	m := &memorydomain.Memory{Name: name}
	body := raw
	if strings.HasPrefix(raw, "---\n") {
		if end := strings.Index(raw[4:], "\n---\n"); end >= 0 {
			front := raw[4 : 4+end]
			body = raw[4+end+len("\n---\n"):]
			for line := range strings.SplitSeq(front, "\n") {
				key, val, ok := strings.Cut(line, ":")
				if !ok {
					continue
				}
				switch strings.TrimSpace(key) {
				case "description":
					m.Description = parseScalar(val)
				case "pinned":
					m.Pinned = strings.TrimSpace(val) == "true"
				case "source":
					m.Source = strings.TrimSpace(val)
				}
			}
		}
	}
	m.Content = strings.TrimSpace(body)
	return m
}

// renderFile renders a memory to frontmatter + body — the inverse of parseFile.
//
// renderFile 把一条记忆渲染为 frontmatter + 正文——parseFile 的逆。
func renderFile(m *memorydomain.Memory) string {
	var b strings.Builder
	b.WriteString("---\n")
	fmt.Fprintf(&b, "description: %s\n", renderDescription(m.Description))
	fmt.Fprintf(&b, "pinned: %t\n", m.Pinned)
	fmt.Fprintf(&b, "source: %s\n", m.Source)
	b.WriteString("---\n")
	b.WriteString(m.Content)
	b.WriteString("\n")
	return b.String()
}

// parseScalar accepts the historical plain form and a quoted form used when a
// description contains a line break. Quoting keeps user text from becoming new
// frontmatter keys when the file is read back.
//
// parseScalar 兼容历史裸值；描述含换行时使用引号形式，避免用户文本回读时变成新的 frontmatter key。
func parseScalar(raw string) string {
	value := strings.TrimSpace(raw)
	if strings.HasPrefix(value, "\"") {
		if decoded, err := strconv.Unquote(value); err == nil {
			return decoded
		}
	}
	return value
}

func renderDescription(description string) string {
	if strings.ContainsAny(description, "\r\n") {
		return strconv.Quote(description)
	}
	return description
}
