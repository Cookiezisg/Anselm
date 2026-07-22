// contract_knowledge_test.go — Phase 1 契约全扫 · p1_knowledge 批（skill + memory，文件式实体）。
//
// 覆盖行：A-skl-2/3/4/6/8 · A-mem-2/3/4/7/8 · B-sk-1/2/5/7/9/10。
// 事实源：docs/references/backend/domains/{skill,memory}.md + api.md + error-codes.md。
// 要点：name(slug) 即身份也是路径穿越守卫；List 为文件式全集返回（每次现扫目录，无
// cursor 分页——api.md/域文档如此，N4 张力在批次报告里记账）；body 自带 frontmatter 拒
// SKILL_INVALID_FRONTMATTER；!`cmd` shell 注入刻意不支持；坏 SKILL.md 跳过不连坐。
package scenarios

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/sunweilin/anselm/testend/harness"
)

// knowledgeC_newWS 在既有 server 上开一个隔离 workspace（文件式实体按 workspace 目录隔离，
// 各子场景拿全新目录即拿全新世界——列表集合断言零干扰）。
func knowledgeC_newWS(t *testing.T, srv *harness.Server, name string) (*harness.Client, string) {
	t.Helper()
	c := srv.Client(t)
	id := c.POST("/api/v1/workspaces", map[string]any{"name": name}).Field(t, "id")
	return c.WS(id), id
}

// knowledgeC_skill 构造最小合法 create/replace 载荷。
func knowledgeC_skill(name, desc, body string) map[string]any {
	return map[string]any{"name": name, "description": desc, "body": body}
}

// knowledgeC_skillWire 是 skill 的线缆形状（domain/skill.go 的 JSON 投影）。
type knowledgeC_skillWire struct {
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Source      string    `json:"source"`
	Context     string    `json:"context"`
	Body        string    `json:"body"`
	UpdatedAt   time.Time `json:"updatedAt"`
}

// knowledgeC_memWire 是 memory 的线缆形状。
type knowledgeC_memWire struct {
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Content     string    `json:"content"`
	Pinned      bool      `json:"pinned"`
	Source      string    `json:"source"`
	UpdatedAt   time.Time `json:"updatedAt"`
}

// knowledgeC_assertEmptyArray 断言 N1 空列表是 []、绝非 null / 缺键。
func knowledgeC_assertEmptyArray(t *testing.T, r *harness.Resp) {
	t.Helper()
	r.OK(t, nil)
	if s := strings.TrimSpace(string(r.Data)); s != "[]" {
		t.Fatalf("empty list must serialize as data:[] (N1/N4), got %q raw=%s", s, r.Raw)
	}
}

