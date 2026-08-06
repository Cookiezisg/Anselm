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
		`Do NOT use set_methods`,
	} {
		if !strings.Contains(desc, want) {
			t.Fatalf("edit_handler description missing %q: %s", want, desc)
		}
	}
}

func TestNormalizeHandlerOpsForEdit_SplitsLegacyMethodListByActiveNames(t *testing.T) {
	items, err := normalizeHandlerOpsWithExistingMethods([]json.RawMessage{
		[]byte(`{"op":"set_methods","methods":[{"name":"status","description":"Returns the current revision identifier","inputs":[],"outputs":[],"body":"return {\"revision\": self.revision}","streaming":false},{"name":"health","description":"Report health","inputs":[],"outputs":[],"body":"return {\"ok\": True}","streaming":false}]}`),
	}, map[string]struct{}{"status": {}})
	if err != nil {
		t.Fatalf("normalizeHandlerOpsWithExistingMethods: %v", err)
	}
	if len(items) != 2 {
		t.Fatalf("normalized item count = %d, want 2", len(items))
	}
	var existing, added struct {
		Op     string `json:"op"`
		Name   string `json:"name"`
		Method struct {
			Name string `json:"name"`
		} `json:"method"`
	}
	if err := json.Unmarshal(items[0], &existing); err != nil {
		t.Fatalf("existing op: %v", err)
	}
	if err := json.Unmarshal(items[1], &added); err != nil {
		t.Fatalf("new op: %v", err)
	}
	if existing.Op != "update_method" || existing.Name != "status" {
		t.Fatalf("existing method op = %+v, want update_method/status", existing)
	}
	if added.Op != "add_method" || added.Method.Name != "health" {
		t.Fatalf("new method op = %+v, want add_method/health", added)
	}
}

