package workflow

import (
	"fmt"
	"sort"
	"strings"
)

// ValidateGraph is the pure structural validator for a workflow graph: shape (per-node
// kind/ref/input), well-formedness (unique ids, no dangling/self edges, ≥1 trigger,
// reachability), cycle discipline (every back edge originates from a control/approval
// node), and structural port reconciliation. It does NOT resolve refs (does the entity
// exist? does its active version have this port/method?) — that needs the catalog and is
// the app layer's CapabilityCheck. It does NOT compile CEL (原则 #3) — the app does that.
// A failure returns ErrInvalidGraph carrying a human reason in details["reason"].
//
// The future durable interpreter imports THIS SAME function to gate a graph before a run,
// so it stays pure and dependency-free.
//
// ValidateGraph 是 workflow 图的纯结构校验：形状（逐节点 kind/ref/input）、良构（id 唯一、无
// 悬挂/自环边、≥1 trigger、可达性）、环纪律（每条回边出自 control/approval 节点）、结构性端口
// 调和。它不解析 ref（实体存在吗？active 版本有此端口/方法吗？）——那需 catalog，是 app 层
// CapabilityCheck。它不编译 CEL（原则 #3）——app 做。失败返回 ErrInvalidGraph，人类原因在
// details["reason"]。
//
// 未来 durable 解释器 import 同一函数在运行前给图设闸，故它保持纯、无依赖。
func ValidateGraph(g *Graph) error {
	if g == nil {
		return invalidGraph("graph is nil")
	}

	// --- node ids unique + per-node shape ---
	byID := make(map[string]*Node, len(g.Nodes))
	triggerCount := 0
	for i := range g.Nodes {
		n := &g.Nodes[i]
		if strings.TrimSpace(n.ID) == "" {
			return invalidGraph("node has empty id")
		}
		if _, dup := byID[n.ID]; dup {
			return invalidGraph(fmt.Sprintf("duplicate node id %q", n.ID))
		}
		byID[n.ID] = n
		if err := validateNodeShape(n); err != nil {
			return err
		}
		if n.Kind == NodeKindTrigger {
			triggerCount++
		}
	}
	if len(g.Nodes) == 0 {
		return invalidGraph("graph has no nodes")
	}
	if triggerCount == 0 {
		return invalidGraph("graph must have at least one trigger node")
	}

	// --- edge ids unique + endpoints resolve + no self-loop + port shape ---
	edgeIDs := make(map[string]bool, len(g.Edges))
	for i := range g.Edges {
		e := &g.Edges[i]
		if strings.TrimSpace(e.ID) == "" {
			return invalidGraph("edge has empty id")
		}
		if edgeIDs[e.ID] {
			return invalidGraph(fmt.Sprintf("duplicate edge id %q", e.ID))
		}
		edgeIDs[e.ID] = true

		from, ok := byID[e.From]
		if !ok {
			return invalidGraph(fmt.Sprintf("edge %q references unknown from-node %q", e.ID, e.From))
		}
		if _, ok := byID[e.To]; !ok {
			return invalidGraph(fmt.Sprintf("edge %q references unknown to-node %q", e.ID, e.To))
		}
		if e.From == e.To {
			return invalidGraph(fmt.Sprintf("edge %q is a self-loop on node %q", e.ID, e.From))
		}
		if err := validateEdgePort(e, from); err != nil {
			return err
		}
	}

	// --- reachability: every node reachable from some trigger ---
	if err := validateReachability(g, byID); err != nil {
		return err
	}

	// --- cycle discipline: every back edge must originate from control/approval ---
	for _, be := range BackEdges(g) {
		src := byID[be.From] // present: BackEdges only walks resolved edges
		if src.Kind != NodeKindControl && src.Kind != NodeKindApproval {
			return invalidGraph(fmt.Sprintf(
				"back edge %q from node %q (kind %s) is not allowed: loops may only be closed by a control or approval branch",
				be.ID, be.From, src.Kind))
		}
	}
	return nil
}

// validateNodeShape checks a single node's kind/ref/input independent of the rest of the
// graph: kind is known; ref non-empty and its prefix matches the kind; action inputs are
// non-empty CEL strings.
//
// validateNodeShape 独立于图其余部分校验单节点的 kind/ref/input：kind 已知；ref 非空且前缀配
// kind；action 的 input 是非空 CEL 串。
func validateNodeShape(n *Node) error {
	switch n.Kind {
	case NodeKindTrigger, NodeKindAction, NodeKindAgent, NodeKindControl, NodeKindApproval:
	default:
		return invalidGraph(fmt.Sprintf("node %q has unknown kind %q", n.ID, n.Kind))
	}
	ref := strings.TrimSpace(n.Ref)
	if ref == "" {
		return invalidGraph(fmt.Sprintf("node %q has empty ref", n.ID))
	}
	if !refMatchesKind(n.Kind, ref) {
		return invalidGraph(fmt.Sprintf("node %q (kind %s) has ref %q whose prefix does not match its kind", n.ID, n.Kind, ref))
	}
	// Action wiring must be concrete: every declared input maps to a non-empty CEL string
	// (an empty wire would feed the activity a blank — a silent authoring bug).
	//
	// action 接线须具体：每个声明 input 映射到非空 CEL 串（空连线会喂 activity 空白——静默编排 bug）。
	if n.Kind == NodeKindAction {
		for field, expr := range n.Input {
			if strings.TrimSpace(expr) == "" {
				return invalidGraph(fmt.Sprintf("node %q action input %q has an empty wiring expression", n.ID, field))
			}
		}
	}
	return nil
}

