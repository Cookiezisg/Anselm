// drift.go — the contract-drift detector: the MECHANICAL half of design principle #9. It extracts
// four contract fact-sets from backend source (wire error codes / notification events / endpoint
// resource words / table names) and diffs them against the four index docs' registrations, so "doc
// lagging code" physically cannot happen quietly. The docs stay human prose — this only proves the
// registrations exist. Extraction leans on the constitution's own conventions (S20: every named
// sentinel goes through errorspkg.New; routes are HandleFunc literals; events are Emit/Broadcast
// literals; tables are CREATE TABLE literals), which is exactly what makes it reliable.
//
// Matching philosophy: UNDER-report rather than over-report — a gate that cries wolf gets ignored.
// Strict two-way diffs only where the token shape is unambiguous (error codes, table names, dotted
// event names); one-way / word-level checks where the doc side is prose (endpoints, brace-family
// events); vocabularies the docs themselves declare non-exhaustive (node.type) are NOT checked.
//
// drift.go——契约漂移检测:设计原则 #9 的机械半。从后端源码提取四类契约事实(错误码/通知事件/端点
// 资源词/表名),与四索引文档的登记 diff——「文档落后于代码」从此物理上不可能安静发生。文档仍是人写
// 散文,本检测只证明登记存在。提取依赖宪法自身的约定(S20 唯一构造函数/路由字面量/事件字面量/建表
// 字面量)——正是这些约定让提取可靠。
// 匹配哲学:宁漏报不误报(狼来了的门禁会被无视)。token 形态无歧义处才双向严格(错误码/表名/带点
// 事件名);文档侧是散文处只做单向/词级(端点/花括号族);文档自称非穷举的词表(node.type)不查。
package main

import (
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

var (
	// Error codes. 错误码。
	reNewPrefixed = regexp.MustCompile(`errorspkg\.New\([^"]*"([A-Z][A-Z0-9_]+)"`)
	reNewBare     = regexp.MustCompile(`\bNew\([^"]*"([A-Z][A-Z0-9_]+)"`)
	// Transport synthetic codes carry at least one underscore (CLIENT_CLOSED …) — the underscore
	// requirement keeps random ALL-CAPS strings out. transport 合成码至少一个下划线,防误抓大写串。
	reSynthCode = regexp.MustCompile(`"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)"`)
	reDocCode   = regexp.MustCompile("(?m)^\\| `([A-Z][A-Z0-9_]+)` ")

	// Notification events. Two code shapes: a full dotted literal as any call's second argument
	// (`Emit(ctx, "relation.dependency_broken"`), and the repo-wide helper idiom `"<domain>."+action`
	// (every domain Service concatenates its prefix in ONE place — those events can't be mechanically
	// reassembled, so their domains become a reverse-check exemption set instead).
	// 通知事件两种代码形态:任意调用第二参的完整点写字面量,与全仓统一的 `"<域>."+action` helper 拼接
	// (每域 Service 一处拼前缀——拼接事件无法机械重组全名,故其域进反查豁免集)。
	// Emitter-verb whitelist: a generic "second string arg is dotted" net also catches image
	// registries ("docker.io") and executables ("npm.cmd") — events only leave through the
	// emit family. 发射动词白名单:泛网会捞到镜像域名/可执行名,事件只经 emit 家族出门。
	reEmitEvent  = regexp.MustCompile(`(?:Emit|Broadcast|notify|publish|send)\(\s*[\w.()]+,\s*"([a-z_]+\.[a-z_]+)"`)
	reDynPrefix  = regexp.MustCompile(`"([a-z_]+)\."\s*\+`)
	reDocEvent   = regexp.MustCompile("`([a-z_]+)\\.([a-z_]+)`")
	reDocFamily  = regexp.MustCompile("`([a-z_]+)\\.\\{([^}]+)\\}`")
	reDocFloatFm = regexp.MustCompile("`<域>\\.\\{([^}]+)\\}`")
	reBareAction = regexp.MustCompile("`([a-z_]+)`")

	// Comments must be stripped before extraction — pkg/errors' own doc comment contains the example
	// `New(KindNotFound, "X_NOT_FOUND", …)`. 提取前剥注释:pkg/errors 的文档注释里就有示例构造。
	reLineComment  = regexp.MustCompile(`(?m)//.*$`)
	reBlockComment = regexp.MustCompile(`(?s)/\*.*?\*/`)

	// A dotted token whose tail is a file extension is a filename, not an event ("skill.md").
	// Prose dot-paths in docs ("payload.name") are likewise not events. 点尾是扩展名=文件名非事件;
	// 文档散文点路径(payload.name)同样非事件。
	eventTailBlacklist = map[string]bool{"md": true, "go": true, "json": true, "txt": true, "sh": true,
		"py": true, "js": true, "mjs": true, "cjs": true, "yaml": true, "yml": true, "toml": true,
		"html": true, "css": true, "dart": true, "png": true, "jpg": true, "svg": true, "csv": true,
		"ttf": true, "lock": true, "sum": true, "mod": true, "db": true, "log": true}
	eventDomainBlacklist = map[string]bool{"payload": true, "node": true, "frame": true, "scope": true, "props": true}

	// Endpoints. 端点。
	reHandleFunc = regexp.MustCompile(`HandleFunc\("(GET|POST|PUT|PATCH|DELETE) (/[^"]+)"`)

	// Tables. 表。
	reCreateTable = regexp.MustCompile(`CREATE (?:VIRTUAL )?TABLE IF NOT EXISTS (\w+)`)
	reDocTable    = regexp.MustCompile("(?m)^\\| `(\\w+)`")
)

// checkDrift runs the four contract-drift passes when backend/ is present beside docs/.
//
// checkDrift 在 backend/ 与 docs/ 并存时跑四个漂移 pass。
func (l *linter) checkDrift(backendDir string) {
	if _, err := os.Stat(backendDir); err != nil {
		return // docs-only checkout: the gate still lints docs, just without drift. 无后端源即跳过。
	}
	// Table names are extracted once and shared: the tables pass diffs them, and the events pass
	// exempts doc dot-references to table COLUMNS ("`triggers.paused` 行是重连真相") from the
	// ghost-event check. 表名一次提取共享:tables pass 用来 diff,events pass 用来豁免文档里的
	// 「表.列」散文引用。
	tables := map[string]string{}
	walkGo(filepath.Join(backendDir, "internal"), func(path, content string) {
		for _, g := range reCreateTable.FindAllStringSubmatch(content, -1) {
			if _, ok := tables[g[1]]; !ok {
				tables[g[1]] = path
			}
		}
	})
	l.driftErrorCodes(backendDir)
	l.driftEvents(backendDir, tables)
	l.driftEndpoints(backendDir)
	l.driftTables(tables)
}

// walkGo streams every non-test .go file under dir into fn, comments stripped (doc comments carry
// example constructors / event names that must not enter the fact sets).
//
// walkGo 遍历 dir 下非测试 Go 文件,注释已剥(文档注释携带示例构造/事件名,不得入事实集)。
func walkGo(dir string, fn func(path, content string)) {
	_ = filepath.WalkDir(dir, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}
		b, rerr := os.ReadFile(path)
		if rerr != nil {
			return nil
		}
		content := reBlockComment.ReplaceAllString(string(b), "")
		content = reLineComment.ReplaceAllString(content, "")
		fn(path, content)
		return nil
	})
}

