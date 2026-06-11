package workflow

import (
	"errors"
	"testing"
)

// trigNode / actNode / ctlNode / apfNode are terse fixtures for graph assembly.
func trigNode(id string) Node { return Node{ID: id, Kind: NodeKindTrigger, Ref: "trg_aaaa"} }
func actNode(id string) Node {
	return Node{ID: id, Kind: NodeKindAction, Ref: "fn_bbbb", Input: map[string]string{"x": "input.y"}}
}
func ctlNode(id string) Node { return Node{ID: id, Kind: NodeKindControl, Ref: "ctl_cccc"} }
func apfNode(id string) Node { return Node{ID: id, Kind: NodeKindApproval, Ref: "apf_dddd"} }

func edge(id, from, to string) Edge        { return Edge{ID: id, From: from, To: to} }
func edgeP(id, from, port, to string) Edge { return Edge{ID: id, From: from, FromPort: port, To: to} }

func TestValidateGraph(t *testing.T) {
	cases := []struct {
		name string
		g    *Graph
		ok   bool
	}{
		{
			name: "valid linear trigger->action",
			g: &Graph{
				Nodes: []Node{trigNode("t"), actNode("a")},
				Edges: []Edge{edge("e1", "t", "a")},
			},
			ok: true,
		},
		{
			name: "valid single trigger no edges",
			g:    &Graph{Nodes: []Node{trigNode("t")}},
			ok:   true,
		},
		{
			name: "valid control branch fan-out",
			g: &Graph{
				Nodes: []Node{trigNode("t"), ctlNode("c"), actNode("a"), actNode("b")},
				Edges: []Edge{edge("e1", "t", "c"), edgeP("e2", "c", "hot", "a"), edgeP("e3", "c", "cold", "b")},
			},
			ok: true,
		},
		{
			name: "valid approval yes/no",
			g: &Graph{
				Nodes: []Node{trigNode("t"), apfNode("p"), actNode("a"), actNode("b")},
				Edges: []Edge{edge("e1", "t", "p"), edgeP("e2", "p", "yes", "a"), edgeP("e3", "p", "no", "b")},
			},
			ok: true,
		},
		{
			name: "valid control loop (back edge from control)",
			g: &Graph{
				Nodes: []Node{trigNode("t"), actNode("a"), ctlNode("c")},
				Edges: []Edge{edge("e1", "t", "a"), edge("e2", "a", "c"), edgeP("e3", "c", "retry", "a"), edgeP("e4", "c", "done", "a")},
			},
			ok: true,
		},
		{
			name: "reject unknown kind",
			g:    &Graph{Nodes: []Node{trigNode("t"), {ID: "x", Kind: "bogus", Ref: "fn_z"}}, Edges: []Edge{edge("e", "t", "x")}},
			ok:   false,
		},
		{
			name: "reject ref-prefix mismatch (action with ag_)",
			g:    &Graph{Nodes: []Node{trigNode("t"), {ID: "a", Kind: NodeKindAction, Ref: "ag_xxxx"}}, Edges: []Edge{edge("e", "t", "a")}},
			ok:   false,
		},
		{
			name: "reject empty ref",
			g:    &Graph{Nodes: []Node{trigNode("t"), {ID: "a", Kind: NodeKindAction, Ref: ""}}, Edges: []Edge{edge("e", "t", "a")}},
			ok:   false,
		},
		{
			name: "reject duplicate node id",
			g:    &Graph{Nodes: []Node{trigNode("t"), actNode("t")}},
			ok:   false,
		},
		{
			name: "reject duplicate edge id",
			g: &Graph{
				Nodes: []Node{trigNode("t"), actNode("a"), actNode("b")},
				Edges: []Edge{edge("e", "t", "a"), edge("e", "t", "b")},
			},
			ok: false,
		},
		{
			name: "reject dangling edge (unknown to)",
			g:    &Graph{Nodes: []Node{trigNode("t")}, Edges: []Edge{edge("e", "t", "ghost")}},
			ok:   false,
		},
		{
			name: "reject self-loop",
			g:    &Graph{Nodes: []Node{trigNode("t"), actNode("a")}, Edges: []Edge{edge("e1", "t", "a"), edge("e2", "a", "a")}},
			ok:   false,
		},
		{
			name: "reject no trigger",
			g:    &Graph{Nodes: []Node{actNode("a")}},
			ok:   false,
		},
		{
			name: "reject orphan (unreachable from trigger)",
			g:    &Graph{Nodes: []Node{trigNode("t"), actNode("a")}}, // a has no inbound path
			ok:   false,
		},
		{
			name: "reject back edge from non-control/approval (action)",
			g: &Graph{
				Nodes: []Node{trigNode("t"), actNode("a"), actNode("b")},
				Edges: []Edge{edge("e1", "t", "a"), edge("e2", "a", "b"), edge("e3", "b", "a")}, // b->a closes an unconditional cycle
			},
			ok: false,
		},
		{
			name: "reject approval bad port",
			g: &Graph{
				Nodes: []Node{trigNode("t"), apfNode("p"), actNode("a")},
				Edges: []Edge{edge("e1", "t", "p"), edgeP("e2", "p", "maybe", "a")},
			},
			ok: false,
		},
		{
			name: "reject control missing port",
			g: &Graph{
				Nodes: []Node{trigNode("t"), ctlNode("c"), actNode("a")},
				Edges: []Edge{edge("e1", "t", "c"), edge("e2", "c", "a")}, // control edge has no fromPort
			},
			ok: false,
		},
		{
			name: "reject non-control edge carrying a port",
			g: &Graph{
				Nodes: []Node{trigNode("t"), actNode("a")},
				Edges: []Edge{edgeP("e1", "t", "weird", "a")}, // trigger edge must not set a port
			},
			ok: false,
		},
		{
			name: "reject action input with empty wiring",
			g: &Graph{
				Nodes: []Node{trigNode("t"), {ID: "a", Kind: NodeKindAction, Ref: "fn_z", Input: map[string]string{"x": "  "}}},
				Edges: []Edge{edge("e", "t", "a")},
			},
			ok: false,
		},
		{
			name: "reject nil graph",
			g:    nil,
			ok:   false,
		},
		{
			name: "reject empty graph",
			g:    &Graph{},
			ok:   false,
		},
	}
	for _, c := range cases {
		err := ValidateGraph(c.g)
		if c.ok && err != nil {
			t.Errorf("%s: want valid, got %v", c.name, err)
		}
		if !c.ok {
			if err == nil {
				t.Errorf("%s: want invalid, got nil", c.name)
				continue
			}
			if !errors.Is(err, ErrInvalidGraph) {
				t.Errorf("%s: want ErrInvalidGraph, got %v", c.name, err)
			}
		}
	}
}

