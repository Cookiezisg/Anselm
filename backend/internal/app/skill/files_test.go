package skill

import (
	"errors"
	"strings"
	"testing"

	"go.uber.org/zap"

	skilldomain "github.com/sunweilin/anselm/backend/internal/domain/skill"
	skillfs "github.com/sunweilin/anselm/backend/internal/infra/fs/skill"
)

// B1 files 面（WRK-076）：ReplaceRaw 语义 / 清单路由与拒删 / IsSpecName 创建从严 / 透传链。

func TestReplaceRaw_MissingSkillIsNotFound(t *testing.T) {
	svc := newService(t, nil)
	if _, err := svc.ReplaceRaw(ctxWS("ws_1"), "ghost", []byte("---\nname: ghost\ndescription: d\n---\nb\n")); !errors.Is(err, skilldomain.ErrNotFound) {
		t.Fatalf("raw replace on missing skill should be NotFound (creation is POST/install), got %v", err)
	}
}

func TestReplaceRaw_NameMismatchRejected(t *testing.T) {
	svc := newService(t, nil)
	ctx := ctxWS("ws_1")
	if _, err := svc.Create(ctx, SaveInput{Name: "alpha", Description: "d", Body: "b"}); err != nil {
		t.Fatalf("create: %v", err)
	}
	_, err := svc.ReplaceRaw(ctx, "alpha", []byte("---\nname: beta\ndescription: d\n---\nb\n"))
	if !errors.Is(err, skilldomain.ErrInvalidFrontmatter) {
		t.Fatalf("frontmatter name != directory should be InvalidFrontmatter, got %v", err)
	}
}

func TestReplaceRaw_UpdatesAndResyncsEquipEdges(t *testing.T) {
	svc := newService(t, nil)
	syncer := &fakeSyncer{}
	svc.SetRelationSyncer(syncer)
	ctx := ctxWS("ws_1")
	if _, err := svc.Create(ctx, SaveInput{Name: "alpha", Description: "d", Body: "b"}); err != nil {
		t.Fatalf("create: %v", err)
	}
	raw := "---\nname: alpha\ndescription: new one\nallowed-tools:\n  - fn_new\nlicense: MIT\n---\nNew body.\n"
	sk, err := svc.ReplaceRaw(ctx, "alpha", []byte(raw))
	if err != nil {
		t.Fatalf("replace raw: %v", err)
	}
	if sk.Description != "new one" || sk.Body != "New body." || sk.Frontmatter.License != "MIT" {
		t.Fatalf("raw replace not reflected: %+v", sk)
	}
	// allowed-tools 变了 → equip 出边重同步（fn_ 前缀建边）。
	if len(syncer.outEdges) != 1 || syncer.outEdges[0].OtherID != "fn_new" {
		t.Fatalf("equip edges must resync after raw replace: %+v", syncer.outEdges)
	}
}

func TestWriteFile_ManifestRoutesThroughValidation(t *testing.T) {
	svc := newService(t, nil)
	ctx := ctxWS("ws_1")
	if _, err := svc.Create(ctx, SaveInput{Name: "alpha", Description: "d", Body: "b"}); err != nil {
		t.Fatalf("create: %v", err)
	}
	// 清单路径路由到 ReplaceRaw：坏围栏必须被校验拒绝，而不是当普通文件落盘。
	if err := svc.WriteFile(ctx, "alpha", "./SKILL.md", []byte("no fence at all")); !errors.Is(err, skilldomain.ErrInvalidFrontmatter) {
		t.Fatalf("manifest write without fence should be InvalidFrontmatter, got %v", err)
	}
	if err := svc.WriteFile(ctx, "alpha", "skill.md", []byte("---\nname: alpha\ndescription: via files\n---\nok\n")); err != nil {
		t.Fatalf("lowercase manifest write should route and succeed: %v", err)
	}
	sk, err := svc.Get(ctx, "alpha")
	if err != nil || sk.Description != "via files" {
		t.Fatalf("manifest write not reflected: %+v err=%v", sk, err)
	}
}

func TestDeleteFile_ManifestRefused(t *testing.T) {
	svc := newService(t, nil)
	ctx := ctxWS("ws_1")
	if _, err := svc.Create(ctx, SaveInput{Name: "alpha", Description: "d", Body: "b"}); err != nil {
		t.Fatalf("create: %v", err)
	}
	if err := svc.DeleteFile(ctx, "alpha", "SKILL.md"); !errors.Is(err, skilldomain.ErrFilePathInvalid) {
		t.Fatalf("manifest delete must be refused, got %v", err)
	}
}

func TestFiles_PassthroughChain(t *testing.T) {
	svc := newService(t, nil)
	ctx := ctxWS("ws_1")
	if _, err := svc.Create(ctx, SaveInput{Name: "alpha", Description: "d", Body: "b"}); err != nil {
		t.Fatalf("create: %v", err)
	}
	if err := svc.WriteFile(ctx, "alpha", "scripts/run.py", []byte("print('hi')")); err != nil {
		t.Fatalf("write file: %v", err)
	}
	files, err := svc.ListFiles(ctx, "alpha")
	if err != nil || len(files) != 2 {
		t.Fatalf("list files: %+v err=%v", files, err)
	}
	data, err := svc.ReadFile(ctx, "alpha", "scripts/run.py")
	if err != nil || string(data) != "print('hi')" {
		t.Fatalf("read file: %q err=%v", data, err)
	}
	if err := svc.DeleteFile(ctx, "alpha", "scripts/run.py"); err != nil {
		t.Fatalf("delete file: %v", err)
	}
	if _, err := svc.ReadFile(ctx, "alpha", "scripts/run.py"); !errors.Is(err, skilldomain.ErrFileNotFound) {
		t.Fatalf("deleted file should be FileNotFound, got %v", err)
	}
}

