package orm

import (
	"fmt"
	"reflect"
	"strings"
	"sync"
)

// column is one mapped struct field: its field index, db column name, and role flags.
//
// column 是一个映射字段：struct 字段下标、db 列名、角色标志。
type column struct {
	index   int
	name    string
	pk      bool // primary key
	ws      bool // workspace_id — auto-filtered by ctx
	json    bool // serialized via encoding/json
	created bool // set to now() on insert
	updated bool // set to now() on insert + update
	deleted bool // soft-delete timestamp column
}

// tableMeta is the reflected layout of T: every mapped column plus quick
// pointers to the special ones. Built once per type and cached.
//
// tableMeta 是 T 反射出的布局：所有映射列 + 指向特殊列的快捷指针。每类型构建一次并缓存。
type tableMeta struct {
	cols    []column
	pk      *column
	ws      *column
	created *column
	updated *column
	deleted *column
}

var metaCache sync.Map // reflect.Type → *tableMeta

// metaOf reflects T's `db:"..."` tags once and caches the result by type.
//
// metaOf 反射 T 的 `db` tag 一次并按类型缓存。
func metaOf[T any]() *tableMeta {
	rt := reflect.TypeFor[T]()
	if cached, ok := metaCache.Load(rt); ok {
		return cached.(*tableMeta)
	}
	m := parseMeta(rt)
	metaCache.Store(rt, m)
	return m
}

// parseMeta walks struct fields, reads the `db` tag (`col,opt1,opt2`), and
// validates roles. It panics on a misconfigured struct — a programming error
// that must surface at startup, not at query time.
//
// parseMeta 遍历字段读 `db` tag（`列名,选项…`）并校验角色。配置错误直接 panic
// ——这是编程错误，必须在启动期暴露，而非查询时。
func parseMeta(rt reflect.Type) *tableMeta {
	if rt.Kind() != reflect.Struct {
		panic(fmt.Sprintf("orm: %s is not a struct", rt))
	}
	m := &tableMeta{}
	for i := range rt.NumField() {
		f := rt.Field(i)
		tag := f.Tag.Get("db")
		if tag == "" || tag == "-" {
			continue
		}
		parts := strings.Split(tag, ",")
		c := column{index: i, name: parts[0]}
		if c.name == "" {
			panic(fmt.Sprintf("orm: %s.%s has an empty db column name", rt, f.Name))
		}
		for _, opt := range parts[1:] {
			switch opt {
			case "pk":
				c.pk = true
			case "ws":
				c.ws = true
			case "json":
				c.json = true
			case "created":
				c.created = true
			case "updated":
				c.updated = true
			case "deleted":
				c.deleted = true
			default:
				panic(fmt.Sprintf("orm: unknown db tag option %q on %s.%s", opt, rt, f.Name))
			}
		}
		m.cols = append(m.cols, c)
	}

	// Resolve special-column pointers after cols is final (append would move them).
	// cols 定稿后再 resolve 特殊列指针（append 会移动底层数组）。
	for i := range m.cols {
		c := &m.cols[i]
		if c.pk {
			m.pk = c
		}
		if c.ws {
			m.ws = c
		}
		if c.created {
			m.created = c
		}
		if c.updated {
			m.updated = c
		}
		if c.deleted {
			m.deleted = c
		}
	}
	if m.pk == nil {
		panic(fmt.Sprintf("orm: %s has no `db:\",pk\"` column", rt))
	}
	return m
}

// columnNames returns every mapped column name in struct-field order.
//
// columnNames 按 struct 字段顺序返回所有映射列名。
func (m *tableMeta) columnNames() []string {
	names := make([]string, len(m.cols))
	for i, c := range m.cols {
		names[i] = c.name
	}
	return names
}