// TestContractKnowledge_SkillCRUDSurface — A-skl-2 / A-skl-3 / A-skl-4 / A-skl-6 / A-skl-8 / B-sk-9：
// skill REST 面的错误码、N1 形状、列表语义与未知字段拒绝（一台 server、每子场景独立 workspace）。
func TestContractKnowledge_SkillCRUDSurface(t *testing.T) {
	srv := harness.Start(t)

	// A-skl-4：零 skill 时 List 返 data:[]；DELETE 是 204 空体；删后列表回到 []。
	t.Run("A-skl-4_empty_list_and_204_delete_shape", func(t *testing.T) {
		wc, _ := knowledgeC_newWS(t, srv, "skl-envelope")
		knowledgeC_assertEmptyArray(t, wc.GET("/api/v1/skills"))

		if r := wc.POST("/api/v1/skills", knowledgeC_skill("ephemeral", "temp skill", "temp body")); r.Status != 201 {
			t.Fatalf("create must be 201 Created, got %d body=%s", r.Status, r.Raw)
		}
		del := wc.DELETE("/api/v1/skills/ephemeral")
		if del.Status != 204 {
			t.Fatalf("delete must be 204 No Content, got %d body=%s", del.Status, del.Raw)
		}
		if len(del.Raw) != 0 {
			t.Fatalf("204 must carry an empty body, got %s", del.Raw)
		}
		knowledgeC_assertEmptyArray(t, wc.GET("/api/v1/skills"))
	})

	// A-skl-2 + B-sk-9：创作错误面——POST 同名 409 SKILL_NAME_CONFLICT（且不覆写既有内容）、
	// GET/DELETE/PUT 未知 name 404 SKILL_NOT_FOUND、非 slug name 400 SKILL_INVALID_NAME。
	t.Run("A-skl-2_B-sk-9_error_surface", func(t *testing.T) {
		wc, _ := knowledgeC_newWS(t, srv, "skl-errors")
		wc.POST("/api/v1/skills", knowledgeC_skill("dup-name", "first edition", "one")).OK(t, nil)
		wc.Do("POST", "/api/v1/skills", knowledgeC_skill("dup-name", "second edition", "two")).
			Fail(t, 409, "SKILL_NAME_CONFLICT")

		// 冲突的 create 绝不能部分生效——原件逐字幸存。
		var got knowledgeC_skillWire
		wc.GET("/api/v1/skills/dup-name").OK(t, &got)
		if got.Description != "first edition" || got.Body != "one" {
			t.Fatalf("conflicted create must not clobber the original, got %+v", got)
		}

		wc.Do("GET", "/api/v1/skills/never-made", nil).Fail(t, 404, "SKILL_NOT_FOUND")
		wc.Do("DELETE", "/api/v1/skills/never-made", nil).Fail(t, 404, "SKILL_NOT_FOUND")
		wc.Do("PUT", "/api/v1/skills/never-made",
			map[string]any{"description": "d", "body": "b"}).Fail(t, 404, "SKILL_NOT_FOUND")
		wc.Do("GET", "/api/v1/skills/Not-A-Slug", nil).Fail(t, 400, "SKILL_INVALID_NAME")
	})

	// A-skl-3：List 是文件式全集（每次现扫目录、name 升序、不含 body）；cursor/limit 参数被
	// 忽略——契约（api.md skill 节 + domains/skill.md「每次 List 现扫目录」）不提供分页，
	// 顶层无分页坐标。N4「所有 List 必须分页」与此的张力记为缺陷报告（doc 层面）。
	t.Run("A-skl-3_list_full_set_unpaginated", func(t *testing.T) {
		wc, _ := knowledgeC_newWS(t, srv, "skl-list")
		names := []string{"s-charlie", "s-alpha", "s-echo", "s-bravo", "s-delta"}
		for _, n := range names {
			wc.POST("/api/v1/skills", knowledgeC_skill(n, "desc "+n, "body "+n)).OK(t, nil)
		}
		var items []knowledgeC_skillWire
		wc.GET("/api/v1/skills").OK(t, &items)
		if len(items) != 5 {
			t.Fatalf("list must return the full set, got %d", len(items))
		}
		wantOrder := []string{"s-alpha", "s-bravo", "s-charlie", "s-delta", "s-echo"}
		for i, w := range wantOrder {
			if items[i].Name != w {
				t.Fatalf("list must sort by name asc, got[%d]=%s want %s", i, items[i].Name, w)
			}
			if items[i].Body != "" {
				t.Fatalf("list items must omit body (Get-only field), got body on %s", items[i].Name)
			}
			if items[i].UpdatedAt.IsZero() {
				t.Fatalf("list items must carry updatedAt (file mtime), zero on %s", items[i].Name)
			}
		}

		// cursor/limit 被忽略：仍返全集、无顶层分页坐标（文件式契约，非 keyset 截断）。
		paged := wc.GET("/api/v1/skills?cursor=bogus&limit=2")
		var again []knowledgeC_skillWire
		paged.OK(t, &again)
		if len(again) != 5 || paged.NextCursor != "" || paged.HasMore {
			t.Fatalf("file-based list is unpaginated by contract: want full 5 + no cursor coords, got %d nextCursor=%q hasMore=%v",
				len(again), paged.NextCursor, paged.HasMore)
		}
	})

	// A-skl-6：name 即 id、无软删——删除后同名重建是全新文件，新内容生效、无 409 残影。
	t.Run("A-skl-6_delete_then_recreate_same_name", func(t *testing.T) {
		wc, _ := knowledgeC_newWS(t, srv, "skl-reborn")
		wc.POST("/api/v1/skills", knowledgeC_skill("reborn", "first life", "FIRST edition")).OK(t, nil)
		wc.DELETE("/api/v1/skills/reborn")
		wc.Do("GET", "/api/v1/skills/reborn", nil).Fail(t, 404, "SKILL_NOT_FOUND")

		if r := wc.POST("/api/v1/skills", knowledgeC_skill("reborn", "second life", "SECOND edition")); r.Status != 201 {
			t.Fatalf("recreate after delete must be a clean 201 (no soft-delete name conflict), got %d %s", r.Status, r.Raw)
		}
		var got knowledgeC_skillWire
		wc.GET("/api/v1/skills/reborn").OK(t, &got)
		if got.Body != "SECOND edition" || got.Description != "second life" {
			t.Fatalf("recreated skill must carry the NEW content, got %+v", got)
		}
	})

	// A-skl-8：严格解码——POST/PUT 载荷带未知字段一律 400 INVALID_REQUEST（decodeJSON
	// DisallowUnknownFields），且被拒的 PUT 不得部分生效。
	t.Run("A-skl-8_unknown_fields_rejected", func(t *testing.T) {
		wc, _ := knowledgeC_newWS(t, srv, "skl-strict")
		wc.Do("POST", "/api/v1/skills", map[string]any{
			"name": "strict-a", "description": "d", "body": "b", "bogusField": true,
		}).Fail(t, 400, "INVALID_REQUEST")

		wc.POST("/api/v1/skills", knowledgeC_skill("strict-a", "orig", "orig body")).OK(t, nil)
		wc.Do("PUT", "/api/v1/skills/strict-a", map[string]any{
			"description": "patched", "body": "patched body", "surprise": 1,
		}).Fail(t, 400, "INVALID_REQUEST")

		var got knowledgeC_skillWire
		wc.GET("/api/v1/skills/strict-a").OK(t, &got)
		if got.Description != "orig" || got.Body != "orig body" {
			t.Fatalf("rejected PUT must not partially apply, got %+v", got)
		}
	})
}