func (l *linter) readDoc(rel string) (string, bool) {
	b, err := os.ReadFile(filepath.Join(l.docsDir, rel))
	if err != nil {
		l.errf("drift: cannot read %s: %v", rel, err)
		return "", false
	}
	return string(b), true
}

func sortedKeys(m map[string]string) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

// driftErrorCodes — STRICT two-way: every wire code constructed in code must be registered in
// error-codes.md's table, and every table row must correspond to a real constructor. Three code
// sources mirror the doc's own accounting: errorspkg.New everywhere + pkg/errors' bare New
// sentinels + transport synthetic codes (response/router).
//
// driftErrorCodes——双向严格:代码里构造的每个 wire code 必须在 error-codes.md 表格登记,反之每行
// 必须对应真实构造。三个代码源对应文档自己的记账:全域 errorspkg.New + pkg/errors 裸 New +
// transport 合成码。
func (l *linter) driftErrorCodes(backendDir string) {
	code := map[string]string{} // code → first file 首见文件
	add := func(m [][]string, path string) {
		for _, g := range m {
			if _, ok := code[g[1]]; !ok {
				code[g[1]] = path
			}
		}
	}
	walkGo(filepath.Join(backendDir, "internal"), func(path, content string) {
		add(reNewPrefixed.FindAllStringSubmatch(content, -1), path)
		if strings.Contains(path, filepath.Join("pkg", "errors")) {
			add(reNewBare.FindAllStringSubmatch(content, -1), path)
		}
		if strings.Contains(path, filepath.Join("transport", "httpapi", "response")) ||
			strings.Contains(path, filepath.Join("transport", "httpapi", "router")) {
			add(reSynthCode.FindAllStringSubmatch(content, -1), path)
		}
	})

	doc, ok := l.readDoc(filepath.Join("references", "backend", "error-codes.md"))
	if !ok {
		return
	}
	registered := map[string]bool{}
	for _, g := range reDocCode.FindAllStringSubmatch(doc, -1) {
		registered[g[1]] = true
	}

	for _, c := range sortedKeys(code) {
		if !registered[c] {
			l.errf("drift: error code %s (constructed in %s) is NOT registered in error-codes.md", c, filepath.Base(code[c]))
		}
	}
	for c := range registered {
		if _, ok := code[c]; !ok {
			l.errf("drift: error-codes.md registers %s but no constructor exists in backend (ghost registration)", c)
		}
	}
}

