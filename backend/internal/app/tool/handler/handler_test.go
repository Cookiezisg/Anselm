package handler

import (
	"encoding/json"
	"strings"
	"testing"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	handlerdomain "github.com/sunweilin/anselm/backend/internal/domain/handler"
)

func TestDecodeHandlerOps_AcceptsNativeAndStringifiedArrays(t *testing.T) {
	cases := []struct {
		name string
		raw  string
		want int
	}{
		{name: "native array", raw: `[{"op":"set_meta","name":"probe"}]`, want: 1},
		{name: "exact JSON encoded array", raw: `"[{\"op\":\"set_meta\",\"name\":\"probe\"}]"`, want: 1},
		{name: "null is empty", raw: `null`, want: 0},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			ops, err := decodeHandlerOps(json.RawMessage(tc.raw))
			if err != nil {
				t.Fatalf("decodeHandlerOps(%s): %v", tc.raw, err)
			}
			if len(ops) != tc.want {
				t.Fatalf("got %d ops, want %d", len(ops), tc.want)
			}
		})
	}
}

func TestDecodeHandlerOps_RejectsMalformedOrNonArrayValues(t *testing.T) {
	for _, raw := range []string{
		`"not json"`,
		`"{\"op\":\"set_meta\"}"`,
		`{"op":"set_meta"}`,
		`7`,
	} {
		t.Run(raw, func(t *testing.T) {
			if _, err := decodeHandlerOps(json.RawMessage(raw)); err == nil {
				t.Fatalf("decodeHandlerOps(%s) unexpectedly succeeded", raw)
			}
		})
	}
}

func TestEditHandler_DescriptionPinsUpdateMethodShape(t *testing.T) {
	desc := (&EditHandler{}).Description()
	for _, want := range []string{
		`"op":"update_method"`,
		`"name":"place"`,
		`"patch":{"description":"..."}`,
		`Do NOT use "methodName"`,
	} {
		if !strings.Contains(desc, want) {
			t.Fatalf("edit_handler description missing %q: %s", want, desc)
		}
	}
}

func TestDeleteHandler_DescriptionPinsSoftDeleteRetention(t *testing.T) {
	desc := (&DeleteHandler{}).Description()
	for _, want := range []string{
		"soft-delete the handler row",
		"Immutable versions remain available for audit",
		"destroyed best-effort",
		"relation edges are purged",
	} {
		if !strings.Contains(desc, want) {
			t.Fatalf("delete_handler description missing %q: %s", want, desc)
		}
	}
	if strings.Contains(desc, "remove all versions") {
		t.Fatalf("delete_handler description still claims versions are removed: %s", desc)
	}
}

func TestHandlerDeleteResultStatesRetentionTruth(t *testing.T) {
	result := handlerDeleteResult("hd_1", nil)
	if result["id"] != "hd_1" || result["deleted"] != true {
		t.Fatalf("result identity = %#v, want deleted hd_1", result)
	}
	retention, ok := result["retention"].(map[string]any)
	if !ok {
		t.Fatalf("retention = %#v, want object", result["retention"])
	}
	for key, want := range map[string]string{
		"handler":  "soft_deleted",
		"versions": "retained_for_audit",
		"sandbox":  "destroy_requested_best_effort",
		"actions":  "not_found",
	} {
		if retention[key] != want {
			t.Fatalf("retention[%q] = %#v, want %q", key, retention[key], want)
		}
	}
}

func TestUpdateHandlerConfig_AcceptsObjectEncodingOnly(t *testing.T) {
	tool := &UpdateHandlerConfig{}
	cases := []struct {
		name    string
		args    string
		wantErr bool
	}{
		{name: "native object", args: `{"handlerId":"hd_1","config":{"mode":"cool"}}`},
		{name: "stringified object", args: `{"handlerId":"hd_1","config":"{\"mode\":\"cool\"}"}`},
		{name: "missing config", args: `{"handlerId":"hd_1"}`, wantErr: true},
		{name: "null config", args: `{"handlerId":"hd_1","config":null}`, wantErr: true},
		{name: "array config", args: `{"handlerId":"hd_1","config":[]}`, wantErr: true},
		{name: "malformed string", args: `{"handlerId":"hd_1","config":"not json"}`, wantErr: true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := tool.ValidateInput([]byte(tc.args))
			if (err != nil) != tc.wantErr {
				t.Fatalf("ValidateInput(%s) err=%v, wantErr=%v", tc.args, err, tc.wantErr)
			}
		})
	}
}