// TestContractKnowledge_SkillGuards — B-sk-1 / B-sk-2 / B-sk-10：slug 正则既是身份也是
// 路径穿越守卫；body 自带 frontmatter 拒绝面；盘上坏 SKILL.md 扫描跳过不连坐。
func TestContractKnowledge_SkillGuards(t *testing.T) {
	srv := harness.Start(t)

	// B-sk-1：非法 name 矩阵（../ 穿越、绝对路径、分隔符、大写、unicode、超长、空白，及创建
	// 从严的规范拒项：下划线、连续/首位连字符——WRK-076 D3 双正则）全部 400 SKILL_INVALID_NAME；
	// 数字开头按 Agent Skills 规范**合法**（如 3d-print）；URL 段里的 %2F 编码穿越同拒；合法
	// slug 1:1 映射盘上目录；全数据目录无逃逸产物。
	t.Run("B-sk-1_slug_is_path_traversal_guard", func(t *testing.T) {
		wc, wsID := knowledgeC_newWS(t, srv, "skl-traversal")
		bad := []string{
			"../pwn", "..", "a/pwn", "/pwn-abs", `a\pwn`, "PWN-Upper",
			"スキルpwn", strings.Repeat("a", 65), "pwn name-space", "",
			"pwn_underscore", "pwn--double", "-pwn-lead", "pwn-trail-",
		}
		for _, n := range bad {
			wc.Do("POST", "/api/v1/skills", knowledgeC_skill(n, "d", "b")).
				Fail(t, 400, "SKILL_INVALID_NAME")
		}
		// URL 段级穿越（%2F 编码斜杠留在单段、PathValue 解码出 ../../）：同一道 slug 守卫拒。
		wc.Do("PUT", "/api/v1/skills/..%2F..%2Fpwn-url",
			map[string]any{"description": "d", "body": "b"}).Fail(t, 400, "SKILL_INVALID_NAME")
		wc.Do("GET", "/api/v1/skills/..%2F..%2Fpwn-url", nil).Fail(t, 400, "SKILL_INVALID_NAME")

		// 合法 slug（含规范允许的数字开头）→ <dataDir>/workspaces/<ws>/skills/<name>/SKILL.md 恰在其位。
		for _, good := range []string{"good-skill-1", "3d-print"} {
			wc.POST("/api/v1/skills", knowledgeC_skill(good, "legit", "hello")).OK(t, nil)
			want := filepath.Join(srv.DataDir, "workspaces", wsID, "skills", good, "SKILL.md")
			if _, err := os.Stat(want); err != nil {
				t.Fatalf("valid slug must map 1:1 to its directory, missing %s: %v", want, err)
			}
		}

		// 逃逸审计：数据目录全树 + 目录外兄弟位都不得出现任何 pwn 产物。
		var escaped []string
		_ = filepath.WalkDir(srv.DataDir, func(path string, _ os.DirEntry, err error) error {
			if err == nil && strings.Contains(strings.ToLower(filepath.Base(path)), "pwn") {
				escaped = append(escaped, path)
			}
			return nil
		})
		if len(escaped) > 0 {
			t.Fatalf("traversal attempts must leave zero artifacts, found %v", escaped)
		}
		if _, err := os.Stat(filepath.Join(srv.DataDir, "..", "pwn")); !os.IsNotExist(err) {
			t.Fatalf("traversal must not write outside the data dir")
		}
	})

	// B-sk-2：body 以自带 YAML frontmatter 块开头（--- 围栏 + 后续闭合围栏）→ 422
	// SKILL_INVALID_FRONTMATTER（否则双 frontmatter、body 里的 allowed-tools 被静默丢）；
	// 孤立 --- 分隔线（无闭合围栏 / 非开头）放行。附 frontmatter 拒绝面其余护栏：
	// description 必填/≤1024、body ≤32KB。
	t.Run("B-sk-2_body_frontmatter_fence_rules", func(t *testing.T) {
		wc, _ := knowledgeC_newWS(t, srv, "skl-fence")

		wc.Do("POST", "/api/v1/skills", knowledgeC_skill("fenced-a", "d",
			"---\nallowed-tools:\n  - run_function\n---\nreal content")).
			Fail(t, 422, "SKILL_INVALID_FRONTMATTER")
		// 开头围栏 + 很远处的闭合围栏——仍构成 frontmatter 块，拒。
		wc.Do("POST", "/api/v1/skills", knowledgeC_skill("fenced-b", "d",
			"---\n\nsection one\n\n---\n\nsection two")).
			Fail(t, 422, "SKILL_INVALID_FRONTMATTER")

		// 孤立分隔线两姿势放行：开头无闭合围栏 / 正文中间的围栏。
		wc.POST("/api/v1/skills", knowledgeC_skill("break-lead", "d",
			"---\njust a thematic break, never closed")).OK(t, nil)
		wc.POST("/api/v1/skills", knowledgeC_skill("break-mid", "d",
			"Part A\n\n---\n\nPart B")).OK(t, nil)

		// frontmatter 拒绝面其余护栏（domains/skill.md：description 必填 ≤1024、body ≤32KB）。
		wc.Do("POST", "/api/v1/skills", map[string]any{"name": "no-desc", "body": "b"}).
			Fail(t, 422, "SKILL_INVALID_FRONTMATTER")
		wc.Do("POST", "/api/v1/skills",
			knowledgeC_skill("desc-huge", strings.Repeat("d", 1025), "b")).
			Fail(t, 422, "SKILL_INVALID_FRONTMATTER")
		wc.Do("POST", "/api/v1/skills",
			knowledgeC_skill("body-huge", "d", strings.Repeat("x", 32*1024+1))).
			Fail(t, 422, "SKILL_BODY_TOO_LARGE")
	})

	// B-sk-10：盘上手写坏文件（缺围栏 / 坏 YAML / 超 32KB / 桶根散文件）——List 跳过坏件、
	// 其余健康 skill 照常在场；单读坏件 fail-loud 各返其码。
	t.Run("B-sk-10_bad_files_skipped_not_contagious", func(t *testing.T) {
		wc, wsID := knowledgeC_newWS(t, srv, "skl-badfiles")
		wc.POST("/api/v1/skills", knowledgeC_skill("alpha-ok", "healthy", "body a")).OK(t, nil)
		wc.POST("/api/v1/skills", knowledgeC_skill("beta-ok", "healthy", "body b")).OK(t, nil)

		bucket := filepath.Join(srv.DataDir, "workspaces", wsID, "skills")
		seed := func(dir, content string) {
			t.Helper()
			if err := os.MkdirAll(filepath.Join(bucket, dir), 0o755); err != nil {
				t.Fatalf("seed mkdir: %v", err)
			}
			if err := os.WriteFile(filepath.Join(bucket, dir, "SKILL.md"), []byte(content), 0o644); err != nil {
				t.Fatalf("seed write: %v", err)
			}
		}
		seed("badfm", "no frontmatter fence at all\n")
		seed("badyaml", "---\nname: [unclosed\n---\nbody\n")
		seed("toolarge", "---\nname: toolarge\ndescription: d\n---\n"+strings.Repeat("z", 33*1024))
		if err := os.WriteFile(filepath.Join(bucket, "stray.txt"), []byte("not a skill"), 0o644); err != nil {
			t.Fatalf("seed stray: %v", err)
		}

		var items []knowledgeC_skillWire
		wc.GET("/api/v1/skills").OK(t, &items)
		var names []string
		for _, it := range items {
			names = append(names, it.Name)
		}
		if len(names) != 2 || names[0] != "alpha-ok" || names[1] != "beta-ok" {
			t.Fatalf("list must skip broken files and keep the healthy set, got %v", names)
		}

		// 单读坏件 fail-loud（非 500）：各返自己的 4xx 码。
		wc.Do("GET", "/api/v1/skills/badfm", nil).Fail(t, 422, "SKILL_INVALID_FRONTMATTER")
		wc.Do("GET", "/api/v1/skills/badyaml", nil).Fail(t, 422, "SKILL_INVALID_FRONTMATTER")
		wc.Do("GET", "/api/v1/skills/toolarge", nil).Fail(t, 422, "SKILL_BODY_TOO_LARGE")
	})
}

