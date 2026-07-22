// drift_frontend.go — the DTO-mirror drift pass (#9's third leg): frontend freezed DTOs that
// declare a mirror ANCHOR (`<file>.go:<line>` in their doc comment — an existing contract-layer
// convention) are field-diffed against the Go struct OF THE SAME NAME in that file. Anchor-driven
// on purpose: only pairs that opt in are checked (no anchor → no check → no false positives on
// deliberate projections), and the line number is advisory — the struct is found by NAME, so a
// drifting line never mis-targets.
//
// Field semantics: Go side = json tag heads (`json:"-"` skipped; tagless fields skipped — they
// don't cross the wire under this repo's conventions); Dart side = freezed factory parameter
// names, with `@JsonKey(name: 'x')` overriding. Go-has/Dart-lacks = missed mirror; Dart-has/
// Go-lacks = ghost field. Both red.
//
// drift_frontend.go——DTO 镜像漂移 pass(#9 第三条腿):声明镜像锚(doc 注释里的 `<file>.go:<line>`,
// 契约层既有惯例)的 freezed DTO,与该文件里**同名** Go struct 逐字段 diff。刻意锚驱动:opt-in 才查
// (无锚不查→刻意投影零误报),行号仅提示——按名找 struct,行号漂移不误伤。字段语义:Go 侧=json tag
// 首段(`-` 与无 tag 跳过);Dart 侧=freezed 工厂参数名(@JsonKey(name) 覆盖)。Go 有 Dart 无=漏镜像,
// Dart 有 Go 无=幽灵字段,皆红。
package main

