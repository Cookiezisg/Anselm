package sandbox

import (
	"context"
	"errors"
	"testing"

	sandboxdomain "github.com/sunweilin/anselm/backend/internal/domain/sandbox"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
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