// TestContractKnowledge_SkillActivateSurface — B-sk-5 / B-sk-7：REST :activate 的渲染面——
// !`cmd` shell 注入刻意不支持（字面保留、零执行痕迹）；fork 缺 agent 在创作期与激活期都拒。
func TestContractKnowledge_SkillActivateSurface(t *testing.T) {
	srv := harness.Start(t)

	// B-sk-5：body 携带 !`touch marker` 的 skill 激活后——$ARGUMENTS 正常替换、!`cmd` 原样
	// 留在渲染文本里（不是被剥离、更不是被执行）、盘上无 marker。
	t.Run("B-sk-5_no_shell_injection_on_activate", func(t *testing.T) {
		wc, _ := knowledgeC_newWS(t, srv, "skl-inject")
		marker := filepath.Join(srv.DataDir, "shell-injection-marker")
		body := "Deploy $ARGUMENTS now.\n!`touch " + marker + "`\nAlso !`rm -rf /tmp/nope`\nDone."
		wc.POST("/api/v1/skills", knowledgeC_skill("injector", "injection probe", body)).OK(t, nil)

		var rendered string
		wc.POST("/api/v1/skills/injector:activate",
			map[string]any{"arguments": []string{"blue", "green"}}).OK(t, &rendered)
		if !strings.Contains(rendered, "Deploy blue green now.") {
			t.Fatalf("$ARGUMENTS must substitute, got %q", rendered)
		}
		if !strings.Contains(rendered, "!`touch "+marker+"`") {
			t.Fatalf("!`cmd` must stay literal text (unsupported syntax, not stripped), got %q", rendered)
		}
		if _, err := os.Stat(marker); !os.IsNotExist(err) {
			t.Fatalf("!`cmd` must NEVER execute — marker file appeared (stat err=%v)", err)
		}
	})

	// B-sk-7：context=fork 缺 agent——创作期 422 SKILL_FORK_REQUIRES_AGENT；绕过创作校验
	// 直接手写盘上文件（文件用户可编辑是契约的一部分）后 :activate 同码拒。
	t.Run("B-sk-7_fork_requires_agent", func(t *testing.T) {
		wc, wsID := knowledgeC_newWS(t, srv, "skl-fork")
		in := knowledgeC_skill("forky", "fork without agent", "do the thing")
		in["context"] = "fork"
		wc.Do("POST", "/api/v1/skills", in).Fail(t, 422, "SKILL_FORK_REQUIRES_AGENT")

		dir := filepath.Join(srv.DataDir, "workspaces", wsID, "skills", "forkless")
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatalf("seed mkdir: %v", err)
		}
		file := "---\nname: forkless\ndescription: fork missing agent\ncontext: fork\nsource: user\n---\nBody here.\n"
		if err := os.WriteFile(filepath.Join(dir, "SKILL.md"), []byte(file), 0o644); err != nil {
			t.Fatalf("seed write: %v", err)
		}
		wc.Do("POST", "/api/v1/skills/forkless:activate", nil).Fail(t, 422, "SKILL_FORK_REQUIRES_AGENT")
	})
}

