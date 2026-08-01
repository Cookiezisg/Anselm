package function

import (
	"encoding/json"
	"strings"
	"testing"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
)

// TestFunctionTools_Wiring asserts the 10 tools are constructed with the expected names.
func TestFunctionTools_Wiring(t *testing.T) {
	tools := FunctionTools(nil, nil, nil) // nil svc OK: we only inspect Name() here
	want := map[string]bool{
		"search_function": false, "get_function": false, "create_function": false,
		"edit_function": false, "revert_function": false, "delete_function": false,
		"run_function": false, "search_function_executions": false, "get_function_execution": false,
		"update_function_meta": false,
	}
	if len(tools) != len(want) {
		t.Fatalf("want %d tools, got %d", len(want), len(tools))
	}
	for _, tl := range tools {
		if _, ok := want[tl.Name()]; !ok {
			t.Fatalf("unexpected tool name %q", tl.Name())
		}
		want[tl.Name()] = true
		var _ toolapp.Tool = tl // every tool satisfies the 5-method interface
	}
	for name, seen := range want {
		if !seen {
			t.Fatalf("missing tool %q", name)
		}
	}
}

func TestDeleteFunction_DescriptionStatesRetentionTruth(t *testing.T) {
	d := (&DeleteFunction{}).Description()
	for _, want := range []string{"Soft-delete", "immutable version history", "retained", "sandbox environments"} {
		if !strings.Contains(d, want) {
			t.Errorf("delete_function description must state %q, got %q", want, d)
		}
	}
}

func TestUpdateFunctionMeta_DescriptionStatesPatchShape(t *testing.T) {
	d := (&UpdateFunctionMeta{}).Description()
	for _, want := range []string{"JSON array of strings", "never a comma-separated string", `"tags":["alpha","beta"]`} {
		if !strings.Contains(d, want) {
			t.Errorf("update_function_meta description must state %q, got %q", want, d)
		}
	}
}

func TestRunFunction_DescriptionStatesArgumentShapes(t *testing.T) {
	d := (&RunFunction{}).Description()
	for _, want := range []string{"JSON integer number", `exact decimal string "2"`, `"version":2`, `"args":{"text":"hello"}`} {
		if !strings.Contains(d, want) {
			t.Errorf("run_function description must state %q, got %q", want, d)
		}
	}
}

func TestRunFunctionArgs_AcceptsStringifiedVersion(t *testing.T) {
	var args runFunctionArgs
	if err := json.Unmarshal([]byte(`{"functionId":"fn_1","args":{"text":"hello"},"version":"2"}`), &args); err != nil {
		t.Fatalf("stringified integer should be accepted: %v", err)
	}
	if args.Version != 2 || args.Args["text"] != "hello" {
		t.Fatalf("decoded args = %+v, want version 2 and text hello", args)
	}
}

func TestRunFunctionArgs_RejectsNonIntegerVersion(t *testing.T) {
	for _, raw := range []string{`2.5`, `[]`, `"two"`} {
		var args runFunctionArgs
		if err := json.Unmarshal([]byte(`{"functionId":"fn_1","args":{},"version":`+raw+`}`), &args); err == nil {
			t.Errorf("version %s should be rejected", raw)
		}
	}
}

func TestSearchFunctionExecutions_DescriptionStatesPagingShape(t *testing.T) {
	d := (&SearchFunctionExecutions{}).Description()
	for _, want := range []string{"JSON integer", `exact decimal string "2"`, "nextCursor verbatim"} {
		if !strings.Contains(d, want) {
			t.Errorf("search_function_executions description must state %q, got %q", want, d)
		}
	}
}

func TestSearchFunctionExecutionsArgs_AcceptsStringifiedLimit(t *testing.T) {
	var args searchFunctionExecutionsArgs
	if err := json.Unmarshal([]byte(`{"functionId":"fn_1","limit":"2","cursor":"c1"}`), &args); err != nil {
		t.Fatalf("stringified integer limit should be accepted: %v", err)
	}
	if args.Limit != 2 || args.Cursor != "c1" {
		t.Fatalf("decoded args = %+v, want limit 2 and cursor c1", args)
	}
}

func TestSearchFunctionExecutionsArgs_RejectsNonIntegerLimit(t *testing.T) {
	for _, raw := range []string{`2.5`, `[]`, `"two"`} {
		var args searchFunctionExecutionsArgs
		if err := json.Unmarshal([]byte(`{"functionId":"fn_1","limit":`+raw+`}`), &args); err == nil {
			t.Errorf("limit %s should be rejected", raw)
		}
	}
}

func TestValidateInput_RequiredFields(t *testing.T) {
	cases := []struct {
		name    string
		tool    toolapp.Tool
		args    string
		wantErr bool
	}{
		{"create empty ops", &CreateFunction{}, `{"ops":[]}`, true},
		{"create with ops", &CreateFunction{}, `{"ops":[{"op":"set_meta","name":"a"}]}`, false},
		{"edit no id", &EditFunction{}, `{"ops":[]}`, true},
		{"edit with id", &EditFunction{}, `{"functionId":"fn_1","ops":[]}`, false},
		{"get no id", &GetFunction{}, `{}`, true},
		{"get with id", &GetFunction{}, `{"functionId":"fn_1"}`, false},
		{"run no id", &RunFunction{}, `{"args":{}}`, true},
		{"run with id", &RunFunction{}, `{"functionId":"fn_1","args":{}}`, false},
		{"revert no id", &RevertFunction{}, `{"version":1}`, true},
		{"revert bad version", &RevertFunction{}, `{"functionId":"fn_1","version":0}`, true},
		{"revert ok", &RevertFunction{}, `{"functionId":"fn_1","version":2}`, false},
		{"delete no id", &DeleteFunction{}, `{}`, true},
		{"search exec no id", &SearchFunctionExecutions{}, `{}`, true},
		{"get exec no id", &GetFunctionExecution{}, `{}`, true},
		{"search any", &SearchFunction{}, `{}`, false},
	}
	for _, c := range cases {
		err := c.tool.ValidateInput([]byte(c.args))
		if (err != nil) != c.wantErr {
			t.Errorf("%s: ValidateInput(%s) err=%v, wantErr=%v", c.name, c.args, err, c.wantErr)
		}
	}
}
