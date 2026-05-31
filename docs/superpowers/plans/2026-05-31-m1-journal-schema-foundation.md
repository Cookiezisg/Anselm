# M1 — Journal + Schema Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline, this session) to implement task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add the durable-execution journal schema + journal store with ADR-018 record-once, **without breaking the build** (strangler-fig: old scheduler keeps running on old columns until M2).

**Architecture:** Additive GORM-struct schema. Amend `flowruns` (add `pinned_callables`/`generation`/`trigger_node_id`; keep `paused_state` transitionally; add `awaiting_signal` to the status CHECK). New tables `flowrun_events` (with computed `dedup_key`), `approvals`, `trigger_schedules`, `trigger_firings`, `polling_states`. New journal store with `AppendEvent` (compare-and-insert via one partial unique index) + `LoadJournal`. The other tables' stores come in M4/M5; M1 only builds the journal store + the schema for all.

**Tech Stack:** Go, GORM, modernc SQLite (`serializer:json;type:text`, `check:` CHECK, `schema_extras.go` partial index per D7), in-mem SQLite tests (T2).

**Contract:** `docs/working/workflow-revamp/17-execution-contract.md` §1/§2 + ADR-017/018/019.

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `backend/internal/domain/flowrun/flowrun.go` | FlowRun entity | Modify (3 cols + status const/CHECK) |
| `backend/internal/domain/flowrun/event.go` | `FlowRunEvent` + event-type consts + `DedupKey()` | Create |
| `backend/internal/domain/flowrun/approval.go` | `Approval` entity | Create |
| `backend/internal/domain/flowrun/journal.go` | `JournalRepository` port | Create |
| `backend/internal/domain/trigger/schedule.go` | `TriggerSchedule` + `TriggerFiring` + `PollingState` | Create |
| `backend/internal/infra/store/flowrunevent/flowrunevent.go` | journal store: `AppendEvent`, `LoadJournal` | Create |
| `backend/internal/infra/store/flowrunevent/flowrunevent_test.go` | record-once / seq / first-wins tests | Create |
| `backend/internal/infra/db/schema_extras.go` | partial unique index | Modify |
| `backend/internal/infra/store/flowrun/flowrun.go` | `AutoMigrateModels()` | Modify (add new structs) |
| `backend/cmd/server/main.go` + `backend/test/harness/harness.go` | migration registration | Modify (if not via AutoMigrateModels) |

> §S13 package alias: `flowrundomain`, `triggerdomain`, `flowruneventstore`. §S15 prefixes: events reuse no new entity prefix (child rows); approvals — new prefix? Reuse `ap_`? **Decision:** approvals id = `ap_<16hex>` (new prefix, add to S15 when M4 wires the service); events id = `fre_<16hex>`; firings = `trf_<16hex>`; schedules keyed by `(workflow_id,trigger_node_id)` composite (no id). Record these in S15 at M4/M5.

---

## Task 1: Amend FlowRun (additive, non-breaking)

**Files:** Modify `backend/internal/domain/flowrun/flowrun.go`

- [ ] **Step 1: Add the awaiting_signal status constant + the 3 new columns + expand the CHECK.**

In the status const block add:
```go
	StatusAwaitingSignal = "awaiting_signal"
```
In the `FlowRun` struct, after `VersionID`, add:
```go
	PinnedCallables map[string]string `gorm:"serializer:json;type:text;default:'{}'" json:"pinnedCallables"` // {callable_id: version_id} transitive closure snapshot (A-5/ADR-020)
	Generation      int               `gorm:"not null;default:0" json:"generation"`                          // replay-reset generation (ADR-019)
	TriggerNodeID   string            `gorm:"type:text;default:''" json:"triggerNodeId"`                     // which trigger node started this run
```
Change the `Status` tag's CHECK to include `awaiting_signal` (keep `paused` transitionally for the old scheduler; M4 drops it):
```go
	Status string `gorm:"not null;check:status IN ('running','paused','awaiting_signal','completed','failed','cancelled');index:idx_flowruns_workflow,priority:2;type:text" json:"status"`
```
Leave `PausedState` for now (deleted in M2 with the old scheduler).

- [ ] **Step 2: Build to verify non-breaking.**

Run: `cd backend && go build ./...`
Expected: success (additive columns; old scheduler untouched).