// TestContractKnowledge_MemorySurface — A-mem-2 / A-mem-3 / A-mem-4 / A-mem-7 / A-mem-8：
// memory REST 面（文件式,name 即 id）：错误码矩阵、N1 形状、全集列表 + pinned 过滤、
// pin/unpin 逐打 + upsert 保策展（F147）、未知字段拒绝。
func TestContractKnowledge_MemorySurface(t *testing.T) {
	srv := harness.Start(t)

	// A-mem-4：零 memory 时 List 返 data:[]；PUT upsert 返回完整 memory 形（200,非 201——
	// upsert 语义）；DELETE 204 空体。
	t.Run("A-mem-4_empty_list_and_upsert_shape", func(t *testing.T) {
		wc, _ := knowledgeC_newWS(t, srv, "mem-envelope")
		knowledgeC_assertEmptyArray(t, wc.GET("/api/v1/memories"))

		put := wc.PUT("/api/v1/memories/first-note",
			map[string]any{"description": "a note", "content": "remember this", "source": "user"})
		if put.Status != 200 {
			t.Fatalf("upsert is PUT→200 (create and update share the shape), got %d %s", put.Status, put.Raw)
		}
		var m knowledgeC_memWire
		put.OK(t, &m)
		if m.Name != "first-note" || m.Description != "a note" || m.Content != "remember this" ||
			m.Pinned || m.Source != "user" {
			t.Fatalf("upsert response must echo the full memory shape, got %+v", m)
		}
		// PUT 响应携带真文件 mtime（fs Save 落盘后 stat 回盖 UpdatedAt）——与 GET 回读一致,不再零值。
		if m.UpdatedAt.IsZero() {
			t.Fatalf("upsert response must carry the file mtime, got zero updatedAt")
		}

		// GET 回读则带真 mtime。
		var g knowledgeC_memWire
		wc.GET("/api/v1/memories/first-note").OK(t, &g)
		if g.UpdatedAt.IsZero() {
			t.Fatalf("GET must carry the file mtime, got zero updatedAt: %+v", g)
		}

		del := wc.DELETE("/api/v1/memories/first-note")
		if del.Status != 204 || len(del.Raw) != 0 {
			t.Fatalf("delete must be a bare 204, got %d body=%s", del.Status, del.Raw)
		}
		knowledgeC_assertEmptyArray(t, wc.GET("/api/v1/memories"))
	})

	// A-mem-2：错误面矩阵——未知 name 404 MEMORY_NOT_FOUND（GET/DELETE/pin）；坏 name
	// 400 MEMORY_INVALID_NAME（大写、%2F 穿越、超长）；坏 source 400 MEMORY_INVALID_SOURCE；
	// 缺 description/content 400 MEMORY_INVALID_INPUT。
	t.Run("A-mem-2_error_surface", func(t *testing.T) {
		wc, _ := knowledgeC_newWS(t, srv, "mem-errors")
		wc.Do("GET", "/api/v1/memories/ghost-note", nil).Fail(t, 404, "MEMORY_NOT_FOUND")
		wc.Do("DELETE", "/api/v1/memories/ghost-note", nil).Fail(t, 404, "MEMORY_NOT_FOUND")
		wc.Do("POST", "/api/v1/memories/ghost-note/pin", nil).Fail(t, 404, "MEMORY_NOT_FOUND")

		valid := map[string]any{"description": "d", "content": "c", "source": "user"}
		wc.Do("PUT", "/api/v1/memories/Upper-Case", valid).Fail(t, 400, "MEMORY_INVALID_NAME")
		wc.Do("PUT", "/api/v1/memories/..%2F..%2Fpwn-mem", valid).Fail(t, 400, "MEMORY_INVALID_NAME")
		wc.Do("PUT", "/api/v1/memories/"+strings.Repeat("m", 65), valid).Fail(t, 400, "MEMORY_INVALID_NAME")
		wc.Do("GET", "/api/v1/memories/Upper-Case", nil).Fail(t, 400, "MEMORY_INVALID_NAME")

		wc.Do("PUT", "/api/v1/memories/bad-source",
			map[string]any{"description": "d", "content": "c", "source": "robot"}).
			Fail(t, 400, "MEMORY_INVALID_SOURCE")
		wc.Do("PUT", "/api/v1/memories/no-content",
			map[string]any{"description": "d", "content": "   ", "source": "user"}).
			Fail(t, 400, "MEMORY_INVALID_INPUT")
		wc.Do("PUT", "/api/v1/memories/no-desc",
			map[string]any{"description": " ", "content": "c", "source": "user"}).
			Fail(t, 400, "MEMORY_INVALID_INPUT")

		// 穿越尝试零盘上产物。
		var escaped []string
		_ = filepath.WalkDir(srv.DataDir, func(path string, _ os.DirEntry, err error) error {
			if err == nil && strings.Contains(filepath.Base(path), "pwn-mem") {
				escaped = append(escaped, path)
			}
			return nil
		})
		if len(escaped) > 0 {
			t.Fatalf("memory name traversal must leave zero artifacts, found %v", escaped)
		}
	})

	// A-mem-3：List 是文件式全集（name 升序）；cursor/limit 被忽略（无分页——api.md memory 节
	// 无分页参数,与 skill 同为文件式契约,N4 张力入报告）；?pinned= 过滤真分拣。
	t.Run("A-mem-3_list_full_set_and_pinned_filter", func(t *testing.T) {
		wc, _ := knowledgeC_newWS(t, srv, "mem-list")
		for _, n := range []string{
			"m-01", "m-02", "m-03", "m-04", "m-05", "m-06",
			"m-07", "m-08", "m-09", "m-10", "m-11", "m-12",
		} {
			wc.PUT("/api/v1/memories/"+n,
				map[string]any{"description": "desc " + n, "content": "content " + n, "source": "user"}).OK(t, nil)
		}
		var items []knowledgeC_memWire
		wc.GET("/api/v1/memories").OK(t, &items)
		if len(items) != 12 {
			t.Fatalf("list must return the full set of 12, got %d", len(items))
		}
		for i := 1; i < len(items); i++ {
			if items[i-1].Name >= items[i].Name {
				t.Fatalf("list must sort by name asc, %s !< %s", items[i-1].Name, items[i].Name)
			}
		}

		paged := wc.GET("/api/v1/memories?cursor=bogus&limit=3")
		var again []knowledgeC_memWire
		paged.OK(t, &again)
		if len(again) != 12 || paged.NextCursor != "" || paged.HasMore {
			t.Fatalf("file-based memory list is unpaginated by contract: want 12 + no cursor coords, got %d nextCursor=%q hasMore=%v",
				len(again), paged.NextCursor, paged.HasMore)
		}

		// ?pinned= 过滤。
		wc.POST("/api/v1/memories/m-03/pin", nil).OK(t, nil)
		var pinned []knowledgeC_memWire
		wc.GET("/api/v1/memories?pinned=true").OK(t, &pinned)
		if len(pinned) != 1 || pinned[0].Name != "m-03" {
			t.Fatalf("?pinned=true must return exactly the pinned one, got %+v", pinned)
		}
		var rest []knowledgeC_memWire
		wc.GET("/api/v1/memories?pinned=false").OK(t, &rest)
		if len(rest) != 11 {
			t.Fatalf("?pinned=false must return the other 11, got %d", len(rest))
		}
	})

	// A-mem-7：pin/unpin 逐打——pin 置真、GET 持久可见、重复 pin 幂等 200；PUT 内容更新
	// **保留**策展（pinned 不被 body 拉回 false、source 作者归属不可变——F147）；unpin 置假幂等。
	t.Run("A-mem-7_pin_unpin_and_curation_preserved", func(t *testing.T) {
		wc, _ := knowledgeC_newWS(t, srv, "mem-pin")
		wc.PUT("/api/v1/memories/curated",
			map[string]any{"description": "curated note", "content": "v1", "source": "user"}).OK(t, nil)

		var m knowledgeC_memWire
		wc.POST("/api/v1/memories/curated/pin", nil).OK(t, &m)
		if !m.Pinned {
			t.Fatalf("pin must flip pinned=true, got %+v", m)
		}
		wc.GET("/api/v1/memories/curated").OK(t, &m)
		if !m.Pinned {
			t.Fatalf("pin must persist to the file, got %+v", m)
		}
		wc.POST("/api/v1/memories/curated/pin", nil).OK(t, &m) // 幂等重打
		if !m.Pinned {
			t.Fatalf("re-pin must stay pinned (idempotent), got %+v", m)
		}

		// 内容更新永不降级策展：body 里的 pinned:false / source:ai 被忽略（F147）。
		wc.PUT("/api/v1/memories/curated",
			map[string]any{"description": "curated note", "content": "v2", "pinned": false, "source": "ai"}).OK(t, &m)
		if m.Content != "v2" || !m.Pinned || m.Source != "user" {
			t.Fatalf("content update must preserve pinned+source curation (F147), got %+v", m)
		}
		wc.GET("/api/v1/memories/curated").OK(t, &m)
		if m.Content != "v2" || !m.Pinned || m.Source != "user" {
			t.Fatalf("curation must persist after content update, got %+v", m)
		}

		wc.POST("/api/v1/memories/curated/unpin", nil).OK(t, &m)
		if m.Pinned {
			t.Fatalf("unpin must flip pinned=false, got %+v", m)
		}
		wc.POST("/api/v1/memories/curated/unpin", nil).OK(t, &m) // 幂等重打
		if m.Pinned {
			t.Fatalf("re-unpin must stay unpinned (idempotent), got %+v", m)
		}
		wc.GET("/api/v1/memories/curated").OK(t, &m)
		if m.Pinned {
			t.Fatalf("unpin must persist, got %+v", m)
		}
	})

	// A-mem-8：严格解码——PUT 载荷带未知字段 400 INVALID_REQUEST，且不部分生效。
	t.Run("A-mem-8_unknown_fields_rejected", func(t *testing.T) {
		wc, _ := knowledgeC_newWS(t, srv, "mem-strict")
		wc.PUT("/api/v1/memories/strict-m",
			map[string]any{"description": "orig", "content": "orig", "source": "user"}).OK(t, nil)
		wc.Do("PUT", "/api/v1/memories/strict-m", map[string]any{
			"description": "patched", "content": "patched", "source": "user", "extraField": 1,
		}).Fail(t, 400, "INVALID_REQUEST")

		var m knowledgeC_memWire
		wc.GET("/api/v1/memories/strict-m").OK(t, &m)
		if m.Description != "orig" || m.Content != "orig" {
			t.Fatalf("rejected PUT must not partially apply, got %+v", m)
		}
	})
}