func TestUpdateHandlerConfig_DescriptionPinsStringifiedObjectBoundary(t *testing.T) {
	desc := (&UpdateHandlerConfig{}).Description()
	for _, want := range []string{
		"only tool for changing",
		"Do NOT use call_handler",
		"JSON Merge Patch",
		"exact JSON-encoded object string is also accepted",
		"arrays and malformed strings are rejected",
	} {
		if !strings.Contains(desc, want) {
			t.Fatalf("update_handler_config description missing %q: %s", want, desc)
		}
	}
}

func TestCallHandler_RejectsTopLevelConfig(t *testing.T) {
	tool := &CallHandler{}
	if err := tool.ValidateInput([]byte(`{"handlerId":"hd_1","method":"inspect","args":{},"config":{"mode":"cool"}}`)); err == nil {
		t.Fatal("call_handler accepted top-level config; config changes must use update_handler_config")
	}
	if err := tool.ValidateInput([]byte(`{"handlerId":"hd_1","method":"inspect","args":{"config":"method argument"}}`)); err != nil {
		t.Fatalf("call_handler rejected a method-level config argument: %v", err)
	}
}

func TestCallHandler_DescriptionPinsConfigBoundary(t *testing.T) {
	desc := (&CallHandler{}).Description()
	for _, want := range []string{
		"does NOT change the handler's init config",
		"use update_handler_config",
	} {
		if !strings.Contains(desc, want) {
			t.Fatalf("call_handler description missing %q: %s", want, desc)
		}
	}
}

func TestNormalizeHandlerOps_RepairsHostedUpdateMethodAlias(t *testing.T) {
	items, err := normalizeHandlerOps([]json.RawMessage{
		[]byte(`{"op":"updateMethod","methodName":"place","description":"Place an order and return a confirmation"}`),
	})
	if err != nil {
		t.Fatalf("normalizeHandlerOps: %v", err)
	}
	var got map[string]json.RawMessage
	if err := json.Unmarshal(items[0], &got); err != nil {
		t.Fatalf("normalized op is invalid JSON: %v", err)
	}
	if string(got["name"]) != `"place"` {
		t.Fatalf("normalized name = %s, want %q", got["name"], "place")
	}
	if string(got["op"]) != `"update_method"` {
		t.Fatalf("normalized op = %s, want %q", got["op"], "update_method")
	}
	var patch map[string]string
	if err := json.Unmarshal(got["patch"], &patch); err != nil {
		t.Fatalf("normalized patch is invalid: %v", err)
	}
	if patch["description"] != "Place an order and return a confirmation" {
		t.Fatalf("normalized patch = %#v", patch)
	}
}

func TestNormalizeHandlerOps_RepairsHostedSetMethodAlias(t *testing.T) {
	items, err := normalizeHandlerOps([]json.RawMessage{
		[]byte(`{"kind":"set_method","method":{"name":"place","description":"Revert probe v2","body":"return {\"ok\": True}","inputs":[],"streaming":false}}`),
	})
	if err != nil {
		t.Fatalf("normalizeHandlerOps: %v", err)
	}
	var got map[string]json.RawMessage
	if err := json.Unmarshal(items[0], &got); err != nil {
		t.Fatalf("normalized op is invalid JSON: %v", err)
	}
	if string(got["op"]) != `"update_method"` || string(got["name"]) != `"place"` {
		t.Fatalf("normalized discriminator/name = %s / %s", got["op"], got["name"])
	}
	var patch map[string]json.RawMessage
	if err := json.Unmarshal(got["patch"], &patch); err != nil {
		t.Fatalf("normalized patch is invalid: %v", err)
	}
	if string(patch["description"]) != `"Revert probe v2"` || string(patch["body"]) == "" {
		t.Fatalf("normalized patch = %s", got["patch"])
	}
}

func TestNormalizeHandlerOps_RejectsUnknownUpdateMethodShape(t *testing.T) {
	for _, raw := range []string{
		`{"op":"update_method","method":"place"}`,
		`{"op":"update_method","method":7,"description":"bad"}`,
		`{"op":"update_method","method":"place","description":"bad","unknown":"bad"}`,
	} {
		if _, err := normalizeHandlerOps([]json.RawMessage{[]byte(raw)}); err == nil {
			t.Fatalf("normalizeHandlerOps(%s) unexpectedly succeeded", raw)
		}
	}
	for _, raw := range []string{
		`{"kind":"set_method","method":{"name":"place"}}`,
		`{"kind":"set_method","method":{"name":"place","unknown":"bad"}}`,
		`{"kind":"set_method","method":"place"}`,
	} {
		if _, err := normalizeHandlerOps([]json.RawMessage{[]byte(raw)}); err == nil {
			t.Fatalf("normalizeHandlerOps(%s) unexpectedly succeeded", raw)
		}
	}
}