- [ ] **Step 3: Commit.**

```bash
git add backend/internal/domain/flowrun/flowrun.go
git commit -m "feat(flowrun): add pinned_callables/generation/trigger_node_id + awaiting_signal status (M1, additive)"
```

---

## Task 2: FlowRunEvent entity + event types + DedupKey (ADR-018)

**Files:** Create `backend/internal/domain/flowrun/event.go`

- [ ] **Step 1: Write the entity, the closed event-type enum, and the DedupKey helper.**

```go
package flowrun

import (
	"fmt"
	"time"
)

// Closed event-type enum (17 §1). Result + waiting + agent-substep + control = record-once;
// node_started/node_failed = append-many attempt trail (excluded from the record-once index).
const (
	EventNodeStarted        = "node_started"
	EventNodeCompleted      = "node_completed"
	EventNodeFailed         = "node_failed"
	EventBranchTaken        = "branch_taken"
	EventSignalAwaited      = "signal_awaited"
	EventSignalReceived     = "signal_received"
	EventTimerArmed         = "timer_armed"
	EventTimerFired         = "timer_fired"
	EventAgentStepStarted   = "agent_step_started"
	EventAgentStepCompleted = "agent_step_completed"
	EventFlowrunCancelled   = "flowrun_cancelled"
	EventReplayStarted      = "replay_started"
)

// FlowRunEvent is one append-only journal entry — the single source of replay truth (17 §1).
//
// FlowRunEvent 是 journal 一条 append-only 记账，重放唯一真相。
type FlowRunEvent struct {
	ID           string `gorm:"primaryKey;type:text" json:"id"`
	FlowrunID    string `gorm:"not null;type:text;index:idx_fre_flowrun,priority:1;uniqueIndex:idx_fre_seq,priority:1" json:"flowrunId"`
	Seq          int64  `gorm:"not null;uniqueIndex:idx_fre_seq,priority:2" json:"seq"` // per-flowrun strictly monotonic (allocated in the write tx)
	Type         string `gorm:"not null;check:type IN ('node_started','node_completed','node_failed','branch_taken','signal_awaited','signal_received','timer_armed','timer_fired','agent_step_started','agent_step_completed','flowrun_cancelled','replay_started');type:text" json:"type"`
	NodeID       string `gorm:"type:text;default:'';index:idx_fre_lookup,priority:2" json:"nodeId"`
	IterationKey int    `gorm:"not null;default:0;index:idx_fre_lookup,priority:3" json:"iterationKey"` // ADR-017 loop ordinal
	Generation   int    `gorm:"not null;default:0;index:idx_fre_lookup,priority:4" json:"generation"`    // ADR-019
	Attempt      int    `gorm:"not null;default:0" json:"attempt"`                                       // attempt class only
	Turn         int    `gorm:"not null;default:0" json:"turn"`                                          // agent substep only
	ToolCallID   string `gorm:"type:text;default:''" json:"toolCallId"`                                  // agent substep only
	DedupKey     string `gorm:"not null;type:text;default:''" json:"-"`                                  // record-once key (ADR-018); '' for attempt types
	Result       any    `gorm:"serializer:json;type:text" json:"result,omitempty"`

	CreatedAt time.Time `json:"createdAt"` // append-only: no updated_at / deleted_at (17 §1)
}

func (FlowRunEvent) TableName() string { return "flowrun_events" }

// DedupKey computes the record-once idempotency key (ADR-018). The partial unique index
// idx_fre_record_once is on (flowrun_id, dedup_key) WHERE type NOT IN attempt types.
//
// DedupKey 算 record-once 幂等键;attempt 类返 '' 被 partial 索引排除。
func (e *FlowRunEvent) ComputeDedupKey() string {
	switch e.Type {
	case EventNodeStarted, EventNodeFailed:
		return "" // append-many; excluded from the partial unique index
	case EventAgentStepStarted, EventAgentStepCompleted:
		return fmt.Sprintf("%s|%d|%s|%d|%d|%s", e.NodeID, e.IterationKey, e.Type, e.Generation, e.Turn, e.ToolCallID)
	default:
		return fmt.Sprintf("%s|%d|%s|%d", e.NodeID, e.IterationKey, e.Type, e.Generation)
	}
}
```

- [ ] **Step 2: Build.**