import (
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

var (
	// The doc comment above `@freezed` + `abstract class X with _$X` may carry `skill.go:26`.
	// @freezed 行隔在注释与类声明之间,必须计入形态。
	reDartClass  = regexp.MustCompile(`(?ms)((?:^///[^\n]*\n)*)^@freezed\nabstract class (\w+) with _\$`)
	reDartAnchor = regexp.MustCompile(`([a-z_]+\.go):\d+`)
	// One factory parameter line: optional annotations/required/default, then `Type name,`.
	// JsonKey(name:'x') overrides the wire name. 工厂参数行;JsonKey(name) 覆盖线名。
	reJsonKey   = regexp.MustCompile(`@JsonKey\(\s*name:\s*'([^']+)'`)
	reParamName = regexp.MustCompile(`(\w+)\s*,?\s*$`)

	reGoStruct = regexp.MustCompile(`(?ms)^type (\w+) struct \{(.*?)^\}`)
	reGoTag    = regexp.MustCompile("`[^`]*json:\"([^\",`]+)")
)

// dartFactoryFields extracts the wire field names from a freezed class body: comments stripped
// (a doc word like "file mtime" must not become a field), then the factory's parameter list split
// at DEPTH-ZERO commas only — `@Default(<String, String>{})` carries commas inside annotation
// parens/generics that a naive split shreds. 从 freezed 类体抽线字段名:先剥注释(注释词不得成
// 字段),参数表只在括号深度 0 的逗号处切——注解/泛型内逗号会把裸 split 切碎。
func dartFactoryFields(body string) []string {
	body = reLineComment.ReplaceAllString(body, "")
	start := strings.Index(body, "const factory")
	if start < 0 {
		return nil
	}
	open := strings.Index(body[start:], "({")
	if open < 0 {
		return nil
	}
	// Scan to the MATCHING `}` — a naive Index(`})`) truncates at literals like
	// `@Default(<String, String>{})` and silently drops every later parameter (the exact bug the
	// first calibration produced). 扫到**配对**的 `}`——裸找 "})" 会在 `@Default(...{})` 字面处
	// 截断、其后参数全丢(首次校准踩的正是这个)。
	rest := body[start+open+2:]
	depth, end := 0, -1
	for i, r := range rest {
		switch r {
		case '{', '(', '[', '<':
			depth++
		case ')', ']', '>':
			depth--
		case '}':
			if depth == 0 {
				end = i
			} else {
				depth--
			}
		}
		if end >= 0 {
			break
		}
	}
	if end < 0 {
		return nil
	}
	var out []string
	for _, frag := range splitDepthZero(rest[:end]) {
		line := strings.TrimSpace(frag)
		if line == "" {
			continue
		}
		if m := reJsonKey.FindStringSubmatch(line); m != nil {
			out = append(out, m[1])
			continue
		}
		// The parameter NAME is the fragment's last identifier (annotations + type precede it).
		// 参数名=片段末识别符(注解与类型在前)。
		if m := reParamName.FindStringSubmatch(line); m != nil {
			out = append(out, m[1])
		}
	}
	return out
}

// splitDepthZero splits on commas at bracket depth zero ((){}[]<>). 深度 0 逗号切分。
func splitDepthZero(s string) []string {
	var out []string
	depth, startAt := 0, 0
	for i, r := range s {
		switch r {
		case '(', '{', '[', '<':
			depth++
		case ')', '}', ']', '>':
			depth--
		case ',':
			if depth == 0 {
				out = append(out, s[startAt:i])
				startAt = i + 1
			}
		}
	}
	return append(out, s[startAt:])
}

// goStructFields returns json-tag heads for the named struct found in any of the files.
// 在候选文件里按名找 struct,返回 json tag 首段集。
func goStructFields(files []string, structName string) (map[string]bool, bool) {
	for _, f := range files {
		b, err := os.ReadFile(f)
		if err != nil {
			continue
		}
		for _, m := range reGoStruct.FindAllStringSubmatch(string(b), -1) {
			if m[1] != structName {
				continue
			}
			fields := map[string]bool{}
			for _, line := range strings.Split(m[2], "\n") {
				if tag := reGoTag.FindStringSubmatch(line); tag != nil && tag[1] != "-" {
					fields[tag[1]] = true
				}
			}
			return fields, true
		}
	}
	return nil, false
}

// driftDTO diffs every anchored frontend DTO against its same-named Go struct.
//
// driftDTO 把每个带锚前端 DTO 与同名 Go struct 逐字段 diff。
func (l *linter) driftDTO(repoRoot string) {
	contractDir := filepath.Join(repoRoot, "frontend", "lib", "core", "contract")
	backendDir := filepath.Join(repoRoot, "backend", "internal")
	if _, err := os.Stat(contractDir); err != nil {
		return
	}

	// Index backend .go files by basename (an anchor names only the file). 按 basename 索引后端文件。
	goByBase := map[string][]string{}
	_ = filepath.WalkDir(backendDir, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}
		base := filepath.Base(path)
		goByBase[base] = append(goByBase[base], path)
		return nil
	})

	checked := 0
	skippedNames := 0
	_ = filepath.WalkDir(contractDir, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(path, ".dart") || strings.Contains(path, ".freezed.") || strings.Contains(path, ".g.") {
			return nil
		}
		b, rerr := os.ReadFile(path)
		if rerr != nil {
			return nil
		}
		content := string(b)
		classMatches := reDartClass.FindAllStringSubmatchIndex(content, -1)
		for i, loc := range classMatches {
			docComment := content[loc[2]:loc[3]]
			className := content[loc[4]:loc[5]]
			anchor := reDartAnchor.FindStringSubmatch(docComment)
			if anchor == nil {
				continue // no anchor → deliberately unchecked (opt-in gate) 无锚不查
			}
			candidates := goByBase[anchor[1]]
			if len(candidates) == 0 {
				l.errf("drift: %s anchors %s but no such backend file exists", className, anchor[1])
				continue
			}
			goFields, found := goStructFields(candidates, className)
			if !found {
				// The pair needs BOTH keys — the anchor AND a same-named struct. Frontend classes
				// legitimately namespace (FunctionEntity ↔ Go Function), so a name miss is a quiet
				// skip, not an error (宁漏报不误报); the summary warn reports the skip count.
				// 配对需双钥匙(锚+同名 struct);前端类名合法加前缀,不同名=静默跳过,汇总 warn 报数。
				skippedNames++
				continue
			}
			// The class body: from this match to the next class (or EOF). 类体=本匹配到下一类。
			bodyEnd := len(content)
			if i+1 < len(classMatches) {
				bodyEnd = classMatches[i+1][0]
			}
			dartFields := dartFactoryFields(content[loc[0]:bodyEnd])
			dartSet := map[string]bool{}
			for _, f := range dartFields {
				dartSet[f] = true
			}
			checked++
			var missing []string
			for gf := range goFields {
				if !dartSet[gf] {
					missing = append(missing, gf)
				}
			}
			sort.Strings(missing)
			for _, gf := range missing {
				l.errf("drift: DTO %s (%s) misses wire field %q that Go %s carries — mirror the field or drop the anchor",
					className, filepath.Base(path), gf, anchor[1])
			}
			var ghosts []string
			for _, df := range dartFields {
				if !goFields[df] {
					ghosts = append(ghosts, df)
				}
			}
			sort.Strings(ghosts)
			for _, df := range ghosts {
				l.errf("drift: DTO %s (%s) carries field %q that Go %s does not — ghost field or missing backend half",
					className, filepath.Base(path), df, anchor[1])
			}
		}
		return nil
	})
	if checked > 0 || skippedNames > 0 {
		l.warnf("drift: %d anchored DTO mirror pairs checked, %d anchors without a same-named Go struct skipped (anchor + same name = the opt-in keys)", checked, skippedNames)
	}
}
