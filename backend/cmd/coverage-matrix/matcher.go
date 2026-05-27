package main

import (
	"sort"
	"strings"
)

// BuildMatrix joins truth × covers and returns the post-matching Matrix.
// Orphan annotations (point at no truth) and unannotated tests are also surfaced.
//
// BuildMatrix 合并 truth × covers,返匹配后的 Matrix。
// 孤立注释(指向不存在 truth)与漏注释测试也呈现。
func BuildMatrix(t Truth, covers []Coverage, unannotated []UnannotatedRow) Matrix {
	m := Matrix{Unannotated: unannotated}

	// Build truth lookup tables: target-key → row index.
	// 建 truth 索引表:target-key → row index。
	epIdx := map[string]int{}
	for i, ep := range t.Endpoints {
		epIdx[ep.Key()] = i
	}
	ecIdx := map[string]int{}
	for i, ec := range t.ErrCodes {
		ecIdx["errcode:"+ec.Code] = i
	}
	sseIdx := map[string]int{}
	for i, s := range t.SSE {
		sseIdx[s.Key()] = i
	}

	// Prepare row buckets in same order as truth.
	// 按 truth 顺序预创建 row 容器。
	m.Endpoints = make([]EndpointRow, len(t.Endpoints))
	for i, ep := range t.Endpoints {
		m.Endpoints[i].Endpoint = ep
	}
	m.ErrCodes = make([]ErrCodeRow, len(t.ErrCodes))
	for i, ec := range t.ErrCodes {
		m.ErrCodes[i].ErrCode = ec
	}
	m.SSE = make([]SSERow, len(t.SSE))
	for i, s := range t.SSE {
		m.SSE[i].SSE = s
	}
	var crossSeams, lifecycleSeams []Seam
	for _, s := range t.Seams {
		if s.Type == "cross" {
			crossSeams = append(crossSeams, s)
		} else {
			lifecycleSeams = append(lifecycleSeams, s)
		}
	}
	m.Cross = make([]SeamRow, len(crossSeams))
	crossIdx := map[string]int{}
	for i, s := range crossSeams {
		m.Cross[i].Seam = s
		crossIdx["cross:"+s.ID] = i
	}
	m.Lifecycle = make([]SeamRow, len(lifecycleSeams))
	lifeIdx := map[string]int{}
	for i, s := range lifecycleSeams {
		m.Lifecycle[i].Seam = s
		lifeIdx["lifecycle:"+s.ID] = i
	}

	// Walk each annotation; route to its bucket.
	// 遍历每条注释,路由到对应 bucket。
	for _, c := range covers {
		testRef := c.File + "::" + c.TestFunc
		for _, raw := range c.Targets {
			target := stripModifier(raw)
			matched := false

			// 1) HTTP endpoint: "METHOD /path"
			if i, ok := epIdx[target]; ok {
				m.Endpoints[i].Tests = append(m.Endpoints[i].Tests, testRef)
				matched = true
			}
			// 2) errcode:CODE
			if i, ok := ecIdx[target]; ok {
				m.ErrCodes[i].Tests = append(m.ErrCodes[i].Tests, testRef)
				matched = true
			}
			// 3) sse:STREAM:EVENT[:SUB]
			if i, ok := sseIdx[target]; ok {
				m.SSE[i].Tests = append(m.SSE[i].Tests, testRef)
				matched = true
			}
			// 4) cross:<seam_id>
			if i, ok := crossIdx[target]; ok {
				m.Cross[i].Tests = append(m.Cross[i].Tests, testRef)
				matched = true
			}
			// 5) lifecycle:<seam_id>
			if i, ok := lifeIdx[target]; ok {
				m.Lifecycle[i].Tests = append(m.Lifecycle[i].Tests, testRef)
				matched = true
			}
			if !matched {
				m.Orphans = append(m.Orphans, OrphanRow{
					Annotation: raw,
					TestFunc:   c.TestFunc,
					File:       c.File,
					Line:       c.Line,
				})
			}
		}
	}

	sort.Slice(m.Orphans, func(i, j int) bool {
		if m.Orphans[i].File != m.Orphans[j].File {
			return m.Orphans[i].File < m.Orphans[j].File
		}
		return m.Orphans[i].Line < m.Orphans[j].Line
	})

	return m
}

// stripModifier removes the "(modifier)" suffix from an annotation target so
// the same endpoint can have multiple covering tests scoped by modifier
// (happy / not_found_404 / etc).
//
// stripModifier 剥去 "(modifier)" 后缀,让同一 endpoint 可被多个测试以不同
// modifier(happy / not_found_404 等)各自覆盖。
func stripModifier(target string) string {
	if i := strings.Index(target, "("); i >= 0 {
		return strings.TrimSpace(target[:i])
	}
	return target
}
