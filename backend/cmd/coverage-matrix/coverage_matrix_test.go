package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestSplitMethodPath_HappyAndBad verifies the pattern parser accepts canonical
// "METHOD /path" strings and rejects anything malformed.
//
// TestSplitMethodPath_HappyAndBad 校验 splitMethodPath 接受规范 "METHOD /path",
// 拒绝其它。
func TestSplitMethodPath_HappyAndBad(t *testing.T) {
	cases := []struct {
		in           string
		wantMethod   string
		wantPath     string
	}{
		{"GET /api/v1/users", "GET", "/api/v1/users"},
		{"POST /api/v1/api-keys/{id}:test", "POST", "/api/v1/api-keys/{id}:test"},
		{"PATCH /api/v1/conversations/{id}", "PATCH", "/api/v1/conversations/{id}"},
		{"BOGUS /path", "", ""},                  // unknown verb
		{"GET path-no-slash", "", ""},            // path doesn't start with /
		{"only-one-token", "", ""},               // no space
	}
	for _, tc := range cases {
		m, p := splitMethodPath(tc.in)
		if m != tc.wantMethod || p != tc.wantPath {
			t.Errorf("splitMethodPath(%q) = (%q, %q); want (%q, %q)",
				tc.in, m, p, tc.wantMethod, tc.wantPath)
		}
	}
}

// TestScanEndpoints_FromSample runs the AST scanner against a synthetic
// "handlers" directory and verifies the discovered endpoints.
//
// TestScanEndpoints_FromSample 用 synthetic handlers 目录跑 AST 扫描器,
// 验证发现的 endpoints。
func TestScanEndpoints_FromSample(t *testing.T) {
	dir := t.TempDir()
	handlerSrc := `package fake

import "net/http"

type H struct{}

func (h *H) Register(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/widgets", h.list)
	mux.HandleFunc("POST /api/v1/widgets", h.create)
	mux.HandleFunc("PATCH /api/v1/widgets/{id}", h.update)
}

func (h *H) list(http.ResponseWriter, *http.Request)   {}
func (h *H) create(http.ResponseWriter, *http.Request) {}
func (h *H) update(http.ResponseWriter, *http.Request) {}
`
	writeFile(t, filepath.Join(dir, "widgets.go"), handlerSrc)

	// Add a dev_*.go file to confirm it's skipped.
	// 加一个 dev_*.go 验证跳过逻辑。
	writeFile(t, filepath.Join(dir, "dev_routes.go"), `package fake
import "net/http"
func RegDev(mux *http.ServeMux) { mux.HandleFunc("GET /dev/info", nil) }
`)

	got, err := ScanEndpoints(dir)
	if err != nil {
		t.Fatalf("ScanEndpoints: %v", err)
	}
	keys := keysOf(got)
	for _, want := range []string{
		"GET /api/v1/widgets",
		"POST /api/v1/widgets",
		"PATCH /api/v1/widgets/{id}",
	} {
		if !contains(keys, want) {
			t.Errorf("missing endpoint %q in result %v", want, keys)
		}
	}
	for _, dev := range []string{"GET /dev/info"} {
		if contains(keys, dev) {
			t.Errorf("dev-only endpoint %q should be skipped", dev)
		}
	}
}

// TestScanErrCodes_FromSample parses an errmap.go-shaped file and verifies the
// (sentinel, status, code) extraction.
//
// TestScanErrCodes_FromSample 解析类 errmap.go 文件,验证 (sentinel,status,code)
// 提取。
func TestScanErrCodes_FromSample(t *testing.T) {
	dir := t.TempDir()
	src := `package response

import "net/http"

type errMapping struct {
	Status int
	Code   string
}

var errTable = map[error]errMapping{
	domain.ErrFoo: {http.StatusNotFound, "FOO_NOT_FOUND"},
	domain.ErrBar: {http.StatusConflict, "BAR_CONFLICT"},
	domain.ErrBaz: {http.StatusUnprocessableEntity, "BAZ_UNPROCESSABLE"},
}
`
	path := filepath.Join(dir, "errmap.go")
	writeFile(t, path, src)

	rows, err := ScanErrCodes(path)
	if err != nil {
		t.Fatalf("ScanErrCodes: %v", err)
	}
	if len(rows) != 3 {
		t.Fatalf("got %d rows, want 3: %+v", len(rows), rows)
	}
	wantStatus := map[string]int{
		"FOO_NOT_FOUND":     404,
		"BAR_CONFLICT":      409,
		"BAZ_UNPROCESSABLE": 422,
	}
	for _, r := range rows {
		if wantStatus[r.Code] != r.HTTPStatus {
			t.Errorf("code %q: status=%d, want %d", r.Code, r.HTTPStatus, wantStatus[r.Code])
		}
	}
}