func TestRevertHandler_OnlyAcceptsExactIntegerOrIntegerString(t *testing.T) {
	tool := &RevertHandler{}
	for _, raw := range []string{
		`{"handlerId":"hd_1","version":1}`,
		`{"handlerId":"hd_1","version":"1"}`,
		`{"handlerId":"hd_1","version":" 1 "}`,
	} {
		if err := tool.ValidateInput(json.RawMessage(raw)); err != nil {
			t.Fatalf("ValidateInput(%s) = %v, want nil", raw, err)
		}
	}
	for _, raw := range []string{
		`{"handlerId":"hd_1","version":"1.0"}`,
		`{"handlerId":"hd_1","version":"one"}`,
		`{"handlerId":"hd_1","version":[]}`,
		`{"handlerId":"hd_1","version":true}`,
		`{"handlerId":"hd_1","version":0}`,
	} {
		if err := tool.ValidateInput(json.RawMessage(raw)); err == nil {
			t.Fatalf("ValidateInput(%s) unexpectedly succeeded", raw)
		}
	}
}

// TestBuildOutput_SurfacesRuntimeState — F-handler-broken-init-outage (round-8): edit_handler must
// surface the post-edit runtimeState (+ a warning when not running) so a broken __init__ that builds
// the env fine but fails to spawn doesn't read as a clean "successful" edit. Create (runtimeState="")
// stays silent — a fresh handler not running is expected, not a bricking.
func TestBuildOutput_SurfacesRuntimeState(t *testing.T) {
	v := &handlerdomain.Version{ID: "hdv_1", Version: 2, EnvStatus: "ready"}

	running := buildOutput("hd_1", v, 1, nil, handlerdomain.RuntimeStateRunning, false)
	if running["runtimeState"] != handlerdomain.RuntimeStateRunning {
		t.Fatalf("running edit must report runtimeState, got %+v", running)
	}
	if _, hasWarn := running["runtimeWarning"]; hasWarn {
		t.Fatalf("a running instance must NOT carry a warning, got %+v", running)
	}

	broken := buildOutput("hd_1", v, 1, nil, handlerdomain.RuntimeStateStopped, false)
	if broken["runtimeState"] != handlerdomain.RuntimeStateStopped {
		t.Fatalf("broken edit must report runtimeState=stopped, got %+v", broken)
	}
	if _, hasWarn := broken["runtimeWarning"]; !hasWarn {
		t.Fatalf("a not-running instance after edit MUST carry a warning (else the brick is silent), got %+v", broken)
	}

	created := buildOutput("hd_1", v, 1, nil, "", false)
	if _, has := created["runtimeState"]; has {
		t.Fatalf("create (runtimeState=\"\") must stay silent on runtime state, got %+v", created)
	}
}

// TestBuildOutput_EmptyOpsRestartIsVisible — F140: an empty-ops edit_handler rebuilds the env and
// restarts the resident instance (wiping in-memory state) but applies no ops and mints no version —
// it must NOT read as a no-op. The result carries restarted:true + a note so the state wipe is visible.
func TestBuildOutput_EmptyOpsRestartIsVisible(t *testing.T) {
	v := &handlerdomain.Version{ID: "hdv_1", Version: 2, EnvStatus: "ready"}

	restarted := buildOutput("hd_1", v, 0, nil, handlerdomain.RuntimeStateRunning, true)
	if restarted["restarted"] != true {
		t.Fatalf("empty-ops restart must surface restarted:true (else it reads as a no-op), got %+v", restarted)
	}
	if _, has := restarted["restartNote"]; !has {
		t.Fatalf("a restart must carry a note that in-memory state was wiped, got %+v", restarted)
	}

	normal := buildOutput("hd_1", v, 2, nil, handlerdomain.RuntimeStateRunning, false)
	if _, has := normal["restarted"]; has {
		t.Fatalf("a normal op-applying edit must NOT flag restarted (the version bump already signals change), got %+v", normal)
	}
}