Run: `cd backend && go build ./...`
Expected: success.

- [ ] **Step 3: Commit.**

```bash
git add backend/internal/domain/flowrun/event.go
git commit -m "feat(flowrun): FlowRunEvent journal entity + dedup_key (ADR-018)"
```

---

## Task 3: Approval + trigger schedule/firing/polling entities

**Files:** Create `backend/internal/domain/flowrun/approval.go`; Create `backend/internal/domain/trigger/schedule.go`

- [ ] **Step 1: Approval entity.**

`approval.go`:
```go
package flowrun

import (
	"time"
	"gorm.io/gorm"
)

const (
	ApprovalParked    = "parked"
	ApprovalApproved  = "approved"
	ApprovalRejected  = "rejected"
	ApprovalTimedOut  = "timed_out"
	ApprovalFailed    = "failed"
	ApprovalCancelled = "cancelled" // flowrun cancelled (17 §1, +cancelled)
)

// Approval is the durable parked state for an approval node (17 §1/§9).
type Approval struct {
	ID          string         `gorm:"primaryKey;type:text" json:"id"`
	FlowrunID   string         `gorm:"not null;type:text;index" json:"flowrunId"`
	NodeID      string         `gorm:"not null;type:text" json:"nodeId"`
	Prompt      string         `gorm:"type:text" json:"prompt"`
	Payload     any            `gorm:"serializer:json;type:text" json:"payload,omitempty"`
	Status      string         `gorm:"not null;check:status IN ('parked','approved','rejected','timed_out','failed','cancelled');type:text" json:"status"`
	AllowReason bool           `gorm:"not null;default:false" json:"allowReason"`
	Reason      string         `gorm:"type:text;default:''" json:"reason,omitempty"`
	DecidedAt   *time.Time     `json:"decidedAt,omitempty"`
	CreatedAt   time.Time      `json:"createdAt"`
	UpdatedAt   time.Time      `json:"updatedAt"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Approval) TableName() string { return "approvals" }
```

- [ ] **Step 2: Trigger schedule/firing/polling entities.**

`schedule.go`:
```go
package trigger

import (
	"time"
	"gorm.io/gorm"
)

const (
	FiringPending    = "pending"
	FiringClaimed    = "claimed"
	FiringStarted    = "started"
	FiringSkipped    = "skipped"
	FiringSuperseded = "superseded"
	FiringShed       = "shed"
)

// TriggerSchedule persists listener registration + retry state (17 §1, ADR-022).
type TriggerSchedule struct {
	WorkflowID          string         `gorm:"primaryKey;type:text" json:"workflowId"`
	TriggerNodeID       string         `gorm:"primaryKey;type:text" json:"triggerNodeId"`
	Kind                string         `gorm:"not null;type:text" json:"kind"`
	Spec                map[string]any `gorm:"serializer:json;type:text;default:'{}'" json:"spec"`
	LastFiredAt         *time.Time     `json:"lastFiredAt,omitempty"`
	CatchupWindow       string         `gorm:"not null;default:'latest';check:catchup_window IN ('none','latest','window');type:text" json:"catchupWindow"`
	OverlapPolicy       string         `gorm:"not null;default:'BufferOne';check:overlap_policy IN ('Skip','BufferOne','BufferAll','AllowAll');type:text" json:"overlapPolicy"`
	RetryPolicy         map[string]any `gorm:"serializer:json;type:text;default:'{}'" json:"retryPolicy"`         // {maxAttempts, backoff} (ADR-022)
	ConsecutiveFailures int            `gorm:"not null;default:0" json:"consecutiveFailures"`                    // ADR-022
	CreatedAt           time.Time      `json:"createdAt"`
	UpdatedAt           time.Time      `json:"updatedAt"`
	DeletedAt           gorm.DeletedAt `gorm:"index" json:"-"`
}

func (TriggerSchedule) TableName() string { return "trigger_schedules" }

