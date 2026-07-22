// Command seed furnishes a running dev backend with a standard demo dataset over REAL HTTP —
// the one-command acceptance stage for `make app` and for exploratory curl probing (W4): a
// workspace, functions, a handler, an agent, skills (one binding a function id in allowed-tools,
// one with a bundled file), documents (wikilinked), and a conversation. Idempotent: the workspace
// is reused by name and per-entity name conflicts are skipped, so re-running never duplicates.
// It ends by printing the probe env (base URL + workspace header) ready to eval/copy.
//
// Command seed 用真 HTTP 给跑着的 dev 后端灌标准演示数据——make app 与探索式 curl 验证的一键现场
// (W4):workspace、function、handler、agent、skill(一个 allowed-tools 绑 fn id、一个带捆绑文件)、
// document(带 wikilink)、conversation。幂等:workspace 按名复用、实体撞名跳过,重跑不重复。
// 末尾打印 probe env(BASE + workspace 头),可 eval/复制。
package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"os"
	"time"
)

var (
	base = flag.String("base", "http://127.0.0.1:8742", "dev backend base URL")
	ws   string
)

func main() {
	flag.Parse()
	if !healthy() {
		fmt.Fprintf(os.Stderr, "seed: no backend at %s — start one first: make -C backend run\n", *base)
		os.Exit(1)
	}

	ws = ensureWorkspace("演示工作台")

	fnGreet := ensure("functions", map[string]any{
		"name": "greet", "description": "打个招呼",
		"code": "def f(name: str) -> dict:\n    return {\"msg\": f\"你好, {name}!\"}\n",
	})
	ensure("functions", map[string]any{
		"name": "sync_inventory", "description": "同步库存快照",
		"code": "def f() -> dict:\n    return {\"synced\": 42}\n",
	})
	ensure("handlers", map[string]any{
		"name": "order_desk", "description": "订单台",
		"methods": []map[string]any{
			{"name": "place", "inputs": []any{}, "body": "return {\"ok\": True}"},
			{"name": "cancel", "inputs": []any{}, "body": "return {\"ok\": True}"},
		},
	})
	ensure("agents", map[string]any{
		"name": "报表助手", "description": "整理周报", "prompt": "你负责整理每周运营周报。",
	})

	allowed := []string{"Read", "Bash(git:*)"}
	if fnGreet != "" {
		allowed = append(allowed, fnGreet) // fn id in allowed-tools → equip edge 绑定演示
	}
	ensure("skills", map[string]any{
		"name": "deploy-helper", "description": "安全发布一个版本",
		"body": "# Deploy\n\n## Steps\n\n1. 检查工作区\n2. 发布\n\n## Rollback\n\n回滚步骤。\n", "context": "inline",
		"allowedTools": allowed,
	})
	if ensure("skills", map[string]any{
		"name": "commit-helper", "description": "规范提交信息",
		"body": "# Commit helper\n\n用法见 GUIDE.md。\n", "context": "inline",
	}) != "" {
		putRaw("/api/v1/skills/commit-helper/files/GUIDE.md",
			"# Guide\n\n## 格式\n\ntype(scope): subject\n")
	}

	// Documents/conversations have no unique-name constraint (a 409 will never come) — dedupe by
	// listing first. 文档/对话无唯一名约束(等不来 409),先列表查重。
	if !nameExists("/api/v1/documents/tree", "上手指南") {
		docA := ensure("documents", map[string]any{
			"name": "上手指南", "content": "# 上手指南\n\n## 三岛\n\n左岛导航、海洋内容、右岛检查器。\n",
		})
		if docA != "" {
			ensure("documents", map[string]any{
				"name": "运营手册", "content": "# 运营手册\n\n参见 [[" + docA + "]]。\n\n## 周任务\n\n每周一轮换 key。\n",
			})
		}
	} else {
		fmt.Println("  = documents     上手指南/运营手册 (already there)")
	}
	if !nameExists("/api/v1/conversations", "演示对话") {
		ensure("conversations", map[string]any{"title": "演示对话"})
	} else {
		fmt.Println("  = conversations 演示对话 (already there)")
	}

	fmt.Println()
	fmt.Println("✓ seeded (idempotent — reruns reuse the workspace and skip name conflicts)")
	fmt.Println()
	fmt.Printf("export ANSELM_BASE=%s\n", *base)
	fmt.Printf("export ANSELM_WS=%s\n", ws)
	fmt.Println(`# probe 示例: curl -s -H "X-Anselm-Workspace-ID: $ANSELM_WS" $ANSELM_BASE/api/v1/skills | head -c 300`)
}

