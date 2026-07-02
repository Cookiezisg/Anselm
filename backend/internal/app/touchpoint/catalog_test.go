package touchpoint

import (
	"testing"

	touchpointdomain "github.com/sunweilin/anselm/backend/internal/domain/touchpoint"
)

// The catalog's extraction contract: right kind/verb/id per tool family, total-function
// behavior on every malformed input (nil, never error).
// 目录提取契约:各工具族 kind/verb/id 正确;一切畸形输入全函数(返 nil、绝不报错)。

func one(t *testing.T, refs []ItemRef) ItemRef {
	t.Helper()
	if len(refs) != 1 {
		t.Fatalf("want 1 ref, got %v", refs)
	}
	return refs[0]
}

func TestExtract_ArgKeyed(t *testing.T) {
	cases := []struct {
		tool, argKey, id, kind, verb string
	}{
		{"edit_function", "functionId", "fn_1", "function", touchpointdomain.VerbEdited},
		{"revert_agent", "agentId", "ag_1", "agent", touchpointdomain.VerbEdited},
		{"delete_workflow", "workflowId", "wf_1", "workflow", touchpointdomain.VerbDeleted},
		{"run_function", "functionId", "fn_1", "function", touchpointdomain.VerbExecuted},
		{"call_handler", "handlerId", "hd_1", "handler", touchpointdomain.VerbExecuted},
		{"invoke_agent", "agentId", "ag_1", "agent", touchpointdomain.VerbExecuted},
		{"trigger_workflow", "workflowId", "wf_1", "workflow", touchpointdomain.VerbExecuted},
		{"fire_trigger", "triggerId", "trg_1", "trigger", touchpointdomain.VerbExecuted},
		{"get_function", "functionId", "fn_1", "function", touchpointdomain.VerbViewed},
		{"read_document", "id", "doc_1", "document", touchpointdomain.VerbViewed},
		{"read_attachment", "id", "att_1", touchpointdomain.ItemKindAttachment, touchpointdomain.VerbViewed},
		{"search_function_executions", "functionId", "fn_1", "function", touchpointdomain.VerbViewed},
		{"activate_workflow", "workflowId", "wf_1", "workflow", touchpointdomain.VerbEdited},
		{"update_agent_meta", "agentId", "ag_1", "agent", touchpointdomain.VerbEdited},
	}
	for _, c := range cases {
		r := one(t, ExtractTouches(c.tool, map[string]any{c.argKey: c.id}, ""))
		if r.Kind != c.kind || r.ID != c.id || r.Verb != c.verb {
			t.Errorf("%s: %+v", c.tool, r)
		}
	}
}

func TestExtract_NameKeyedCarryName(t *testing.T) {
	// skill / mcp short names double as display names — no hydration round-trip.
	// skill / mcp 短名即显示名——不走 hydrate。
	r := one(t, ExtractTouches("edit_skill", map[string]any{"name": "deploy"}, ""))
	if r.Kind != "skill" || r.ID != "deploy" || r.Name != "deploy" || r.Verb != touchpointdomain.VerbEdited {
		t.Errorf("edit_skill: %+v", r)
	}
	r = one(t, ExtractTouches("uninstall_mcp_server", map[string]any{"name": "context7"}, ""))
	if r.Kind != "mcp" || r.ID != "context7" || r.Name != "context7" || r.Verb != touchpointdomain.VerbDeleted {
		t.Errorf("uninstall_mcp_server: %+v", r)
	}
	r = one(t, ExtractTouches("create_skill", map[string]any{"name": "deploy"}, `{"created":"deploy"}`))
	if r.Kind != "skill" || r.ID != "deploy" || r.Verb != touchpointdomain.VerbCreated {
		t.Errorf("create_skill: %+v", r)
	}
}

func TestExtract_OutputKeyedCreates(t *testing.T) {
	r := one(t, ExtractTouches("create_function", nil, `{"id":"fn_9","versionId":"fnv_1","version":1}`))
	if r.Kind != "function" || r.ID != "fn_9" || r.Verb != touchpointdomain.VerbCreated {
		t.Errorf("create_function: %+v", r)
	}
	r = one(t, ExtractTouches("install_mcp_server", map[string]any{"name": "io.github.upstash/context7"}, `{"id":"mcp_1","name":"context7"}`))
	if r.Kind != "mcp" || r.ID != "mcp_1" {
		t.Errorf("install_mcp_server: %+v", r)
	}
	// Unparsable output under-reports. 输出不可解析:少报。
	if refs := ExtractTouches("create_function", nil, "exploded"); refs != nil {
		t.Errorf("bad output must yield nil: %v", refs)
	}
}

func TestExtract_CreateDocumentProse(t *testing.T) {
	out := `Created document "规范" (id=doc_00ff00ff00ff00ff, path=/specs/规范)`
	r := one(t, ExtractTouches("create_document", nil, out))
	if r.Kind != "document" || r.ID != "doc_00ff00ff00ff00ff" || r.Verb != touchpointdomain.VerbCreated {
		t.Errorf("create_document: %+v", r)
	}
	if refs := ExtractTouches("create_document", nil, "no id here"); refs != nil {
		t.Errorf("missing id must yield nil: %v", refs)
	}
}

func TestExtract_GetRelations(t *testing.T) {
	r := one(t, ExtractTouches("get_relations", map[string]any{"kind": "workflow", "id": "wf_1"}, ""))
	if r.Kind != "workflow" || r.ID != "wf_1" || r.Verb != touchpointdomain.VerbViewed {
		t.Errorf("get_relations: %+v", r)
	}
	if refs := ExtractTouches("get_relations", map[string]any{"kind": "flowrun", "id": "frn_1"}, ""); refs != nil {
		t.Errorf("non-ledger kind must yield nil: %v", refs)
	}
}

func TestExtract_MCPDynamic(t *testing.T) {
	r := one(t, ExtractTouches("mcp__context7__search_docs", map[string]any{"q": "x"}, ""))
	if r.Kind != "mcp" || r.ID != "context7" || r.Name != "context7" || r.Verb != touchpointdomain.VerbExecuted {
		t.Errorf("dynamic: %+v", r)
	}
	if refs := ExtractTouches("mcp__broken", nil, ""); refs != nil {
		t.Errorf("malformed dynamic name must yield nil: %v", refs)
	}
}

func TestExtract_TotalFunction(t *testing.T) {
	// Unknown tool / no-touch tool / absent optional arg / wrong arg type — all nil, no panic.
	// 未知工具 / no-touch 工具 / 可选参数缺席 / 参数类型不对——全 nil、不炸。
	if ExtractTouches("Bash", map[string]any{"command": "ls"}, "") != nil {
		t.Error("resident tool must yield nil")
	}
	if ExtractTouches("totally_new_tool", nil, "") != nil {
		t.Error("unknown tool must yield nil")
	}
	if ExtractTouches("search_agent_executions", map[string]any{}, "") != nil {
		t.Error("absent optional filter must yield nil")
	}
	if ExtractTouches("edit_function", map[string]any{"functionId": 42}, "") != nil {
		t.Error("non-string id must yield nil")
	}
}

func TestCovers(t *testing.T) {
	for _, name := range []string{
		"edit_function", "create_document", "get_relations", // catalog + specials
		"Bash", "todo_write", "manage_conversation", // no-touch
		"mcp__anything__tool", // dynamic prefix
	} {
		if !Covers(name) {
			t.Errorf("%s must be covered", name)
		}
	}
	if Covers("some_future_tool") {
		t.Error("unknown tool must NOT be covered — that is the gate's whole point")
	}
}