// TestContractKnowledge_SkillFilesSurface — B-sk-f1..f4（WRK-076 B1「文件即真相」）：files
// 子资源的裸字节 CRUD、编码穿越拒于守卫 + 全数据目录零逃逸产物、清单特判（校验路由 / 拒删 /
// name==目录名）、frontmatter 保真（license/未知键/键序经结构化 PUT 幸存——契约级保真守护）、
// 双护栏（清单 32KB / 附属 1MB）。
func TestContractKnowledge_SkillFilesSurface(t *testing.T) {
	srv := harness.Start(t)

	t.Run("B-sk-f1_raw_crud_roundtrip", func(t *testing.T) {
		wc, _ := knowledgeC_newWS(t, srv, "skl-files-crud")
		wc.POST("/api/v1/skills", knowledgeC_skill("pdf", "d", "b")).OK(t, nil)

		// PUT 嵌套裸字节 → 204 空体；GET 裸字节回读 + 按扩展名的 Content-Type。
		if r := wc.DoRaw("PUT", "/api/v1/skills/pdf/files/references/deep/notes.md", "text/markdown", []byte("# notes")); r.Status != 204 {
			t.Fatalf("nested raw put: %d %s", r.Status, r.Raw)
		}
		got := wc.DoRaw("GET", "/api/v1/skills/pdf/files/references/deep/notes.md", "", nil)
		if got.Status != 200 || string(got.Raw) != "# notes" {
			t.Fatalf("raw read back: %d %q", got.Status, got.Raw)
		}

		// 列表（JSON envelope）含清单与嵌套文件，slash 相对路径、按路径排序。
		var files []struct {
			Path string `json:"path"`
			Size int64  `json:"size"`
		}
		wc.GET("/api/v1/skills/pdf/files").OK(t, &files)
		if len(files) != 2 || files[0].Path != "SKILL.md" || files[1].Path != "references/deep/notes.md" {
			t.Fatalf("file list shape: %+v", files)
		}

		// DELETE → 204；再读 404 SKILL_FILE_NOT_FOUND；重删同码。
		if r := wc.DoRaw("DELETE", "/api/v1/skills/pdf/files/references/deep/notes.md", "", nil); r.Status != 204 {
			t.Fatalf("raw delete: %d %s", r.Status, r.Raw)
		}
		wc.DoRaw("GET", "/api/v1/skills/pdf/files/references/deep/notes.md", "", nil).Fail(t, 404, "SKILL_FILE_NOT_FOUND")
		wc.DoRaw("DELETE", "/api/v1/skills/pdf/files/references/deep/notes.md", "", nil).Fail(t, 404, "SKILL_FILE_NOT_FOUND")

		// 未知 skill 的 files 面 → SKILL_NOT_FOUND（skill 级 404，非 file 级）。
		wc.GET("/api/v1/skills/ghost/files").Fail(t, 404, "SKILL_NOT_FOUND")
	})

	t.Run("B-sk-f2_traversal_guard_and_escape_audit", func(t *testing.T) {
		wc, _ := knowledgeC_newWS(t, srv, "skl-files-guard")
		wc.POST("/api/v1/skills", knowledgeC_skill("guarded", "d", "b")).OK(t, nil)

		// 单段内 %2F 编码穿越：PathValue 解码出 ../../ → 词法守卫 400 SKILL_FILE_PATH_INVALID。
		wc.DoRaw("PUT", "/api/v1/skills/guarded/files/..%2F..%2F..%2Fpwn-file", "", []byte("owned")).
			Fail(t, 400, "SKILL_FILE_PATH_INVALID")
		wc.DoRaw("GET", "/api/v1/skills/guarded/files/..%2F..%2Fpwn-file", "", nil).
			Fail(t, 400, "SKILL_FILE_PATH_INVALID")
		// 反斜杠形态同拒。
		wc.DoRaw("PUT", "/api/v1/skills/guarded/files/a%5Cpwn-file", "", []byte("owned")).
			Fail(t, 400, "SKILL_FILE_PATH_INVALID")

		// 多段 /../ 形态可能在 mux 层被 clean 重定向——安全语义统一由逃逸审计兜底：
		// 全数据目录树 + 目录外兄弟位零 pwn 产物。
		_, _ = wc.Try("PUT", "/api/v1/skills/guarded/files/references/../../../pwn-file", nil)
		var escaped []string
		_ = filepath.WalkDir(srv.DataDir, func(path string, _ os.DirEntry, err error) error {
			if err == nil && strings.Contains(strings.ToLower(filepath.Base(path)), "pwn") {
				escaped = append(escaped, path)
			}
			return nil
		})
		if len(escaped) > 0 {
			t.Fatalf("files traversal must leave zero artifacts, found %v", escaped)
		}
		if _, err := os.Stat(filepath.Join(srv.DataDir, "..", "pwn-file")); !os.IsNotExist(err) {
			t.Fatalf("files traversal must not write outside the data dir")
		}
	})

	t.Run("B-sk-f3_manifest_special_casing_and_fidelity", func(t *testing.T) {
		wc, _ := knowledgeC_newWS(t, srv, "skl-files-manifest")
		wc.POST("/api/v1/skills", knowledgeC_skill("fidelity-probe", "original", "old body")).OK(t, nil)

		// 清单 PUT 无围栏 → 422；frontmatter name != 目录名 → 422；删清单 → 400 指向正门。
		wc.DoRaw("PUT", "/api/v1/skills/fidelity-probe/files/SKILL.md", "", []byte("no fence at all")).
			Fail(t, 422, "SKILL_INVALID_FRONTMATTER")
		wc.DoRaw("PUT", "/api/v1/skills/fidelity-probe/files/SKILL.md", "",
			[]byte("---\nname: other-name\ndescription: d\n---\nb\n")).
			Fail(t, 422, "SKILL_INVALID_FRONTMATTER")
		wc.DoRaw("DELETE", "/api/v1/skills/fidelity-probe/files/SKILL.md", "", nil).
			Fail(t, 400, "SKILL_FILE_PATH_INVALID")

		// 合法原文 PUT：license + 未知键 + metadata + 刻意键序（license 在 name 前）。
		raw := "---\nlicense: MIT\nname: fidelity-probe\nx-vendor-thing: keepme\ndescription: via files\nmetadata:\n  author: upstream\n---\nNew body.\n"
		if r := wc.DoRaw("PUT", "/api/v1/skills/fidelity-probe/files/SKILL.md", "text/markdown", []byte(raw)); r.Status != 204 {
			t.Fatalf("manifest raw put: %d %s", r.Status, r.Raw)
		}
		var sk struct {
			Description string `json:"description"`
			Frontmatter struct {
				License  string            `json:"license"`
				Metadata map[string]string `json:"metadata"`
			} `json:"frontmatter"`
		}
		wc.GET("/api/v1/skills/fidelity-probe").OK(t, &sk)
		if sk.Description != "via files" || sk.Frontmatter.License != "MIT" || sk.Frontmatter.Metadata["author"] != "upstream" {
			t.Fatalf("raw manifest not reflected in typed projection: %+v", sk)
		}

		// 结构化 PUT（旧 API）只改 description → 未知键 / license / metadata / 键序必须幸存。
		wc.PUT("/api/v1/skills/fidelity-probe", map[string]any{
			"description": "structured edit", "body": "New body.",
		}).OK(t, nil)
		after := wc.DoRaw("GET", "/api/v1/skills/fidelity-probe/files/SKILL.md", "", nil)
		text := string(after.Raw)
		for _, want := range []string{"license: MIT", "x-vendor-thing: keepme", "author: upstream", "description: structured edit"} {
			if !strings.Contains(text, want) {
				t.Fatalf("fidelity lost %q after structured PUT:\n%s", want, text)
			}
		}
		if strings.Index(text, "license:") > strings.Index(text, "name:") {
			t.Fatalf("key order must survive structured PUT:\n%s", text)
		}
	})

	t.Run("B-sk-f4_dual_size_guards", func(t *testing.T) {
		wc, _ := knowledgeC_newWS(t, srv, "skl-files-guards")
		wc.POST("/api/v1/skills", knowledgeC_skill("bulky", "d", "b")).OK(t, nil)

		// 清单 32KB 护栏（经 files 面同样生效）。
		bigManifest := "---\nname: bulky\ndescription: d\n---\n" + strings.Repeat("a", 32*1024)
		wc.DoRaw("PUT", "/api/v1/skills/bulky/files/SKILL.md", "", []byte(bigManifest)).
			Fail(t, 422, "SKILL_BODY_TOO_LARGE")
		// 附属文件 1MB 护栏。
		wc.DoRaw("PUT", "/api/v1/skills/bulky/files/assets/huge.bin", "", bytes.Repeat([]byte("a"), 1024*1024+1)).
			Fail(t, 422, "SKILL_FILE_TOO_LARGE")
	})
}
