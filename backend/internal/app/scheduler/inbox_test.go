package scheduler

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	approvaldomain "github.com/sunweilin/anselm/backend/internal/domain/approval"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
)

// ---- ListInbox enrichment (scheduler 工单④) --------------------------------
//
// The inbox row = parked node + workflow context: workflowId/workflowName joined from the run
// header, deadline derived from the pinned approval version's timeout (the same DeadlineFrom the
// CheckTimeouts sweep uses). These tests pin the join, the soft-deleted name fallback, the
// deadline presence/absence semantic, the wire key shape, and the bounded-batch-read guarantee.

// TestInbox_EnrichWorkflowAndDeadline: the happy path — a parked approval row carries its
// workflow's id + display name and an absolute deadline of parkedAt + timeout.
func TestInbox_EnrichWorkflowAndDeadline(t *testing.T) {
	apf := &fakeApproval{byID: map[string]*approvaldomain.Version{
		"apf_1": {Template: "ok?", Timeout: "30d", TimeoutBehavior: approvaldomain.TimeoutReject},
	}}
	svc, _ := mkSvc(t, approvalGraph(), newDisp(), nil, apf, "")
	wf := svc.workflows.(*fakeWorkflows)
	wf.names = map[string]string{"wf_1": "spend pipeline"}
	ctx := ctxWS("ws_1")
	id := mustRun(t, svc, ctx, map[string]any{"v": "1"}) // parks at "human"

	rows, err := svc.ListInbox(ctx)
	if err != nil {
		t.Fatalf("ListInbox: %v", err)
	}
	if len(rows) != 1 {
		t.Fatalf("want 1 inbox row, got %d: %+v", len(rows), rows)
	}
	row := rows[0]
	if row.FlowRunID != id || row.NodeID != "human" || row.Status != flowrundomain.NodeParked {
		t.Fatalf("parked node identity lost: %+v", row.FlowRunNode)
	}
	if row.WorkflowID != "wf_1" || row.WorkflowName != "spend pipeline" {
		t.Fatalf("workflow join wrong: id=%q name=%q", row.WorkflowID, row.WorkflowName)
	}
	if row.Deadline == nil {
		t.Fatalf("timeout=30d must yield a deadline")
	}
	want := row.CreatedAt.Add(30 * 24 * time.Hour)
	if !row.Deadline.Equal(want) {
		t.Fatalf("deadline must be parkedAt+30d: got %v want %v", row.Deadline, want)
	}
	// The deadline the wire shows must be the SAME one the sweep fires on (DeadlineFrom is shared):
	// sweeping just before it leaves the row parked, sweeping at it settles the row.
	if err := svc.CheckTimeouts(ctx, want.Add(-time.Second)); err != nil {
		t.Fatalf("CheckTimeouts(before): %v", err)
	}
	if after, _ := svc.ListInbox(ctx); len(after) != 1 {
		t.Fatalf("sweep before the advertised deadline must not settle the row")
	}
	if err := svc.CheckTimeouts(ctx, want); err != nil {
		t.Fatalf("CheckTimeouts(at): %v", err)
	}
	if after, _ := svc.ListInbox(ctx); len(after) != 0 {
		t.Fatalf("sweep at the advertised deadline must settle the row, still parked: %+v", after)
	}
}

// TestInbox_WireKeyShape pins the JSON contract: camelCase enrich keys present when resolvable,
// deadline ABSENT (not null/zero) when the form never times out.
func TestInbox_WireKeyShape(t *testing.T) {
	apf := &fakeApproval{byID: map[string]*approvaldomain.Version{
		"apf_1": {Template: "ok?", Timeout: "1w", TimeoutBehavior: approvaldomain.TimeoutApprove},
	}}
	svc, _ := mkSvc(t, approvalGraph(), newDisp(), nil, apf, "")
	svc.workflows.(*fakeWorkflows).names = map[string]string{"wf_1": "named"}
	ctx := ctxWS("ws_1")
	mustRun(t, svc, ctx, map[string]any{"v": "1"})

	rows, err := svc.ListInbox(ctx)
	if err != nil || len(rows) != 1 {
		t.Fatalf("ListInbox: rows=%d err=%v", len(rows), err)
	}
	raw, err := json.Marshal(rows[0])
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	s := string(raw)
	for _, key := range []string{`"workflowId":"wf_1"`, `"workflowName":"named"`, `"deadline":"`, `"flowrunId":"`, `"nodeId":"human"`} {
		if !strings.Contains(s, key) {
			t.Fatalf("wire row missing %s: %s", key, s)
		}
	}

	// No timeout → the deadline key is absent, not null.
	apf.byID["apf_1"] = &approvaldomain.Version{Template: "ok?"}
	svc2, _ := mkSvc(t, approvalGraph(), newDisp(), nil, apf, "")
	mustRun(t, svc2, ctx, map[string]any{"v": "1"})
	rows2, err := svc2.ListInbox(ctx)
	if err != nil || len(rows2) != 1 {
		t.Fatalf("ListInbox(no timeout): rows=%d err=%v", len(rows2), err)
	}
	if rows2[0].Deadline != nil {
		t.Fatalf("no timeout must yield no deadline, got %v", rows2[0].Deadline)
	}
	if raw2, _ := json.Marshal(rows2[0]); strings.Contains(string(raw2), `"deadline"`) {
		t.Fatalf("deadline key must be absent when the form never times out: %s", raw2)
	}
}

