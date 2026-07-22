package skillfetch

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	skilldomain "github.com/sunweilin/anselm/backend/internal/domain/skill"
)

func TestParseSource_Matrix(t *testing.T) {
	cases := []struct {
		in                      string
		repo, ref, subdir, host string
		wantErr                 bool
	}{
		{in: "anthropics/skills", repo: "anthropics/skills", host: "codeload.github.com"},
		{in: "anthropics/skills@main#skills/pdf", repo: "anthropics/skills", ref: "main", subdir: "skills/pdf", host: "codeload.github.com"},
		{in: "https://github.com/anthropics/skills", repo: "anthropics/skills", host: "codeload.github.com"},
		{in: "https://github.com/anthropics/skills/tree/main/skills/pdf", repo: "anthropics/skills", ref: "main", subdir: "skills/pdf", host: "codeload.github.com"},
		{in: "https://example.com/my.tar.gz", host: "example.com"},
		{in: "", wantErr: true},
		{in: "notaslashform", wantErr: true},
		{in: "a/b/c", wantErr: true},
	}
	for _, c := range cases {
		src, err := ParseSource(c.in)
		if c.wantErr {
			if !errors.Is(err, skilldomain.ErrInstallSourceInvalid) {
				t.Fatalf("ParseSource(%q) want invalid, got %v", c.in, err)
			}
			continue
		}
		if err != nil {
			t.Fatalf("ParseSource(%q): %v", c.in, err)
		}
		if src.Repo != c.repo || src.Ref != c.ref || src.Subdir != c.subdir {
			t.Fatalf("ParseSource(%q) = %+v", c.in, src)
		}
		if c.host != "" && !bytes.Contains([]byte(src.URL), []byte(c.host)) {
			t.Fatalf("ParseSource(%q) url %q missing host %q", c.in, src.URL, c.host)
		}
	}
}

// tgz builds an in-memory gzipped tarball.
func tgz(t *testing.T, files map[string]string) []byte {
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

func serveTgz(t *testing.T, body []byte) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write(body)
	}))
	t.Cleanup(srv.Close)
	return srv
}

func TestFetch_MonorepoCarving(t *testing.T) {
	// GitHub 形态包装目录 + 两个 skill + 无关文件；subdir 过滤只留一个。
	body := tgz(t, map[string]string{
		"repo-abc123/README.md":                   "readme",
		"repo-abc123/skills/pdf/SKILL.md":         "---\nname: pdf\ndescription: d\n---\nb\n",
		"repo-abc123/skills/pdf/scripts/x.py":     "print()",
		"repo-abc123/skills/docx/skill.md":        "---\nname: docx\ndescription: d\n---\nb\n",
		"repo-abc123/skills/docx/references/a.md": "# ref",
		"repo-abc123/not-a-skill/notes.txt":       "junk",
	})
	srv := serveTgz(t, body)

	src, _ := ParseSource(srv.URL + "/x.tar.gz")
	cands, err := Fetch(context.Background(), src)
	if err != nil {
		t.Fatalf("fetch: %v", err)
	}
	if len(cands) != 2 || cands[0].Name != "docx" || cands[1].Name != "pdf" {
		t.Fatalf("carve mismatch: %+v", names(cands))
	}
	if string(cands[1].Files["scripts/x.py"]) != "print()" || len(cands[1].Files) != 2 {
		t.Fatalf("pdf files mismatch: %v", keys(cands[1].Files))
	}
	// 小写清单也被识别为 skill 根。
	if _, ok := cands[0].Files["skill.md"]; !ok {
		t.Fatalf("lowercase manifest must be carried: %v", keys(cands[0].Files))
	}

	// subdir 过滤。
	src.Subdir = "skills/pdf"
	cands, err = Fetch(context.Background(), src)
	if err != nil || len(cands) != 1 || cands[0].Name != "pdf" {
		t.Fatalf("subdir filter: %+v err=%v", names(cands), err)
	}
}