// TestSSETruth_ContainsExpectedShape sanity-checks the hardcoded SSE truth list.
//
// TestSSETruth_ContainsExpectedShape sanity 校验 hardcoded SSE truth 列表。
func TestSSETruth_ContainsExpectedShape(t *testing.T) {
	truth := SSETruth()
	if len(truth) < 30 {
		t.Errorf("SSE truth has only %d entries; expected ≥ 30 (5 eventlog + 21 block × event + 12 forge + 13 notif)", len(truth))
	}
	// Confirm specific keys are present.
	// 确认特定 key 在内。
	keys := map[string]bool{}
	for _, s := range truth {
		keys[s.Key()] = true
	}
	for _, want := range []string{
		"sse:eventlog:message_start",
		"sse:eventlog:block_start:text",
		"sse:eventlog:block_delta:tool_call",
		"sse:forge:forge_completed:function",
		"sse:notifications:conversation",
	} {
		if !keys[want] {
			t.Errorf("SSE truth missing key %q", want)
		}
	}
}

// TestExtractCoversTargets reads a fixture test file and asserts the parser
// pulls out the right targets per function.
//
// TestExtractCoversTargets 读 fixture 测试文件,断言 parser 按函数提取出正确
// targets。
func TestExtractCoversTargets(t *testing.T) {
	dir := t.TempDir()
	src := `//go:build pipeline

package sample

import "testing"

// covers: POST /api/v1/widgets (happy)
// covers: sse:eventlog:block_start:text
func TestWidget_Create_Happy(t *testing.T) {}

// covers: errcode:WIDGET_NOT_FOUND
func TestWidget_Get_NotFound(t *testing.T) {}

// not a covers line
// covers: cross:widget_seam
// covers: lifecycle:widget_env
func TestWidget_Lifecycle(t *testing.T) {}

func TestWidget_NoAnnotation(t *testing.T) {}
`
	path := filepath.Join(dir, "widget_pipeline_test.go")
	writeFile(t, path, src)

	covers, unannotated, err := ScanCovers(dir, dir)
	if err != nil {
		t.Fatalf("ScanCovers: %v", err)
	}
	if len(covers) != 3 {
		t.Fatalf("got %d covers, want 3: %+v", len(covers), covers)
	}
	if len(unannotated) != 1 {
		t.Fatalf("got %d unannotated, want 1: %+v", len(unannotated), unannotated)
	}
	if unannotated[0].TestFunc != "TestWidget_NoAnnotation" {
		t.Errorf("unannotated[0]=%s; want TestWidget_NoAnnotation", unannotated[0].TestFunc)
	}
	// Walk covers and confirm targets.
	// 遍历 covers 确认 targets。
	byName := map[string][]string{}
	for _, c := range covers {
		byName[c.TestFunc] = c.Targets
	}
	wantTargets := map[string][]string{
		"TestWidget_Create_Happy": {
			"POST /api/v1/widgets (happy)",
			"sse:eventlog:block_start:text",
		},
		"TestWidget_Get_NotFound": {"errcode:WIDGET_NOT_FOUND"},
		"TestWidget_Lifecycle":    {"cross:widget_seam", "lifecycle:widget_env"},
	}
	for fn, want := range wantTargets {
		got := byName[fn]
		if len(got) != len(want) {
			t.Errorf("%s targets=%v; want %v", fn, got, want)
			continue
		}
		for i := range got {
			if got[i] != want[i] {
				t.Errorf("%s targets[%d]=%q; want %q", fn, i, got[i], want[i])
			}
		}
	}
}

