package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"sort"
	"strconv"
	"strings"
)

// ScanErrCodes parses response/errmap.go and extracts every (sentinel, status, code)
// triple from the errTable map literal. Status numeric values are converted from
// http.StatusXxx identifiers via a tiny lookup table.
//
// ScanErrCodes 解析 response/errmap.go,提取 errTable 中每条
// (sentinel, status, code) 三元组。Status 数值通过 http.StatusXxx 标识符查表换算。
func ScanErrCodes(errmapPath string) ([]ErrCode, error) {
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, errmapPath, nil, 0)
	if err != nil {
		return nil, fmt.Errorf("parse %s: %w", errmapPath, err)
	}

	var rows []ErrCode

	ast.Inspect(file, func(n ast.Node) bool {
		spec, ok := n.(*ast.ValueSpec)
		if !ok {
			return true
		}
		// Find: var errTable = map[error]errMapping{ ... }
		// 找:var errTable = map[error]errMapping{...}
		for _, name := range spec.Names {
			if name.Name != "errTable" {
				continue
			}
			if len(spec.Values) != 1 {
				continue
			}
			cl, ok := spec.Values[0].(*ast.CompositeLit)
			if !ok {
				continue
			}
			for _, elt := range cl.Elts {
				kv, ok := elt.(*ast.KeyValueExpr)
				if !ok {
					continue
				}
				sentinel := exprString(kv.Key)
				valLit, ok := kv.Value.(*ast.CompositeLit)
				if !ok || len(valLit.Elts) < 2 {
					continue
				}
				statusName := exprString(valLit.Elts[0])
				codeLit, ok := valLit.Elts[1].(*ast.BasicLit)
				if !ok || codeLit.Kind != token.STRING {
					continue
				}
				code, err := strconv.Unquote(codeLit.Value)
				if err != nil {
					continue
				}
				status := httpStatusToInt(statusName)
				pos := fset.Position(kv.Pos())
				rows = append(rows, ErrCode{
					Code:       code,
					HTTPStatus: status,
					Sentinel:   sentinel,
					Source:     fmt.Sprintf("%s:%d", errmapPath, pos.Line),
				})
			}
		}
		return true
	})

	sort.Slice(rows, func(i, j int) bool { return rows[i].Code < rows[j].Code })
	return rows, nil
}

// exprString reconstructs a dotted identifier from an ast.Expr (e.g. pkg.Identifier).
//
// exprString 从 ast.Expr 重建点分标识符(如 pkg.Identifier)。
func exprString(e ast.Expr) string {
	switch v := e.(type) {
	case *ast.Ident:
		return v.Name
	case *ast.SelectorExpr:
		return exprString(v.X) + "." + v.Sel.Name
	}
	return ""
}

// httpStatusToInt maps http.StatusXxx identifier strings to numeric codes.
// Only the codes that appear in errTable are listed; extend as needed.
//
// httpStatusToInt 把 http.StatusXxx 标识符映射到数字码;只列 errTable 出现过的。
func httpStatusToInt(name string) int {
	// Strip leading "http." namespace if present.
	if i := strings.Index(name, "."); i >= 0 {
		name = name[i+1:]
	}
	switch name {
	case "StatusOK":
		return 200
	case "StatusCreated":
		return 201
	case "StatusAccepted":
		return 202
	case "StatusNoContent":
		return 204
	case "StatusBadRequest":
		return 400
	case "StatusUnauthorized":
		return 401
	case "StatusForbidden":
		return 403
	case "StatusNotFound":
		return 404
	case "StatusConflict":
		return 409
	case "StatusGone":
		return 410
	case "StatusRequestEntityTooLarge", "StatusPayloadTooLarge":
		return 413
	case "StatusUnsupportedMediaType":
		return 415
	case "StatusUnprocessableEntity":
		return 422
	case "StatusTooManyRequests":
		return 429
	case "StatusInternalServerError":
		return 500
	case "StatusBadGateway":
		return 502
	case "StatusServiceUnavailable":
		return 503
	}
	return 0
}
