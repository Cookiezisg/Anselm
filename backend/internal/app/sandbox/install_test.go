package sandbox

import (
	"context"
	"errors"
	"os/exec"
	"sync"
	"testing"
	"time"

	sandboxdomain "github.com/sunweilin/anselm/backend/internal/domain/sandbox"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

type failingRuntimeInstaller struct {
	kind string
}

func (failingRuntimeInstaller) Install(context.Context, string, string, sandboxdomain.ProgressFunc) (string, error) {
	return "", errors.New("checksum mismatch")
}

func (f failingRuntimeInstaller) Kind() string { return f.kind }

func (failingRuntimeInstaller) Locate(string, string) (string, error) {
	return "", errors.New("not installed")
}

func (failingRuntimeInstaller) ResolveDefault(context.Context) (string, error) { return "1.0.0", nil }

func (failingRuntimeInstaller) NormalizeVersion(version string) string { return version }

func TestEnsureRuntimeInstallFailureCarriesRuntimeIdentity(t *testing.T) {
	svc := newSvc(t, "uv")
	svc.RegisterInstaller(failingRuntimeInstaller{kind: "uv"})

	_, err := svc.EnsureRuntime(context.Background(), sandboxdomain.RuntimeSpec{
		Kind:    "uv",
		Version: "0.11.4",
	}, nil)
	if err == nil {
		t.Fatal("EnsureRuntime should fail")
	}

	var structured *errorspkg.Error
	if !errors.As(err, &structured) {
		t.Fatalf("error = %v, want structured error", err)
	}
	if structured.Code != sandboxdomain.ErrRuntimeInstallFailed.Code {
		t.Fatalf("code = %q, want %q", structured.Code, sandboxdomain.ErrRuntimeInstallFailed.Code)
	}
	if got := structured.Details["kind"]; got != "uv" {
		t.Errorf("details.kind = %v, want uv", got)
	}
	if got := structured.Details["version"]; got != "0.11.4" {
		t.Errorf("details.version = %v, want 0.11.4", got)
	}
}

type sandboxEvent struct {
	method    string
	eventType string
	status    string
	workspace string
}

type recordingSandboxEmitter struct {
	mu     sync.Mutex
	events []sandboxEvent
}

func (r *recordingSandboxEmitter) Emit(ctx context.Context, eventType string, payload map[string]any) error {
	r.record("emit", ctx, eventType, payload)
	return nil
}

func (r *recordingSandboxEmitter) Broadcast(ctx context.Context, eventType string, payload map[string]any) error {
	r.record("broadcast", ctx, eventType, payload)
	return nil
}

func (r *recordingSandboxEmitter) record(method string, ctx context.Context, eventType string, payload map[string]any) {
	workspace, _ := reqctxpkg.GetWorkspaceID(ctx)
	status, _ := payload["status"].(string)
	r.mu.Lock()
	defer r.mu.Unlock()
	r.events = append(r.events, sandboxEvent{
		method:    method,
		eventType: eventType,
		status:    status,
		workspace: workspace,
	})
}

type cancellingEnvManager struct {
	started chan struct{}
	once    sync.Once
}

func (m *cancellingEnvManager) Kind() string { return "uv" }

func (m *cancellingEnvManager) CreateEnv(_ context.Context, _ string, _ string) error { return nil }

func (m *cancellingEnvManager) InstallDeps(ctx context.Context, _, _ string, _ []string, _ sandboxdomain.ProgressFunc) error {
	m.once.Do(func() { close(m.started) })
	<-ctx.Done()
	return ctx.Err()
}

func (m *cancellingEnvManager) ResolveExec(_, envPath string, opts sandboxdomain.SpawnOpts) (string, []string, string) {
	cmd := opts.Cmd
	if path, err := exec.LookPath(cmd); err == nil {
		cmd = path
	}
	return cmd, opts.Args, envPath
}

type failedEnvManager struct{}

func (failedEnvManager) Kind() string { return "uv" }

func (failedEnvManager) CreateEnv(_ context.Context, _ string, _ string) error { return nil }

func (failedEnvManager) InstallDeps(_ context.Context, _, _ string, _ []string, _ sandboxdomain.ProgressFunc) error {
	return errors.New("dependency install failed")
}

func (failedEnvManager) ResolveExec(_, envPath string, opts sandboxdomain.SpawnOpts) (string, []string, string) {
	return opts.Cmd, opts.Args, envPath
}

func TestEnsureEnv_CancelledInstallPersistsTerminalStateAndScopedNotification(t *testing.T) {
	svc := newSvc(t, "uv")
	emitter := &recordingSandboxEmitter{}
	svc.emitter = emitter
	manager := &cancellingEnvManager{started: make(chan struct{})}
	svc.RegisterEnvManager(manager)

	ctx, cancel := context.WithCancel(reqctxpkg.SetWorkspaceID(context.Background(), "ws_cancel"))
	owner := sandboxdomain.Owner{Kind: sandboxdomain.OwnerKindFunction, ID: "fn_cancel"}
	done := make(chan error, 1)
	go func() {
		_, err := svc.EnsureEnv(ctx, owner, sandboxdomain.EnvSpec{
			Runtime: sandboxdomain.RuntimeSpec{Kind: "uv", Version: "1.0"},
			Deps:    []string{"cancel-me"},
		}, nil)
		done <- err
	}()

	select {
	case <-manager.started:
	case <-time.After(2 * time.Second):
		t.Fatal("environment install did not start")
	}
	cancel()
	select {
	case err := <-done:
		if err == nil {
			t.Fatal("cancelled environment install should fail")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("cancelled environment install did not finish")
	}

	env, err := svc.repo.FindEnvByOwner(context.Background(), owner.Kind, owner.ID)
	if err != nil {
		t.Fatalf("find failed env: %v", err)
	}
	if env.Status != sandboxdomain.EnvStatusFailed {
		t.Fatalf("env status = %q, want failed", env.Status)
	}

	emitter.mu.Lock()
	defer emitter.mu.Unlock()
	var failed *sandboxEvent
	for i := range emitter.events {
		if emitter.events[i].status == sandboxdomain.EnvStatusFailed {
			failed = &emitter.events[i]
			break
		}
	}
	if failed == nil {
		t.Fatalf("events = %+v, want failed terminal event", emitter.events)
	}
	if failed.method != "emit" || failed.eventType != "sandbox.env_status_changed" {
		t.Fatalf("failed event = %+v, want inbox env status event", *failed)
	}
	if failed.workspace != "ws_cancel" {
		t.Fatalf("failed event workspace = %q, want ws_cancel", failed.workspace)
	}
}

func TestEnsureEnv_WithoutWorkspacePersistsButDoesNotEmit(t *testing.T) {
	svc := newSvc(t, "uv")
	emitter := &recordingSandboxEmitter{}
	svc.emitter = emitter
	svc.RegisterEnvManager(failedEnvManager{})
	owner := sandboxdomain.Owner{Kind: sandboxdomain.OwnerKindAttachment, ID: "attachment-extractor"}

	if _, err := svc.EnsureEnv(context.Background(), owner, sandboxdomain.EnvSpec{
		Runtime: sandboxdomain.RuntimeSpec{Kind: "uv", Version: "1.0"},
		Deps:    []string{"missing"},
	}, nil); err == nil {
		t.Fatal("failed environment install should return an error")
	}
	env, err := svc.repo.FindEnvByOwner(context.Background(), owner.Kind, owner.ID)
	if err != nil {
		t.Fatalf("find failed env: %v", err)
	}
	if env.Status != sandboxdomain.EnvStatusFailed {
		t.Fatalf("env status = %q, want failed", env.Status)
	}
	emitter.mu.Lock()
	defer emitter.mu.Unlock()
	if len(emitter.events) != 0 {
		t.Fatalf("events = %+v, want none without workspace", emitter.events)
	}
}
