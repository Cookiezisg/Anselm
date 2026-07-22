// skill_install_test.go — WRK-076 B4 安装通道黑盒：本地 tarball server 供源，真二进制走
// inspect → install → source 推导 → 信任门（approve-tools）→ update（漂移拒/force 过）全链。
package scenarios

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// installC_tgz 构造内存 gzip tarball。
func installC_tgz(t *testing.T, files map[string]string) []byte {
	t.Helper()
	var buf bytes.Buffer
	gz := gzip.NewWriter(&buf)
	tw := tar.NewWriter(gz)
	for name, content := range files {
		if err := tw.WriteHeader(&tar.Header{Name: name, Mode: 0o644, Size: int64(len(content)), Typeflag: tar.TypeReg}); err != nil {
			t.Fatalf("tar hdr: %v", err)
		}
		if _, err := tw.Write([]byte(content)); err != nil {
			t.Fatalf("tar write: %v", err)
		}
	}
	_ = tw.Close()
	_ = gz.Close()
	return buf.Bytes()
}

func TestSkillInstall_FullChain(t *testing.T) {
	srv := harness.Start(t)
	wc, _ := knowledgeC_newWS(t, srv, "skl-install")

	body := installC_tgz(t, map[string]string{
		"repo-main/skills/pdf/SKILL.md":     "---\nname: pdf\ndescription: pdf powers\nallowed-tools:\n  - run_function\nlicense: MIT\n---\nINSTALLMARK do pdf things.\n",
		"repo-main/skills/pdf/scripts/x.py": "print('hi')",
		"repo-main/skills/broken/SKILL.md":  "no fence at all",
	})
	tarSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write(body)
	}))
	defer tarSrv.Close()

	// inspect：可装与不可装并列，allowed-tools 前置亮相。
	var previews []struct {
		Name         string   `json:"name"`
		Installable  bool     `json:"installable"`
		AllowedTools []string `json:"allowedTools"`
		Reason       string   `json:"reason"`
		FileCount    int      `json:"fileCount"`
	}
	wc.POST("/api/v1/skills:inspect-source", map[string]any{"source": tarSrv.URL}).OK(t, &previews)
	if len(previews) != 2 {
		t.Fatalf("want 2 candidates, got %+v", previews)
	}
	byName := map[string]int{}
	for i, p := range previews {
		byName[p.Name] = i
	}
	pdf := previews[byName["pdf"]]
	if !pdf.Installable || len(pdf.AllowedTools) != 1 || pdf.AllowedTools[0] != "run_function" || pdf.FileCount != 2 {
		t.Fatalf("pdf preview: %+v", pdf)
	}
	if broken := previews[byName["broken"]]; broken.Installable || broken.Reason == "" {
		t.Fatalf("broken candidate must be honest: %+v", broken)
	}

	// install：只装 pdf；broken 未点名不出现在结果。
	var res struct {
		Installed []string          `json:"installed"`
		Skipped   map[string]string `json:"skipped"`
	}
	wc.POST("/api/v1/skills:install", map[string]any{"source": tarSrv.URL, "names": []string{"pdf"}}).OK(t, &res)
	if len(res.Installed) != 1 || res.Installed[0] != "pdf" {
		t.Fatalf("install result: %+v", res)
	}

	// source=installed 推导 + provenance 附带 + 信任门初始关。
	var sk struct {
		Source      string `json:"source"`
		Body        string `json:"body"`
		Frontmatter struct {
			License string `json:"license"`
		} `json:"frontmatter"`
		Provenance *struct {
			Source        string `json:"source"`
			ToolsApproved bool   `json:"toolsApproved"`
		} `json:"provenance"`
	}
	wc.GET("/api/v1/skills/pdf").OK(t, &sk)
	if sk.Source != "installed" || sk.Provenance == nil || sk.Provenance.ToolsApproved {
		t.Fatalf("installed skill projection: %+v", sk)
	}
	if sk.Frontmatter.License != "MIT" || !strings.Contains(sk.Body, "INSTALLMARK") {
		t.Fatalf("installed content mismatch: %+v", sk)
	}
	// 附属文件真在盘上（files 面可读）。
	got := wc.DoRaw("GET", "/api/v1/skills/pdf/files/scripts/x.py", "", nil)
	if got.Status != 200 || string(got.Raw) != "print('hi')" {
		t.Fatalf("bundled file must land: %d %q", got.Status, got.Raw)
	}

	// 信任门翻转：approve-tools → provenance.toolsApproved=true。
	wc.Do("POST", "/api/v1/skills/pdf:approve-tools", nil).OK(t, &sk)
	if sk.Provenance == nil || !sk.Provenance.ToolsApproved {
		t.Fatalf("approve-tools must flip the gate: %+v", sk)
	}
	// 非安装 skill 的 approve-tools → 422 SKILL_NOT_INSTALLED。
	wc.POST("/api/v1/skills", knowledgeC_skill("hand-made", "d", "b")).OK(t, nil)
	wc.Do("POST", "/api/v1/skills/hand-made:approve-tools", nil).Fail(t, 422, "SKILL_NOT_INSTALLED")

	// update：本地改动 → 409 SKILL_LOCALLY_MODIFIED；force → 覆盖回上游内容。
	if r := wc.DoRaw("PUT", "/api/v1/skills/pdf/files/scripts/x.py", "", []byte("print('edited')")); r.Status != 204 {
		t.Fatalf("local edit: %d", r.Status)
	}
	wc.Do("POST", "/api/v1/skills/pdf:update", nil).Fail(t, 409, "SKILL_LOCALLY_MODIFIED")
	wc.Do("POST", "/api/v1/skills/pdf:update", map[string]any{"force": true}).OK(t, &sk)
	back := wc.DoRaw("GET", "/api/v1/skills/pdf/files/scripts/x.py", "", nil)
	if string(back.Raw) != "print('hi')" {
		t.Fatalf("force update must restore upstream content, got %q", back.Raw)
	}

	// 坏来源：非 tarball → 502 SKILL_INSTALL_FETCH_FAILED；坏形态 → 400。
	junk := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("not a tarball"))
	}))
	defer junk.Close()
	wc.Do("POST", "/api/v1/skills:inspect-source", map[string]any{"source": junk.URL}).
		Fail(t, 502, "SKILL_INSTALL_FETCH_FAILED")
	wc.Do("POST", "/api/v1/skills:inspect-source", map[string]any{"source": "not a source"}).
		Fail(t, 400, "SKILL_INSTALL_SOURCE_INVALID")
}