// TestInbox_SoftDeletedWorkflowNameFallsBackToID: a workflow the namer cannot see (soft-deleted)
// still yields a row; its name falls back to the bare id (the relation Namer precedent).
func TestInbox_SoftDeletedWorkflowNameFallsBackToID(t *testing.T) {
	apf := &fakeApproval{byID: map[string]*approvaldomain.Version{
		"apf_1": {Template: "ok?"},
	}}
	svc, _ := mkSvc(t, approvalGraph(), newDisp(), nil, apf, "")
	// names left nil → NamesByIDs returns no entry for wf_1 (the soft-deleted shape).
	ctx := ctxWS("ws_1")
	mustRun(t, svc, ctx, map[string]any{"v": "1"})

	rows, err := svc.ListInbox(ctx)
	if err != nil || len(rows) != 1 {
		t.Fatalf("ListInbox: rows=%d err=%v", len(rows), err)
	}
	if rows[0].WorkflowID != "wf_1" || rows[0].WorkflowName != "wf_1" {
		t.Fatalf("soft-deleted workflow must fall back to the bare id: id=%q name=%q", rows[0].WorkflowID, rows[0].WorkflowName)
	}
}

// TestInbox_BoundedBatchReads: N parked rows cost ONE NamesByIDs call (deduped ids) and ONE
// approval Resolve per distinct (ref, pinned version) — never per-row N+1.
func TestInbox_BoundedBatchReads(t *testing.T) {
	apf := &fakeApproval{byID: map[string]*approvaldomain.Version{
		"apf_1": {Template: "ok?", Timeout: "3d", TimeoutBehavior: approvaldomain.TimeoutReject},
	}}
	svc, _ := mkSvc(t, approvalGraph(), newDisp(), nil, apf, "")
	wf := svc.workflows.(*fakeWorkflows)
	wf.names = map[string]string{"wf_1": "batch"}
	ctx := ctxWS("ws_1")
	mustRun(t, svc, ctx, map[string]any{"v": "1"})
	mustRun(t, svc, ctx, map[string]any{"v": "2"})
	mustRun(t, svc, ctx, map[string]any{"v": "3"})

	apf.resolveCalls = 0 // StartRun's own park path resolves too; count only the inbox read
	rows, err := svc.ListInbox(ctx)
	if err != nil {
		t.Fatalf("ListInbox: %v", err)
	}
	if len(rows) != 3 {
		t.Fatalf("want 3 parked rows, got %d", len(rows))
	}
	if wf.namesCalls != 1 {
		t.Fatalf("workflow names must be ONE batch call, got %d", wf.namesCalls)
	}
	if len(wf.namesIDs) != 1 || wf.namesIDs[0] != "wf_1" {
		t.Fatalf("names batch must receive deduped ids, got %v", wf.namesIDs)
	}
	if apf.resolveCalls != 1 {
		t.Fatalf("same (ref, pinned version) must resolve ONCE (memoized), got %d", apf.resolveCalls)
	}
	for _, r := range rows {
		if r.WorkflowName != "batch" || r.Deadline == nil {
			t.Fatalf("every row must be enriched: %+v", r)
		}
	}
}

// TestInbox_UnresolvableFormOmitsDeadlineOnly: a form the resolver cannot produce (deleted
// approval entity) costs the row its deadline — never the row itself (it must stay decidable).
func TestInbox_UnresolvableFormOmitsDeadlineOnly(t *testing.T) {
	apf := &fakeApproval{byID: map[string]*approvaldomain.Version{
		"apf_1": {Template: "ok?", Timeout: "3d", TimeoutBehavior: approvaldomain.TimeoutReject},
	}}
	svc, _ := mkSvc(t, approvalGraph(), newDisp(), nil, apf, "")
	svc.workflows.(*fakeWorkflows).names = map[string]string{"wf_1": "still here"}
	ctx := ctxWS("ws_1")
	id := mustRun(t, svc, ctx, map[string]any{"v": "1"})

	delete(apf.byID, "apf_1") // form gone after the park (fake returns nil, nil)
	rows, err := svc.ListInbox(ctx)
	if err != nil || len(rows) != 1 {
		t.Fatalf("ListInbox: rows=%d err=%v", len(rows), err)
	}
	row := rows[0]
	if row.FlowRunID != id || row.WorkflowName != "still here" {
		t.Fatalf("row must survive an unresolvable form: %+v", row)
	}
	if row.Deadline != nil {
		t.Fatalf("unresolvable form must omit the deadline, got %v", row.Deadline)
	}
}