func TestBackEdges(t *testing.T) {
	t.Run("DAG has no back edges", func(t *testing.T) {
		g := &Graph{
			Nodes: []Node{trigNode("t"), actNode("a"), actNode("b"), ctlNode("c")},
			Edges: []Edge{edge("e1", "t", "a"), edge("e2", "a", "b"), edge("e3", "b", "c")},
		}
		if be := BackEdges(g); len(be) != 0 {
			t.Fatalf("DAG should have no back edges, got %v", be)
		}
	})

	t.Run("control retry loop yields the closing edge", func(t *testing.T) {
		g := &Graph{
			Nodes: []Node{trigNode("t"), actNode("a"), ctlNode("c")},
			Edges: []Edge{edge("e1", "t", "a"), edge("e2", "a", "c"), edgeP("e3", "c", "retry", "a")},
		}
		be := BackEdges(g)
		if len(be) != 1 || be[0].ID != "e3" {
			t.Fatalf("want single back edge e3, got %v", be)
		}
	})

	t.Run("edges to missing endpoints are skipped", func(t *testing.T) {
		g := &Graph{
			Nodes: []Node{trigNode("t")},
			Edges: []Edge{edge("e1", "t", "ghost")},
		}
		if be := BackEdges(g); len(be) != 0 {
			t.Fatalf("dangling edge must be skipped, got %v", be)
		}
	})

	t.Run("nil graph", func(t *testing.T) {
		if be := BackEdges(nil); be != nil {
			t.Fatalf("nil graph should yield nil, got %v", be)
		}
	})
}

func TestAncestors(t *testing.T) {
	eq := func(got, want []string) bool {
		if len(got) != len(want) {
			return false
		}
		for i := range got {
			if got[i] != want[i] {
				return false
			}
		}
		return true
	}

	t.Run("linear t→a→b", func(t *testing.T) {
		g := &Graph{
			Nodes: []Node{trigNode("t"), actNode("a"), actNode("b")},
			Edges: []Edge{edge("e1", "t", "a"), edge("e2", "a", "b")},
		}
		if got := Ancestors(g, "b"); !eq(got, []string{"a", "t"}) {
			t.Fatalf("ancestors(b) = %v, want [a t]", got)
		}
		if got := Ancestors(g, "a"); !eq(got, []string{"t"}) {
			t.Fatalf("ancestors(a) = %v, want [t]", got)
		}
		if got := Ancestors(g, "t"); !eq(got, []string{}) {
			t.Fatalf("ancestors(t) = %v, want []", got)
		}
	})

	t.Run("diamond: siblings are not each other's ancestors", func(t *testing.T) {
		g := &Graph{
			Nodes: []Node{trigNode("t"), actNode("a"), actNode("b"), actNode("c")},
			Edges: []Edge{edge("e1", "t", "a"), edge("e2", "t", "b"), edge("e3", "a", "c"), edge("e4", "b", "c")},
		}
		if got := Ancestors(g, "c"); !eq(got, []string{"a", "b", "t"}) {
			t.Fatalf("ancestors(c) = %v, want [a b t] (join sees both branches)", got)
		}
		// the visibility lint's whole point: a may NOT read b (and vice versa).
		if got := Ancestors(g, "a"); !eq(got, []string{"t"}) {
			t.Fatalf("ancestors(a) = %v, want [t] (sibling b must NOT be visible)", got)
		}
	})

	t.Run("loop: back edge carries an ancestor + self on the cycle", func(t *testing.T) {
		g := &Graph{
			Nodes: []Node{trigNode("t"), actNode("a"), ctlNode("c")},
			Edges: []Edge{edge("e1", "t", "a"), edge("e2", "a", "c"), edgeP("e3", "c", "retry", "a")},
		}
		// a's ancestors include c (reachable only via the back edge c→a) and a itself (a→c→a cycle),
		// so a loop body may read its own / the control's previous-iteration result.
		if got := Ancestors(g, "a"); !eq(got, []string{"a", "c", "t"}) {
			t.Fatalf("ancestors(a) = %v, want [a c t] (loop-carried + self)", got)
		}
	})
}
