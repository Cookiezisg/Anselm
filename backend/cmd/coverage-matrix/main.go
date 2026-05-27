// Command coverage-matrix generates / verifies the testing coverage matrix.
//
// Source-of-truth inputs:
//   - HTTP endpoints: AST scan of backend/internal/transport/httpapi/handlers/*.go
//   - Error codes:    AST scan of backend/internal/transport/httpapi/response/errmap.go
//   - SSE protocol:   hardcoded enumeration (3 streams × N events × sub)
//   - Cross / lifecycle seams: seams.yaml in this directory
//
// Test-side input:
//   - `// covers:` annotations on each Test* function in backend/test/**/*_pipeline_test.go
//
// Outputs:
//   - `--update` (default): write matrix section into backend/test/README.md
//   - `--check`:             exit 1 when README is stale or violations exist
//   - `--report`:            print stdout summary; exit 0 regardless
//   - `--strict` (with check): elevate uncovered targets / orphans / unannotated
//                              tests to a failure
package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	var (
		mode   = flag.String("mode", "update", "update | check | report")
		update = flag.Bool("update", false, "shortcut for --mode=update")
		check  = flag.Bool("check", false, "shortcut for --mode=check")
		report = flag.Bool("report", false, "shortcut for --mode=report")
		strict = flag.Bool("strict", false, "with --check, also fail on uncovered/orphan/unannotated")
		root   = flag.String("root", "", "project root override (default: auto-detect)")
	)
	flag.Parse()

	if *update {
		*mode = "update"
	}
	if *check {
		*mode = "check"
	}
	if *report {
		*mode = "report"
	}

	projectRoot := *root
	if projectRoot == "" {
		var err error
		projectRoot, err = findProjectRoot()
		if err != nil {
			die(err)
		}
	}

	t, err := loadTruth(projectRoot)
	if err != nil {
		die(err)
	}

	testsRoot := filepath.Join(projectRoot, "backend", "test")
	covers, unannotated, err := ScanCovers(testsRoot, projectRoot)
	if err != nil {
		die(err)
	}

	m := BuildMatrix(t, covers, unannotated)
	body := Render(m)
	readmePath := filepath.Join(testsRoot, "README.md")

	switch *mode {
	case "update":
		if err := updateReadme(readmePath, body); err != nil {
			die(err)
		}
		fmt.Println(stdoutSummary(m))
		fmt.Printf("✓ %s updated\n", relTo(projectRoot, readmePath))

	case "check":
		fresh, err := readmeIsFresh(readmePath, body)
		if err != nil {
			die(err)
		}
		violations := []string{}
		if !fresh {
			violations = append(violations,
				"README matrix section is stale; run `make matrix` to regenerate.")
		}
		if *strict {
			violations = append(violations, Validate(m)...)
		}
		if len(violations) > 0 {
			fmt.Fprintln(os.Stderr, stdoutSummary(m))
			fmt.Fprintln(os.Stderr)
			for _, v := range violations {
				fmt.Fprintln(os.Stderr, v)
				fmt.Fprintln(os.Stderr)
			}
			os.Exit(1)
		}
		fmt.Println(stdoutSummary(m))
		fmt.Println("✓ matrix is fresh + clean")

	case "report":
		fmt.Println(stdoutSummary(m))

	default:
		die(fmt.Errorf("unknown --mode %q (use update | check | report)", *mode))
	}
}

// loadTruth runs all four scanners and combines results.
//
// loadTruth 跑四个扫描器并合并结果。
func loadTruth(projectRoot string) (Truth, error) {
	var t Truth
	handlersDir := filepath.Join(projectRoot, "backend", "internal", "transport", "httpapi", "handlers")
	eps, err := ScanEndpoints(handlersDir)
	if err != nil {
		return t, fmt.Errorf("scan endpoints: %w", err)
	}
	t.Endpoints = eps

	errmapPath := filepath.Join(projectRoot, "backend", "internal", "transport", "httpapi", "response", "errmap.go")
	ecs, err := ScanErrCodes(errmapPath)
	if err != nil {
		return t, fmt.Errorf("scan errcodes: %w", err)
	}
	t.ErrCodes = ecs

	t.SSE = SSETruth()

	seamsPath := filepath.Join(projectRoot, "backend", "cmd", "coverage-matrix", "seams.yaml")
	seams, err := LoadSeams(seamsPath)
	if err != nil {
		return t, fmt.Errorf("load seams: %w", err)
	}
	t.Seams = seams

	return t, nil
}

// findProjectRoot walks upward from cwd until a go.mod file is found.
//
// findProjectRoot 从 cwd 向上找 go.mod 所在目录。
func findProjectRoot() (string, error) {
	cwd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	d := cwd
	for {
		if fi, err := os.Stat(filepath.Join(d, "go.mod")); err == nil && !fi.IsDir() {
			// Stop at backend/go.mod; project root is parent.
			// backend/go.mod 命中后,项目根是其父目录。
			if filepath.Base(d) == "backend" {
				return filepath.Dir(d), nil
			}
			return d, nil
		}
		parent := filepath.Dir(d)
		if parent == d {
			return "", fmt.Errorf("no go.mod found from %s upwards", cwd)
		}
		d = parent
	}
}

