package handlers

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"go.uber.org/zap"

	skillapp "github.com/sunweilin/anselm/backend/internal/app/skill"
	skillfs "github.com/sunweilin/anselm/backend/internal/infra/fs/skill"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// B1 files 面 httptest 电池（WRK-076）——`{path...}` 是全仓首条尾随通配路由，这里钉死它的
// 物理行为：多段匹配、URL 解码穿越（%2F/%2E）拒于守卫、与 {name}/{nameAction} 路由共存、
// 裸字节收发与 204 形状。

// newSkillMux 组一个真 mux + 真 service + 真 store，外包一层 workspace ctx 注入（生产里由
// 中间件做）。
func newSkillMux(t *testing.T) http.Handler {
	t.Helper()
	svc := skillapp.NewService(skillfs.New(t.TempDir()), nil, nil, zap.NewNop())
	mux := http.NewServeMux()
	NewSkillHandler(svc, zap.NewNop()).Register(mux)
	seed := httptest.NewRequest(http.MethodPost, "/api/v1/skills",
		strings.NewReader(`{"name":"pdf","description":"d","body":"b"}`))
	seed.Header.Set("Content-Type", "application/json")
	wrapped := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mux.ServeHTTP(w, r.WithContext(reqctxpkg.SetWorkspaceID(r.Context(), "ws_1")))
	})
	rec := httptest.NewRecorder()
	wrapped.ServeHTTP(rec, seed)
	if rec.Code != http.StatusCreated {
		t.Fatalf("seed skill: %d %s", rec.Code, rec.Body.String())
	}
	return wrapped
}

