package loop

import (
	"regexp"
	"strings"

	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

// These markers identify implementation diagnostics, not user-facing explanations. The
// exact traceback remains available in the tool card and durable execution history.
// 这些词标识实现诊断而不是用户解释；完整 traceback 仍保留在工具卡和耐久执行历史中。
var technicalFailureMarkerPattern = regexp.MustCompile(
	`(?i)\b(?:traceback|runtimeerror|valueerror|typeerror|keyerror|indexerror|importerror|moduleNotFoundError|exception|stack trace)\b|` +
		`\bpanic:\s|File\s+["'].*["'],\s*line\s+\d+`,
)

var technicalFailureSentencePattern = regexp.MustCompile(
	`(?is)[^。！？.!?\n]*(?:\b(?:traceback|runtimeerror|valueerror|typeerror|keyerror|indexerror|importerror|moduleNotFoundError|exception|stack trace)\b|\bpanic:\s|File\s+["'].*["'],\s*line\s+\d+)[^。！？.!?\n]*[。！？.!?\n]?`,
)

// suppressTechnicalFailureProse is true only for the model sample immediately following a
// failed tool result. Explicit requests for raw diagnostics keep the existing technical view.
// suppressTechnicalFailureProse 仅对紧跟失败工具结果的模型采样生效；用户明确索要原始诊断时保留技术视图。
func suppressTechnicalFailureProse(messages []llminfra.LLMMessage) bool {
	last := -1
	for i := len(messages) - 1; i >= 0; i-- {
		if messages[i].Role == llminfra.RoleUser && strings.HasPrefix(strings.TrimSpace(messages[i].Content), "<system-reminder>") {
			continue
		}
		last = i
		break
	}
	if last < 0 || messages[last].Role != llminfra.RoleTool || !messages[last].ToolError {
		return false
	}
	for i := last - 1; i >= 0; i-- {
		if messages[i].Role != llminfra.RoleUser || strings.HasPrefix(strings.TrimSpace(messages[i].Content), "<system-reminder>") {
			continue
		}
		return !requestsTechnicalFailureDetails(messages[i].Content)
	}
	return true
}

func requestsTechnicalFailureDetails(text string) bool {
	lower := strings.ToLower(text)
	for _, phrase := range []string{
		"technical details", "raw error", "stack trace", "traceback", "stderr", "exact error",
		"原始错误", "原始异常", "技术细节", "完整错误", "完整异常", "错误详情", "异常详情",
	} {
		if strings.Contains(lower, phrase) {
			return true
		}
	}
	return false
}
