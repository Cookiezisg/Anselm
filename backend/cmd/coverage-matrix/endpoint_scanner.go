package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// ScanEndpoints walks the httpapi handlers tree, parses every .go file as Go AST,
// and extracts every `mux.HandleFunc("METHOD /path", ...)` call as an Endpoint.
// Result is deduplicated + sorted by (Path, Method).
//
// ScanEndpoints 遍历 httpapi handlers 树,AST 解析每个 .go 文件,
// 提取每个 mux.HandleFunc("METHOD /path", ...) 调用为 Endpoint。
// 结果去重 + 按 (Path, Method) 排序。
func ScanEndpoints(handlersDir string) ([]Endpoint, error) {
	fset := token.NewFileSet()
	var endpoints []Endpoint
	seen := map[string]bool{}

	err := filepath.WalkDir(handlersDir, func(path string, d os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if d.IsDir() {
			return nil
		}
		if !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}
		// Skip dev-only routes; they're not part of the public API surface.
		// 跳过 dev 路由,不算公共 API 面。
		base := filepath.Base(path)
		if strings.HasPrefix(base, "dev") {
			return nil
		}

		file, err := parser.ParseFile(fset, path, nil, 0)
		if err != nil {
			return fmt.Errorf("parse %s: %w", path, err)
		}

		ast.Inspect(file, func(n ast.Node) bool {
			call, ok := n.(*ast.CallExpr)
			if !ok {
				return true
			}
			sel, ok := call.Fun.(*ast.SelectorExpr)
			if !ok {
				return true
			}
			if sel.Sel.Name != "HandleFunc" {
				return true
			}
			if len(call.Args) < 1 {
				return true
			}
			lit, ok := call.Args[0].(*ast.BasicLit)
			if !ok || lit.Kind != token.STRING {
				return true
			}
			// Unquote "METHOD /path"
			pattern := strings.Trim(lit.Value, "`\"")
			method, p := splitMethodPath(pattern)
			if method == "" || p == "" {
				return true
			}
			pos := fset.Position(lit.Pos())
			key := method + " " + p
			if seen[key] {
				return true
			}
			seen[key] = true
			endpoints = append(endpoints, Endpoint{
				Method: method,
				Path:   p,
				Source: relPath(handlersDir, pos.Filename) + fmt.Sprintf(":%d", pos.Line),
			})
			return true
		})
		return nil
	})
	if err != nil {
		return nil, err
	}

	sort.Slice(endpoints, func(i, j int) bool {
		if endpoints[i].Path != endpoints[j].Path {
			return endpoints[i].Path < endpoints[j].Path
		}
		return endpoints[i].Method < endpoints[j].Method
	})

	return endpoints, nil
}

// splitMethodPath parses "METHOD /path" into (METHOD, /path); returns
// ("", "") when not in expected form.
//
// splitMethodPath 把 "METHOD /path" 拆成 (METHOD, /path);形式不对返 ("", "")。
func splitMethodPath(pattern string) (method, path string) {
	parts := strings.SplitN(pattern, " ", 2)
	if len(parts) != 2 {
		return "", ""
	}
	method = strings.TrimSpace(parts[0])
	path = strings.TrimSpace(parts[1])
	switch method {
	case "GET", "POST", "PUT", "PATCH", "DELETE":
		// ok
	default:
		return "", ""
	}
	if !strings.HasPrefix(path, "/") {
		return "", ""
	}
	return method, path
}

// relPath makes a path relative to dir, falling back to the original on failure.
//
// relPath 取相对 dir 的相对路径,失败则返原路径。
func relPath(dir, file string) string {
	r, err := filepath.Rel(filepath.Dir(filepath.Dir(filepath.Dir(dir))), file)
	if err != nil {
		return file
	}
	return r
}
