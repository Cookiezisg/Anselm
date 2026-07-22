package main

import (
	"os"
	"path/filepath"
	"testing"
)

// DTO-mirror drift tests — mini repo (a Go struct + an anchored freezed class) per case: missed
// mirrors and ghost fields go red; the truncation regression (`@Default(<String, String>{})`
// carrying a literal `})`) must NOT eat later parameters; anchor-free and name-mismatched classes
// stay quiet. DTO 镜像漂移测试:漏镜像/幽灵红;@Default 字面 `})` 不得截断后续参数(校准回归);
// 无锚/不同名保持安静。
func dtoFixture(t *testing.T, goSrc, dartSrc string) *linter {
	t.Helper()
	root := t.TempDir()
	goPath := filepath.Join(root, "backend", "internal", "domain", "skill", "skill.go")
	dartPath := filepath.Join(root, "frontend", "lib", "core", "contract", "entities", "skill.dart")
	for p, c := range map[string]string{goPath: goSrc, dartPath: dartSrc} {
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(c), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	l := &linter{docsDir: filepath.Join(root, "docs")}
	l.driftDTO(root)
	return l
}

const goSkill = "package skill\n\ntype Skill struct {\n" +
	"\tName string `json:\"name\"`\n" +
	"\tDir  string `json:\"dir\"`\n" +
	"\tRaw  []byte `json:\"-\"`\n" + // json:"-" never crosses the wire 不上线缆
	"}\n"

func TestDriftDTO_MirrorAndGhost(t *testing.T) {
	dart := `/// Mirrors skill.go:26。
@freezed
abstract class Skill with _$Skill {
  const factory Skill({
    required String name,
    @Default('') String ghostField,
  }) = _Skill;
}
`
	l := dtoFixture(t, goSkill, dart)
	if !hasErr(l, `misses wire field "dir"`) {
		t.Errorf("missed mirror must go red; errs=%v", l.errs)
	}
	if !hasErr(l, `"ghostField"`) {
		t.Errorf("ghost field must go red; errs=%v", l.errs)
	}
	if hasErr(l, `"name"`) || hasErr(l, `"-"`) {
		t.Errorf("mirrored field / json:\"-\" must stay green; errs=%v", l.errs)
	}
}

func TestDriftDTO_DefaultLiteralDoesNotTruncate(t *testing.T) {
	// The calibration bug: a naive Index("})") stopped at @Default(<String, String>{}) and
	// "lost" every later parameter. 校准踩过的截断 bug 回归。
	dart := `/// Mirrors skill.go:26。
@freezed
abstract class Skill with _$Skill {
  const factory Skill({
    required String name,
    @Default(<String, String>{}) Map<String, String> meta,
    @Default('') String dir,
  }) = _Skill;
}
`
	goSrc := "package skill\n\ntype Skill struct {\n" +
		"\tName string            `json:\"name\"`\n" +
		"\tMeta map[string]string `json:\"meta\"`\n" +
		"\tDir  string            `json:\"dir\"`\n" +
		"}\n"
	l := dtoFixture(t, goSrc, dart)
	if len(l.errs) != 0 {
		t.Errorf("fully mirrored class must be green (truncation regression?); errs=%v", l.errs)
	}
}

func TestDriftDTO_OptInKeys(t *testing.T) {
	// No anchor → unchecked; anchored but differently-named → quiet skip (both by design).
	// 无锚不查;带锚不同名=静默跳过(皆设计)。
	dart := `@freezed
abstract class Skill with _$Skill {
  const factory Skill({required String wrong}) = _Skill;
}

/// Mirrors skill.go:1。
@freezed
abstract class SkillEntity with _$SkillEntity {
  const factory SkillEntity({required String alsoWrong}) = _SkillEntity;
}
`
	l := dtoFixture(t, goSkill, dart)
	if len(l.errs) != 0 {
		t.Errorf("anchor-free + name-mismatch must both stay quiet; errs=%v", l.errs)
	}
}
