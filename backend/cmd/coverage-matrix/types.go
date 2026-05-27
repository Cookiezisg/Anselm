package main

// Truth holds the authoritative inventory of testable surfaces scanned from
// production code + protocol specs + seams.yaml. The matrix tool reconciles
// these with `// covers:` annotations in pipeline tests.
//
// Truth 是从生产代码 + 协议规范 + seams.yaml 扫出的"应当被覆盖"权威清单;
// 工具用它来对账 pipeline 测试的 // covers: 注释。
type Truth struct {
	Endpoints []Endpoint
	ErrCodes  []ErrCode
	SSE       []SSEEvent
	Seams     []Seam
}

// Endpoint identifies a single HTTP endpoint discovered in handler Register methods.
//
// Endpoint 标识一个 HTTP 端点(来自 handler Register 方法 mux.HandleFunc 调用)。
type Endpoint struct {
	Method string // GET / POST / PATCH / DELETE
	Path   string // e.g. /api/v1/api-keys/{id}
	Source string // file:line of registration
}

// Key returns the canonical "METHOD PATH" representation used in annotations.
//
// Key 返回注释中使用的标准 "METHOD PATH" 形式。
func (e Endpoint) Key() string { return e.Method + " " + e.Path }

// ErrCode is a registered (sentinel, http status, code) row from response/errmap.go.
//
// ErrCode 是 response/errmap.go 登记的 (sentinel, http status, code) 三元组。
type ErrCode struct {
	Code       string
	HTTPStatus int
	Sentinel   string
	Source     string
}

// SSEEvent represents one observable SSE protocol surface (stream × event ×
// optional sub-discriminator). Closed enumeration; hardcoded in sse_truth.go.
//
// SSEEvent 表示一个 SSE 协议可观察面(流 × 事件 × 可选子区分符)。
// 封闭枚举;hardcode 在 sse_truth.go。
type SSEEvent struct {
	Stream    string // "eventlog" / "notifications" / "forge"
	Event     string // e.g. block_start / message_stop / forge_completed
	BlockType string // optional, for eventlog block_*
	Kind      string // optional, for forge events (function/handler/workflow)
	NotifType string // optional, for notifications
}

// Key returns the canonical "sse:STREAM:EVENT[:SUB]" annotation form.
//
// Key 返回注释里的标准 "sse:STREAM:EVENT[:SUB]" 形式。
func (s SSEEvent) Key() string {
	k := "sse:" + s.Stream + ":" + s.Event
	if s.BlockType != "" {
		k += ":" + s.BlockType
	}
	if s.Kind != "" {
		k += ":" + s.Kind
	}
	if s.NotifType != "" {
		k = "sse:" + s.Stream + ":" + s.NotifType
	}
	return k
}

// Seam represents one cross-domain or lifecycle integration surface
// (handwritten in seams.yaml; not derivable from code).
//
// Seam 表示一个跨 domain / 长链路集成面(手维护在 seams.yaml)。
type Seam struct {
	ID          string `yaml:"id"`
	Description string `yaml:"description"`
	Type        string `yaml:"-"` // "cross" or "lifecycle", set by loader
}

// SeamsFile is the on-disk YAML shape.
//
// SeamsFile 是磁盘 YAML 的形状。
type SeamsFile struct {
	Cross     []Seam `yaml:"cross"`
	Lifecycle []Seam `yaml:"lifecycle"`
}

// Coverage is one `// covers:` annotation extracted from a test function.
//
// Coverage 是从测试函数提取的一条 // covers: 注释。
type Coverage struct {
	TestFunc string
	File     string
	Line     int
	Targets  []string
}

// Matrix is the post-matching report: each truth row plus its (possibly empty)
// list of covering tests, plus orphan annotations and unannotated tests.
//
// Matrix 是匹配后的报告:每条 truth 行附其(可能为空)覆盖测试列表,
// 外加孤立注释 + 漏注释测试。
type Matrix struct {
	Endpoints  []EndpointRow
	ErrCodes   []ErrCodeRow
	SSE        []SSERow
	Cross      []SeamRow
	Lifecycle  []SeamRow
	Orphans    []OrphanRow         // annotation → no matching truth
	Unannotated []UnannotatedRow   // pipeline test function with no // covers: line
}

// EndpointRow is one HTTP endpoint with its covering tests.
type EndpointRow struct {
	Endpoint Endpoint
	Tests    []string // "file::TestFunc"
}

// ErrCodeRow is one error code with its covering tests.
type ErrCodeRow struct {
	ErrCode ErrCode
	Tests   []string
}

// SSERow is one SSE event with its covering tests.
type SSERow struct {
	SSE   SSEEvent
	Tests []string
}

// SeamRow is one seam with its covering tests.
type SeamRow struct {
	Seam  Seam
	Tests []string
}

// OrphanRow is a `// covers:` annotation pointing at nothing in truth.
type OrphanRow struct {
	Annotation string
	TestFunc   string
	File       string
	Line       int
}

// UnannotatedRow is a pipeline test function with no // covers: line.
type UnannotatedRow struct {
	TestFunc string
	File     string
	Line     int
}

// Summary computes count totals across categories for human reports.
//
// Summary 计算各类别覆盖率统计供 stdout 摘要。
type Summary struct {
	Endpoints struct{ Covered, Total int }
	ErrCodes  struct{ Covered, Total int }
	SSE       struct{ Covered, Total int }
	Cross     struct{ Covered, Total int }
	Lifecycle struct{ Covered, Total int }
	Tests     int
	Files     int
}

func (m *Matrix) Summarize() Summary {
	var s Summary
	for _, r := range m.Endpoints {
		s.Endpoints.Total++
		if len(r.Tests) > 0 {
			s.Endpoints.Covered++
		}
	}
	for _, r := range m.ErrCodes {
		s.ErrCodes.Total++
		if len(r.Tests) > 0 {
			s.ErrCodes.Covered++
		}
	}
	for _, r := range m.SSE {
		s.SSE.Total++
		if len(r.Tests) > 0 {
			s.SSE.Covered++
		}
	}
	for _, r := range m.Cross {
		s.Cross.Total++
		if len(r.Tests) > 0 {
			s.Cross.Covered++
		}
	}
	for _, r := range m.Lifecycle {
		s.Lifecycle.Total++
		if len(r.Tests) > 0 {
			s.Lifecycle.Covered++
		}
	}
	return s
}