func TestCreate_SpecNameEnforced(t *testing.T) {
	svc := newService(t, nil)
	ctx := ctxWS("ws_1")
	for _, bad := range []string{"has_underscore", "-lead", "trail-", "double--hyphen"} {
		if _, err := svc.Create(ctx, SaveInput{Name: bad, Description: "d", Body: "b"}); !errors.Is(err, skilldomain.ErrInvalidName) {
			t.Fatalf("Create(%q) should be ErrInvalidName (spec form), got %v", bad, err)
		}
	}
	// 规范允许数字开头（对齐 Agent Skills spec；旧正则拒之）。
	if _, err := svc.Create(ctx, SaveInput{Name: "3d-print", Description: "d", Body: "b"}); err != nil {
		t.Fatalf("digit-start spec name must be accepted, got %v", err)
	}
}

func TestReplace_LegacyUnderscoreNameStillEditable(t *testing.T) {
	// 存量下划线 skill（守卫正则收、规范正则拒）：结构化 Replace / ReplaceRaw / Delete 照常。
	st := skillfs.New(t.TempDir())
	svc := NewService(st, nil, nil, zap.NewNop())
	ctx := ctxWS("ws_1")
	if err := st.Save(ctx, "legacy_name", skilldomain.Frontmatter{Name: "legacy_name", Description: "old", Source: "user"}, "b"); err != nil {
		t.Fatalf("seed legacy: %v", err)
	}
	if _, err := svc.Replace(ctx, SaveInput{Name: "legacy_name", Description: "newer", Body: "b2"}); err != nil {
		t.Fatalf("legacy underscore name must stay editable: %v", err)
	}
	sk, err := svc.Get(ctx, "legacy_name")
	if err != nil || sk.Description != "newer" {
		t.Fatalf("legacy edit not reflected: %+v err=%v", sk, err)
	}
	if err := svc.Delete(ctx, "legacy_name"); err != nil {
		t.Fatalf("legacy delete: %v", err)
	}
	if !strings.Contains("legacy_name", "_") {
		t.Fatal("sanity")
	}
}

// B2 渐进披露（WRK-076）：${CLAUDE_SKILL_DIR} 替换 + 目录前导注入语义。

func TestActivate_SkillDirPlaceholderSubstituted(t *testing.T) {
	svc := newService(t, nil)
	ctx := ctxWS("ws_1")
	if _, err := svc.Create(ctx, SaveInput{
		Name: "anchored", Description: "d",
		Body: "Run ${CLAUDE_SKILL_DIR}/scripts/x.py now.",
	}); err != nil {
		t.Fatalf("create: %v", err)
	}
	out, err := svc.Activate(ctx, "anchored", nil)
	if err != nil {
		t.Fatalf("activate: %v", err)
	}
	if strings.Contains(out, "${CLAUDE_SKILL_DIR}") {
		t.Fatalf("placeholder must substitute, got: %s", out)
	}
	if !strings.Contains(out, "/skills/anchored/scripts/x.py") {
		t.Fatalf("substituted path must point into the skill dir, got: %s", out)
	}
	// 写了占位符 → 不再加前导行。
	if strings.Contains(out, "This skill's directory") {
		t.Fatalf("no preamble when the body already anchors itself: %s", out)
	}
}

func TestActivate_PreambleOnlyWhenBundledFilesExist(t *testing.T) {
	svc := newService(t, nil)
	ctx := ctxWS("ws_1")
	// 单文件 skill：无前导（无物可指）。
	if _, err := svc.Create(ctx, SaveInput{Name: "solo", Description: "d", Body: "Just do it."}); err != nil {
		t.Fatalf("create solo: %v", err)
	}
	out, err := svc.Activate(ctx, "solo", nil)
	if err != nil {
		t.Fatalf("activate solo: %v", err)
	}
	if strings.Contains(out, "This skill's directory") {
		t.Fatalf("single-file skill must not get a preamble: %s", out)
	}
	// 带捆绑文件且没写占位符：前置一行目录说明。
	if _, err := svc.Create(ctx, SaveInput{Name: "bundled", Description: "d", Body: "See references/notes.md."}); err != nil {
		t.Fatalf("create bundled: %v", err)
	}
	if err := svc.WriteFile(ctx, "bundled", "references/notes.md", []byte("# n")); err != nil {
		t.Fatalf("write file: %v", err)
	}
	out, err = svc.Activate(ctx, "bundled", nil)
	if err != nil {
		t.Fatalf("activate bundled: %v", err)
	}
	if !strings.HasPrefix(out, "This skill's directory") || !strings.Contains(out, "/skills/bundled") {
		t.Fatalf("bundled skill without placeholder must get the directory preamble, got: %s", out)
	}
	// Guide（agent 挂载路径）同享注入。
	guide, err := svc.Guide(ctx, "bundled")
	if err != nil {
		t.Fatalf("guide: %v", err)
	}
	if !strings.HasPrefix(guide, "This skill's directory") {
		t.Fatalf("guide must carry the preamble too, got: %s", guide)
	}
}