// driftEvents — notification events (`<domain>.<action>` Emit/Broadcast literals). Code→doc: an
// event passes if registered as a dotted literal, a `domain.{a,b}` family, or LINE-LEVEL pairing
// (its action appears in a brace family / bare-action backtick on a line that also mentions the
// domain — events.md writes one domain's mounting per line). Doc→code: only dotted literals are
// reverse-checked (families/placeholders describe, prose can't ghost-check).
//
// driftEvents——通知事件。代码→文档:点写直登 / `域.{a,b}` 族 / 行级配对(action 出现在某行的花括号
// 族或裸反引号里、且该行同时提及域——events.md 每行写一个域的挂载)即通过。文档→代码:只反查点写
// 直登形态(族/占位是描述,散文不反查)。
func (l *linter) driftEvents(backendDir string, tables map[string]string) {
	events := map[string]string{}
	dynDomains := map[string]bool{} // "<domain>."+action helper 域(全名无法机械重组)
	walkGo(filepath.Join(backendDir, "internal"), func(path, content string) {
		for _, g := range reEmitEvent.FindAllStringSubmatch(content, -1) {
			tail := g[1][strings.LastIndex(g[1], ".")+1:]
			if eventTailBlacklist[tail] {
				continue // a filename ("skill.md"), not an event 文件名非事件
			}
			if _, ok := events[g[1]]; !ok {
				events[g[1]] = path
			}
		}
		for _, g := range reDynPrefix.FindAllStringSubmatch(content, -1) {
			dynDomains[g[1]] = true
		}
	})

	doc, ok := l.readDoc(filepath.Join("references", "backend", "events.md"))
	if !ok {
		return
	}
	dotted := map[string]bool{}
	for _, g := range reDocEvent.FindAllStringSubmatch(doc, -1) {
		if eventDomainBlacklist[g[1]] || eventTailBlacklist[g[2]] {
			continue // prose dot-path / filename, not an event 散文点路径/文件名非事件
		}
		dotted[g[1]+"."+g[2]] = true
	}
	family := map[string]bool{}
	for _, g := range reDocFamily.FindAllStringSubmatch(doc, -1) {
		for _, a := range strings.Split(g[2], ",") {
			family[g[1]+"."+strings.TrimSpace(a)] = true
		}
	}
	lines := strings.Split(doc, "\n")

	lineRegisters := func(domain, action string) bool {
		for _, line := range lines {
			if !strings.Contains(line, "`"+domain+"`") && !strings.Contains(line, domain+".") {
				continue
			}
			for _, g := range reDocFamily.FindAllStringSubmatch(line, -1) {
				for _, a := range strings.Split(g[2], ",") {
					if strings.TrimSpace(a) == action {
						return true
					}
				}
			}
			for _, g := range reDocFloatFm.FindAllStringSubmatch(line, -1) {
				for _, a := range strings.Split(g[1], ",") {
					if strings.TrimSpace(a) == action {
						return true
					}
				}
			}
			// `{created, updated, moved}` families with the domain named separately on the line,
			// and bare `deleted` actions. 域另写的无前缀族与裸 action。
			if strings.Contains(line, "{") {
				for _, seg := range strings.Split(line, "{")[1:] {
					if i := strings.Index(seg, "}"); i >= 0 {
						for _, a := range strings.Split(seg[:i], ",") {
							if strings.TrimSpace(a) == action {
								return true
							}
						}
					}
				}
			}
			for _, g := range reBareAction.FindAllStringSubmatch(line, -1) {
				if g[1] == action {
					return true
				}
			}
		}
		return false
	}

	for _, e := range sortedKeys(events) {
		if dotted[e] || family[e] {
			continue
		}
		parts := strings.SplitN(e, ".", 2)
		if lineRegisters(parts[0], parts[1]) {
			continue
		}
		l.errf("drift: notification event %s (emitted in %s) is NOT registered in events.md", e, filepath.Base(events[e]))
	}
	for e := range dotted {
		if _, ok := events[e]; ok {
			continue
		}
		domain := strings.SplitN(e, ".", 2)[0]
		// Two exemptions: a helper-domain event ("workflow."+action) can't be mechanically
		// reassembled; a doc dot-reference whose head is a TABLE name is prose about a column
		// ("triggers.paused 行"), not an event. 两豁免:helper 域事件无法机械重组;头是表名的
		// 点引用是「表.列」散文,非事件。
		if dynDomains[domain] {
			continue
		}
		if _, isTable := tables[domain]; isTable {
			continue
		}
		l.errf("drift: events.md registers %s as a dotted literal but no emit constructs it (ghost registration)", e)
	}
}