func TestFetch_TopLevelSingleSkillUsesRepoName(t *testing.T) {
	body := tgz(t, map[string]string{
		"my-skill-main/SKILL.md":     "---\nname: my-skill\ndescription: d\n---\nb\n",
		"my-skill-main/references/r": "x",
	})
	srv := serveTgz(t, body)
	src := Source{Raw: "o/my-skill", Repo: "o/my-skill", URL: srv.URL + "/t.tar.gz"}
	cands, err := Fetch(context.Background(), src)
	if err != nil || len(cands) != 1 || cands[0].Name != "my-skill" {
		t.Fatalf("top-level skill: %+v err=%v", names(cands), err)
	}
}

func TestFetch_GuardsAndJunk(t *testing.T) {
	// symlink 条目丢弃、越界条目丢弃、非 gzip 拒。
	var buf bytes.Buffer
	gz := gzip.NewWriter(&buf)
	tw := tar.NewWriter(gz)
	_ = tw.WriteHeader(&tar.Header{Name: "w/SKILL.md", Mode: 0o644, Size: 30, Typeflag: tar.TypeReg})
	_, _ = tw.Write([]byte("---\nname: w\ndescription: d\n---"))
	_ = tw.WriteHeader(&tar.Header{Name: "w/evil-link", Linkname: "/etc/passwd", Typeflag: tar.TypeSymlink})
	_ = tw.WriteHeader(&tar.Header{Name: "../escape.txt", Mode: 0o644, Size: 1, Typeflag: tar.TypeReg})
	_, _ = tw.Write([]byte("x"))
	_ = tw.Close()
	_ = gz.Close()
	srv := serveTgz(t, buf.Bytes())

	src := Source{Raw: "u", URL: srv.URL}
	cands, err := Fetch(context.Background(), src)
	if err != nil || len(cands) != 1 {
		t.Fatalf("fetch: %+v err=%v", names(cands), err)
	}
	for p := range cands[0].Files {
		if p == "evil-link" || p == "../escape.txt" {
			t.Fatalf("junk entry must be dropped: %s", p)
		}
	}

	bad := serveTgz(t, []byte("this is not gzip"))
	if _, err := Fetch(context.Background(), Source{Raw: "u", URL: bad.URL}); !errors.Is(err, skilldomain.ErrInstallFetchFailed) {
		t.Fatalf("non-gzip must be FetchFailed, got %v", err)
	}
}

func TestFetch_PlatformJunkDropped(t *testing.T) {
	// AppleDouble ._* / .DS_Store / __MACOSX/ / Thumbs.db 绝不作为 skill 文件落盘（真机实测缺口）。
	body := tgz(t, map[string]string{
		"w/SKILL.md":         "---\nname: w\ndescription: d\n---\nb\n",
		"w/._SKILL.md":       "appledouble junk",
		"w/.DS_Store":        "finder junk",
		"w/scripts/run.py":   "print()",
		"w/scripts/._run.py": "appledouble junk",
		"__MACOSX/w/foo":     "macosx junk",
		"w/refs/Thumbs.db":   "windows junk",
	})
	srv := serveTgz(t, body)
	cands, err := Fetch(context.Background(), Source{Raw: "u", Repo: "o/w", URL: srv.URL})
	if err != nil || len(cands) != 1 {
		t.Fatalf("fetch: %+v err=%v", names(cands), err)
	}
	got := keys(cands[0].Files)
	if len(got) != 2 {
		t.Fatalf("only SKILL.md + scripts/run.py must survive, got %v", got)
	}
	for _, k := range got {
		if isJunkPath(k) {
			t.Fatalf("junk leaked into candidate: %s", k)
		}
	}
}

func names(cs []Candidate) []string {
	out := make([]string, 0, len(cs))
	for _, c := range cs {
		out = append(out, c.Name)
	}
	return out
}

func keys(m map[string][]byte) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}
