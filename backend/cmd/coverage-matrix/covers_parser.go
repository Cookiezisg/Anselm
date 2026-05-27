package main

import (
	"bufio"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

// coversLineRe matches a `// covers: <target>` annotation, capturing the target.
//
// coversLineRe 匹配 // covers: <target> 注释,捕获 target。
var coversLineRe = regexp.MustCompile(`^\s*//\s*covers:\s*(.+?)\s*$`)

// ScanCovers walks every *_pipeline_test.go file under testsRoot, locates each
// top-level Test* function, and collects the `// covers:` annotations from the
// comment lines immediately preceding the function declaration. Returns the
// covers list plus the list of unannotated test functions for the validator.
//
// ScanCovers 遍历 testsRoot 下每个 *_pipeline_test.go 文件,定位每个顶层
// Test* 函数,收集函数声明前紧邻的 // covers: 注释。
// 返 covers 列表 + 漏注释的测试函数列表(给 validator 用)。
func ScanCovers(testsRoot string, repoRoot string) ([]Coverage, []UnannotatedRow, error) {
	fset := token.NewFileSet()
	var covers []Coverage
	var unannotated []UnannotatedRow

	err := filepath.WalkDir(testsRoot, func(path string, d os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if d.IsDir() {
			return nil
		}
		if !strings.HasSuffix(path, "_pipeline_test.go") {
			return nil
		}
		// Skip harness internals — harness has no test functions to annotate.
		// 跳过 harness 内部 — harness 无需测试函数注释。
		if strings.Contains(path, "/harness/") {
			return nil
		}

		// Parse with comments preserved.
		// 带注释解析。
		file, err := parser.ParseFile(fset, path, nil, parser.ParseComments)
		if err != nil {
			return fmt.Errorf("parse %s: %w", path, err)
		}

		rel := mustRel(repoRoot, path)

		for _, decl := range file.Decls {
			fn, ok := decl.(*ast.FuncDecl)
			if !ok || fn.Recv != nil {
				continue
			}
			if !strings.HasPrefix(fn.Name.Name, "Test") {
				continue
			}
			pos := fset.Position(fn.Pos())
			targets := extractCoversTargets(path, pos.Line)
			if len(targets) == 0 {
				unannotated = append(unannotated, UnannotatedRow{
					TestFunc: fn.Name.Name,
					File:     rel,
					Line:     pos.Line,
				})
				continue
			}
			covers = append(covers, Coverage{
				TestFunc: fn.Name.Name,
				File:     rel,
				Line:     pos.Line,
				Targets:  targets,
			})
		}
		return nil
	})
	if err != nil {
		return nil, nil, err
	}

	sort.Slice(covers, func(i, j int) bool {
		if covers[i].File != covers[j].File {
			return covers[i].File < covers[j].File
		}
		return covers[i].Line < covers[j].Line
	})
	sort.Slice(unannotated, func(i, j int) bool {
		if unannotated[i].File != unannotated[j].File {
			return unannotated[i].File < unannotated[j].File
		}
		return unannotated[i].Line < unannotated[j].Line
	})

	return covers, unannotated, nil
}

// extractCoversTargets reads the file and walks lines backward from funcLine
// until a non-comment / non-blank line is hit; collects targets in original order.
//
// extractCoversTargets 从 funcLine 倒读文件,遇非注释 / 非空行止;
// 按原顺序收集 targets。
func extractCoversTargets(path string, funcLine int) []string {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()

	var lines []string
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for sc.Scan() {
		lines = append(lines, sc.Text())
	}

	// Walk backward from line just before funcLine.
	// 从 funcLine 前一行倒走。
	var rev []string
	for i := funcLine - 2; i >= 0; i-- {
		line := strings.TrimSpace(lines[i])
		if line == "" {
			break
		}
		if !strings.HasPrefix(line, "//") {
			break
		}
		if m := coversLineRe.FindStringSubmatch(lines[i]); m != nil {
			rev = append(rev, m[1])
			continue
		}
		// Allow other // doc comment lines interleaved with covers lines —
		// stop only on non-comment / blank.
		// 允许其它 // doc 注释和 covers 行混排;仅在非注释 / 空行时停。
	}
	// Reverse to original order.
	out := make([]string, len(rev))
	for i, t := range rev {
		out[len(rev)-1-i] = t
	}
	return out
}

// mustRel falls back to absolute path on error.
//
// mustRel 出错时 fallback 到绝对路径。
func mustRel(base, path string) string {
	r, err := filepath.Rel(base, path)
	if err != nil {
		return path
	}
	return r
}
