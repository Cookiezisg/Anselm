package memory

import (
	"context"
	"errors"
	"strings"
	"testing"

	"go.uber.org/zap"

	memorydomain "github.com/sunweilin/anselm/backend/internal/domain/memory"
)

type fakeRepo struct {
	items map[string]*memorydomain.Memory
}

func newFakeRepo() *fakeRepo { return &fakeRepo{items: map[string]*memorydomain.Memory{}} }

func (f *fakeRepo) Save(_ context.Context, m *memorydomain.Memory) error {
	cp := *m
	f.items[m.Name] = &cp
	return nil
}
func (f *fakeRepo) Get(_ context.Context, name string) (*memorydomain.Memory, error) {
	m, ok := f.items[name]
	if !ok {
		return nil, memorydomain.ErrNotFound
	}
	cp := *m
	return &cp, nil
}
func (f *fakeRepo) List(_ context.Context, filter memorydomain.ListFilter) ([]*memorydomain.Memory, error) {
	var out []*memorydomain.Memory
	for _, m := range f.items {
		if filter.Pinned != nil && m.Pinned != *filter.Pinned {
			continue
		}
		cp := *m
		out = append(out, &cp)
	}
	return out, nil
}
func (f *fakeRepo) Delete(_ context.Context, name string) error {
	if _, ok := f.items[name]; !ok {
		return memorydomain.ErrNotFound
	}
	delete(f.items, name)
	return nil
}

// events holds both tiers (what fired); persisted / broadcast split them so a test can
// prove the pin echo took the frame-only tier while content writes persist an inbox row.
// events 含两档；persisted / broadcast 分档,使测试证明 pin 回声走仅帧、内容写落收件箱行。
type fakeEmitter struct {
	events    []string
	persisted []string
	broadcast []string
}

func (f *fakeEmitter) Emit(_ context.Context, eventType string, _ map[string]any) error {
	f.events = append(f.events, eventType)
	f.persisted = append(f.persisted, eventType)
	return nil
}

func (f *fakeEmitter) Broadcast(_ context.Context, eventType string, _ map[string]any) error {
	f.events = append(f.events, eventType)
	f.broadcast = append(f.broadcast, eventType)
	return nil
}

// TestUpsert_UpdatePreservesUserCuration — F147: a content update must NOT change Pinned or Source. An
// LLM write_memory (source=ai, pinned unset) editing a user's PINNED, user-authored rule must keep it
// pinned + source=user — else the verbatim-injected safety rule is silently demoted to a lazy index line.
func TestUpsert_UpdatePreservesUserCuration(t *testing.T) {
	repo := newFakeRepo()
	svc := NewService(repo, nil, zap.NewNop())
	ctx := context.Background()

	// The user curates a pinned, user-authored rule.
	if _, err := svc.Upsert(ctx, UpsertInput{Name: "rule", Description: "d", Content: "NEVER deploy on Fridays", Pinned: true, Source: "user"}); err != nil {
		t.Fatalf("create: %v", err)
	}
	// The LLM edits its wording (write_memory always sends source=ai and never sets pinned).
	m, err := svc.Upsert(ctx, UpsertInput{Name: "rule", Description: "d", Content: "NEVER deploy on Fridays or weekends", Source: "ai"})
	if err != nil {
		t.Fatalf("update: %v", err)
	}
	if !m.Pinned {
		t.Fatalf("update must PRESERVE the user's pin — a pinned safety rule was silently demoted")
	}
	if m.Source != "user" {
		t.Fatalf("update must PRESERVE authorship=user, got %q", m.Source)
	}
	if m.Content != "NEVER deploy on Fridays or weekends" {
		t.Fatalf("the content edit must still apply, got %q", m.Content)
	}
}

func TestUpsert_CreateThenUpdate_Notifies(t *testing.T) {
	repo := newFakeRepo()
	em := &fakeEmitter{}
	svc := NewService(repo, em, zap.NewNop())
	in := UpsertInput{Name: "foo", Description: "d", Content: "c", Source: "ai"}
	if _, err := svc.Upsert(context.Background(), in); err != nil {
		t.Fatal(err)
	}
	in.Content = "c2"
	if _, err := svc.Upsert(context.Background(), in); err != nil {
		t.Fatal(err)
	}
	if len(em.events) != 2 || em.events[0] != "memory.created" || em.events[1] != "memory.updated" {
		t.Errorf("notify events = %v, want [memory.created, memory.updated]", em.events)
	}
	// Content writes (created + content-update) are inbox-worthy — both persist a row. 内容写落行。
	if len(em.persisted) != 2 || len(em.broadcast) != 0 {
		t.Errorf("content writes must persist inbox rows, got persisted=%v broadcast=%v", em.persisted, em.broadcast)
	}
}

