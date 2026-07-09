package settings

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
)

// TestLoad_AbsentFileIsDefaults: first boot has no settings.json — pure defaults, no file created.
//
// TestLoad_AbsentFileIsDefaults：首启无 settings.json——纯默认、不建文件。
func TestLoad_AbsentFileIsDefaults(t *testing.T) {
	defer limitspkg.SetProvider(limitspkg.Default)
	dir := t.TempDir()
	s, err := Load(dir)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if s.Limits() != limitspkg.Default() {
		t.Fatalf("absent file must mean defaults: %+v", s.Limits())
	}
	if _, err := os.Stat(filepath.Join(dir, "settings.json")); !os.IsNotExist(err) {
		t.Fatal("Load must not create the file")
	}
}

// TestDataDir pins G11: DataDir() returns the resolved data directory (settings.json's
// parent), which GET /api/v1/system/data-dir surfaces read-only to the desktop UI.
//
// TestDataDir 锁 G11:DataDir() 返回解析后的数据目录（settings.json 的父目录）,即
// GET /api/v1/system/data-dir 只读透出给桌面 UI 的值。
func TestDataDir(t *testing.T) {
	defer limitspkg.SetProvider(limitspkg.Default)
	dir := t.TempDir()
	s, err := Load(dir)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if got := s.DataDir(); got != dir {
		t.Fatalf("DataDir() = %q, want %q", got, dir)
	}
}

// TestPatch_PersistsAndHotSwaps: a patch survives reload and limits.Current() sees it
// immediately (the hot-swap consumers rely on).
//
// TestPatch_PersistsAndHotSwaps：patch 经得起重载，limits.Current() 立即可见（消费方依赖的热换）。
func TestPatch_PersistsAndHotSwaps(t *testing.T) {
	defer limitspkg.SetProvider(limitspkg.Default)
	dir := t.TempDir()
	s, err := Load(dir)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	got, err := s.PatchLimits(json.RawMessage(`{"agent":{"maxSteps":40},"timeout":{"mcpCallSec":300}}`))
	if err != nil {
		t.Fatalf("PatchLimits: %v", err)
	}
	if got.Agent.MaxSteps != 40 || got.Timeout.MCPCallSec != 300 || got.Agent.InvokeMaxTurns != 10 {
		t.Fatalf("merge wrong: %+v", got)
	}
	if limitspkg.Current().Agent.MaxSteps != 40 {
		t.Fatal("hot-swap did not land in limits.Current()")
	}
	// reload from disk sees the same values
	s2, err := Load(dir)
	if err != nil {
		t.Fatalf("re-Load: %v", err)
	}
	if s2.Limits().Agent.MaxSteps != 40 || s2.Limits().Timeout.MCPCallSec != 300 {
		t.Fatalf("persisted values lost: %+v", s2.Limits())
	}
}

// TestLimits_AreMachineGlobal_NotWorkspaceScoped pins F162: limits are a single
// machine-level setting keyed only by dataDir — there is NO workspace dimension. The route
// sits behind RequireWorkspace, but the header is identity only; a value written "from one
// workspace" is the value every workspace reads. Two Service instances on the same dataDir
// (two workspace sessions on one machine) must observe each other's writes — if limits were
// per-workspace, B would still read the default.
//
// TestLimits_AreMachineGlobal_NotWorkspaceScoped 锁 F162：limits 是仅按 dataDir 索引的单一
// 机器级设置、无 workspace 维度。路由在 RequireWorkspace 后，但 header 仅作身份；任一 workspace
// 写的就是所有 workspace 读到的同一份。同一 dataDir 上两个 Service 实例（一台机器上两个 workspace
// 会话）必须互见对方的写——若 limits 是 per-workspace，B 仍会读到默认。
func TestLimits_AreMachineGlobal_NotWorkspaceScoped(t *testing.T) {
	defer limitspkg.SetProvider(limitspkg.Default)
	dir := t.TempDir()

	// "workspace A" session patches the global ceiling.
	sA, err := Load(dir)
	if err != nil {
		t.Fatalf("Load A: %v", err)
	}
	def := limitspkg.Default().Agent.MaxSteps
	if _, err := sA.PatchLimits(json.RawMessage(`{"agent":{"maxSteps":42}}`)); err != nil {
		t.Fatalf("PatchLimits A: %v", err)
	}
	if def == 42 {
		t.Fatal("test vacuous: pick a maxSteps that differs from the default")
	}

	// "workspace B" session — a fresh load of the SAME dataDir — must see A's write (42),
	// not the default. Global, not workspace-isolated.
	sB, err := Load(dir)
	if err != nil {
		t.Fatalf("Load B: %v", err)
	}
	if got := sB.Limits().Agent.MaxSteps; got != 42 {
		t.Fatalf("limits not machine-global: workspace-B session read maxSteps=%d, want 42 (A's write)", got)
	}
}

