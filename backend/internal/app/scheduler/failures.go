package scheduler

import (
	"context"
	"fmt"

	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
)

// FailureRecord is one node failure surfaced to the operator (failures API; ADR-019 highest-gen).
//
// FailureRecord 是给操作者看的单个节点失败(failures API)。
type FailureRecord struct {
	NodeID       string `json:"nodeId"`
	IterationKey int    `json:"iterationKey"`
	Generation   int    `json:"generation"`
	Error        string `json:"error"`
}

// ListFailures returns a flowrun's node failures from the journal — the node_failed events, keeping
// only the ones not superseded by a node_completed at an equal-or-higher generation (ADR-019
// highest-generation state). So after a `:replay` re-ran a failed step and it succeeded, that step no
// longer appears here. Today generation is pinned at 0 so this is just the set of node_failed events.
//
// ListFailures 从 journal 返 flowrun 的节点失败(node_failed),排除被同代或更高代 node_completed 取代的(ADR-019)。
func (s *Service) ListFailures(ctx context.Context, flowrunID string) ([]FailureRecord, error) {
	if s.journal == nil {
		return nil, nil
	}
	evs, err := s.journal.LoadJournal(ctx, flowrunID)
	if err != nil {
		return nil, fmt.Errorf("schedulerapp.ListFailures: %w", err)
	}
	type key struct {
		node string
		iter int
	}
	failed := map[key]FailureRecord{}
	succeededGen := map[key]int{}
	for i := range evs {
		e := evs[i]
		k := key{e.NodeID, e.IterationKey}
		switch e.Type {
		case flowrundomain.EventNodeFailed:
			if cur, ok := failed[k]; !ok || e.Generation >= cur.Generation {
				errMsg, _ := asMap(e.Result)["error"].(string)
				failed[k] = FailureRecord{NodeID: e.NodeID, IterationKey: e.IterationKey, Generation: e.Generation, Error: errMsg}
			}
		case flowrundomain.EventNodeCompleted:
			if g, ok := succeededGen[k]; !ok || e.Generation > g {
				succeededGen[k] = e.Generation
			}
		}
	}
	out := make([]FailureRecord, 0, len(failed))
	for k, f := range failed {
		if g, ok := succeededGen[k]; ok && g >= f.Generation {
			continue // a later (re-run) success at >= this generation supersedes the failure
		}
		out = append(out, f)
	}
	return out, nil
}
