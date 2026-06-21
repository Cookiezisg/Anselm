package workflow

import (
	"context"
	"errors"
	"fmt"
	"strings"

	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
	workflowdomain "github.com/sunweilin/anselm/backend/internal/domain/workflow"
	celpkg "github.com/sunweilin/anselm/backend/internal/pkg/cel"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// CapabilityReport is the result of a capability check: structural validity always, ref
// resolution only when a resolver is wired. Resolved=false means the report is
// structural-only (no resolver injected). Problems is the (possibly empty) list of resolved
// issues — a non-empty Problems with Resolved=true means the graph is structurally fine but
// references something missing/mismatched.
//
// CapabilityReport 是能力检查结果：总有结构合法，仅在接了 resolver 时有 ref 解析。Resolved=false
// 表示报告仅结构（未注入 resolver）。Problems 是（可能空的）解析问题列表——Resolved=true 且
// Problems 非空表示图结构没问题但引用了缺失/不符的东西。
type CapabilityReport struct {
	StructurallyValid bool     `json:"structurallyValid"`
	Resolved          bool     `json:"resolved"`
	Problems          []string `json:"problems,omitempty"`
	// Warnings are ADVISORY dataflow issues that are NOT provable runtime failures, so they do NOT
	// block (OK ignores them). Today: a node input reads `producer.field` where the producer declares
	// outputs that don't include `field` (F156) — likely a typo or a missing output declaration, but a
	// declared-output contract is advisory (not runtime-enforced — the callable may return extra/fewer
	// keys), so this is a hint, not a hard problem.
	//
	// Warnings 是**建议性**数据流问题，**非**可证的运行时失败，故**不**阻断（OK 忽略它们）。当前：节点 input
	// 读 `producer.field`、而 producer 声明的输出不含 `field`（F156）——多半是拼写错或漏声明输出，但声明输出
	// 契约是建议性的（非运行时强制——callable 可能返回多/少键），故这是提示、非硬问题。
	Warnings []string `json:"warnings,omitempty"`
}

// OK reports whether the graph is structurally valid AND (when resolved) has no ref problems.
// Warnings are advisory and deliberately do NOT affect OK.
//
// OK 报告图是否结构合法，且（已解析时）无 ref 问题。Warnings 是建议性的、刻意不影响 OK。
func (r CapabilityReport) OK() bool {
	return r.StructurallyValid && len(r.Problems) == 0
}

// CapabilityCheck validates a graph structurally (domain.ValidateGraph) and, if a resolver
// is wired, resolves every node ref (existence + kind match) and reconciles control/approval
// ports against the resolved branch sets. It never returns a transport error for a missing
// ref — those land in Problems so an editor can show all issues at once. A nil resolver
// yields a structural-only report (Resolved=false).
//
// CapabilityCheck 结构校验图（domain.ValidateGraph），并在接了 resolver 时解析每个 node ref
// （存在 + kind 匹配）、把 control/approval 端口与解析出的分支集调和。它绝不为缺失 ref 返 transport
// 错误——那些落入 Problems，使编辑器一次显示所有问题。nil resolver 得仅结构报告（Resolved=false）。
func (s *Service) CapabilityCheck(ctx context.Context, g *workflowdomain.Graph) (CapabilityReport, error) {
	report := CapabilityReport{}
	if err := workflowdomain.ValidateGraph(g); err != nil {
		// Surface the structural reason as a single problem; structurally invalid graphs
		// short-circuit (ref resolution over a malformed graph is noise).
		//
		// 把结构原因作为单个问题上呈；结构非法的图短路（在畸形图上解析 ref 是噪声）。
		report.Problems = append(report.Problems, structuralReason(err))
		return report, nil
	}
	report.StructurallyValid = true

	if s.resolver == nil {
		return report, nil // structural-only
	}
	report.Resolved = true

	// Resolve each node's ref, then reconcile control/approval edge ports against the
	// resolved branch sets. Collect ALL problems (don't stop at the first).
	//
	// 解析每个节点的 ref，再把 control/approval 边端口与解析出的分支集调和。收集所有问题（不止首个）。
	infoByNode := make(map[string]RefInfo, len(g.Nodes))
	for i := range g.Nodes {
		n := &g.Nodes[i]
		info, err := s.resolver.Resolve(ctx, n.Ref)
		if err != nil {
			if errors.Is(err, workflowdomain.ErrRefNotFound) {
				report.Problems = append(report.Problems, fmt.Sprintf("node %q: ref %q not found", n.ID, n.Ref))
				continue
			}
			return CapabilityReport{}, fmt.Errorf("workflowapp.CapabilityCheck: resolve node %q: %w", n.ID, err)
		}
		infoByNode[n.ID] = info

		if want := expectedKind(n.Kind); want != "" && info.Kind != want {
			report.Problems = append(report.Problems, fmt.Sprintf("node %q: ref %q resolved to kind %q, expected %q", n.ID, n.Ref, info.Kind, want))
		}
		if !info.HasActiveVersion {
			report.Problems = append(report.Problems, fmt.Sprintf("node %q: ref %q has no active version", n.ID, n.Ref))
		}
		// Handler method must exist on the resolved handler (the .method suffix).
		//
		// handler 方法须存在于解析出的 handler 上（.method 后缀）。
		if n.Kind == workflowdomain.NodeKindAction && strings.HasPrefix(n.Ref, workflowdomain.RefPrefixHandler) {
			if method := handlerMethod(n.Ref); method != "" && !contains(info.MethodNames, method) {
				report.Problems = append(report.Problems, fmt.Sprintf("node %q: handler method %q not found on %q", n.ID, method, n.Ref))
			}
		}
		// MCP tool must exist on the connected server (the /tool suffix) — mirrors the handler-method
		// check, closing the asymmetry where a bad MCP tool name passed green to a runtime MCP_RPC_ERROR.
		// Skipped when the server is disconnected (MCPToolNames empty → nothing to validate against).
		//
		// MCP 工具须存在于已连 server（/tool 后缀）——镜像 handler 方法校验，补上「坏 MCP 工具名过绿、运行时才 MCP_RPC_ERROR」
		// 的不对称。server 未连（MCPToolNames 空）则跳过。
		if n.Kind == workflowdomain.NodeKindAction && strings.HasPrefix(n.Ref, workflowdomain.RefPrefixMCP) {
			if tool := mcpTool(n.Ref); tool != "" && len(info.MCPToolNames) > 0 && !contains(info.MCPToolNames, tool) {
				report.Problems = append(report.Problems, fmt.Sprintf("node %q: mcp tool %q not found on %q", n.ID, tool, n.Ref))
			}
		}
		// Required-input wiring (F71): every DECLARED input of a node must be wired — the schema model
		// is "declared = required" by design (no optional flag; `ToJSONSchema` treats every field as
		// required). A declared input left unwired otherwise passes this green check and crashes at
		// runtime with a "missing argument". DeclaredInputs is populated for fn / hd(.method) / agent /
		// control / approval (all have canonical declared inputs — F71 + F168-M6); only mcp leaves it
		// empty (external-tool contract, no local declared inputs) and skips naturally.
		//
		// 必填输入接线（F71）：节点每个**声明**的 input 都须接线——schema 模型本就「声明即必填」（无可选标记、
		// ToJSONSchema 视全字段必填）。否则漏接的声明 input 过这道绿检查、运行时才崩「缺参数」。DeclaredInputs
		// 对 fn/hd/agent/control/approval 都填（均有 canonical 声明 input——F71+F168-M6）；仅 mcp 留空
		//（外部工具契约、无本地声明 input）、自然跳过。
		for _, field := range info.DeclaredInputs {
			if _, wired := n.Input[field]; !wired {
				report.Problems = append(report.Problems, fmt.Sprintf("node %q: required input %q is not wired", n.ID, field))
			}
		}
	}

	s.reconcileControlPorts(g, infoByNode, &report)
	s.warnUndeclaredOutputReads(g, infoByNode, &report)
	return report, nil
}

// warnUndeclaredOutputReads is the OUTPUT-side counterpart to the F71 input-wiring check (closing the
// asymmetry F156 flagged) — but as a WARNING, not a problem. For every node input expression, it
// extracts the `producer.field` reads and warns when the producer DECLARES outputs that don't include
// `field`: at runtime scope[producer] is a strict map, so reading an absent key fails — UNLESS the
// callable returned that key anyway. Declared outputs are NOT runtime-enforced (a function/agent's
// result is passed through verbatim — toResultMap / coerceDeclaredOutputs — so it may carry extra keys
// or omit declared ones), so a mismatch is a likely-but-not-certain failure → advisory, never blocking.
// Skips: schema-less producers (no declared outputs → mcp/control/approval/trigger), the implicit `.text`
// fallback key, and has()-guarded reads (the author defended the absence). A compile failure on the
// per-graph env is ignored (the structural pass already validated compilability).
//
// warnUndeclaredOutputReads 是 F71 输入接线检查的输出侧对应（补 F156 指出的不对称）——但作为**警告**、非问题。
// 对每条节点 input 表达式，抽出 `producer.field` 读，当 producer **声明**了不含 `field` 的输出时告警：运行时
// scope[producer] 是严格 map，读不存在的键会失败——除非 callable 恰好返回了该键。声明输出**非**运行时强制
// （function/agent 结果原样透传——toResultMap / coerceDeclaredOutputs——可能带多余键或漏声明键），故不匹配是
// 很可能但非必然的失败 → 建议性、绝不阻断。跳过：无声明输出的 producer（mcp/control/approval/trigger）、隐式
// `.text` 兜底键、has() 守卫读（作者已防其缺失）。每图 env 编译失败则忽略（结构检查已校过可编译性）。
func (s *Service) warnUndeclaredOutputReads(g *workflowdomain.Graph, infoByNode map[string]RefInfo, report *CapabilityReport) {
	roots := make([]string, len(g.Nodes))
	for i := range g.Nodes {
		roots[i] = g.Nodes[i].ID
	}
	senv, err := celpkg.NewScopedEnv(roots)
	if err != nil {
		return // env build failed (no roots / dup) — skip the advisory pass, never fail the check
	}
	seen := map[string]bool{} // dedup per (consumer, producer, field)
	for i := range g.Nodes {
		n := &g.Nodes[i]
		for field, expr := range n.Input {
			plain, guarded, eerr := senv.ExtractRootSelects(expr)
			if eerr != nil {
				continue
			}
			guardedSet := make(map[string]bool, len(guarded))
			for _, gs := range guarded {
				guardedSet[gs.Root+"\x00"+gs.Field] = true
			}
			for _, rs := range plain {
				info, ok := infoByNode[rs.Root]
				if !ok || len(info.DeclaredOutputs) == 0 {
					continue // producer unresolved or schema-less → nothing to check against
				}
				if rs.Field == flowrunResultTextKey || contains(info.DeclaredOutputs, rs.Field) {
					continue // implicit .text fallback, or a declared field — fine
				}
				if guardedSet[rs.Root+"\x00"+rs.Field] {
					continue // has(producer.field)-guarded read — the author handled the absence
				}
				key := n.ID + "\x00" + rs.Root + "\x00" + rs.Field
				if seen[key] {
					continue
				}
				seen[key] = true
				// A trigger's payload fields are fixed (canonical for cron/webhook/fsnotify, config-driven
				// for sensor) — "declare it on the producer" doesn't apply, so steer to a typo fix instead.
				fix := fmt.Sprintf("declare it as an output of %q or guard with has(%s.%s)", rs.Root, rs.Root, rs.Field)
				if info.Kind == relationdomain.EntityKindTrigger {
					fix = fmt.Sprintf("fix the field name or guard with has(%s.%s) — a trigger's payload fields are fixed", rs.Root, rs.Field)
				}
				report.Warnings = append(report.Warnings, fmt.Sprintf(
					"node %q input %q reads %q.%s, but %q declares no output %q (declared: %v) — if it is not produced at runtime this node fails; %s",
					n.ID, field, rs.Root, rs.Field, rs.Root, rs.Field, info.DeclaredOutputs, fix))
			}
		}
	}
}

// flowrunResultTextKey is the implicit result key a schema-less callable result is wrapped under
// (toResultMap), so `producer.text` is ALWAYS a legal read regardless of declared outputs (F156).
const flowrunResultTextKey = "text"

// CapabilityCheckByID resolves the workflow's active graph and capability-checks it.
//
// CapabilityCheckByID 解析 workflow 的 active 图并能力检查。
func (s *Service) CapabilityCheckByID(ctx context.Context, id string) (CapabilityReport, error) {
	w, err := s.repo.GetWorkflow(ctx, id)
	if err != nil {
		return CapabilityReport{}, fmt.Errorf("workflowapp.CapabilityCheckByID: %w", err)
	}
	if w.ActiveVersionID == "" {
		return CapabilityReport{}, workflowdomain.ErrNoActiveVersion
	}
	v, err := s.repo.GetVersion(ctx, w.ActiveVersionID)
	if err != nil {
		return CapabilityReport{}, fmt.Errorf("workflowapp.CapabilityCheckByID: %w", err)
	}
	g, err := decodeGraph(v.Graph)
	if err != nil {
		return CapabilityReport{}, fmt.Errorf("workflowapp.CapabilityCheckByID: %w", err)
	}
	return s.CapabilityCheck(ctx, g)
}

// reconcileControlPorts checks every control-source edge's FromPort is a real branch port of
// the resolved control logic. (Approval ports yes/no are structural and already enforced by
// ValidateGraph; control branch membership needs the resolved ref, so it lives here.)
//
// reconcileControlPorts 检查每条 control 源边的 FromPort 是解析出的 control 逻辑的真实分支端口。
// （approval 的 yes/no 是结构性的、ValidateGraph 已强制；control 分支归属需解析后的 ref，故在此。）
func (s *Service) reconcileControlPorts(g *workflowdomain.Graph, infoByNode map[string]RefInfo, report *CapabilityReport) {
	kindByNode := make(map[string]string, len(g.Nodes))
	for i := range g.Nodes {
		kindByNode[g.Nodes[i].ID] = g.Nodes[i].Kind
	}
	for _, e := range g.Edges {
		if kindByNode[e.From] != workflowdomain.NodeKindControl {
			continue
		}
		info, ok := infoByNode[e.From]
		if !ok {
			continue // the control ref failed to resolve; already reported as a problem
		}
		if !contains(info.BranchPorts, e.FromPort) {
			report.Problems = append(report.Problems, fmt.Sprintf("edge %q: control %q has no branch port %q", e.ID, e.From, e.FromPort))
		}
	}
}

// BuildPinClosure walks every node ref in the graph, resolves each referenced entity's active
// version id, and recurses into an agent's mounted fn_/hd_ callables (depth ≤ 2), returning a
// {entity_id: active_version_id} map. The scheduler calls this in StartRun to freeze the
// exact entity versions a flowrun executes against — so a mid-run edit to any referenced
// entity cannot change a running flow (determinism / replay safety). This lives here, not in
// the scheduler, because the workflow module best understands "graph + ref resolution".
// Requires a resolver; with none it returns an empty map (the scheduler treats that as
// unpinnable and refuses to start — but that wiring is the scheduler's, not ours).
//
// BuildPinClosure 走图里每个 node ref，解析每个被引用实体的 active 版本 id，并递归进 agent 挂载的
// fn_/hd_ 可调用项（深度 ≤ 2），返回 {entity_id: active_version_id} map。调度器在 StartRun 调它冻结
// flowrun 执行所依的确切实体版本——使运行中对任何被引用实体的编辑无法改变运行中的流（确定性 / 重放
// 安全）。它在此而非调度器，因为 workflow 模块最懂「图 + ref 解析」。需 resolver；无则返空 map
// （调度器视作不可 pin 而拒启——但那接线是调度器的、非我们的）。
func (s *Service) BuildPinClosure(ctx context.Context, g *workflowdomain.Graph) (map[string]string, error) {
	pins := map[string]string{}
	if s.resolver == nil || g == nil {
		return pins, nil
	}
	for i := range g.Nodes {
		if err := s.pinRef(ctx, g.Nodes[i].Ref, pins, 0); err != nil {
			return nil, err
		}
	}
	return pins, nil
}

// pinRef resolves one ref and records its entity → active-version pin, then (for an agent,
// and only at depth 0) recurses one level into the agent's mounted fn_/hd_ callables. depth
// caps recursion at 2 (the agent itself, then its direct callables) — an agent cannot mount
// another agent, so two levels is the closure's natural floor.
//
// pinRef 解析一个 ref 并记录其 实体 → active 版本 pin，然后（对 agent、且仅在深度 0）向 agent
// 挂载的 fn_/hd_ 可调用项递归一层。depth 把递归封顶在 2（agent 自身，再其直接可调用项）——agent
// 不能挂 agent，故两层是闭包的天然下界。
func (s *Service) pinRef(ctx context.Context, ref string, pins map[string]string, depth int) error {
	if depth > 1 {
		return nil
	}
	entityID := entityIDOf(ref)
	if entityID == "" {
		return nil
	}
	if _, done := pins[entityID]; done {
		return nil
	}
	info, err := s.resolver.Resolve(ctx, ref)
	if err != nil {
		if errors.Is(err, workflowdomain.ErrRefNotFound) {
			return nil // unresolvable ref is a CapabilityCheck concern, not a pin failure
		}
		return fmt.Errorf("workflowapp.BuildPinClosure: resolve %q: %w", ref, err)
	}
	if info.HasActiveVersion {
		pins[entityID] = info.ActiveVersionID
	}
	if info.Kind == relationdomain.EntityKindAgent {
		for _, callable := range info.AgentCallables {
			if err := s.pinRef(ctx, callable, pins, depth+1); err != nil {
				return err
			}
		}
	}
	return nil
}

// expectedKind maps a node kind to the relation EntityKind its ref must resolve to (empty for
// action, which spans function/handler/mcp — that match is by ref prefix, checked separately).
//
// expectedKind 把 node kind 映射到其 ref 须解析成的 relation EntityKind（action 为空——它跨
// function/handler/mcp，靠 ref 前缀单独检查）。
func expectedKind(nodeKind string) string {
	switch nodeKind {
	case workflowdomain.NodeKindTrigger:
		return relationdomain.EntityKindTrigger
	case workflowdomain.NodeKindAgent:
		return relationdomain.EntityKindAgent
	case workflowdomain.NodeKindControl:
		return relationdomain.EntityKindControl
	case workflowdomain.NodeKindApproval:
		return relationdomain.EntityKindApproval
	}
	return ""
}

// entityIDOf strips a ref down to the bare entity id used as the pin key: fn_/ag_/ctl_/apf_/
// trg_ pass through; hd_<id>.method drops the method; mcp:server/tool maps to the mcp server.
//
// entityIDOf 把 ref 削成 pin key 用的裸实体 id：fn_/ag_/ctl_/apf_/trg_ 直通；hd_<id>.method 去
// 方法；mcp:server/tool 映射到 mcp server。
func entityIDOf(ref string) string {
	ref = strings.TrimSpace(ref)
	switch {
	case strings.HasPrefix(ref, workflowdomain.RefPrefixHandler):
		if i := strings.IndexByte(ref, '.'); i > 0 {
			return ref[:i]
		}
		return ref
	case strings.HasPrefix(ref, workflowdomain.RefPrefixMCP):
		server := strings.TrimPrefix(ref, workflowdomain.RefPrefixMCP)
		if i := strings.IndexByte(server, '/'); i > 0 {
			server = server[:i]
		}
		return server
	default:
		return ref
	}
}

// handlerMethod extracts the .method suffix from a handler ref (empty if none).
//
// handlerMethod 抽 handler ref 的 .method 后缀（无则空）。
func handlerMethod(ref string) string {
	if i := strings.IndexByte(ref, '.'); i > 0 {
		return ref[i+1:]
	}
	return ""
}

// mcpTool extracts the /tool suffix from an mcp ref (mcp:server/tool → tool; empty if none).
//
// mcpTool 抽 mcp ref 的 /tool 后缀（mcp:server/tool → tool；无则空）。
func mcpTool(ref string) string {
	token := strings.TrimPrefix(ref, workflowdomain.RefPrefixMCP)
	if i := strings.IndexByte(token, '/'); i >= 0 {
		return token[i+1:]
	}
	return ""
}

// structuralReason pulls the human reason out of an ErrInvalidGraph (falls back to the error
// string).
//
// structuralReason 从 ErrInvalidGraph 取人类原因（回退为错误串）。
func structuralReason(err error) string {
	var de *errorspkg.Error
	if errors.As(err, &de) && de.Details != nil {
		if reason, ok := de.Details["reason"].(string); ok {
			return reason
		}
	}
	return err.Error()
}

func contains(ss []string, s string) bool {
	for _, v := range ss {
		if v == s {
			return true
		}
	}
	return false
}