// TestPin_EchoesFrameOnly — N0 fork: pin/unpin shares "memory.updated" with a content
// write but is a user-action echo, so it takes the frame-only tier (a live signal, NO
// inbox row) — the tier chosen at the setPinned callsite, not by action string.
//
// TestPin_EchoesFrameOnly — N0 分径:pin/unpin 与内容写共用 "memory.updated" 但是用户动作回声,
// 走仅帧径(live signal、**不落行**)——档位在 setPinned 调用点选、非按 action 字符串。
func TestPin_EchoesFrameOnly(t *testing.T) {
	repo := newFakeRepo()
	em := &fakeEmitter{}
	svc := NewService(repo, em, zap.NewNop())
	if _, err := svc.Upsert(context.Background(), UpsertInput{Name: "foo", Description: "d", Content: "c", Source: "ai"}); err != nil {
		t.Fatal(err)
	}
	// created persisted a row; reset the ledger so we watch only the pin. reset 只看 pin。
	em.events, em.persisted, em.broadcast = nil, nil, nil
	if _, err := svc.Pin(context.Background(), "foo"); err != nil {
		t.Fatalf("pin: %v", err)
	}
	if len(em.broadcast) != 1 || em.broadcast[0] != "memory.updated" {
		t.Errorf("pin must broadcast memory.updated (frame-only), got broadcast=%v", em.broadcast)
	}
	if len(em.persisted) != 0 {
		t.Errorf("pin must NOT persist an inbox row, got persisted=%v", em.persisted)
	}
}

func TestUpsert_Validates(t *testing.T) {
	svc := NewService(newFakeRepo(), nil, zap.NewNop())
	cases := []struct {
		name string
		in   UpsertInput
		want error
	}{
		{"bad name", UpsertInput{Name: "Bad Name", Description: "d", Content: "c", Source: "ai"}, memorydomain.ErrInvalidName},
		{"bad source", UpsertInput{Name: "ok", Description: "d", Content: "c", Source: "robot"}, memorydomain.ErrInvalidSource},
		{"no content", UpsertInput{Name: "ok", Description: "d", Content: "", Source: "ai"}, memorydomain.ErrInvalidInput},
	}
	for _, c := range cases {
		if _, err := svc.Upsert(context.Background(), c.in); !errors.Is(err, c.want) {
			t.Errorf("%s: err = %v, want %v", c.name, err, c.want)
		}
	}
}

func TestForSystemPrompt_TwoSections(t *testing.T) {
	repo := newFakeRepo()
	svc := NewService(repo, nil, zap.NewNop())
	repo.items["rule"] = &memorydomain.Memory{Name: "rule", Description: "用户规则", Content: "全文规则", Pinned: true, Source: "user"}
	repo.items["note"] = &memorydomain.Memory{Name: "note", Description: "AI 笔记", Content: "笔记全文", Pinned: false, Source: "ai"}
	out := svc.ForSystemPrompt(context.Background())
	if !strings.Contains(out, "## Memory (pinned)") || !strings.Contains(out, "全文规则") {
		t.Errorf("missing pinned full text:\n%s", out)
	}
	if !strings.Contains(out, "## Memory index") || !strings.Contains(out, "- note: AI 笔记") {
		t.Errorf("missing index line:\n%s", out)
	}
	// non-pinned full content must NOT leak — only its description appears in the index.
	if strings.Contains(out, "笔记全文") {
		t.Errorf("non-pinned content leaked into prompt:\n%s", out)
	}
}

func TestForSystemPrompt_Empty(t *testing.T) {
	svc := NewService(newFakeRepo(), nil, zap.NewNop())
	if out := svc.ForSystemPrompt(context.Background()); out != "" {
		t.Errorf("empty memory should yield empty prompt, got:\n%q", out)
	}
}

func TestDelete_Notifies(t *testing.T) {
	repo := newFakeRepo()
	em := &fakeEmitter{}
	repo.items["x"] = &memorydomain.Memory{Name: "x"}
	svc := NewService(repo, em, zap.NewNop())
	if err := svc.Delete(context.Background(), "x"); err != nil {
		t.Fatal(err)
	}
	if len(em.events) != 1 || em.events[0] != "memory.deleted" {
		t.Errorf("delete notify = %v, want [memory.deleted]", em.events)
	}
}
