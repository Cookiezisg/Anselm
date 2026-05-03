// task_test.go — unit tests for the 4 task system tools. Identity /
// schema / ValidateInput / Execute happy paths via a real Service backed
// by in-memory SQLite + nil bridge (events not exercised here; covered
// in app/task tests).
//
// task_test.go — 4 个 task 系统工具的单测。identity / schema /
// ValidateInput / Execute 走真 Service（内存 SQLite + nil bridge；事件
// 由 app/task 测覆盖）。
package task

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"

	"go.uber.org/zap"

	taskapp "github.com/sunweilin/forgify/backend/internal/app/task"
	taskdomain "github.com/sunweilin/forgify/backend/internal/domain/task"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	taskstore "github.com/sunweilin/forgify/backend/internal/infra/store/task"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

func newTestService(t *testing.T) *taskapp.Service {
	t.Helper()
	db, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	if err := dbinfra.Migrate(db, &taskdomain.Task{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return taskapp.NewService(taskstore.New(db), nil, zap.NewNop())
}

func ctxWithConv(id string) context.Context {
	return reqctxpkg.WithConversationID(context.Background(), id)
}

// ── TaskTools factory ─────────────────────────────────────────────────────────

func TestTaskTools_ReturnsFourTools(t *testing.T) {
	tools := TaskTools(newTestService(t))
	if len(tools) != 4 {
		t.Fatalf("len = %d, want 4", len(tools))
	}
	names := map[string]bool{}
	for _, tl := range tools {
		names[tl.Name()] = true
	}
	for _, want := range []string{"TaskCreate", "TaskList", "TaskGet", "TaskUpdate"} {
		if !names[want] {
			t.Errorf("missing tool %q (got: %v)", want, names)
		}
	}
}

// ── TaskCreate ────────────────────────────────────────────────────────────────

func TestTaskCreate_Identity(t *testing.T) {
	tool := &TaskCreate{svc: newTestService(t)}
	if tool.Name() != "TaskCreate" {
		t.Errorf("Name = %q", tool.Name())
	}
	if tool.IsReadOnly() {
		t.Error("TaskCreate should not be read-only")
	}
}

func TestTaskCreate_ValidateInput_RequiresSubject(t *testing.T) {
	tool := &TaskCreate{svc: newTestService(t)}
	if err := tool.ValidateInput(json.RawMessage(`{}`)); !errors.Is(err, taskdomain.ErrSubjectRequired) {
		t.Errorf("want ErrSubjectRequired, got %v", err)
	}
	if err := tool.ValidateInput(json.RawMessage(`{"subject":"  "}`)); !errors.Is(err, taskdomain.ErrSubjectRequired) {
		t.Errorf("whitespace subject should fail, got %v", err)
	}
}

func TestTaskCreate_Execute_PersistsAndReturnsJSON(t *testing.T) {
	svc := newTestService(t)
	tool := &TaskCreate{svc: svc}
	ctx := ctxWithConv("cv_x")
	out, err := tool.Execute(ctx, `{"subject":"Run tests","active_form":"Running tests"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	var got taskdomain.Task
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatalf("unmarshal (raw=%q): %v", out, err)
	}
	if got.Subject != "Run tests" || got.ID == "" {
		t.Errorf("got %+v", got)
	}
	// And it's actually persisted — ListByConversation must see it.
	// 实际落库——ListByConversation 必须看到。
	tasks, _ := svc.List(ctx)
	if len(tasks) != 1 {
		t.Errorf("expected 1 persisted task, got %d", len(tasks))
	}
}

// ── TaskList ─────────────────────────────────────────────────────────────────

func TestTaskList_Identity(t *testing.T) {
	tool := &TaskList{svc: newTestService(t)}
	if tool.Name() != "TaskList" {
		t.Errorf("Name = %q", tool.Name())
	}
	if !tool.IsReadOnly() {
		t.Error("TaskList should be read-only")
	}
}

func TestTaskList_Execute_ReturnsAllTasks(t *testing.T) {
	svc := newTestService(t)
	ctx := ctxWithConv("cv_x")
	for i, subj := range []string{"a", "b", "c"} {
		if _, err := svc.Create(ctx, taskapp.CreateInput{Subject: subj}); err != nil {
			t.Fatalf("seed %d: %v", i, err)
		}
	}
	out, err := (&TaskList{svc: svc}).Execute(ctx, `{}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	var resp struct {
		Total int               `json:"total"`
		Tasks []taskdomain.Task `json:"tasks"`
	}
	if err := json.Unmarshal([]byte(out), &resp); err != nil {
		t.Fatalf("unmarshal: %v\nraw=%q", err, out)
	}
	if resp.Total != 3 || len(resp.Tasks) != 3 {
		t.Errorf("total=%d tasks=%d, want 3 each", resp.Total, len(resp.Tasks))
	}
}

func TestTaskList_Execute_NoConvID_ReportsFriendly(t *testing.T) {
	tool := &TaskList{svc: newTestService(t)}
	out, err := tool.Execute(context.Background(), `{}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if !strings.Contains(out, "Task list failed") && !strings.Contains(out, "missing conversation") {
		t.Errorf("expected friendly missing-conv message, got: %q", out)
	}
}

// ── TaskGet ──────────────────────────────────────────────────────────────────

func TestTaskGet_ValidateInput_RequiresTaskID(t *testing.T) {
	tool := &TaskGet{svc: newTestService(t)}
	err := tool.ValidateInput(json.RawMessage(`{}`))
	if err == nil || !strings.Contains(err.Error(), "task_id") {
		t.Errorf("want task_id error, got %v", err)
	}
}

func TestTaskGet_Execute_RetrievesByID(t *testing.T) {
	svc := newTestService(t)
	ctx := ctxWithConv("cv_x")
	created, err := svc.Create(ctx, taskapp.CreateInput{Subject: "fetch me"})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	out, err := (&TaskGet{svc: svc}).Execute(ctx, `{"task_id":"`+created.ID+`"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if !strings.Contains(out, "fetch me") {
		t.Errorf("expected subject in result, got: %q", out)
	}
}

func TestTaskGet_Execute_UnknownID_FriendlyMessage(t *testing.T) {
	tool := &TaskGet{svc: newTestService(t)}
	out, err := tool.Execute(ctxWithConv("cv_x"), `{"task_id":"tk_doesnotexist"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if !strings.Contains(out, "not found") {
		t.Errorf("expected not-found message, got: %q", out)
	}
}

// ── TaskUpdate ────────────────────────────────────────────────────────────────

func TestTaskUpdate_ValidateInput_RequiresTaskID(t *testing.T) {
	tool := &TaskUpdate{svc: newTestService(t)}
	err := tool.ValidateInput(json.RawMessage(`{}`))
	if err == nil || !strings.Contains(err.Error(), "task_id") {
		t.Errorf("want task_id error, got %v", err)
	}
}

func TestTaskUpdate_ValidateInput_RejectsBadStatus(t *testing.T) {
	tool := &TaskUpdate{svc: newTestService(t)}
	err := tool.ValidateInput(json.RawMessage(`{"task_id":"tk_x","status":"bogus"}`))
	if !errors.Is(err, taskdomain.ErrInvalidStatus) {
		t.Errorf("want ErrInvalidStatus, got %v", err)
	}
}

func TestTaskUpdate_Execute_StatusToInProgressApplied(t *testing.T) {
	svc := newTestService(t)
	ctx := ctxWithConv("cv_x")
	created, err := svc.Create(ctx, taskapp.CreateInput{Subject: "x"})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	out, err := (&TaskUpdate{svc: svc}).Execute(ctx,
		`{"task_id":"`+created.ID+`","status":"in_progress"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	var got taskdomain.Task
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatalf("unmarshal: %v\nraw=%q", err, out)
	}
	if got.Status != taskdomain.StatusInProgress {
		t.Errorf("Status = %q, want in_progress", got.Status)
	}
}

func TestTaskUpdate_Execute_StatusDeletedRoutesToDelete(t *testing.T) {
	svc := newTestService(t)
	ctx := ctxWithConv("cv_x")
	created, err := svc.Create(ctx, taskapp.CreateInput{Subject: "x"})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	out, err := (&TaskUpdate{svc: svc}).Execute(ctx,
		`{"task_id":"`+created.ID+`","status":"deleted"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if !strings.Contains(out, `"deleted":true`) {
		t.Errorf("expected deletion confirmation, got: %q", out)
	}
	// After delete, the task should disappear from the list.
	// 删除后列表里应消失。
	tasks, _ := svc.List(ctx)
	if len(tasks) != 0 {
		t.Errorf("expected 0 tasks after delete, got %d", len(tasks))
	}
}

// ── classifyTaskErr ──────────────────────────────────────────────────────────

func TestClassifyTaskErr_KnownSentinels(t *testing.T) {
	cases := map[error]string{
		taskdomain.ErrNotFound:         "not found",
		taskdomain.ErrSubjectRequired:  "subject is required",
		taskdomain.ErrInvalidStatus:    "Invalid status",
	}
	for sentinel, fragment := range cases {
		got := classifyTaskErr(sentinel, "op")
		if !strings.Contains(got, fragment) {
			t.Errorf("classifyTaskErr(%v) = %q, want fragment %q", sentinel, got, fragment)
		}
	}
}

func TestClassifyTaskErr_UnknownErrFallsBack(t *testing.T) {
	got := classifyTaskErr(errors.New("strange"), "op")
	if !strings.Contains(got, "Task op failed") || !strings.Contains(got, "strange") {
		t.Errorf("unexpected: %q", got)
	}
}