// TestReset_RestoresDefaults pins G6: ResetLimits brings every field back to Default(),
// hot-swaps it live, and persists it (a fresh Load then sees defaults).
//
// TestReset_RestoresDefaults 锁 G6:ResetLimits 把每个字段拉回 Default()、热换生效、并持久化
// （重载即见默认）。
func TestReset_RestoresDefaults(t *testing.T) {
	defer limitspkg.SetProvider(limitspkg.Default)
	dir := t.TempDir()
	s, err := Load(dir)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if _, err := s.PatchLimits(json.RawMessage(`{"agent":{"maxSteps":40}}`)); err != nil {
		t.Fatalf("PatchLimits: %v", err)
	}
	if s.Limits() == limitspkg.Default() {
		t.Fatal("patch left limits at default; choose a real non-default field")
	}
	out, err := s.ResetLimits()
	if err != nil {
		t.Fatalf("ResetLimits: %v", err)
	}
	if out != limitspkg.Default() || s.Limits() != limitspkg.Default() || limitspkg.Current() != limitspkg.Default() {
		t.Fatalf("reset did not restore defaults: %+v", s.Limits())
	}
	s2, err := Load(dir)
	if err != nil {
		t.Fatalf("re-Load: %v", err)
	}
	if s2.Limits() != limitspkg.Default() {
		t.Fatalf("reset not persisted: %+v", s2.Limits())
	}
}

// TestPatch_RejectsOutOfRange: negative ceilings and out-of-(0,1) ratio reject without
// touching the live values or the file.
//
// TestPatch_RejectsOutOfRange：负上限与 (0,1) 外 ratio 被拒，活动值与文件不动。
func TestPatch_RejectsOutOfRange(t *testing.T) {
	defer limitspkg.SetProvider(limitspkg.Default)
	dir := t.TempDir()
	s, _ := Load(dir)
	for _, patch := range []string{
		`{"agent":{"maxSteps":-1}}`,
		`{"context":{"triggerRatio":1.5}}`,
		`{"agent":{"maxSteps":`, // malformed JSON
		// Explicit 0 on a positive-minimum field must be REJECTED, not silently snapped back to the
		// default — the present-zero-vs-absent bug (WithDefaults previously refilled it before validate).
		`{"timeout":{"functionRunSec":0}}`,
		`{"agent":{"maxSteps":0}}`,
		`{"context":{"triggerRatio":0}}`,
	} {
		if _, err := s.PatchLimits(json.RawMessage(patch)); !errors.Is(err, ErrLimitsInvalid) {
			t.Fatalf("patch %q: want ErrLimitsInvalid, got %v", patch, err)
		}
	}
	if limitspkg.Current() != limitspkg.Default() {
		t.Fatal("rejected patch leaked into live values")
	}
}

// TestLoad_MalformedFileFails: a hand-edited broken file must fail boot loudly, not be
// silently ignored.
//
// TestLoad_MalformedFileFails：手编坏文件必须把 boot 喊停，不得静默忽略。
func TestLoad_MalformedFileFails(t *testing.T) {
	defer limitspkg.SetProvider(limitspkg.Default)
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "settings.json"), []byte("{not json"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Load(dir); err == nil || !strings.Contains(err.Error(), "parse") {
		t.Fatalf("want parse error, got %v", err)
	}
}

// TestPatchNetwork: persist + reload round-trips the proxy config, applies the proxy env, and a
// limits patch never drops the network block (both share fileShape). TestPatchNetwork:代理配置
// 持久化+重载往返、应用代理 env,且 limits patch 绝不丢网络段(共用 fileShape)。
func TestPatchNetwork(t *testing.T) {
	defer limitspkg.SetProvider(limitspkg.Default)
	t.Setenv("HTTP_PROXY", "")
	dir := t.TempDir()
	s, err := Load(dir)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if _, err := s.PatchNetwork(Network{HTTPProxy: "http://127.0.0.1:7890", NoProxy: "localhost"}); err != nil {
		t.Fatalf("PatchNetwork: %v", err)
	}
	if os.Getenv("HTTP_PROXY") != "http://127.0.0.1:7890" {
		t.Errorf("proxy env not applied: %q", os.Getenv("HTTP_PROXY"))
	}

	// A limits patch must not wipe the network block. limits patch 不得抹掉网络段。
	if _, err := s.PatchLimits(json.RawMessage(`{"agent":{"maxSteps":42}}`)); err != nil {
		t.Fatalf("PatchLimits: %v", err)
	}
	s2, err := Load(dir)
	if err != nil {
		t.Fatalf("re-Load: %v", err)
	}
	if s2.Net().HTTPProxy != "http://127.0.0.1:7890" {
		t.Errorf("network block lost after a limits patch: %+v", s2.Net())
	}
	if s2.Limits().Agent.MaxSteps != 42 {
		t.Errorf("limits lost: %+v", s2.Limits())
	}

	// Clearing the proxy unsets the env. 清空即 unset。
	if _, err := s2.PatchNetwork(Network{}); err != nil {
		t.Fatalf("clear: %v", err)
	}
	if os.Getenv("HTTP_PROXY") != "" {
		t.Errorf("proxy env not cleared: %q", os.Getenv("HTTP_PROXY"))
	}
}
