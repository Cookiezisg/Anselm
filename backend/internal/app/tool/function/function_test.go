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

func TestBuildTools_AcceptHostedModelStringifiedOpsAndNormalizeBeforeExecution(t *testing.T) {
	createArgs := json.RawMessage(`{"ops":"[{\"op\":\"set_meta\",\"name\":\"temperature\"}]","changeReason":"probe"}`)
	editArgs := json.RawMessage(`{"functionId":"fn_1","ops":"[{\"op\":\"set_meta\",\"name\":\"temperature\"}]","changeReason":"probe"}`)
	for _, tc := range []struct {
		name string
		tool toolapp.Tool
		args json.RawMessage
	}{
		{name: "create_function", tool: &CreateFunction{}, args: createArgs},
		{name: "edit_function", tool: &EditFunction{}, args: editArgs},
	} {
		if err := tc.tool.ValidateInput(tc.args); err != nil {
			t.Fatalf("%s should accept a valid JSON-encoded ops array: %v", tc.name, err)
		}
		normalizer, ok := tc.tool.(toolapp.ArgumentNormalizer)
		if !ok {
			t.Fatalf("%s must normalize hosted-model arguments", tc.name)
		}
		normalized, changed := normalizer.NormalizeArguments(tc.args)
		if !changed {
			t.Fatalf("%s did not report the stringified array repair", tc.name)
		}
		var fields map[string]json.RawMessage
		if err := json.Unmarshal(normalized, &fields); err != nil {
			t.Fatalf("%s normalized invalid JSON: %v", tc.name, err)
		}
		var ops []json.RawMessage
		if err := json.Unmarshal(fields["ops"], &ops); err != nil || len(ops) != 1 {
			t.Fatalf("%s normalized ops = %s, want one native array item", tc.name, fields["ops"])
		}
	}
}

func TestCreateFunction_ParametersDeclareOpDiscriminator(t *testing.T) {
	var schema struct {
		Properties map[string]struct {
			Items struct {
				Required   []string                  `json:"required"`
				Properties map[string]map[string]any `json:"properties"`
			} `json:"items"`
		} `json:"properties"`
	}
	if err := json.Unmarshal((&CreateFunction{}).Parameters(), &schema); err != nil {
		t.Fatalf("create_function schema is invalid JSON: %v", err)
	}
	ops := schema.Properties["ops"].Items
	if len(ops.Required) != 1 || ops.Required[0] != "op" {
		t.Fatalf("ops.items required = %v, want [op]", ops.Required)
	}
	op, ok := ops.Properties["op"]
	if !ok {
		t.Fatal("ops.items must declare the op discriminator")
	}
	values, ok := op["enum"].([]any)
	if !ok || len(values) != 6 {
		t.Fatalf("op enum = %#v, want six known function operations", op["enum"])
	}
	if _, legacy := ops.Properties["kind"]; legacy {
		t.Fatal("public schema must teach the canonical op key, not the observed legacy alias")
	}
}

func TestBuildTools_NormalizeKnownKindDiscriminator(t *testing.T) {
	tool := &CreateFunction{}
	args := json.RawMessage(`{"ops":[{"kind":"set_meta","name":"ep227_probe"},{"kind":"set_code","code":"def main():\n    return {\"status\": \"ok\"}"}]}`)
	if err := tool.ValidateInput(args); err != nil {
		t.Fatalf("known kind alias should be accepted at the compatibility boundary: %v", err)
	}
	normalized, changed := tool.NormalizeArguments(args)
	if !changed {
		t.Fatal("known kind alias should report normalization")
	}
	var got struct {
		Ops []map[string]json.RawMessage `json:"ops"`
	}
	if err := json.Unmarshal(normalized, &got); err != nil {
		t.Fatalf("normalized args invalid: %v", err)
	}
	if len(got.Ops) != 2 {
		t.Fatalf("normalized ops length = %d, want 2", len(got.Ops))
	}
	for i, op := range got.Ops {
		if _, ok := op["op"]; !ok {
			t.Fatalf("normalized op %d has no canonical op key: %v", i, op)
		}
		if _, ok := op["kind"]; ok {
			t.Fatalf("normalized op %d retained legacy kind key: %v", i, op)
		}
	}
}

