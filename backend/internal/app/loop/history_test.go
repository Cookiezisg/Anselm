package loop

import (
	"testing"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
)

// TestToolResultMediaIDs_CarriesTheToolCallID pins the wiring whose absence silently disabled the
// whole tool_result expansion branch: the expander must learn WHICH call produced each artifact,
// and the only honest source is the result block's parent (the tool_call). H5.8 read that id off
// ctx instead — the unit tests seeded ctx by hand and passed, while the loop expands one scope out
// where the id is empty, so every real expansion refused. A parameter cannot be forgotten silently;
// this asserts it is also the RIGHT id, and that a step with two tool calls yields two groups.
//
// TestToolResultMediaIDs_CarriesTheToolCallID 钉住那处接线——它的缺席静默关掉了整条 tool_result 展开
// 分支:展开器必须知道每件产物是**哪次调用**产出的,而唯一诚实的来源是结果块的父块(即 tool_call)。
// H5.8 改成从 ctx 读——单测**手工**种了 ctx 于是全绿,而 loop 在**外面一层**展开、那里 id 是空的,于是
// 每一次真实展开都被拒。参数没法被静默忘掉;这条再断言它还是**对的那个** id,且一步两个工具调用会分成
// 两组。
func TestToolResultMediaIDs_CarriesTheToolCallID(t *testing.T) {
	blocks := []messagesdomain.Block{
		{Type: messagesdomain.BlockTypeToolResult, ParentBlockID: "tc_one",
			Content: `{"chart":{"attachmentId":"att_1111111111111111","source":"function_artifact"}}`},
		{Type: messagesdomain.BlockTypeToolResult, ParentBlockID: "tc_two",
			Content: `{"shot":{"attachmentId":"att_2222222222222222","source":"mcp_artifact"}}`},
		// The generation family is collected like everything else — its veto died with ADR 0017
		// (the veto-on arm of the paired live experiment re-drew until MAX_STEPS; ADR 0020).
		// 生成族与其余产地一样被收集——它的否决随 ADR 0017 死了(成对真钱实验的否决开那一臂重画到
		// MAX_STEPS;ADR 0020)。
		{Type: messagesdomain.BlockTypeToolResult, ParentBlockID: "tc_three",
			Content: `{"attachmentId":"att_3333333333333333","source":"generate_image"}`},
	}
	groups := toolResultMediaIDs(blocks)
	if len(groups) != 3 {
		t.Fatalf("groups = %+v, want one per tool_result that carries media", groups)
	}
	if groups[0].toolCallID != "tc_one" || len(groups[0].ids) != 1 || groups[0].ids[0] != "att_1111111111111111" {
		t.Fatalf("group 0 = %+v, want tc_one's own artifact", groups[0])
	}
	if groups[1].toolCallID != "tc_two" || len(groups[1].ids) != 1 {
		t.Fatalf("group 1 = %+v, want tc_two's own artifact", groups[1])
	}
	if groups[2].toolCallID != "tc_three" || len(groups[2].ids) != 1 || groups[2].ids[0] != "att_3333333333333333" {
		t.Fatalf("group 2 = %+v, want the generated artifact under its own call", groups[2])
	}
}