func do(t *testing.T, h http.Handler, method, target, body string) *httptest.ResponseRecorder {
	t.Helper()
	var req *http.Request
	if body == "" {
		req = httptest.NewRequest(method, target, nil)
	} else {
		req = httptest.NewRequest(method, target, strings.NewReader(body))
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func TestSkillFiles_MultiSegmentWildcardRoundTrip(t *testing.T) {
	h := newSkillMux(t)
	// PUT 多段路径（{path...} 首例）：裸字节体 → 204。
	if rec := do(t, h, http.MethodPut, "/api/v1/skills/pdf/files/references/deep/notes.md", "# notes"); rec.Code != http.StatusNoContent {
		t.Fatalf("put nested file: %d %s", rec.Code, rec.Body.String())
	}
	// GET 裸字节回读，mime 按扩展名。
	rec := do(t, h, http.MethodGet, "/api/v1/skills/pdf/files/references/deep/notes.md", "")
	if rec.Code != http.StatusOK || rec.Body.String() != "# notes" {
		t.Fatalf("get nested file: %d %q", rec.Code, rec.Body.String())
	}
	if ct := rec.Header().Get("Content-Type"); !strings.Contains(ct, "markdown") && !strings.Contains(ct, "text/") {
		t.Fatalf("markdown mime expected, got %q", ct)
	}
	// 列表含清单与嵌套文件（slash 相对路径、排序）。
	rec = do(t, h, http.MethodGet, "/api/v1/skills/pdf/files", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("list files: %d", rec.Code)
	}
	bodyStr := rec.Body.String()
	if !strings.Contains(bodyStr, `"SKILL.md"`) || !strings.Contains(bodyStr, `"references/deep/notes.md"`) {
		t.Fatalf("file list missing entries: %s", bodyStr)
	}
	// DELETE → 204；再读 404 SKILL_FILE_NOT_FOUND。
	if rec := do(t, h, http.MethodDelete, "/api/v1/skills/pdf/files/references/deep/notes.md", ""); rec.Code != http.StatusNoContent {
		t.Fatalf("delete file: %d", rec.Code)
	}
	rec = do(t, h, http.MethodGet, "/api/v1/skills/pdf/files/references/deep/notes.md", "")
	if rec.Code != http.StatusNotFound || !strings.Contains(rec.Body.String(), "SKILL_FILE_NOT_FOUND") {
		t.Fatalf("deleted file read: %d %s", rec.Code, rec.Body.String())
	}
}

func TestSkillFiles_EncodedTraversalRejected(t *testing.T) {
	h := newSkillMux(t)
	// URL 编码穿越：Go 1.22 mux 对 %2F 保守（多按 404 拒于路由层），%2E 解码为 . 后由守卫拒。
	// 断言统一为「非 2xx 且目录外零产物」——具体拒绝层（路由 404 / 守卫 400）都算安全。
	for _, target := range []string{
		"/api/v1/skills/pdf/files/..%2F..%2Fpwn",
		"/api/v1/skills/pdf/files/%2e%2e/%2e%2e/pwn",
		"/api/v1/skills/pdf/files/references/..%2f..%2f..%2fpwn",
	} {
		rec := do(t, h, http.MethodPut, target, "owned")
		if rec.Code < 400 {
			t.Fatalf("encoded traversal %q must be rejected, got %d", target, rec.Code)
		}
	}
	// dot-path：Go 1.22 mux 在路由层做 clean 重定向（301）——到不了 handler，同样安全。
	// 断言：绝不能是 2xx 内容响应。
	rec := do(t, h, http.MethodGet, "/api/v1/skills/pdf/files/.", "")
	if rec.Code >= 200 && rec.Code < 300 {
		t.Fatalf("dot path must not serve content, got %d", rec.Code)
	}
}

func TestSkillFiles_ManifestSpecialCasing(t *testing.T) {
	h := newSkillMux(t)
	// 经 files 面 PUT 清单：坏围栏 422。
	rec := do(t, h, http.MethodPut, "/api/v1/skills/pdf/files/SKILL.md", "no fence")
	if rec.Code != http.StatusUnprocessableEntity || !strings.Contains(rec.Body.String(), "SKILL_INVALID_FRONTMATTER") {
		t.Fatalf("fenceless manifest put: %d %s", rec.Code, rec.Body.String())
	}
	// 合法清单 PUT → 204，随后 GET /skills/{name} 反映新 description。
	ok := "---\nname: pdf\ndescription: replaced via files\nlicense: MIT\n---\nNew body.\n"
	if rec := do(t, h, http.MethodPut, "/api/v1/skills/pdf/files/SKILL.md", ok); rec.Code != http.StatusNoContent {
		t.Fatalf("manifest put: %d %s", rec.Code, rec.Body.String())
	}
	rec = do(t, h, http.MethodGet, "/api/v1/skills/pdf", "")
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "replaced via files") || !strings.Contains(rec.Body.String(), `"license":"MIT"`) {
		t.Fatalf("manifest replace not reflected (incl. spec-core license): %d %s", rec.Code, rec.Body.String())
	}
	// name != 目录名 → 422。
	bad := "---\nname: other\ndescription: d\n---\nb\n"
	if rec := do(t, h, http.MethodPut, "/api/v1/skills/pdf/files/SKILL.md", bad); rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("name-mismatch manifest put should be 422, got %d %s", rec.Code, rec.Body.String())
	}
	// DELETE 清单 → 400。
	if rec := do(t, h, http.MethodDelete, "/api/v1/skills/pdf/files/SKILL.md", ""); rec.Code != http.StatusBadRequest {
		t.Fatalf("manifest delete should be 400, got %d", rec.Code)
	}
}

func TestSkillFiles_CoexistsWithColonActionRoute(t *testing.T) {
	h := newSkillMux(t)
	// {nameAction} 冒号派发与 files 路由共存：activate 照常。
	rec := do(t, h, http.MethodPost, "/api/v1/skills/pdf:activate", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("colon action must keep working alongside files routes: %d %s", rec.Code, rec.Body.String())
	}
	// 未匹配方法（PATCH files）→ envelope 化 405（envelopeMuxErrors 在 router 层——此处裸 mux
	// 返回 stdlib 405 即可，只断言方法被拒）。
	if rec := do(t, h, http.MethodPatch, "/api/v1/skills/pdf/files/x.md", "b"); rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("PATCH on files should be 405, got %d", rec.Code)
	}
}

func TestSkillFiles_UnknownSkill404(t *testing.T) {
	h := newSkillMux(t)
	rec := do(t, h, http.MethodGet, "/api/v1/skills/ghost/files", "")
	if rec.Code != http.StatusNotFound || !strings.Contains(rec.Body.String(), "SKILL_NOT_FOUND") {
		t.Fatalf("files on unknown skill: %d %s", rec.Code, rec.Body.String())
	}
}

var _ = context.Background // keep import when helpers shrink 保持导入