// TestBuildMatrix_HappyPath links sample truth × sample covers and verifies the
// per-bucket coverage rollup.
//
// TestBuildMatrix_HappyPath 用 sample truth × covers 连接,验证按 bucket 汇总。
func TestBuildMatrix_HappyPath(t *testing.T) {
	truth := Truth{
		Endpoints: []Endpoint{
			{Method: "GET", Path: "/api/v1/widgets"},
			{Method: "POST", Path: "/api/v1/widgets"},
		},
		ErrCodes: []ErrCode{
			{Code: "WIDGET_NOT_FOUND", HTTPStatus: 404},
		},
		SSE: []SSEEvent{
			{Stream: "eventlog", Event: "block_start", BlockType: "text"},
		},
		Seams: []Seam{
			{ID: "widget_seam", Type: "cross"},
			{ID: "widget_env", Type: "lifecycle"},
		},
	}
	covers := []Coverage{
		{TestFunc: "TestList", File: "f.go", Line: 1,
			Targets: []string{"GET /api/v1/widgets (happy)"}},
		{TestFunc: "TestCreate", File: "f.go", Line: 2,
			Targets: []string{"POST /api/v1/widgets"}},
		{TestFunc: "TestNotFound", File: "f.go", Line: 3,
			Targets: []string{"errcode:WIDGET_NOT_FOUND"}},
		{TestFunc: "TestSSE", File: "f.go", Line: 4,
			Targets: []string{"sse:eventlog:block_start:text"}},
		{TestFunc: "TestSeam", File: "f.go", Line: 5,
			Targets: []string{"cross:widget_seam", "lifecycle:widget_env"}},
		{TestFunc: "TestOrphan", File: "f.go", Line: 6,
			Targets: []string{"errcode:MISSING_CODE"}},
	}
	m := BuildMatrix(truth, covers, nil)

	for i, r := range m.Endpoints {
		if len(r.Tests) == 0 {
			t.Errorf("endpoint[%d] %s has no tests", i, r.Endpoint.Key())
		}
	}
	if len(m.ErrCodes) != 1 || len(m.ErrCodes[0].Tests) != 1 {
		t.Errorf("errcode rollup wrong: %+v", m.ErrCodes)
	}
	if len(m.SSE) != 1 || len(m.SSE[0].Tests) != 1 {
		t.Errorf("sse rollup wrong: %+v", m.SSE)
	}
	if len(m.Cross) != 1 || len(m.Cross[0].Tests) != 1 {
		t.Errorf("cross rollup wrong: %+v", m.Cross)
	}
	if len(m.Lifecycle) != 1 || len(m.Lifecycle[0].Tests) != 1 {
		t.Errorf("lifecycle rollup wrong: %+v", m.Lifecycle)
	}
	if len(m.Orphans) != 1 || m.Orphans[0].Annotation != "errcode:MISSING_CODE" {
		t.Errorf("orphan not detected: %+v", m.Orphans)
	}
}

// TestValidate_StrictReportsAll runs Validate against a matrix with one
// uncovered + one orphan + one unannotated and asserts each is reported.
//
// TestValidate_StrictReportsAll 跑 Validate 对一个含 uncovered/orphan/unannotated
// 三类各 1 的 matrix,断言全部报告。
func TestValidate_StrictReportsAll(t *testing.T) {
	m := Matrix{
		Endpoints: []EndpointRow{
			{Endpoint: Endpoint{Method: "GET", Path: "/api/v1/x"}},
		},
		Orphans: []OrphanRow{
			{Annotation: "errcode:NONEXISTENT", TestFunc: "TestX", File: "f.go", Line: 1},
		},
		Unannotated: []UnannotatedRow{
			{TestFunc: "TestY", File: "f.go", Line: 5},
		},
	}
	v := Validate(m)
	if len(v) != 3 {
		t.Fatalf("expected 3 violation categories, got %d:\n%v", len(v), v)
	}
	wantSubstr := []string{"uncovered targets", "orphan annotations", "missing"}
	for _, sub := range wantSubstr {
		found := false
		for _, msg := range v {
			if strings.Contains(msg, sub) {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("no violation message contains %q; got: %v", sub, v)
		}
	}
}

// TestRender_HasAllSections runs Render against an empty matrix and verifies all
// five top-level sections appear (cosmetic guard against accidental deletion).
//
// TestRender_HasAllSections 跑 Render 空 matrix,验证 5 大 section 都在
// (防误删的形式守卫)。
func TestRender_HasAllSections(t *testing.T) {
	m := Matrix{}
	out := Render(m)
	for _, s := range []string{
		"## 1. HTTP endpoints",
		"## 2. Error codes",
		"## 3. SSE protocol",
		"## 4. Cross-domain seams",
		"## 5. Lifecycle chains",
		MarkerStart,
		MarkerEnd,
	} {
		if !strings.Contains(out, s) {
			t.Errorf("Render output missing %q", s)
		}
	}
}

func writeFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}
}

func keysOf(eps []Endpoint) []string {
	out := make([]string, len(eps))
	for i, e := range eps {
		out[i] = e.Key()
	}
	return out
}

func contains(slice []string, want string) bool {
	for _, s := range slice {
		if s == want {
			return true
		}
	}
	return false
}
