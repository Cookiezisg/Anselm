package loop

import (
	"strings"
	"testing"

	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

func TestRedactTechnicalFailureProseAcrossChunks(t *testing.T) {
	var redactor textRedactor
	redactor.suppressTechnicalErrors = true
	var live strings.Builder
	for _, chunk := range []string{
		"函数已执行并按预期失败。",
		"失败原因：函数内部主动抛出了 Run",
		"timeError: edge295 intentional failure，这是一个人为设计的失败，用于验收测试。",
		"查看执行历史：请打开执行记录。",
	} {
		piece := redactor.Write(chunk)
		if strings.Contains(piece, "RuntimeError") || strings.Contains(piece, "edge295 intentional failure") {
			t.Fatalf("technical diagnostic leaked from live delta: %q", piece)
		}
		live.WriteString(piece)
	}
	live.WriteString(redactor.Flush())
	got := live.String()
	for _, forbidden := range []string{"RuntimeError", "edge295 intentional failure", "人为设计的失败"} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("technical diagnostic leaked from final live stream: %q", got)
		}
	}
	for _, expected := range []string{"函数已执行并按预期失败。", "这一步执行失败，详细技术信息见下方执行记录。", "查看执行历史"} {
		if !strings.Contains(got, expected) {
			t.Fatalf("failure summary lost %q: %q", expected, got)
		}
	}
}

func TestTechnicalFailureDetailsRemainWhenExplicitlyRequested(t *testing.T) {
	messages := []llminfra.LLMMessage{
		{Role: llminfra.RoleUser, Content: "请给我原始错误和完整 traceback。"},
		{Role: llminfra.RoleAssistant, ToolCalls: []llminfra.LLMToolCall{{ID: "call-1", Name: "run_function"}}},
		{Role: llminfra.RoleTool, ToolCallID: "call-1", ToolError: true, Content: "RuntimeError: exact failure"},
	}
	if suppressTechnicalFailureProse(messages) {
		t.Fatal("explicit technical-detail request was incorrectly suppressed")
	}
}

func TestToolErrorProjectionIsInternalOnly(t *testing.T) {
	messages := BlocksToAssistantLLM(nil)
	if len(messages) != 1 || messages[0].ToolError {
		t.Fatalf("unexpected empty projection: %+v", messages)
	}
}