func healthy() bool {
	c := http.Client{Timeout: 2 * time.Second}
	r, err := c.Get(*base + "/api/v1/health")
	if err != nil {
		return false
	}
	defer r.Body.Close()
	return r.StatusCode == 200
}

// nameExists reports whether any row in the listing carries the name/title. 列表里有无同名/同题行。
func nameExists(listPath, name string) bool {
	var list struct {
		Data []struct {
			Name  string `json:"name"`
			Title string `json:"title"`
		} `json:"data"`
	}
	get(listPath, &list)
	for _, row := range list.Data {
		if row.Name == name || row.Title == name {
			return true
		}
	}
	return false
}

// ensureWorkspace finds the named workspace or creates it. 按名找或建 workspace。
func ensureWorkspace(name string) string {
	var list struct {
		Data []struct {
			ID   string `json:"id"`
			Name string `json:"name"`
		} `json:"data"`
	}
	get("/api/v1/workspaces", &list)
	for _, w := range list.Data {
		if w.Name == name {
			return w.ID
		}
	}
	var created struct {
		Data struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	status := do("POST", "/api/v1/workspaces", map[string]any{"name": name}, &created, false)
	if status >= 300 || created.Data.ID == "" {
		fmt.Fprintf(os.Stderr, "seed: create workspace failed (%d)\n", status)
		os.Exit(1)
	}
	return created.Data.ID
}

// ensure POSTs one entity; a 2xx returns its id, a conflict (409) is the idempotent no-op path.
// 建一个实体;2xx 返 id,409 撞名=幂等跳过。
func ensure(resource string, body map[string]any) string {
	var out struct {
		Data struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	label := body["name"]
	if label == nil {
		label = body["title"] // conversations are titled, not named 对话用 title
	}
	status := do("POST", "/api/v1/"+resource, body, &out, true)
	switch {
	case status < 300:
		fmt.Printf("  + %-13s %v\n", resource, label)
		return out.Data.ID
	case status == 409:
		fmt.Printf("  = %-13s %v (already there)\n", resource, label)
		return ""
	default:
		fmt.Fprintf(os.Stderr, "  ✗ %-13s %v → %d\n", resource, label, status)
		return ""
	}
}

func putRaw(path, content string) {
	req, _ := http.NewRequest("PUT", *base+path, bytes.NewReader([]byte(content)))
	req.Header.Set("X-Anselm-Workspace-ID", ws)
	req.Header.Set("Content-Type", "application/octet-stream")
	if r, err := http.DefaultClient.Do(req); err == nil {
		r.Body.Close()
	}
}

func get(path string, out any) {
	req, _ := http.NewRequest("GET", *base+path, nil)
	if ws != "" {
		req.Header.Set("X-Anselm-Workspace-ID", ws)
	}
	r, err := http.DefaultClient.Do(req)
	if err != nil {
		return
	}
	defer r.Body.Close()
	_ = json.NewDecoder(r.Body).Decode(out)
}

func do(method, path string, body map[string]any, out any, withWS bool) int {
	b, _ := json.Marshal(body)
	req, _ := http.NewRequest(method, *base+path, bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	if withWS && ws != "" {
		req.Header.Set("X-Anselm-Workspace-ID", ws)
	}
	r, err := http.DefaultClient.Do(req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "seed: %s %s: %v\n", method, path, err)
		os.Exit(1)
	}
	defer r.Body.Close()
	if out != nil {
		_ = json.NewDecoder(r.Body).Decode(out)
	}
	return r.StatusCode
}
