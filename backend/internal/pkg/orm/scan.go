package orm

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"reflect"
)

// scanAll reads every row into a freshly-allocated []*T, mapping columns to
// struct fields in meta order (which matches the SELECT column list). A
// json-tagged column scans through a []byte staging buffer and is then
// unmarshalled into its field; an empty/NULL buffer leaves the field zero.
//
// scanAll 把每行读进新分配的 []*T，按 meta 顺序（与 SELECT 列表一致）映射字段。
// json 列经 []byte 暂存再 unmarshal 进字段；空/NULL 暂存则字段保持零值。
func scanAll[T any](rows *sql.Rows, meta *tableMeta) ([]*T, error) {
	var out []*T
	for rows.Next() {
		v := new(T)
		rv := reflect.ValueOf(v).Elem()

		targets := make([]any, len(meta.cols))
		jsonBufs := make(map[int]*[]byte)
		for i, c := range meta.cols {
			if c.json {
				buf := new([]byte)
				targets[i] = buf
				jsonBufs[i] = buf
			} else {
				targets[i] = rv.Field(c.index).Addr().Interface()
			}
		}

		if err := rows.Scan(targets...); err != nil {
			return nil, fmt.Errorf("orm: scan: %w", err)
		}

		for i, buf := range jsonBufs {
			if len(*buf) == 0 {
				continue
			}
			field := rv.Field(meta.cols[i].index).Addr().Interface()
			if err := json.Unmarshal(*buf, field); err != nil {
				return nil, fmt.Errorf("orm: scan json column %q: %w", meta.cols[i].name, err)
			}
		}

		out = append(out, v)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("orm: rows: %w", err)
	}
	return out, nil
}

// columnValues extracts the args for every mapped column from v, in meta order,
// marshalling json columns to a string. Used by INSERT / upsert.
//
// columnValues 按 meta 顺序从 v 取出所有映射列的参数，json 列序列化为字符串。供 INSERT / upsert 用。
func columnValues[T any](v *T, meta *tableMeta) ([]any, error) {
	rv := reflect.ValueOf(v).Elem()
	vals := make([]any, len(meta.cols))
	for i, c := range meta.cols {
		fv := rv.Field(c.index)
		if c.json {
			b, err := json.Marshal(fv.Interface())
			if err != nil {
				return nil, fmt.Errorf("orm: marshal json column %q: %w", c.name, err)
			}
			vals[i] = string(b)
		} else {
			vals[i] = fv.Interface()
		}
	}
	return vals, nil
}