// driftEndpoints — one-way, resource-word level: for every /api/v1 route literal, each NAMED path
// segment (placeholders stripped) must appear somewhere in api.md. Catches "new resource / new
// sub-resource never registered"; deliberately does NOT parse api.md's free prose into full routes
// (`PUT/DELETE {id}/default-models/{scenario}` shorthand would make that a false-positive farm).
//
// driftEndpoints——单向、资源词级:每条 /api/v1 路由字面量的具名段(剥占位符)必须在 api.md 出现。
// 抓「新资源/新子资源忘登记」;刻意不把 api.md 的自由散文解析成完整路由(简写形态会变误报农场)。
func (l *linter) driftEndpoints(backendDir string) {
	type route struct{ verb, path, file string }
	var routes []route
	walkGo(filepath.Join(backendDir, "internal"), func(path, content string) {
		for _, g := range reHandleFunc.FindAllStringSubmatch(content, -1) {
			if strings.HasPrefix(g[2], "/api/v1/") {
				routes = append(routes, route{g[1], g[2], path})
			}
		}
	})

	doc, ok := l.readDoc(filepath.Join("references", "backend", "api.md"))
	if !ok {
		return
	}
	for _, r := range routes {
		for _, seg := range strings.Split(strings.TrimPrefix(r.path, "/api/v1/"), "/") {
			if seg == "" || strings.HasPrefix(seg, "{") {
				continue
			}
			// An `:action` suffix rides a named segment (`skills:install`) — the resource word is
			// the part before the colon. `:action` 骑在具名段上,资源词取冒号前。
			word := seg
			if i := strings.Index(seg, ":"); i > 0 {
				word = seg[:i]
			}
			if !strings.Contains(doc, word) {
				l.errf("drift: endpoint %s %s (registered in %s) — resource word %q never appears in api.md", r.verb, r.path, filepath.Base(r.file), word)
			}
		}
	}
}

// driftTables — table names: strict on the code side (every CREATE TABLE literal must be mentioned
// in backend references — database.md's table rows first, any references/backend doc as fallback
// for foundation-owned tables), and strict on database.md's side (every table row must correspond
// to a real CREATE TABLE). Columns are NOT checked: database.md's rows list salient columns only
// (id/workspace_id/timestamps elided by convention) — a column diff would be a false-positive farm.
//
// driftTables——表名:代码侧严格(每个 CREATE TABLE 字面量须在后端 references 被提及——先看
// database.md 表格行,foundation 自有表回落到任意 references/backend 文档);database.md 侧严格
// (每个表格行须对应真实 CREATE TABLE)。列不查:database.md 只列要点列(id/ws/时间戳按惯例省略),
// 列级 diff 是误报农场。
func (l *linter) driftTables(tables map[string]string) {
	dbDoc, ok := l.readDoc(filepath.Join("references", "backend", "database.md"))
	if !ok {
		return
	}
	rows := map[string]bool{}
	for _, g := range reDocTable.FindAllStringSubmatch(dbDoc, -1) {
		rows[g[1]] = true
	}

	// Fallback corpus: every references/backend doc (foundation tables live in foundation/*.md).
	// 回落语料:references/backend 全部文档(地基表登在 foundation/*.md)。
	var corpus strings.Builder
	_ = filepath.WalkDir(filepath.Join(l.docsDir, "references", "backend"), func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(path, ".md") {
			return nil
		}
		if b, rerr := os.ReadFile(path); rerr == nil {
			corpus.Write(b)
			corpus.WriteByte('\n')
		}
		return nil
	})
	all := corpus.String()

	for _, t := range sortedKeys(tables) {
		if !rows[t] && !strings.Contains(all, "`"+t+"`") {
			l.errf("drift: table %s (CREATE TABLE in %s) is NOT mentioned anywhere in references/backend", t, filepath.Base(tables[t]))
		}
	}
	for t := range rows {
		if _, ok := tables[t]; !ok {
			l.errf("drift: database.md has a table row for %s but no CREATE TABLE exists (ghost registration)", t)
		}
	}
}