// updateReadme reads README.md, replaces the section between MarkerStart/End,
// and writes back atomically. If the file doesn't exist, creates a minimal one.
//
// updateReadme 读 README.md,替换 Marker 之间的段,原子写回。
// 文件不存在则建最小骨架。
func updateReadme(path, body string) error {
	cur, err := os.ReadFile(path)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	var out string
	if err != nil && os.IsNotExist(err) {
		out = minimalReadme(body)
	} else {
		out = replaceMatrixSection(string(cur), body)
	}
	return os.WriteFile(path, []byte(out), 0o644)
}

// readmeIsFresh returns true when README's matrix section already equals body.
//
// readmeIsFresh README 矩阵段已等于 body 时返 true。
func readmeIsFresh(path, body string) (bool, error) {
	cur, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, err
	}
	current := extractMatrixSection(string(cur))
	return strings.TrimSpace(current) == strings.TrimSpace(body), nil
}

// replaceMatrixSection swaps the content between MarkerStart and MarkerEnd
// with newBody; if either marker is absent, appends a new section at the end.
//
// replaceMatrixSection 把 Marker 之间内容替换为 newBody;Marker 缺则末尾追加。
func replaceMatrixSection(content, newBody string) string {
	startIdx := strings.Index(content, MarkerStart)
	endIdx := strings.Index(content, MarkerEnd)
	if startIdx < 0 || endIdx < 0 || endIdx < startIdx {
		// Append section at end.
		// 末尾追加。
		sep := "\n\n---\n\n"
		if strings.HasSuffix(content, "\n") {
			sep = "\n---\n\n"
		}
		return content + sep + newBody + "\n"
	}
	endIdx += len(MarkerEnd)
	return content[:startIdx] + newBody + content[endIdx:]
}

// extractMatrixSection returns the content between MarkerStart and MarkerEnd
// (inclusive of both markers); empty string when not present.
//
// extractMatrixSection 取 Marker 之间内容(含 Marker);不存在返空。
func extractMatrixSection(content string) string {
	startIdx := strings.Index(content, MarkerStart)
	endIdx := strings.Index(content, MarkerEnd)
	if startIdx < 0 || endIdx < 0 || endIdx < startIdx {
		return ""
	}
	endIdx += len(MarkerEnd)
	return content[startIdx:endIdx]
}

// minimalReadme is the skeleton dropped when README.md doesn't exist yet.
//
// minimalReadme 是 README.md 不存在时的最小骨架。
func minimalReadme(body string) string {
	return "# backend/test/ — pipeline 测试\n\n" + body + "\n"
}

// stdoutSummary builds a compact per-category report.
//
// stdoutSummary 拼简短的各类别报告。
func stdoutSummary(m Matrix) string {
	s := m.Summarize()
	var b strings.Builder
	b.WriteString("Coverage Matrix Summary\n")
	b.WriteString("=======================\n")
	fmt.Fprintf(&b, "HTTP endpoints  %5d/%-5d  %s  %s\n",
		s.Endpoints.Covered, s.Endpoints.Total,
		pct(s.Endpoints.Covered, s.Endpoints.Total),
		badge(s.Endpoints.Covered, s.Endpoints.Total))
	fmt.Fprintf(&b, "Error codes     %5d/%-5d  %s  %s\n",
		s.ErrCodes.Covered, s.ErrCodes.Total,
		pct(s.ErrCodes.Covered, s.ErrCodes.Total),
		badge(s.ErrCodes.Covered, s.ErrCodes.Total))
	fmt.Fprintf(&b, "SSE protocol    %5d/%-5d  %s  %s\n",
		s.SSE.Covered, s.SSE.Total,
		pct(s.SSE.Covered, s.SSE.Total),
		badge(s.SSE.Covered, s.SSE.Total))
	fmt.Fprintf(&b, "Cross seams     %5d/%-5d  %s  %s\n",
		s.Cross.Covered, s.Cross.Total,
		pct(s.Cross.Covered, s.Cross.Total),
		badge(s.Cross.Covered, s.Cross.Total))
	fmt.Fprintf(&b, "Lifecycle       %5d/%-5d  %s  %s\n",
		s.Lifecycle.Covered, s.Lifecycle.Total,
		pct(s.Lifecycle.Covered, s.Lifecycle.Total),
		badge(s.Lifecycle.Covered, s.Lifecycle.Total))
	total := s.Endpoints.Total + s.ErrCodes.Total + s.SSE.Total + s.Cross.Total + s.Lifecycle.Total
	covered := s.Endpoints.Covered + s.ErrCodes.Covered + s.SSE.Covered + s.Cross.Covered + s.Lifecycle.Covered
	b.WriteString("---------------------------------------\n")
	fmt.Fprintf(&b, "Total           %5d/%-5d  %s\n", covered, total, pct(covered, total))
	if n := len(m.Orphans); n > 0 {
		fmt.Fprintf(&b, "\nOrphan annotations: %d\n", n)
	}
	if n := len(m.Unannotated); n > 0 {
		fmt.Fprintf(&b, "Unannotated tests:  %d\n", n)
	}
	return b.String()
}

// relTo returns the readme path relative to projectRoot when possible.
//
// relTo 尽量返回相对项目根的路径。
func relTo(root, path string) string {
	if r, err := filepath.Rel(root, path); err == nil {
		return r
	}
	return path
}

func die(err error) {
	fmt.Fprintln(os.Stderr, "coverage-matrix:", err)
	os.Exit(2)
}
