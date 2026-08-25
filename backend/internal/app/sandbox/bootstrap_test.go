package sandbox

import (
	"context"
	"os"
	"testing"
)

// TestBootstrap_DegradedThenRetry makes the sandbox root itself unusable, rather than merely
// injecting a returned error. Bootstrap must enter degraded mode without claiming readiness, and
// RetryBootstrap must recover once the filesystem obstruction is removed.
//
// TestBootstrap_DegradedThenRetry 让 sandbox 根目录真实变成不可用文件，而不是注入一个返回错误。
// Bootstrap 必须进入 degraded 且不宣称 ready；移除文件障碍后 RetryBootstrap 必须恢复。
func TestBootstrap_DegradedThenRetry(t *testing.T) {
	svc := newSvc(t, "uv")
	root := svc.SandboxRoot()
	if err := os.RemoveAll(root); err != nil {
		t.Fatalf("remove sandbox root: %v", err)
	}
	if err := os.WriteFile(root, []byte("not a directory"), 0o600); err != nil {
		t.Fatalf("plant filesystem obstruction: %v", err)
	}

	if err := svc.Bootstrap(context.Background()); err == nil {
		t.Fatal("bootstrap must fail when sandbox root is a regular file")
	}
	if svc.IsReady() {
		t.Fatal("failed bootstrap must leave sandbox degraded, not ready")
	}
	if svc.BootstrapError() == nil {
		t.Fatal("failed bootstrap must retain the degraded error")
	}

	if err := os.Remove(root); err != nil {
		t.Fatalf("remove filesystem obstruction: %v", err)
	}
	if err := svc.RetryBootstrap(context.Background()); err != nil {
		t.Fatalf("retry bootstrap: %v", err)
	}
	if !svc.IsReady() || svc.BootstrapError() != nil {
		t.Fatalf("retry must restore ready state and clear the error: ready=%v err=%v", svc.IsReady(), svc.BootstrapError())
	}
	if info, err := os.Stat(root); err != nil || !info.IsDir() {
		t.Fatalf("retry must restore sandbox root directory: info=%v err=%v", info, err)
	}
}