// TriggerFiring is the durable inbox row; status is the single lifecycle+outcome enum (17 §1, ADR-021).
type TriggerFiring struct {
	ID            string         `gorm:"primaryKey;type:text" json:"id"`
	WorkflowID    string         `gorm:"not null;type:text;uniqueIndex:idx_trf_dedup,priority:1" json:"workflowId"`
	TriggerNodeID string         `gorm:"not null;type:text;uniqueIndex:idx_trf_dedup,priority:2" json:"triggerNodeId"`
	Payload       map[string]any `gorm:"serializer:json;type:text;default:'{}'" json:"payload"`
	DedupKey      string         `gorm:"not null;type:text;uniqueIndex:idx_trf_dedup,priority:3" json:"dedupKey"`
	Status        string         `gorm:"not null;check:status IN ('pending','claimed','started','skipped','superseded','shed');type:text;index" json:"status"`
	ScheduledAt   *time.Time     `json:"scheduledAt,omitempty"`
	EnqueuedAt    time.Time      `json:"enqueuedAt"`
	FlowrunID     string         `gorm:"type:text;default:''" json:"flowrunId,omitempty"`
	CreatedAt     time.Time      `json:"createdAt"`
	UpdatedAt     time.Time      `json:"updatedAt"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
}

func (TriggerFiring) TableName() string { return "trigger_firings" }

// PollingState persists the business cursor per polling trigger (17 §1).
type PollingState struct {
	WorkflowID string         `gorm:"primaryKey;type:text" json:"workflowId"`
	NodeID     string         `gorm:"primaryKey;type:text" json:"nodeId"`
	Cursor     string         `gorm:"type:text;default:''" json:"cursor"`
	CreatedAt  time.Time      `json:"createdAt"`
	UpdatedAt  time.Time      `json:"updatedAt"`
	DeletedAt  gorm.DeletedAt `gorm:"index" json:"-"`
}

func (PollingState) TableName() string { return "polling_states" }
```

- [ ] **Step 3: Build + commit.**

Run: `cd backend && go build ./...` (Expected: success)
```bash
git add backend/internal/domain/flowrun/approval.go backend/internal/domain/trigger/schedule.go
git commit -m "feat(flowrun,trigger): approval + trigger_schedules/firings/polling_states entities (M1)"
```

---

## Task 4: Register migrations + partial unique index

**Files:** Modify `backend/internal/infra/store/flowrun/flowrun.go` (`AutoMigrateModels`); Modify `backend/internal/infra/db/schema_extras.go`

- [ ] **Step 1: Add the new structs to `AutoMigrateModels()`.**

In `infra/store/flowrun/flowrun.go`, extend the returned slice:
```go
func AutoMigrateModels() []interface{} {
	return []interface{}{
		&flowrundomain.FlowRun{},
		&flowrundomain.Node{},
		&flowrundomain.FlowRunEvent{},
		&flowrundomain.Approval{},
		&triggerdomain.TriggerSchedule{},
		&triggerdomain.TriggerFiring{},
		&triggerdomain.PollingState{},
	}
}
```
(Add the `triggerdomain "…/internal/domain/trigger"` import. If main.go/harness.go register models explicitly rather than via this factory, add the 5 structs there instead — grep `AutoMigrateModels\|flowrundomain.FlowRun{}` to find the call sites.)

- [ ] **Step 2: Add the record-once partial unique index to `schema_extras.go`.**

Find `schemaExtraGroups` (the slice of `{table, statements}`). Add a group:
```go
	{
		table: "flowrun_events",
		statements: []string{
			`CREATE UNIQUE INDEX IF NOT EXISTS idx_fre_record_once
				ON flowrun_events(flowrun_id, dedup_key)
				WHERE type NOT IN ('node_started','node_failed')`,
		},
	},
```
(Match the exact field names of the existing group struct — read the file first; the pattern is `CREATE UNIQUE INDEX IF NOT EXISTS … WHERE …`, idempotent per D6.)

- [ ] **Step 3: Build.**

Run: `cd backend && go build ./...` (Expected: success)

- [ ] **Step 4: Commit.**

```bash
git add backend/internal/infra/store/flowrun/flowrun.go backend/internal/infra/db/schema_extras.go
git commit -m "feat(db): register durable tables + record-once partial unique index (M1, ADR-018)"
```

---

## Task 5: Journal store — AppendEvent (record-once) [TDD]

**Files:** Create `backend/internal/infra/store/flowrunevent/flowrunevent.go`, `…/flowrunevent_test.go`; Create `backend/internal/domain/flowrun/journal.go`

- [ ] **Step 1: Write the port + the failing record-once test.**

`domain/flowrun/journal.go`:
```go
package flowrun

import "context"

// JournalRepository is the append-only journal port (17 §2).
type JournalRepository interface {
	// AppendEvent allocates seq in-tx and inserts; on a record-once collision (dedup_key)
	// it is a no-op and returns the existing event (compare-and-insert / first-wins, ADR-018).
	AppendEvent(ctx context.Context, e *FlowRunEvent) (*FlowRunEvent, error)
	LoadJournal(ctx context.Context, flowrunID string) ([]FlowRunEvent, error)
}
```

`infra/store/flowrunevent/flowrunevent_test.go`:
```go
package flowrunevent_test

import (
	"context"
	"testing"

	dbinfra "github.com/.../backend/internal/infra/db"            // fix import paths to module
	flowrundomain "github.com/.../backend/internal/domain/flowrun"
	flowruneventstore "github.com/.../backend/internal/infra/store/flowrunevent"
	flowrunstore "github.com/.../backend/internal/infra/store/flowrun"
)

func newStore(t *testing.T) (*flowruneventstore.Store, func()) {
	t.Helper()
	gdb, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	if err != nil { t.Fatal(err) }
	if err := dbinfra.Migrate(gdb, flowrunstore.AutoMigrateModels()...); err != nil { t.Fatal(err) }
	return flowruneventstore.New(gdb), func() {}
}

func TestAppendEvent_RecordOnceCollisionReturnsExisting(t *testing.T) {
	s, done := newStore(t); defer done()
	ctx := context.Background()
	mk := func() *flowrundomain.FlowRunEvent {
		return &flowrundomain.FlowRunEvent{ID: flowrundomain.NewEventID(), FlowrunID: "fr_1", Type: flowrundomain.EventNodeCompleted, NodeID: "n1", IterationKey: 0, Generation: 0, Result: map[string]any{"v": 1}}
	}
	first, err := s.AppendEvent(ctx, mk())
	if err != nil { t.Fatal(err) }
	second, err := s.AppendEvent(ctx, mk()) // same dedup_key → must be no-op, return first
	if err != nil { t.Fatal(err) }
	if second.Seq != first.Seq { t.Fatalf("record-once violated: got seq %d, want existing %d", second.Seq, first.Seq) }
	all, _ := s.LoadJournal(ctx, "fr_1")
	if len(all) != 1 { t.Fatalf("want 1 journaled event, got %d", len(all)) }
}
```

- [ ] **Step 2: Run — verify it fails (no Store yet).**

Run: `cd backend && go test ./internal/infra/store/flowrunevent/ -run TestAppendEvent_RecordOnce -v`
Expected: FAIL (package/Store undefined).

- [ ] **Step 3: Implement the store with seq allocation + compare-and-insert.**

`infra/store/flowrunevent/flowrunevent.go`:
```go
package flowrunevent

import (
	"context"
	"errors"
	"fmt"

	"gorm.io/gorm"
	flowrundomain "github.com/.../backend/internal/domain/flowrun"
)

type Store struct{ db *gorm.DB }

func New(db *gorm.DB) *Store { return &Store{db: db} }

// AppendEvent: single write tx — allocate per-flowrun seq, compute dedup_key, insert;
// a record-once unique violation means already-recorded → return the existing row (ADR-018).
func (s *Store) AppendEvent(ctx context.Context, e *flowrundomain.FlowRunEvent) (*flowrundomain.FlowRunEvent, error) {
	e.DedupKey = e.ComputeDedupKey()
	var out *flowrundomain.FlowRunEvent
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var maxSeq int64
		if err := tx.Model(&flowrundomain.FlowRunEvent{}).
			Where("flowrun_id = ?", e.FlowrunID).
			Select("COALESCE(MAX(seq),0)").Scan(&maxSeq).Error; err != nil {
			return err
		}
		e.Seq = maxSeq + 1
		if err := tx.Create(e).Error; err != nil {
			if isUniqueViolation(err) && e.DedupKey != "" {
				return tx.Where("flowrun_id = ? AND dedup_key = ?", e.FlowrunID, e.DedupKey).
					First(&out).Error // first-wins: hand back the already-recorded event
			}
			return err
		}
		out = e
		return nil
	})
	if err != nil { return nil, fmt.Errorf("flowruneventstore.AppendEvent: %w", err) }
	return out, nil
}

func (s *Store) LoadJournal(ctx context.Context, flowrunID string) ([]flowrundomain.FlowRunEvent, error) {
	var evs []flowrundomain.FlowRunEvent
	if err := s.db.WithContext(ctx).Where("flowrun_id = ?", flowrunID).Order("seq asc").Find(&evs).Error; err != nil {
		return nil, fmt.Errorf("flowruneventstore.LoadJournal: %w", err)
	}
	return evs, nil
}

func isUniqueViolation(err error) bool {
	return err != nil && (errors.Is(err, gorm.ErrDuplicatedKey) ||
		// modernc sqlite surfaces "UNIQUE constraint failed" / "constraint failed"
		contains(err.Error(), "UNIQUE constraint failed") || contains(err.Error(), "constraint failed: UNIQUE"))
}
func contains(s, sub string) bool { return len(s) >= len(sub) && (s == sub || indexOf(s, sub) >= 0) }
func indexOf(s, sub string) int { for i := 0; i+len(sub) <= len(s); i++ { if s[i:i+len(sub)] == sub { return i } }; return -1 }
```
> Note: prefer `strings.Contains`; the inline helper avoids an import if `strings` isn't already used — use `strings.Contains` during execution. Confirm the exact modernc unique-violation error string by running the test (Step 4) and reading the failure; adjust `isUniqueViolation` to match.

Add `NewEventID()` to `domain/flowrun/event.go` (reuse the project ID gen, S15 `fre_<16hex>` — grep an existing `New*ID` for the helper, e.g. `idpkg.New("fre")`).

- [ ] **Step 4: Run — verify it passes.**

Run: `cd backend && go test ./internal/infra/store/flowrunevent/ -run TestAppendEvent_RecordOnce -v`
Expected: PASS. (If FAIL on unique detection, read the error string and fix `isUniqueViolation`.)

- [ ] **Step 5: Commit.**

```bash
git add backend/internal/domain/flowrun/journal.go backend/internal/domain/flowrun/event.go backend/internal/infra/store/flowrunevent/
git commit -m "feat(flowrun): journal store AppendEvent record-once + LoadJournal (M1, TDD, ADR-018)"
```

---

## Task 6: seq strict-monotonic [TDD]

**Files:** Modify `…/flowrunevent_test.go`

- [ ] **Step 1: Write the failing test.**

```go
func TestAppendEvent_SeqStrictlyMonotonicPerFlowrun(t *testing.T) {
	s, done := newStore(t); defer done()
	ctx := context.Background()
	for i := 1; i <= 5; i++ {
		e := &flowrundomain.FlowRunEvent{ID: flowrundomain.NewEventID(), FlowrunID: "fr_x", Type: flowrundomain.EventNodeStarted, NodeID: "n", Attempt: i}
		got, err := s.AppendEvent(ctx, e)
		if err != nil { t.Fatal(err) }
		if got.Seq != int64(i) { t.Fatalf("seq not monotonic: got %d want %d", got.Seq, i) }
	}
	// a different flowrun starts its own seq at 1
	other, _ := s.AppendEvent(ctx, &flowrundomain.FlowRunEvent{ID: flowrundomain.NewEventID(), FlowrunID: "fr_y", Type: flowrundomain.EventNodeStarted, NodeID: "n"})
	if other.Seq != 1 { t.Fatalf("per-flowrun seq isolation broken: got %d want 1", other.Seq) }
}
```
> Note: `node_started` has `dedup_key=''` → append-many → 5 distinct rows (proves attempt-class is NOT deduped).

- [ ] **Step 2: Run — verify PASS** (implementation from Task 5 already satisfies it).

Run: `cd backend && go test ./internal/infra/store/flowrunevent/ -run TestAppendEvent_Seq -v`
Expected: PASS. (If the 5 node_started rows collapse to 1, the partial index is wrong — it must exclude `node_started`.)

- [ ] **Step 3: Commit.**

```bash
git add backend/internal/infra/store/flowrunevent/flowrunevent_test.go
git commit -m "test(flowrun): seq strict-monotonic per-flowrun + attempt-class append-many (M1)"
```

---

## Task 7: first-wins across competing signals [TDD]

**Files:** Modify `…/flowrunevent_test.go`

- [ ] **Step 1: Write the failing test — the approval timeout↔decision race (17 §2/§9).**

```go
func TestAppendEvent_SignalReceivedFirstWins(t *testing.T) {
	s, done := newStore(t); defer done()
	ctx := context.Background()
	// user decision and timeout both journal a signal_received for the same approval node/iter/gen
	decision := &flowrundomain.FlowRunEvent{ID: flowrundomain.NewEventID(), FlowrunID: "fr_a", Type: flowrundomain.EventSignalReceived, NodeID: "appr", Result: map[string]any{"decision": "yes", "source": "user"}}
	timeout := &flowrundomain.FlowRunEvent{ID: flowrundomain.NewEventID(), FlowrunID: "fr_a", Type: flowrundomain.EventSignalReceived, NodeID: "appr", Result: map[string]any{"decision": "no", "source": "timeout"}}
	first, _ := s.AppendEvent(ctx, decision)
	second, _ := s.AppendEvent(ctx, timeout) // same dedup_key bucket → no-op, returns first
	if second.ID != first.ID { t.Fatalf("first-wins violated: second got id %s, want %s", second.ID, first.ID) }
	all, _ := s.LoadJournal(ctx, "fr_a")
	if len(all) != 1 { t.Fatalf("double signal recorded: want 1, got %d", len(all)) }
	if all[0].Result.(map[string]any)["source"] != "user" { t.Fatalf("first writer (user) did not win") }
}
```

- [ ] **Step 2: Run — verify PASS.**

Run: `cd backend && go test ./internal/infra/store/flowrunevent/ -run TestAppendEvent_SignalReceived -v`
Expected: PASS — proves the approval double-fire the review flagged cannot happen (both are `signal_received`, same dedup bucket).

- [ ] **Step 3: Commit.**

```bash
git add backend/internal/infra/store/flowrunevent/flowrunevent_test.go
git commit -m "test(flowrun): signal_received first-wins (approval timeout↔decision race) (M1)"
```

---

## Task 8: Full M1 gate

- [ ] **Step 1: Run unit + mock + staticcheck.**

Run:
```bash
make unit
cd backend && go build ./... && staticcheck ./...
```
Expected: all green (M1 adds no pipeline yet; `make mock` unaffected). Paste output (verification-before-completion).

- [ ] **Step 2: Update IMPLEMENTATION-LOG + changelog (§S14).**

Append an M1 entry to `docs/working/workflow-revamp/IMPLEMENTATION-LOG.md` (schema added, journal store TDD'd, invariants proven) and a dev-log line to `docs/references/changelog.md` (first M1 code shipped).

- [ ] **Step 3: Final M1 commit + push.**

```bash
git add -A backend/ docs/working/workflow-revamp/IMPLEMENTATION-LOG.md docs/references/changelog.md
git commit -m "chore(workflow-revamp): M1 journal+schema foundation complete"
git push origin main
```

---

## Self-Review

**Spec coverage (M1 task #2 + 17 §1/§2):** flowruns amendment ✓ (T1); flowrun_events + dedup_key + partial index ✓ (T2/T4); approvals/trigger_schedules/trigger_firings/polling_states ✓ (T3); journal store AppendEvent/LoadJournal ✓ (T5); record-once dedup ✓ (T5), seq monotonic ✓ (T6), first-wins ✓ (T7). Non-breaking (paused_state/Node kept) ✓ (T1, strangler-fig). Gap: the other tables' *stores* (approvals/triggers) are intentionally deferred to M4/M5 — M1 only ships their schema + the journal store.

**Placeholder scan:** import paths shown as `github.com/.../` — must be replaced with the real module path at execution (grep `module ` in `backend/go.mod`); `isUniqueViolation`'s exact error string confirmed at T5 Step 4; `NewEventID()` wired to the project's id helper. These are flagged execution-time resolutions, not silent TODOs.

**Type consistency:** `ComputeDedupKey()` (event.go) ↔ used in `AppendEvent` (store) ✓; event-type consts ↔ CHECK string ↔ DedupKey switch all use the same 12 literals ✓; `AutoMigrateModels()` lists exactly the 5 new structs + 2 old ✓; partial index `WHERE type NOT IN ('node_started','node_failed')` ↔ DedupKey returns `''` for exactly those two ✓.