func TestHandlerTools_Wiring(t *testing.T) {
	tools := HandlerTools(nil, nil, nil)
	want := map[string]bool{
		"search_handler": false, "get_handler": false, "create_handler": false,
		"edit_handler": false, "revert_handler": false, "delete_handler": false,
		"call_handler": false, "update_handler_config": false, "restart_handler": false,
		"search_handler_calls": false, "get_handler_call": false, "update_handler_meta": false,
	}
	if len(tools) != len(want) {
		t.Fatalf("want %d tools, got %d", len(want), len(tools))
	}
	for _, tl := range tools {
		if _, ok := want[tl.Name()]; !ok {
			t.Fatalf("unexpected tool name %q", tl.Name())
		}
		want[tl.Name()] = true
		var _ toolapp.Tool = tl
	}
	for name, seen := range want {
		if !seen {
			t.Fatalf("missing tool %q", name)
		}
	}
}

func TestSearchHandlerCalls_DescriptionStatesPagingShape(t *testing.T) {
	d := (&SearchHandlerCalls{}).Description()
	for _, want := range []string{"JSON integer", `exact decimal string "2"`, "nextCursor verbatim"} {
		if !strings.Contains(d, want) {
			t.Errorf("search_handler_calls description must state %q, got %q", want, d)
		}
	}
}

func TestSearchHandlerCallsArgs_AcceptsStringifiedLimit(t *testing.T) {
	var args searchHandlerCallsArgs
	if err := json.Unmarshal([]byte(`{"handlerId":"hd_1","limit":"2","cursor":"c1"}`), &args); err != nil {
		t.Fatalf("stringified integer limit should be accepted: %v", err)
	}
	if args.Limit != 2 || args.Cursor != "c1" {
		t.Fatalf("decoded args = %+v, want limit 2 and cursor c1", args)
	}
}

func TestSearchHandlerCallsArgs_RejectsNonIntegerLimit(t *testing.T) {
	for _, raw := range []string{`2.5`, `[]`, `"two"`} {
		var args searchHandlerCallsArgs
		if err := json.Unmarshal([]byte(`{"handlerId":"hd_1","limit":`+raw+`}`), &args); err == nil {
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
		{"create empty ops", &CreateHandler{}, `{"ops":[]}`, true},
		{"create with ops", &CreateHandler{}, `{"ops":[{"op":"set_meta","name":"a"}]}`, false},
		{"create with stringified ops", &CreateHandler{}, `{"ops":"[{\"op\":\"set_meta\",\"name\":\"a\"}]"}`, false},
		{"create with malformed stringified ops", &CreateHandler{}, `{"ops":"not json"}`, true},
		{"edit no id", &EditHandler{}, `{"ops":[]}`, true},
		{"edit with stringified ops", &EditHandler{}, `{"handlerId":"hd_1","ops":"[{\"op\":\"set_meta\",\"name\":\"a\"}]"}`, false},
		{"edit with malformed stringified ops", &EditHandler{}, `{"handlerId":"hd_1","ops":"not json"}`, true},
		{"get no id", &GetHandler{}, `{}`, true},
		{"call no id", &CallHandler{}, `{"method":"m","args":{}}`, true},
		{"call no method", &CallHandler{}, `{"handlerId":"hd_1","args":{}}`, true},
		{"call ok", &CallHandler{}, `{"handlerId":"hd_1","method":"m","args":{}}`, false},
		{"revert bad version", &RevertHandler{}, `{"handlerId":"hd_1","version":0}`, true},
		{"revert ok", &RevertHandler{}, `{"handlerId":"hd_1","version":2}`, false},
		{"delete no id", &DeleteHandler{}, `{}`, true},
		{"restart no id", &RestartHandler{}, `{}`, true},
		{"restart ok", &RestartHandler{}, `{"handlerId":"hd_1"}`, false},
		{"update_config no id", &UpdateHandlerConfig{}, `{"config":{}}`, true},
		{"search_calls no id", &SearchHandlerCalls{}, `{}`, true},
		{"get_call no id", &GetHandlerCall{}, `{}`, true},
		{"search any", &SearchHandler{}, `{}`, false},
	}
	for _, c := range cases {
		err := c.tool.ValidateInput([]byte(c.args))
		if (err != nil) != c.wantErr {
			t.Errorf("%s: ValidateInput(%s) err=%v, wantErr=%v", c.name, c.args, err, c.wantErr)
		}
	}
}
