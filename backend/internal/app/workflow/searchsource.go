package workflow

import (
	"context"
	"errors"
	"strings"
	"time"

	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
	workflowdomain "github.com/sunweilin/anselm/backend/internal/domain/workflow"
)

// SetSearchNotifier wires the optional write-side search hook (bootstrap).
//
// SetSearchNotifier 接上可选的写侧搜索钩子（bootstrap）。
func (s *Service) SetSearchNotifier(n searchdomain.Notifier) { s.search = n }

func (s *Service) notifySearch(ctx context.Context, id string) {
	searchdomain.Notify(ctx, s.search, searchdomain.TypeWorkflow, id, "")
}

// SearchSource projects a workflow: entity card + the ACTIVE version's graph
// textized (node names/refs/inputs/notes + edge ports) — searching "审批" finds
// the workflow that contains an approval node.
//
// SearchSource 投影 workflow：实体卡 + **活跃版本**图的文本化（节点名/ref/输入/备注
// + 边端口）——搜「审批」能找到含审批节点的工作流。
func (s *Service) SearchSource() *SearchSource { return &SearchSource{svc: s} }

type SearchSource struct{ svc *Service }

func (ss *SearchSource) Type() searchdomain.EntityType { return searchdomain.TypeWorkflow }

func (ss *SearchSource) Stamps(ctx context.Context) (map[string]time.Time, error) {
	wfs, err := ss.svc.repo.ListAllWorkflows(ctx)
	if err != nil {
		return nil, err
	}
	out := make(map[string]time.Time, len(wfs))
	for _, w := range wfs {
		out[w.ID] = w.UpdatedAt
	}
	return out, nil
}

func (ss *SearchSource) Docs(ctx context.Context, id string) ([]searchdomain.SourceDoc, error) {
	w, err := ss.svc.repo.GetWorkflow(ctx, id)
	if errors.Is(err, workflowdomain.ErrNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	card := w.Description
	if len(w.Tags) > 0 {
		card += "\n" + strings.Join(w.Tags, " ")
	}
	docs := []searchdomain.SourceDoc{{
		ChunkNo: 0, Title: w.Name, Tags: w.Tags, UpdatedAt: w.UpdatedAt,
	}}
	if w.ActiveVersionID != "" {
		if v, err := ss.svc.repo.GetVersion(ctx, w.ActiveVersionID); err == nil {
			for i, part := range searchdomain.SplitPlain(graphText(v)) {
				docs = append(docs, searchdomain.SourceDoc{
					ChunkNo: i + 1, Title: w.Name, Body: part, Tags: w.Tags, UpdatedAt: w.UpdatedAt,
				})
			}
		}
	}
	docs[0].Body = searchdomain.CapRunes(card)
	return docs, nil
}

// graphText flattens the graph for search; an undecodable graph falls back to
// the raw JSON — trigram substring search still works on it.
//
// graphText 把图拍平供检索；解不开的图回退原始 JSON——trigram 子串检索照样可用。
func graphText(v *workflowdomain.Version) string {
	g := v.GraphParsed
	if g == nil {
		parsed, err := decodeGraph(v.Graph)
		if err != nil {
			return v.Graph
		}
		g = parsed
	}
	var sb strings.Builder
	for _, n := range g.Nodes {
		sb.WriteString(n.ID + " " + n.Kind + " " + n.Ref)
		for k, expr := range n.Input {
			sb.WriteString(" " + k + "=" + expr)
		}
		if n.Notes != "" {
			sb.WriteString(" " + n.Notes)
		}
		sb.WriteString("\n")
	}
	for _, e := range g.Edges {
		if e.FromPort != "" {
			sb.WriteString(e.From + "[" + e.FromPort + "] -> " + e.To + "\n")
		}
	}
	return sb.String()
}