func TestCreateHandler_DescriptionDisambiguatesFunctionOps(t *testing.T) {
	desc := (&CreateHandler{}).Description()
	for _, want := range []string{
		"this is a HANDLER, not a stateless function",
		"Never emit the function ops set_code",
		"never emit set_methods",
		`"op":"add_method","method"`,
	} {
		if !strings.Contains(desc, want) {
			t.Fatalf("create_handler description missing %q: %s", want, desc)
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

func TestNormalizeHandlerOps_RepairsLegacyWholeClassHandlerBuild(t *testing.T) {
	items, err := normalizeHandlerOps([]json.RawMessage{
		[]byte(`{"op":"set_meta","name":"legacy_probe"}`),
		[]byte(`{"op":"set_code","language":"python","runtimeVersion":"3.12","code":"class Handler:\n    def __init__(self):\n        pass\n\n    def ping(self):\n        return {\"pong\": True}\n"}`),
		[]byte(`{"op":"set_init_args","schema":{"type":"object","properties":{}}}`),
	})
	if err != nil {
		t.Fatalf("normalizeHandlerOps: %v", err)
	}
	var got []string
	for _, raw := range items {
		var op struct {
			Op string `json:"op"`
		}
		if err := json.Unmarshal(raw, &op); err != nil {
			t.Fatalf("normalized op is invalid JSON: %v", err)
		}
		got = append(got, op.Op)
	}
	want := []string{"set_meta", "set_python_version", "set_init", "add_method", "set_init_args_schema"}
	if strings.Join(got, ",") != strings.Join(want, ",") {
		t.Fatalf("normalized ops = %v, want %v", got, want)
	}
	var method struct {
		Method struct {
			Name string `json:"name"`
			Body string `json:"body"`
		} `json:"method"`
	}
	if err := json.Unmarshal(items[3], &method); err != nil {
		t.Fatalf("method op is invalid JSON: %v", err)
	}
	if method.Method.Name != "ping" || !strings.Contains(method.Method.Body, `return {"pong": True}`) {
		t.Fatalf("translated method = %+v", method.Method)
	}
}

func TestNormalizeHandlerOps_RepairsLegacyMethodListAndInitSchema(t *testing.T) {
	items, err := normalizeHandlerOps([]json.RawMessage{
		[]byte(`{"op":"set_code","runtimeVersion":"3.11","code":"class Handler:\n    def __init__(self):\n        self.ready = True\n\n    def ping(self):\n        return True\n"}`),
		[]byte(`{"op":"set_methods","methods":[{"name":"ping","inputs":[],"outputs":[{"name":"ok","type":"boolean"}],"body":"return True","streaming":false}]}`),
		[]byte(`{"op":"set_init_args","schema":{"type":"object","properties":{"token":{"type":"string","description":"access token","sensitive":true}},"required":["token"]}}`),
	})
	if err != nil {
		t.Fatalf("normalizeHandlerOps: %v", err)
	}
	var ops []string
	for _, raw := range items {
		var op struct {
			Op string `json:"op"`
		}
		if err := json.Unmarshal(raw, &op); err != nil {
			t.Fatalf("normalized op is invalid JSON: %v", err)
		}
		ops = append(ops, op.Op)
	}
	if strings.Join(ops, ",") != "set_python_version,set_init,add_method,set_init_args_schema" {
		t.Fatalf("normalized ops = %v", ops)
	}
	var schema struct {
		Args []handlerdomain.InitArgSpec `json:"args"`
	}
	if err := json.Unmarshal(items[3], &schema); err != nil {
		t.Fatalf("init schema op is invalid JSON: %v", err)
	}
	if len(schema.Args) != 1 || schema.Args[0].Name != "token" || !schema.Args[0].Required || !schema.Args[0].Sensitive {
		t.Fatalf("translated init args = %+v", schema.Args)
	}
}

func TestNormalizeHandlerOps_RepairsLegacyTypeAndSingularMethod(t *testing.T) {
	items, err := normalizeHandlerOps([]json.RawMessage{
		[]byte(`{"type":"set_meta","name":"legacy_type_probe"}`),
		[]byte(`{"type":"set_code","code":"class Handler:\n    def __init__(self):\n        pass\n\n    def ping(self):\n        return {\"pong\": True}"}`),
		[]byte(`{"type":"set_init_args","config":{}}`),
		[]byte(`{"type":"set_method","method":"ping","description":"Returns pong","parameters":{},"outputs":{"type":"object","properties":{"pong":{"type":"boolean"}},"required":["pong"]}}`),
	})
	if err != nil {
		t.Fatalf("normalizeHandlerOps: %v", err)
	}
	var ops []string
	for _, raw := range items {
		var op struct {
			Op string `json:"op"`
		}
		if err := json.Unmarshal(raw, &op); err != nil {
			t.Fatalf("normalized op is invalid JSON: %v", err)
		}
		ops = append(ops, op.Op)
	}
	want := "set_meta,set_init,add_method,set_init_args_schema,update_method"
	if strings.Join(ops, ",") != want {
		t.Fatalf("normalized ops = %v, want %s", ops, want)
	}
	var update struct {
		Name  string `json:"name"`
		Patch struct {
			Description string           `json:"description"`
			Outputs     []map[string]any `json:"outputs"`
		} `json:"patch"`
	}
	if err := json.Unmarshal(items[len(items)-1], &update); err != nil {
		t.Fatalf("update op is invalid JSON: %v", err)
	}
	if update.Name != "ping" || update.Patch.Description != "Returns pong" || len(update.Patch.Outputs) != 1 {
		t.Fatalf("translated update = %+v", update)
	}
}

func TestNormalizeHandlerOps_RepairsLegacyDeclaredMethodMetadata(t *testing.T) {
	items, err := normalizeHandlerOps([]json.RawMessage{
		[]byte(`{"op":"set_meta","name":"legacy_declared_probe"}`),
		[]byte(`{"op":"set_code","runtime":"python3.12","code":"class Handler:\n    def __init__(self):\n        pass\n\n    def ping(self):\n        return {\"pong\": True}"}`),
		[]byte(`{"op":"declare_method","name":"ping","description":"Returns pong true"}`),
		[]byte(`{"op":"set_method_outputs","method":"ping","outputs":{"type":"object","properties":{"pong":{"type":"boolean"}},"required":["pong"]}}`),
	})
	if err != nil {
		t.Fatalf("normalizeHandlerOps: %v", err)
	}
	var ops []string
	for _, raw := range items {
		var op struct {
			Op string `json:"op"`
		}
		if err := json.Unmarshal(raw, &op); err != nil {
			t.Fatalf("normalized op is invalid JSON: %v", err)
		}
		ops = append(ops, op.Op)
	}
	want := "set_meta,set_python_version,set_init,add_method,update_method,update_method"
	if strings.Join(ops, ",") != want {
		t.Fatalf("normalized ops = %v, want %s", ops, want)
	}
	var update struct {
		Name  string `json:"name"`
		Patch struct {
			Outputs []map[string]any `json:"outputs"`
		} `json:"patch"`
	}
	if err := json.Unmarshal(items[len(items)-1], &update); err != nil {
		t.Fatalf("output update is invalid JSON: %v", err)
	}
	if update.Name != "ping" || len(update.Patch.Outputs) != 1 || update.Patch.Outputs[0]["name"] != "pong" {
		t.Fatalf("translated output update = %+v", update)
	}
}

func TestNormalizeHandlerOps_RepairsLegacyMethodArgsAndReturns(t *testing.T) {
	items, err := normalizeHandlerOps([]json.RawMessage{
		[]byte(`{"op":"set_code","pythonVersion":"3.12","code":"class Handler:\n    def __init__(self):\n        pass\n\n    async def ping(self):\n        return {\"pong\": True}"}`),
		[]byte(`{"op":"set_init_args","schema":[]}`),
		[]byte(`{"op":"set_method","method":"ping","description":"Returns a pong response","args":[],"returns":{"type":"object","properties":{"pong":{"const":true,"type":"boolean"}},"required":["pong"]},"yields":null}`),
	})
	if err != nil {
		t.Fatalf("normalizeHandlerOps: %v", err)
	}
	var ops []string
	for _, raw := range items {
		var op struct {
			Op string `json:"op"`
		}
		if err := json.Unmarshal(raw, &op); err != nil {
			t.Fatalf("normalized op is invalid JSON: %v", err)
		}
		ops = append(ops, op.Op)
	}
	want := "set_python_version,set_init,add_method,set_init_args_schema,update_method"
	if strings.Join(ops, ",") != want {
		t.Fatalf("normalized ops = %v, want %s", ops, want)
	}
	var update struct {
		Name  string `json:"name"`
		Patch struct {
			Description string           `json:"description"`
			Inputs      []map[string]any `json:"inputs"`
			Outputs     []map[string]any `json:"outputs"`
		} `json:"patch"`
	}
	if err := json.Unmarshal(items[len(items)-1], &update); err != nil {
		t.Fatalf("method update is invalid JSON: %v", err)
	}
	if update.Name != "ping" || update.Patch.Description != "Returns a pong response" || update.Patch.Inputs == nil || len(update.Patch.Outputs) != 1 {
		t.Fatalf("translated method update = %+v", update)
	}
}

func TestNormalizeHandlerOps_RepairsLegacyMethodListMetadataAndInitArgs(t *testing.T) {
	items, err := normalizeHandlerOps([]json.RawMessage{
		[]byte(`{"op":"set_meta","name":"legacy_list_probe"}`),
		[]byte(`{"op":"set_code","language":"python","runtimeVersion":"3.12","code":"class Handler:\n    def __init__(self):\n        pass\n\n    def ping(self):\n        return {\"pong\": True}"}`),
		[]byte(`{"op":"set_methods","methods":[{"name":"ping","description":"Returns a pong response","parameters":{"type":"object","properties":{},"required":[]},"returns":{"type":"object","properties":{"pong":{"type":"boolean"}},"required":["pong"]}}]}`),
		[]byte(`{"op":"set_init_args","initArgs":{"type":"object","properties":{},"required":[]}}`),
	})
	if err != nil {
		t.Fatalf("normalizeHandlerOps: %v", err)
	}
	var ops []string
	for _, raw := range items {
		var op struct {
			Op string `json:"op"`
		}
		if err := json.Unmarshal(raw, &op); err != nil {
			t.Fatalf("normalized op is invalid JSON: %v", err)
		}
		ops = append(ops, op.Op)
	}
	want := "set_meta,set_python_version,set_init,add_method,update_method,set_init_args_schema"
	if strings.Join(ops, ",") != want {
		t.Fatalf("normalized ops = %v, want %s", ops, want)
	}
	var update struct {
		Name  string `json:"name"`
		Patch struct {
			Description string           `json:"description"`
			Inputs      []map[string]any `json:"inputs"`
			Outputs     []map[string]any `json:"outputs"`
		} `json:"patch"`
	}
	if err := json.Unmarshal(items[4], &update); err != nil {
		t.Fatalf("method metadata update is invalid JSON: %v", err)
	}
	if update.Name != "ping" || update.Patch.Description != "Returns a pong response" || update.Patch.Inputs == nil || len(update.Patch.Outputs) != 1 {
		t.Fatalf("translated method metadata = %+v", update)
	}
}

func TestNormalizeHandlerOps_RejectsOpaqueLegacyClassCode(t *testing.T) {
	_, err := normalizeHandlerOps([]json.RawMessage{
		[]byte(`{"op":"set_code","code":"def ping(self):\n    return True"}`),
	})
	if err == nil || !strings.Contains(err.Error(), "needs a Python class") {
		t.Fatalf("opaque legacy code error = %v", err)
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