func TestBuildTools_RejectNonArrayOpsStrings(t *testing.T) {
	for _, raw := range []string{`{"ops":"temperature"}`, `{"ops":"{\"op\":\"set_meta\"}"}`, `{"ops":"not json"}`} {
		if err := (&CreateFunction{}).ValidateInput(json.RawMessage(raw)); err == nil {
			t.Errorf("ValidateInput(%s) unexpectedly accepted a non-array ops string", raw)
		}
	}
}

func TestBuildTools_EditValidatesOpsBeforeExecution(t *testing.T) {
	tool := &EditFunction{}
	for _, raw := range []string{
		`{"functionId":"fn_1","ops":"not json"}`,
		`{"functionId":"fn_1","ops":null}`,
	} {
		if err := tool.ValidateInput(json.RawMessage(raw)); err == nil {
			t.Errorf("edit ValidateInput(%s) unexpectedly accepted malformed ops", raw)
		}
	}
	if err := tool.ValidateInput(json.RawMessage(`{"functionId":"fn_1","ops":[]}`)); err != nil {
		t.Fatalf("empty edit ops should remain valid for environment rebuild: %v", err)
	}
}

func TestBuildTools_NormalizeHostedModelNestedFieldShapes(t *testing.T) {
	args := json.RawMessage(`{"ops":"[{\"op\":\"set_meta\",\"name\":\"temperature\"},{\"op\":\"set_inputs\",\"inputs\":{\"celsius\":{\"type\":\"number\",\"description\":\"Temperature in Celsius\"}}},{\"op\":\"set_outputs\",\"outputs\":{\"type\":\"object\",\"properties\":{\"fahrenheit\":{\"type\":\"number\",\"description\":\"Temperature in Fahrenheit\"}},\"required\":[\"fahrenheit\"]}}]"}`)
	tool := &CreateFunction{}
	if err := tool.ValidateInput(args); err != nil {
		t.Fatalf("nested field shapes should be accepted after normalization: %v", err)
	}
	normalized, changed := tool.NormalizeArguments(args)
	if !changed {
		t.Fatal("nested field shapes should report a normalization")
	}
	var envelope struct {
		Ops []map[string]json.RawMessage `json:"ops"`
	}
	if err := json.Unmarshal(normalized, &envelope); err != nil {
		t.Fatalf("normalized args invalid: %v", err)
	}
	if len(envelope.Ops) != 3 {
		t.Fatalf("normalized ops count = %d, want 3", len(envelope.Ops))
	}
	for _, index := range []int{1, 2} {
		var fields []map[string]json.RawMessage
		key := "inputs"
		if index == 2 {
			key = "outputs"
		}
		if err := json.Unmarshal(envelope.Ops[index][key], &fields); err != nil {
			t.Fatalf("normalized %s is not a field array: %v", key, err)
		}
		if len(fields) != 1 {
			t.Fatalf("normalized %s length = %d, want 1", key, len(fields))
		}
		var name string
		if err := json.Unmarshal(fields[0]["name"], &name); err != nil || name == "" {
			t.Fatalf("normalized %s field has no name: %s", key, fields[0]["name"])
		}
	}
}

func TestBuildTools_RejectAmbiguousNestedSchema(t *testing.T) {
	raw := json.RawMessage(`{"ops":[{"op":"set_outputs","outputs":{"type":"object","properties":{"value":{"type":"number"}},"required":[]}}]}`)
	if err := (&CreateFunction{}).ValidateInput(raw); err == nil {
		t.Fatal("schema with non-total required list should not be silently projected")
	}
}

func TestBuildTools_RejectsDuplicateRequiredSchemaNames(t *testing.T) {
	raw := json.RawMessage(`{"ops":[{"op":"set_outputs","outputs":{"properties":{"value":{"type":"number"}},"required":["value","value"]}}]}`)
	if err := (&CreateFunction{}).ValidateInput(raw); err == nil {
		t.Fatal("schema with duplicate required names should not be silently projected")
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