// refMatchesKind reports whether ref's prefix is legal for kind. action accepts fn_ / hd_
// / mcp: ; the others each accept their single prefix.
//
// refMatchesKind 报告 ref 前缀对 kind 是否合法。action 接 fn_ / hd_ / mcp:；其余各接其单一前缀。
func refMatchesKind(kind, ref string) bool {
	switch kind {
	case NodeKindTrigger:
		return strings.HasPrefix(ref, RefPrefixTrigger)
	case NodeKindAction:
		return strings.HasPrefix(ref, RefPrefixFunction) ||
			strings.HasPrefix(ref, RefPrefixHandler) ||
			strings.HasPrefix(ref, RefPrefixMCP)
	case NodeKindAgent:
		return strings.HasPrefix(ref, RefPrefixAgent)
	case NodeKindControl:
		return strings.HasPrefix(ref, RefPrefixControl)
	case NodeKindApproval:
		return strings.HasPrefix(ref, RefPrefixApproval)
	}
	return false
}

// validateEdgePort reconciles the edge's FromPort with its source node's kind, structurally
// only: an approval source must emit yes|no; a control source must name some non-empty port
// (membership in the resolved ctl_'s branch set needs ref resolution → app layer); any other
// source must leave FromPort empty.
//
// validateEdgePort 仅结构性地调和边 FromPort 与源节点 kind：approval 源须发 yes|no；control 源须
// 命名某非空端口（是否属于解析后 ctl_ 的分支集需 ref 解析→app 层）；其它源须 FromPort 留空。
func validateEdgePort(e *Edge, from *Node) error {
	switch from.Kind {
	case NodeKindApproval:
		if e.FromPort != ApprovalPortYes && e.FromPort != ApprovalPortNo {
			return invalidGraph(fmt.Sprintf("edge %q from approval node %q must have fromPort 'yes' or 'no', got %q", e.ID, e.From, e.FromPort))
		}
	case NodeKindControl:
		if strings.TrimSpace(e.FromPort) == "" {
			return invalidGraph(fmt.Sprintf("edge %q from control node %q must name a branch fromPort", e.ID, e.From))
		}
	default:
		if e.FromPort != "" {
			return invalidGraph(fmt.Sprintf("edge %q from %s node %q must not set a fromPort", e.ID, from.Kind, e.From))
		}
	}
	return nil
}

// validateReachability rejects orphan nodes: every node must be reachable by following
// edges forward from some trigger node. A node with no path from any trigger can never run,
// so it is an authoring error, not dead-but-harmless data.
//
// validateReachability 拒绝孤儿节点：每个节点都须从某 trigger 沿边正向可达。无任何 trigger 通路
// 的节点永不会运行，故是编排错误，而非无害死数据。
func validateReachability(g *Graph, byID map[string]*Node) error {
	adj := make(map[string][]string, len(g.Nodes))
	for _, e := range g.Edges {
		adj[e.From] = append(adj[e.From], e.To)
	}
	reached := make(map[string]bool, len(g.Nodes))
	var stack []string
	for i := range g.Nodes {
		if g.Nodes[i].Kind == NodeKindTrigger {
			if !reached[g.Nodes[i].ID] {
				reached[g.Nodes[i].ID] = true
				stack = append(stack, g.Nodes[i].ID)
			}
		}
	}
	for len(stack) > 0 {
		cur := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		for _, nxt := range adj[cur] {
			if !reached[nxt] {
				reached[nxt] = true
				stack = append(stack, nxt)
			}
		}
	}
	for id := range byID {
		if !reached[id] {
			return invalidGraph(fmt.Sprintf("node %q is unreachable from any trigger", id))
		}
	}
	return nil
}

