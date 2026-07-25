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

// ── signal-vocabulary drift: the wire's action verbs vs the frontend's switch ──
//
// The SSE notification protocol is deliberately OPEN (CLAUDE.md keeps `node.type` unsealed), so the
// frontend maps verbs through a `switch` with an `unknown` fallback. That fallback is correct — a build
// must not crash on a verb it has never heard of — but it is also silent, and silence is the exact
// failure mode of WRK-083 B1: the backend had emitted `conversation.work_dir` since WRK-077 WD1, the
// Dart switch never learned it, every residency change fell through to `unknown`, and the rail's
// `_onSignal` returned without doing anything. Nothing was red. Nothing was logged. The rail's own
// regrouping machinery had already been written for exactly this case and simply never ran.
//
// No behavioural test catches that: whoever adds the next verb writes it on the Go side, sees green,
// and ships. So the law is mechanical — every verb registered in the events.md family MUST appear in
// the frontend switch that maps that domain.
//
// events.md (not the Go source) is the reference on purpose. Conversation verbs are assigned to a
// variable and emitted as `"conversation." + action`, which `driftEvents` explicitly cannot reassemble
// (see its `reDynPrefix` note) — but events.md registers the whole family by hand, and driftEvents
// already guards THAT registration against the code. Chaining onto it gives backend → doc → frontend
// without re-deriving what the first leg already proved.
//
// ── 信号词表漂移:线缆动作动词 vs 前端 switch ──
//
// SSE 通知协议**刻意开放**(CLAUDE.md 明写 `node.type` 不封闭),故前端用带 `unknown` 兜底的 `switch` 映射
// 动词。那个兜底是对的——构建不该因为没听过的动词而崩——但它也是**安静的**,而安静正是 WRK-083 B1 的失败形态:
// 后端自 WRK-077 WD1 起就在发 `conversation.work_dir`,Dart switch 从未学会它,每次驻地变更都落进 `unknown`,
// rail 的 `_onSignal` 直接 return。没有红、没有日志。rail 自己的重分组机器早就为这一格写好了,只是从没跑过。
//
// 行为测试抓不到:加下一个动词的人在 Go 侧写完、看到全绿、发版。故本法机械化——events.md 族里登记的**每一个**
// 动词,都必须出现在映射该域的前端 switch 里。
//
// 参照 events.md 而非 Go 源是刻意的。对话动词被赋给变量、以 `"conversation." + action` 发出,而 `driftEvents`
// 明说它重组不了这种形态(见其 `reDynPrefix` 注释);但 events.md 手写登记了整个族,而 driftEvents 已经在拿代码
// 守着**那份登记**。接上它即得「后端 → 文档 → 前端」,不必把第一段已证过的东西再推一遍。

// signalVocabularies maps a wire domain to the frontend file whose switch must cover it.
// signalVocabularies:线缆域 → 必须覆盖它的前端 switch 所在文件。
var signalVocabularies = map[string]string{
	"conversation": filepath.Join(
		"frontend", "lib", "features", "chat", "data", "conversation_signal.dart",
	),
}

var (
	// The registered family in events.md, e.g. `conversation.{created, updated, **work_dir**}`.
	reEventsFamily = regexp.MustCompile("`([a-z_]+)\\.\\{([^}]+)\\}`")
	// A quoted verb in the Dart switch, e.g. 'work_dir'. Dart string literals are single-quoted here.
	reDartVerb = regexp.MustCompile(`'([a-z_]+)'`)
)

// driftSignalVocabulary diffs each registered event family against the frontend switch that consumes it.
//
// driftSignalVocabulary 把每个已登记事件族与消费它的前端 switch 逐动词 diff。
func (l *linter) driftSignalVocabulary(repoRoot string) {
	doc, ok := l.readDoc(filepath.Join("references", "backend", "events.md"))
	if !ok {
		return
	}
	registered := map[string]map[string]bool{}
	for _, g := range reEventsFamily.FindAllStringSubmatch(doc, -1) {
		domain := g[1]
		if _, wanted := signalVocabularies[domain]; !wanted {
			continue
		}
		set := registered[domain]
		if set == nil {
			set = map[string]bool{}
			registered[domain] = set
		}
		for _, raw := range strings.Split(g[2], ",") {
			// events.md emphasises new members with `**verb**` — strip the markdown, keep the verb.
			// events.md 用 `**动词**` 强调新成员——剥掉 markdown、留下动词。
			v := strings.TrimSpace(strings.ReplaceAll(raw, "*", ""))
			if v != "" {
				set[v] = true
			}
		}
	}

	for domain, rel := range signalVocabularies {
		verbs := registered[domain]
		if len(verbs) == 0 {
			l.errf("drift: events.md registers no `%s.{…}` family — the signal-vocabulary guard for %s has nothing to check", domain, rel)
			continue
		}
		b, err := os.ReadFile(filepath.Join(repoRoot, rel))
		if err != nil {
			l.errf("drift: cannot read %s for the %s signal vocabulary: %v", rel, domain, err)
			continue
		}
		mapped := map[string]bool{}
		for _, g := range reDartVerb.FindAllStringSubmatch(string(b), -1) {
			mapped[g[1]] = true
		}
		var missing []string
		for v := range verbs {
			if !mapped[v] {
				missing = append(missing, v)
			}
		}
		sort.Strings(missing)
		for _, v := range missing {
			l.errf("drift: events.md registers `%s.%s` but %s never maps that verb — it would fall through to the silent `unknown` fallback (WRK-083 B1)",
				domain, v, filepath.Base(rel))
		}
	}
}
