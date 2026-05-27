package main

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

// LoadSeams reads seams.yaml from the tool's own directory and returns the
// combined cross + lifecycle seam list with Type set on each row.
//
// LoadSeams 从工具同目录读 seams.yaml,返合并的 cross + lifecycle seam 列表
// (每行 Type 字段已填)。
func LoadSeams(path string) ([]Seam, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read seams.yaml: %w", err)
	}
	var f SeamsFile
	if err := yaml.Unmarshal(data, &f); err != nil {
		return nil, fmt.Errorf("parse seams.yaml: %w", err)
	}
	out := make([]Seam, 0, len(f.Cross)+len(f.Lifecycle))
	for _, s := range f.Cross {
		s.Type = "cross"
		out = append(out, s)
	}
	for _, s := range f.Lifecycle {
		s.Type = "lifecycle"
		out = append(out, s)
	}
	return out, nil
}