// BackEdges returns the graph's back edges: edges whose target is on the current DFS
// recursion stack when the edge is traversed (the classic reducible back-edge test). For an
// acyclic graph this is empty; a structured loop closed by a control/approval branch yields
// exactly that closing edge. Edges referencing a missing endpoint are skipped (ValidateGraph
// reports those separately), so this is safe to call on a not-yet-validated graph.
//
// This is a standalone exported PURE function on purpose: the future durable interpreter
// imports the SAME function to classify edges identically at run time — there is one
// definition of "back edge" in the system.
//
// BackEdges 返回图的回边：遍历某边时其目标正在当前 DFS 递归栈上的边（经典可归约回边判定）。无环图
// 为空；由 control/approval 分支闭合的结构化循环恰得那条闭合边。引用缺失端点的边被跳过（ValidateGraph
// 另行报告），故对未校验图调用也安全。
//
// 它刻意是独立导出的纯函数：未来 durable 解释器 import 同一函数在运行时同样分类边——系统里
// 「回边」只有一个定义。
func BackEdges(g *Graph) []Edge {
	if g == nil {
		return nil
	}
	exists := make(map[string]bool, len(g.Nodes))
	for _, n := range g.Nodes {
		exists[n.ID] = true
	}
	// out[from] is the list of edges leaving `from`, in declaration order — deterministic
	// so the DFS (and thus the back-edge set) is stable across calls.
	//
	// out[from] 是离开 from 的边列表，按声明序——确定性，使 DFS（及回边集）跨调用稳定。
	out := make(map[string][]Edge, len(g.Nodes))
	for _, e := range g.Edges {
		if exists[e.From] && exists[e.To] {
			out[e.From] = append(out[e.From], e)
		}
	}

	const (
		white = 0 // unvisited
		gray  = 1 // on the recursion stack
		black = 2 // fully explored
	)
	color := make(map[string]int, len(g.Nodes))
	var back []Edge

	// Iterative DFS with an explicit frame stack (graphs can be deep; avoid blowing the Go
	// stack). A node is gray while its subtree is in progress; an edge to a gray node is a
	// back edge.
	//
	// 显式帧栈的迭代 DFS（图可能很深；避免爆 Go 栈）。节点子树进行中为 gray；指向 gray 节点的边是回边。
	type frame struct {
		node string
		i    int // index into out[node] of the next edge to follow
	}
	for _, n := range g.Nodes {
		if color[n.ID] != white {
			continue
		}
		color[n.ID] = gray
		stack := []frame{{node: n.ID}}
		for len(stack) > 0 {
			f := &stack[len(stack)-1]
			edges := out[f.node]
			if f.i >= len(edges) {
				color[f.node] = black
				stack = stack[:len(stack)-1]
				continue
			}
			e := edges[f.i]
			f.i++
			switch color[e.To] {
			case gray:
				back = append(back, e)
			case white:
				color[e.To] = gray
				stack = append(stack, frame{node: e.To})
			}
		}
	}
	return back
}

// Ancestors returns, sorted, every node id with a directed path TO nodeID over the FULL edge set
// (forward AND back edges) — i.e. the nodes guaranteed to have completed before nodeID runs, hence
// the only ones whose result its Input CEL may read (model B). Reverse BFS over To→From adjacency; a
// visited set terminates loops, so nodeID itself appears iff it sits on a cycle (a loop body may read
// its own previous iteration). Edges with a missing endpoint are skipped (ValidateGraph reports those
// separately), so this is safe on an unvalidated graph. Like BackEdges, it is an exported pure
// function so any future consumer classifies "ancestor" the one way.
//
// Ancestors 返回（已排序）所有「有一条有向路径通到 nodeID」的 node id（沿全部边——前向 + 回边），即保证在
// nodeID 跑之前已完成、因而其 Input CEL 可读其 result 的节点（model B）。沿 To→From 反向 BFS；visited 集终止
// 循环，故 nodeID 自身仅当它在某个环上时出现（循环体可读自己上一轮）。缺端点的边被跳过（ValidateGraph 另报），
// 故对未校验图调用安全。同 BackEdges，是导出纯函数，使任何后续消费者对「祖先」只有一个定义。
func Ancestors(g *Graph, nodeID string) []string {
	if g == nil {
		return nil
	}
	exists := make(map[string]bool, len(g.Nodes))
	for _, n := range g.Nodes {
		exists[n.ID] = true
	}
	preds := make(map[string][]string, len(g.Nodes))
	for _, e := range g.Edges {
		if exists[e.From] && exists[e.To] {
			preds[e.To] = append(preds[e.To], e.From)
		}
	}
	seen := make(map[string]bool)
	queue := append([]string(nil), preds[nodeID]...)
	for _, p := range queue {
		seen[p] = true
	}
	for len(queue) > 0 {
		cur := queue[0]
		queue = queue[1:]
		for _, p := range preds[cur] {
			if !seen[p] {
				seen[p] = true
				queue = append(queue, p)
			}
		}
	}
	out := make([]string, 0, len(seen))
	for id := range seen {
		out = append(out, id)
	}
	sort.Strings(out) // deterministic env roots + stable error messages
	return out
}

// invalidGraph wraps a human reason into ErrInvalidGraph's details (errors.Is still matches
// the sentinel by Code).
//
// invalidGraph 把人类原因包进 ErrInvalidGraph 的 details（errors.Is 仍按 Code 匹配 sentinel）。
func invalidGraph(reason string) error {
	return ErrInvalidGraph.WithDetails(map[string]any{"reason": reason})
}
