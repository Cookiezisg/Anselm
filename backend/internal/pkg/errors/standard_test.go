package errors_test

import (
	"go/ast"
	"go/parser"
	"go/token"
	"io/fs"
	"path/filepath"
	"strings"
	"testing"
)

// TestErrorSentinelsUseErrorsPkg enforces ADR 0002 / S20 across the whole backend: every
// package-level error sentinel (a `var Err… =`) must be built with errorspkg.New — NOT the
// stdlib errors.New or fmt.Errorf. This is the mechanical guard that keeps the error system
// unified (one type, one construction) — it fails the build the moment anyone reintroduces a
// std-errors sentinel.
//
// Scope: only NAMED package-level sentinels (`var Err…`). Exempt by design — inline errors in
// function bodies (e.g. an http.Client CheckRedirect signal) and fmt.Errorf("…: %w", err)
// wrapping, which add context rather than define the error vocabulary. The errorspkg package
// itself is skipped (it IS the standard).
//
// 守 ADR 0002 / S20（全后端）：每个包级错误 sentinel（`var Err… =`）必须用 errorspkg.New 构造，
// 而非标准库 errors.New / fmt.Errorf。这是保持错误系统统一（一个类型、一种造法）的机械守卫——
// 任何人重新引入 std-errors sentinel 立即 build 失败。
//
// 范围：只查命名包级 sentinel（`var Err…`）。设计上豁免：函数体内的内联错误（如 http.Client
// CheckRedirect 信号）与 fmt.Errorf("…: %w", err) 包裹（加上下文、非定义错误词汇）。errorspkg
// 包自身跳过（它就是标准）。
func TestErrorSentinelsUseErrorsPkg(t *testing.T) {
	const internalRoot = "../.." // this test runs with cwd = internal/pkg/errors

	fset := token.NewFileSet()
	var violations []string

	walkErr := filepath.WalkDir(internalRoot, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		slash := filepath.ToSlash(path)
		if d.IsDir() {
			if strings.HasSuffix(slash, "pkg/errors") {
				return filepath.SkipDir // the standard's own home
			}
			return nil
		}
		if !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}
		file, perr := parser.ParseFile(fset, path, nil, 0)
		if perr != nil {
			return nil // unparseable in isolation — build/vet covers real syntax errors
		}
		for _, decl := range file.Decls {
			gd, ok := decl.(*ast.GenDecl)
			if !ok || gd.Tok != token.VAR {
				continue
			}
			for _, spec := range gd.Specs {
				vs, ok := spec.(*ast.ValueSpec)
				if !ok {
					continue
				}
				for i, name := range vs.Names {
					if !strings.HasPrefix(name.Name, "Err") || i >= len(vs.Values) {
						continue
					}
					if pkg, fn, isCall := selectorCall(vs.Values[i]); isCall {
						if (pkg == "errors" && fn == "New") || (pkg == "fmt" && fn == "Errorf") {
							violations = append(violations,
								fset.Position(name.Pos()).String()+": "+name.Name+" = "+pkg+"."+fn+"(...)")
						}
					}
				}
			}
		}
		return nil
	})
	if walkErr != nil {
		t.Fatalf("walk internal/: %v", walkErr)
	}

	if len(violations) > 0 {
		t.Errorf("%d error sentinel(s) bypass errorspkg.New — use errorspkg.New(kind, code, msg) "+
			"(ADR 0002 / S20):\n%s", len(violations), strings.Join(violations, "\n"))
	}
}

// selectorCall reports a `pkg.Fn(...)` call expression's package + function identifiers.
//
// selectorCall 解出 `pkg.Fn(...)` 调用表达式的包名 + 函数名。
func selectorCall(e ast.Expr) (pkg, fn string, ok bool) {
	call, ok := e.(*ast.CallExpr)
	if !ok {
		return "", "", false
	}
	sel, ok := call.Fun.(*ast.SelectorExpr)
	if !ok {
		return "", "", false
	}
	ident, ok := sel.X.(*ast.Ident)
	if !ok {
		return "", "", false
	}
	return ident.Name, sel.Sel.Name, true
}
