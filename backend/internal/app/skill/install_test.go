package skill

import (
	"context"
	"errors"
	"strings"
	"testing"

	skilldomain "github.com/sunweilin/anselm/backend/internal/domain/skill"
	skillfetch "github.com/sunweilin/anselm/backend/internal/infra/skillfetch"
	agentstatepkg "github.com/sunweilin/anselm/backend/internal/pkg/agentstate"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// B4 安装通道（WRK-076）：inspect 预览面 / install 落盘+sidecar+source 推导 / 信任门
//（未授权不装预授权、授权后装、update 改 allowed-tools 重置）/ update 漂移拒。

func fakeCands(cands ...skillfetch.Candidate) fetchFunc {
	return func(_ context.Context, _ skillfetch.Source) ([]skillfetch.Candidate, error) {
		return cands, nil
	}
}

func installTestSetup(t *testing.T) (*Service, context.Context) {
	t.Helper()
	svc := newService(t, nil)
	svc.SetFetcher(fakeCands(skillfetch.Candidate{
		Name: "pdf",
		Files: map[string][]byte{
			"SKILL.md":     []byte("---\nname: pdf\ndescription: handles pdfs\nallowed-tools:\n  - run_function\n---\nDo pdf things.\n"),
			"scripts/x.py": []byte("print()"),
		},
	}))
	return svc, ctxWS("ws_1")
}

func TestInspectSource_PreviewShape(t *testing.T) {
	svc, ctx := installTestSetup(t)
	previews, err := svc.InspectSource(ctx, "owner/repo")
	if err != nil {
		t.Fatalf("inspect: %v", err)
	}
	p := previews[0]
	if !p.Installable || p.Name != "pdf" || p.Description != "handles pdfs" ||
		len(p.AllowedTools) != 1 || p.AllowedTools[0] != "run_function" || p.FileCount != 2 {
		t.Fatalf("preview shape: %+v", p)
	}
	if p.AlreadyExists {
		t.Fatal("fresh name must not be alreadyExists")
	}
}

func TestInstall_LandsWithProvenanceAndDerivedSource(t *testing.T) {
	svc, ctx := installTestSetup(t)
	res, err := svc.Install(ctx, "owner/repo", nil, false)
	if err != nil || len(res.Installed) != 1 || res.Installed[0] != "pdf" {
		t.Fatalf("install: %+v err=%v", res, err)
	}
	sk, err := svc.Get(ctx, "pdf")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	// source=installed 由 sidecar 推导，frontmatter 未被改写。
	if sk.Source != skilldomain.SourceInstalled {
		t.Fatalf("source must derive to installed, got %q", sk.Source)
	}
	raw, err := svc.ReadFile(ctx, "pdf", "SKILL.md")
	if err != nil || strings.Contains(string(raw), "installed") {
		t.Fatalf("frontmatter must stay pristine (no installed marker written): %s err=%v", raw, err)
	}
	// 二次安装非 force → skip；force → 覆盖。
	res, _ = svc.Install(ctx, "owner/repo", nil, false)
	if len(res.Installed) != 0 || !strings.Contains(res.Skipped["pdf"], "already exists") {
		t.Fatalf("reinstall without force must skip: %+v", res)
	}
	res, err = svc.Install(ctx, "owner/repo", nil, true)
	if err != nil || len(res.Installed) != 1 {
		t.Fatalf("force reinstall: %+v err=%v", res, err)
	}
}

func TestTrustGate_WithholdsUntilApproved(t *testing.T) {
	svc, ctx := installTestSetup(t)
	if _, err := svc.Install(ctx, "owner/repo", nil, false); err != nil {
		t.Fatalf("install: %v", err)
	}
	state := agentstatepkg.New()
	actCtx := reqctxpkg.WithAgentState(ctx, state)

	// 未授权：激活注入正文，但预授权不装。
	out, err := svc.Activate(actCtx, "pdf", nil)
	if err != nil || !strings.Contains(out, "Do pdf things") {
		t.Fatalf("activate must inject body: %q err=%v", out, err)
	}
	if state.ActiveSkill() != "pdf" {
		t.Fatalf("active skill must still be recorded, got %q", state.ActiveSkill())
	}
	if state.IsToolPreApprovedBySkill("run_function") {
		t.Fatal("trust gate must withhold pre-approval before user approval")
	}

	// 授权后：预授权生效。
	if _, err := svc.ApproveTools(ctx, "pdf"); err != nil {
		t.Fatalf("approve: %v", err)
	}
	if _, err := svc.Activate(actCtx, "pdf", nil); err != nil {
		t.Fatalf("re-activate: %v", err)
	}
	if !state.IsToolPreApprovedBySkill("run_function") {
		t.Fatal("approved installed skill must pre-approve its tools")
	}
}

func TestApproveTools_RefusedForLocalSkills(t *testing.T) {
	svc, ctx := installTestSetup(t)
	if _, err := svc.Create(ctx, SaveInput{Name: "local-one", Description: "d", Body: "b"}); err != nil {
		t.Fatalf("create: %v", err)
	}
	if _, err := svc.ApproveTools(ctx, "local-one"); !errors.Is(err, skilldomain.ErrNotInstalled) {
		t.Fatalf("approve on non-installed should be NotInstalled, got %v", err)
	}
}

func TestUpdateInstalled_DriftRefusalAndToolChangeResetsGate(t *testing.T) {
	svc, ctx := installTestSetup(t)
	if _, err := svc.Install(ctx, "owner/repo", nil, false); err != nil {
		t.Fatalf("install: %v", err)
	}
	if _, err := svc.ApproveTools(ctx, "pdf"); err != nil {
		t.Fatalf("approve: %v", err)
	}

	// 本地改动 → 非 force 拒、details 列漂移文件。
	if err := svc.WriteFile(ctx, "pdf", "scripts/x.py", []byte("print('edited')")); err != nil {
		t.Fatalf("edit: %v", err)
	}
	if _, err := svc.UpdateInstalled(ctx, "pdf", false); !errors.Is(err, skilldomain.ErrLocallyModified) {
		t.Fatalf("drift must refuse without force, got %v", err)
	}

	// 上游 allowed-tools 变了 + force 更新 → 信任门重置。
	svc.SetFetcher(fakeCands(skillfetch.Candidate{
		Name: "pdf",
		Files: map[string][]byte{
			"SKILL.md":     []byte("---\nname: pdf\ndescription: v2\nallowed-tools:\n  - bash\n---\nNew.\n"),
			"scripts/x.py": []byte("print('v2')"),
		},
	}))
	sk, err := svc.UpdateInstalled(ctx, "pdf", true)
	if err != nil || sk.Description != "v2" {
		t.Fatalf("force update: %+v err=%v", sk, err)
	}
	state := agentstatepkg.New()
	if _, err := svc.Activate(reqctxpkg.WithAgentState(ctx, state), "pdf", nil); err != nil {
		t.Fatalf("activate: %v", err)
	}
	if state.IsToolPreApprovedBySkill("bash") {
		t.Fatal("changed allowed-tools must RESET the trust gate")
	}

	// update 一个非安装 skill → NotInstalled。
	if _, err := svc.Create(ctx, SaveInput{Name: "hand-made", Description: "d", Body: "b"}); err != nil {
		t.Fatalf("create: %v", err)
	}
	if _, err := svc.UpdateInstalled(ctx, "hand-made", false); !errors.Is(err, skilldomain.ErrNotInstalled) {
		t.Fatalf("update non-installed should be NotInstalled, got %v", err)
	}
}

func TestUpdateInstalled_UnchangedToolsKeepApproval(t *testing.T) {
	svc, ctx := installTestSetup(t)
	if _, err := svc.Install(ctx, "owner/repo", nil, false); err != nil {
		t.Fatalf("install: %v", err)
	}
	if _, err := svc.ApproveTools(ctx, "pdf"); err != nil {
		t.Fatalf("approve: %v", err)
	}
	// 上游只改正文、allowed-tools 未变 → 授权延续。
	svc.SetFetcher(fakeCands(skillfetch.Candidate{
		Name: "pdf",
		Files: map[string][]byte{
			"SKILL.md":     []byte("---\nname: pdf\ndescription: v2\nallowed-tools:\n  - run_function\n---\nNew body.\n"),
			"scripts/x.py": []byte("print()"),
		},
	}))
	if _, err := svc.UpdateInstalled(ctx, "pdf", false); err != nil {
		t.Fatalf("update: %v", err)
	}
	state := agentstatepkg.New()
	if _, err := svc.Activate(reqctxpkg.WithAgentState(ctx, state), "pdf", nil); err != nil {
		t.Fatalf("activate: %v", err)
	}
	if !state.IsToolPreApprovedBySkill("run_function") {
		t.Fatal("unchanged allowed-tools must keep the user's approval across update")
	}
}

func TestInstall_SidecarHiddenFromFilesSurface(t *testing.T) {
	svc, ctx := installTestSetup(t)
	if _, err := svc.Install(ctx, "owner/repo", nil, false); err != nil {
		t.Fatalf("install: %v", err)
	}
	// sidecar 绝不出现在文件列表。
	files, err := svc.ListFiles(ctx, "pdf")
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	for _, f := range files {
		if f.Path == skilldomain.InstallSidecarName {
			t.Fatalf("provenance sidecar must be hidden from ListFiles, got %+v", files)
		}
	}
	// 也不可经 files 面读/写/删。
	if _, err := svc.ReadFile(ctx, "pdf", skilldomain.InstallSidecarName); !errors.Is(err, skilldomain.ErrFileNotFound) {
		t.Fatalf("sidecar read must be FileNotFound, got %v", err)
	}
	if err := svc.WriteFile(ctx, "pdf", skilldomain.InstallSidecarName, []byte("{}")); !errors.Is(err, skilldomain.ErrFilePathInvalid) {
		t.Fatalf("sidecar write must be refused, got %v", err)
	}
	if err := svc.DeleteFile(ctx, "pdf", skilldomain.InstallSidecarName); !errors.Is(err, skilldomain.ErrFilePathInvalid) {
		t.Fatalf("sidecar delete must be refused, got %v", err)
	}
}
