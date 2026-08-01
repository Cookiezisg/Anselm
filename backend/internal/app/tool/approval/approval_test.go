package approval

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"reflect"
	"strings"
	"testing"

	_ "github.com/glebarez/go-sqlite"
	"go.uber.org/zap"

	approvalapp "github.com/sunweilin/anselm/backend/internal/app/approval"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	approvaldomain "github.com/sunweilin/anselm/backend/internal/domain/approval"
	approvalstore "github.com/sunweilin/anselm/backend/internal/infra/store/approval"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
	schemapkg "github.com/sunweilin/anselm/backend/internal/pkg/schema"
)

func newToolSvc(t *testing.T) (*approvalapp.Service, context.Context) {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range approvalstore.Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	svc := approvalapp.NewService(approvalstore.New(ormpkg.Open(sqlDB)), nil, zap.NewNop())
	return svc, reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
}

func TestApprovalTools_Wiring(t *testing.T) {
	tools := ApprovalTools(nil, nil, nil) // nil svc OK: we only inspect Name() here
	want := map[string]bool{
		"search_approval": false, "get_approval": false, "create_approval": false,
		"edit_approval": false, "revert_approval": false, "delete_approval": false,
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

func TestApprovalTools_ValidateInput(t *testing.T) {
	cases := []struct {
		name    string
		tool    toolapp.Tool
		args    string
		wantErr bool
	}{
		{"create no name", &CreateApproval{}, `{"template":"ok?"}`, true},
		{"create no template", &CreateApproval{}, `{"name":"x"}`, true},
		{"create ok", &CreateApproval{}, `{"name":"x","template":"ok?"}`, false},
		{"edit no id", &EditApproval{}, `{"template":"ok?"}`, true},
		{"edit no template", &EditApproval{}, `{"approvalId":"apf_1"}`, true},
		{"edit ok", &EditApproval{}, `{"approvalId":"apf_1","inputs":[],"template":"ok?","allowReason":false,"timeout":"","timeoutBehavior":"","changeReason":"test"}`, false},
		{"revert no id", &RevertApproval{}, `{"version":1}`, true},
		{"revert bad version", &RevertApproval{}, `{"approvalId":"apf_1","version":0}`, true},
		{"revert stringified version", &RevertApproval{}, `{"approvalId":"apf_1","version":"2"}`, false},
		{"revert malformed stringified version", &RevertApproval{}, `{"approvalId":"apf_1","version":"2.0"}`, true},
		{"revert ok", &RevertApproval{}, `{"approvalId":"apf_1","version":2}`, false},
		{"get no id", &GetApproval{}, `{}`, true},
		{"delete no id", &DeleteApproval{}, `{}`, true},
		{"search any", &SearchApproval{}, `{}`, false},
	}
	for _, c := range cases {
		err := c.tool.ValidateInput([]byte(c.args))
		if (err != nil) != c.wantErr {
			t.Errorf("%s: ValidateInput(%s) err=%v, wantErr=%v", c.name, c.args, err, c.wantErr)
		}
	}
}

func TestApprovalTools_RoundTrip(t *testing.T) {
	svc, ctx := newToolSvc(t)

	out, err := (&CreateApproval{svc: svc}).Execute(ctx,
		`{"name":"email","template":"发送给 {{ input.to }}?","allowReason":true,"timeout":"30d","timeoutBehavior":"reject"}`)
	if err != nil {
		t.Fatalf("create execute: %v", err)
	}
	id := extractID(t, out)

	if _, err := (&GetApproval{svc: svc}).Execute(ctx, `{"approvalId":"`+id+`"}`); err != nil {
		t.Fatalf("get execute: %v", err)
	}
	if _, err := (&EditApproval{svc: svc}).Execute(ctx, `{"approvalId":"`+id+`","inputs":[{"name":"x","type":"string","description":"X"}],"template":"改 {{ input.x }}?","allowReason":false,"timeout":"","timeoutBehavior":"","changeReason":"round trip"}`); err != nil {
		t.Fatalf("edit execute: %v", err)
	}
	if _, err := (&RevertApproval{svc: svc}).Execute(ctx, `{"approvalId":"`+id+`","version":1}`); err != nil {
		t.Fatalf("revert execute: %v", err)
	}
	if _, err := (&RevertApproval{svc: svc}).Execute(ctx, `{"approvalId":"`+id+`","version":"1"}`); err != nil {
		t.Fatalf("stringified revert execute: %v", err)
	}
	sout, err := (&SearchApproval{svc: svc}).Execute(ctx, `{"query":"email"}`)
	if err != nil || !strings.Contains(sout, "email") {
		t.Fatalf("search execute: %v out=%s", err, sout)
	}
	if _, err := (&DeleteApproval{svc: svc}).Execute(ctx, `{"approvalId":"`+id+`"}`); err != nil {
		t.Fatalf("delete execute: %v", err)
	}
	if _, err := svc.Get(ctx, id); err == nil {
		t.Fatal("deleted approval must disappear from normal reads")
	}
	versions, _, err := svc.ListVersions(ctx, id, approvaldomain.VersionListFilter{})
	if err != nil {
		t.Fatalf("list retained versions: %v", err)
	}
	if len(versions) != 2 {
		t.Fatalf("soft delete must retain immutable version history, got %d versions", len(versions))
	}
}

func TestDeleteApproval_DescriptionPinsSoftDeleteAndDangerGate(t *testing.T) {
	desc := (&DeleteApproval{}).Description()
	for _, want := range []string{
		"Soft-delete",
		`danger="dangerous"`,
		"wait for the user's approval",
		"version history is retained",
		"does NOT hard-delete the versions",
		"get_relations",
	} {
		if !strings.Contains(desc, want) {
			t.Fatalf("delete description missing %q: %s", want, desc)
		}
	}
	var schema struct {
		Required []string `json:"required"`
	}
	if err := json.Unmarshal((&DeleteApproval{}).Parameters(), &schema); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(schema.Required, []string{"approvalId"}) {
		t.Fatalf("required = %#v, want approvalId only", schema.Required)
	}
}

func TestRevertApproval_DescriptionPinsVersionEncoding(t *testing.T) {
	desc := (&RevertApproval{}).Description()
	for _, want := range []string{"exact decimal integer string is also accepted", "floats, booleans, arrays, and malformed strings are rejected"} {
		if !strings.Contains(desc, want) {
			t.Fatalf("revert description missing %q: %s", want, desc)
		}
	}
}

func TestCreateApproval_InvalidTemplate(t *testing.T) {
	svc, ctx := newToolSvc(t)
	_, err := (&CreateApproval{svc: svc}).Execute(ctx, `{"name":"bad","template":"bad {{ input.( }}"}`)
	if !errors.Is(err, approvaldomain.ErrInvalidTemplate) {
		t.Fatalf("want ErrInvalidTemplate bubbled (framework softens at loop layer), got %v", err)
	}
}

func TestApprovalHostedModelShapeDecoders(t *testing.T) {
	inputs, err := decodeApprovalInputs(json.RawMessage(`"{\"urgent\":{\"type\":\"boolean\",\"description\":\"Urgent payment\"},\"amount\":{\"type\":\"number\",\"description\":\"Amount\"}}"`))
	if err != nil {
		t.Fatalf("decode hosted inputs: %v", err)
	}
	wantInputs := []struct {
		Name, Type, Description string
	}{
		{Name: "amount", Type: "number", Description: "Amount"},
		{Name: "urgent", Type: "boolean", Description: "Urgent payment"},
	}
	for i, want := range wantInputs {
		got := inputs[i]
		if got.Name != want.Name || got.Type != want.Type || got.Description != want.Description {
			t.Fatalf("input[%d] = %+v, want %+v", i, got, want)
		}
	}

	for _, raw := range []string{`true`, `"true"`, `false`, `"false"`} {
		if _, err := decodeApprovalBool(json.RawMessage(raw)); err != nil {
			t.Errorf("decode bool %s: %v", raw, err)
		}
	}
	for _, raw := range []string{`1`, `"yes"`, `[]`} {
		if _, err := decodeApprovalBool(json.RawMessage(raw)); err == nil {
			t.Errorf("decode bool %s unexpectedly succeeded", raw)
		}
	}
}

func TestCreateApproval_HostedModelStringifiedArgs(t *testing.T) {
	svc, ctx := newToolSvc(t)
	args := `{"name":"hosted","template":"Approve {{ input.amount }}?","inputs":"{\"amount\":{\"type\":\"number\",\"description\":\"Amount\"}}","allowReason":"true","timeout":"2h","timeoutBehavior":"reject"}`
	tool := &CreateApproval{svc: svc}
	if err := tool.ValidateInput([]byte(args)); err != nil {
		t.Fatalf("validate hosted args: %v", err)
	}
	out, err := tool.Execute(ctx, args)
	if err != nil {
		t.Fatalf("execute hosted args: %v", err)
	}
	id := extractID(t, out)
	form, err := svc.Get(ctx, id)
	if err != nil {
		t.Fatalf("get hosted form: %v", err)
	}
	if form.ActiveVersion == nil || !form.ActiveVersion.AllowReason {
		t.Fatalf("active version = %+v, want allowReason=true", form.ActiveVersion)
	}
	want := []schemapkg.Field{{Name: "amount", Type: "number", Description: "Amount"}}
	if !reflect.DeepEqual(form.ActiveVersion.Inputs, want) {
		t.Fatalf("inputs = %+v, want %+v", form.ActiveVersion.Inputs, want)
	}
}

func TestEditApproval_RequiresCompleteReplacement(t *testing.T) {
	tool := &EditApproval{}
	for _, tc := range []struct {
		name string
		args string
	}{
		{name: "missing inputs", args: `{"approvalId":"apf_1","template":"new","allowReason":true,"timeout":"2h","timeoutBehavior":"approve"}`},
		{name: "missing rules", args: `{"approvalId":"apf_1","inputs":[],"template":"new"}`},
		{name: "null inputs", args: `{"approvalId":"apf_1","inputs":null,"template":"new","allowReason":true,"timeout":"2h","timeoutBehavior":"approve"}`},
		{name: "missing change reason", args: `{"approvalId":"apf_1","inputs":[],"template":"new","allowReason":true,"timeout":"2h","timeoutBehavior":"approve"}`},
		{name: "empty change reason", args: `{"approvalId":"apf_1","inputs":[],"template":"new","allowReason":true,"timeout":"2h","timeoutBehavior":"approve","changeReason":"  "}`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if err := tool.ValidateInput([]byte(tc.args)); err == nil {
				t.Fatal("ValidateInput unexpectedly accepted incomplete replacement")
			}
		})
	}
}

func TestEditApproval_ParametersRequireCompleteReplacement(t *testing.T) {
	var schema struct {
		Required []string `json:"required"`
	}
	if err := json.Unmarshal((&EditApproval{}).Parameters(), &schema); err != nil {
		t.Fatalf("decode parameters: %v", err)
	}
	want := []string{"approvalId", "inputs", "template", "allowReason", "timeout", "timeoutBehavior", "changeReason"}
	if !reflect.DeepEqual(schema.Required, want) {
		t.Fatalf("required = %#v, want %#v", schema.Required, want)
	}
}

func extractID(t *testing.T, jsonStr string) string {
	t.Helper()
	var m map[string]any
	if err := json.Unmarshal([]byte(jsonStr), &m); err != nil {
		t.Fatalf("unmarshal create out: %v", err)
	}
	id, _ := m["id"].(string)
	if id == "" {
		t.Fatalf("no id in create out: %s", jsonStr)
	}
	return id
}
