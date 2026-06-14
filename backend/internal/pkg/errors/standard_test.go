package errors_test

import (
	"go/ast"
	"go/parser"
	"go/token"
	"io/fs"
	"path"
	"path/filepath"
	"sort"
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

// TestWireCodesGloballyUnique enforces that every errorspkg.New wire code is unique across
// internal/. Two sentinels sharing a code would make errors.Is conflate them (Is matches by Code)
// and corrupt the error-codes registry's single-source property. Catches the exact bug the full
// registry exposed (infra HANDLER_CRASHED vs domain HANDLER_CRASHED).
//
// TestWireCodesGloballyUnique 强制 internal/ 下每个 errorspkg.New 的 wire code 全库唯一。两个 sentinel
// 共码会让 errors.Is 混淆（Is 按 Code 匹配）、破坏 error-codes registry 的单一事实源。正是 registry 暴露的
// 那个 bug（infra HANDLER_CRASHED vs domain HANDLER_CRASHED）的守卫。
func TestWireCodesGloballyUnique(t *testing.T) {
	const internalRoot = "../.."
	fset := token.NewFileSet()
	seen := map[string][]string{} // code → definition positions

	walkErr := filepath.WalkDir(internalRoot, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		if !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}
		file, perr := parser.ParseFile(fset, path, nil, 0)
		if perr != nil {
			return nil
		}
		ast.Inspect(file, func(n ast.Node) bool {
			call, ok := n.(*ast.CallExpr)
			if !ok || len(call.Args) < 2 {
				return true
			}
			sel, ok := call.Fun.(*ast.SelectorExpr)
			if !ok || sel.Sel.Name != "New" {
				return true
			}
			if id, ok := sel.X.(*ast.Ident); !ok || id.Name != "errorspkg" {
				return true
			}
			lit, ok := call.Args[1].(*ast.BasicLit)
			if !ok || lit.Kind != token.STRING {
				return true
			}
			code := strings.Trim(lit.Value, "\"`")
			seen[code] = append(seen[code], fset.Position(call.Pos()).String())
			return true
		})
		return nil
	})
	if walkErr != nil {
		t.Fatalf("walk internal/: %v", walkErr)
	}

	var dups []string
	for code, positions := range seen {
		if len(positions) > 1 {
			dups = append(dups, code+" @ "+strings.Join(positions, ", "))
		}
	}
	if len(dups) > 0 {
		sort.Strings(dups)
		t.Errorf("%d duplicate wire code(s) — each must be globally unique:\n%s",
			len(dups), strings.Join(dups, "\n"))
	}
}

// TestTransportErrorsUseFromDomainError enforces S6: every error written by an HTTP
// handler or middleware must flow through responsehttpapi.FromDomainError, which maps an
// *errorspkg.Error's Kind→HTTP status and Code→wire envelope. The three escape hatches that
// bypass that mapping must be zero in transport code:
//   - responsehttpapi.Error(...)   — writes a raw envelope without a domain sentinel (no Kind)
//   - http.NotFound(w, r)          — stdlib, emits "404 page not found" text, not an N1 envelope
//   - http.Error(w, ...)           — stdlib, emits a plain-text body, not an N1 envelope
//
// This is the mechanical guard that keeps every endpoint's failure path identical for the
// frontend: one envelope shape, one Kind→status table. The response package itself is out of
// scope (FromDomainError legitimately calls the low-level writer there).
//
// 守 S6：HTTP handler / 中间件写出的每个错误都必须走 responsehttpapi.FromDomainError
// （它把 *errorspkg.Error 的 Kind→HTTP status、Code→线缆 envelope）。三个绕过映射的逃逸口在
// transport 代码里必须为零：responsehttpapi.Error（裸 envelope、无 Kind）、http.NotFound、
// http.Error（标准库纯文本、非 N1 envelope）。这是让前端面对每个端点失败路径完全一致（一种
// envelope、一张 Kind→status 表）的机械守卫。response 包自身豁免（FromDomainError 合法地调它）。
func TestTransportErrorsUseFromDomainError(t *testing.T) {
	dirs := []string{
		"../../transport/httpapi/handlers",
		"../../transport/httpapi/middleware",
	}
	fset := token.NewFileSet()
	var violations []string

	for _, dir := range dirs {
		walkErr := filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
			if err != nil || d.IsDir() {
				return err
			}
			if !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
				return nil
			}
			file, perr := parser.ParseFile(fset, path, nil, 0)
			if perr != nil {
				return nil
			}
			// Resolve per-file import aliases — robust to S13 renames.
			// 按文件解析导入别名——对 S13 改名稳健。
			respAlias := importAlias(file, "transport/httpapi/response")
			httpAlias := importAlias(file, "net/http")
			ast.Inspect(file, func(n ast.Node) bool {
				sel, ok := n.(*ast.SelectorExpr)
				if !ok {
					return true
				}
				x, ok := sel.X.(*ast.Ident)
				if !ok {
					return true
				}
				bad := (respAlias != "" && x.Name == respAlias && sel.Sel.Name == "Error") ||
					(httpAlias != "" && x.Name == httpAlias && (sel.Sel.Name == "NotFound" || sel.Sel.Name == "Error"))
				if bad {
					violations = append(violations,
						fset.Position(sel.Pos()).String()+": "+x.Name+"."+sel.Sel.Name+"(...)")
				}
				return true
			})
			return nil
		})
		if walkErr != nil {
			t.Fatalf("walk %s: %v", dir, walkErr)
		}
	}

	if len(violations) > 0 {
		sort.Strings(violations)
		t.Errorf("%d transport error-write(s) bypass FromDomainError — route every failure through "+
			"responsehttpapi.FromDomainError(w, log, err) with a domain/pkg sentinel (S6):\n%s",
			len(violations), strings.Join(violations, "\n"))
	}
}

// importAlias returns the local name bound to the import whose path contains suffix (the explicit
// alias, or the package's base name when unaliased). Empty if the file does not import it.
//
// importAlias 返回路径含 suffix 的那个 import 的本地名（显式别名，或未别名时的包基名）。文件未导入则空。
func importAlias(file *ast.File, suffix string) string {
	for _, imp := range file.Imports {
		p := strings.Trim(imp.Path.Value, "\"`")
		if !strings.Contains(p, suffix) {
			continue
		}
		if imp.Name != nil {
			return imp.Name.Name
		}
		return path.Base(p)
	}
	return ""
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
