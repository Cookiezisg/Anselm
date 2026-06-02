package contextmgr

import (
	"context"
	"testing"
	"time"

	"go.uber.org/zap"
	"go.uber.org/zap/zaptest"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	convdomain "github.com/sunweilin/forgify/backend/internal/domain/conversation"
	modelcatalogpkg "github.com/sunweilin/forgify/backend/internal/pkg/modelcatalog"
)

// stubConvRepo satisfies convdomain.Repository with a single in-memory conversation.
type stubConvRepo struct{ conv *convdomain.Conversation }

func (r *stubConvRepo) Get(_ context.Context, _ string) (*convdomain.Conversation, error) {
	return r.conv, nil
}
func (r *stubConvRepo) Save(_ context.Context, c *convdomain.Conversation) error {
	*r.conv = *c
	return nil
}
func (r *stubConvRepo) List(_ context.Context, _ convdomain.ListFilter) ([]*convdomain.Conversation, string, error) {
	return nil, "", nil
}
func (r *stubConvRepo) Delete(_ context.Context, _ string) error { return nil }

// stubChatRepo satisfies chatdomain.Repository with a static block list.
type stubChatRepo struct{ blocks []*chatdomain.Block }

func (r *stubChatRepo) ListBlocksByConversation(_ context.Context, _ string) ([]*chatdomain.Block, error) {
	return r.blocks, nil
}
func (r *stubChatRepo) SaveMessage(_ context.Context, _ *chatdomain.Message) error { return nil }
func (r *stubChatRepo) GetMessage(_ context.Context, _ string) (*chatdomain.Message, error) {
	return nil, nil
}
func (r *stubChatRepo) ListMessagesByConversation(_ context.Context, _ string, _ chatdomain.ListFilter) ([]*chatdomain.Message, string, error) {
	return nil, "", nil
}
func (r *stubChatRepo) SaveBlock(_ context.Context, _ *chatdomain.Block) error { return nil }
func (r *stubChatRepo) AppendDelta(_ context.Context, _, _ string) error       { return nil }
func (r *stubChatRepo) FinalizeStop(_ context.Context, _, _, _ string) error   { return nil }
func (r *stubChatRepo) GetBlock(_ context.Context, _ string) (*chatdomain.Block, error) {
	return nil, nil
}
func (r *stubChatRepo) ListBlocksByMessage(_ context.Context, _ string) ([]*chatdomain.Block, error) {
	return nil, nil
}
func (r *stubChatRepo) UpdateBlockRole(_ context.Context, _, _ string) error { return nil }
func (r *stubChatRepo) ReplayEventsAfter(_ context.Context, _ string, _ int64) ([]chatdomain.ReplayEnvelope, error) {
	return nil, nil
}
func (r *stubChatRepo) SaveAttachment(_ context.Context, _ *chatdomain.Attachment) error { return nil }
func (r *stubChatRepo) GetAttachment(_ context.Context, _ string) (*chatdomain.Attachment, error) {
	return nil, nil
}
func (r *stubChatRepo) SumTokensByConversation(_ context.Context, _ string) (chatdomain.TokensUsed, error) {
	return chatdomain.TokensUsed{}, nil
}
func (r *stubChatRepo) SumTokensByPeriod(_ context.Context, _, _ time.Time) ([]chatdomain.TokensByModel, error) {
	return nil, nil
}

func newTestManager(t *testing.T, chatRepo chatdomain.Repository, convRepo convdomain.Repository) *Manager {
	t.Helper()
	log := zaptest.NewLogger(t, zaptest.Level(zap.WarnLevel))
	return New(chatRepo, convRepo, nil, nil, nil, log)
}

// TestMaybeCompact_LargeWindow_NoCompaction verifies that a 200K-window model
// (anthropic/claude-sonnet-4) does not trigger compaction for a 50K-token conversation.
//
// TestMaybeCompact_LargeWindow_NoCompaction 验证 200K 窗口模型对 50K 对话不触发压缩。
func TestMaybeCompact_LargeWindow_NoCompaction(t *testing.T) {
	const provider = "anthropic"
	const modelID = "claude-sonnet-4"

	cap := modelcatalogpkg.Lookup(provider, modelID).Capability()
	usable := cap.UsableInput()

	// Build a conversation whose block content totals ~50K characters (≈ tokens after calibration).
	// Soft threshold is 0.70 * usable; usable = 200000 - 64000 - 2000 = 134000.
	// 50K / 134K ≈ 0.37 — well below 0.70.
	const approxTokens = 50_000
	block := &chatdomain.Block{
		ID:          "blk_test01",
		MessageID:   "msg_test01",
		Content:     string(make([]byte, approxTokens)),
		ContextRole: "hot",
	}

	conv := &convdomain.Conversation{ID: "cv_test01", UserID: "u_test01"}
	chatRepo := &stubChatRepo{blocks: []*chatdomain.Block{block}}
	convRepo := &stubConvRepo{conv: conv}

	m := newTestManager(t, chatRepo, convRepo)
	m.SetCapabilityResolver(func(_ context.Context, p, mid string) modelcatalogpkg.Capability {
		return modelcatalogpkg.Lookup(p, mid).Capability()
	})

	// If compaction ran, it would call resolveLLM which is nil → would no-op at Hard check.
	// The critical check is that ratio < Soft so compaction is skipped entirely.
	//
	// compaction 触发路径：ratio >= Soft → demote → ratio >= Hard → fullCompact。
	// 50K/134K < 0.70，所以不应进入 demote，更不会 fullCompact。
	if err := m.MaybeCompact(context.Background(), conv.ID, provider, modelID); err != nil {
		t.Fatalf("MaybeCompact returned unexpected error: %v", err)
	}

	// Verify usable is correct (not the old fallback 4000).
	_, used := m.estimate(context.Background(), conv, []*chatdomain.Block{block}, provider, modelID)
	ratio := float64(used) / float64(usable)
	if ratio >= m.thr.Soft {
		t.Errorf("large-window model: ratio %.3f >= Soft %.2f — compaction would trigger incorrectly (usable=%d)", ratio, m.thr.Soft, usable)
	}
	if usable < 100_000 {
		t.Errorf("usable %d should be > 100K for 200K-window model; capFor not wired correctly", usable)
	}
}

// TestMaybeCompact_SmallWindow_TriggersCompaction verifies that a small-window Ollama model
// (ollama/llama3, 4096 ctx) DOES trigger the Soft threshold for a 4K-token conversation.
//
// TestMaybeCompact_SmallWindow_TriggersCompaction 验证小窗口 Ollama 模型对 4K 对话触发压缩。
func TestMaybeCompact_SmallWindow_TriggersCompaction(t *testing.T) {
	const provider = "ollama"
	const modelID = "llama3"

	cap := modelcatalogpkg.Lookup(provider, modelID).Capability()
	usable := cap.UsableInput()

	// Ollama fallback: ContextWindow=4096, MaxOutput=0, so usable = 4096 - 0 - 2000 = 2096.
	// Soft=0.70 → need used > 2096*0.70=1467 tokens. At ~4 chars/token, need ~6000 chars.
	block := &chatdomain.Block{
		ID:          "blk_small01",
		MessageID:   "msg_small01",
		Content:     string(make([]byte, 6_000)),
		ContextRole: "hot",
	}

	conv := &convdomain.Conversation{ID: "cv_small01", UserID: "u_small01"}
	chatRepo := &stubChatRepo{blocks: []*chatdomain.Block{block}}
	convRepo := &stubConvRepo{conv: conv}

	m := newTestManager(t, chatRepo, convRepo)
	m.SetCapabilityResolver(func(_ context.Context, p, mid string) modelcatalogpkg.Capability {
		return modelcatalogpkg.Lookup(p, mid).Capability()
	})

	_, used := m.estimate(context.Background(), conv, []*chatdomain.Block{block}, provider, modelID)
	ratio := float64(used) / float64(usable)
	if ratio < m.thr.Soft {
		t.Errorf("small-window model: ratio %.3f < Soft %.2f — compaction should trigger (usable=%d, used=%d)", ratio, m.thr.Soft, usable, used)
	}
}

// TestEstimate_UsesRealWindow verifies that estimate() returns usable ≈ window−maxOut−buffer,
// not the old modelmeta fallback of ~4000.
//
// TestEstimate_UsesRealWindow 验证 estimate() 返回真实窗口而非旧的兜底 ~4000。
func TestEstimate_UsesRealWindow(t *testing.T) {
	const provider = "anthropic"
	const modelID = "claude-opus-4-7"

	// claude-opus-4-7: ContextWindow=1_000_000, MaxOutput=128_000.
	// usable = 1_000_000 - 128_000 - 2_000 = 870_000.
	wantUsable := 1_000_000 - 128_000 - modelcatalogpkg.SafetyBuffer

	conv := &convdomain.Conversation{ID: "cv_big01", UserID: "u_big01"}
	chatRepo := &stubChatRepo{}
	convRepo := &stubConvRepo{conv: conv}

	m := newTestManager(t, chatRepo, convRepo)
	m.SetCapabilityResolver(func(_ context.Context, p, mid string) modelcatalogpkg.Capability {
		return modelcatalogpkg.Lookup(p, mid).Capability()
	})

	usable, _ := m.estimate(context.Background(), conv, nil, provider, modelID)
	if usable != wantUsable {
		t.Errorf("usable = %d, want %d (window-aware)", usable, wantUsable)
	}
}

// TestEstimate_NilCapFor_UsesConservativeDefault verifies the nil-capFor defensive fallback.
//
// TestEstimate_NilCapFor_UsesConservativeDefault 验证 nil capFor 时走保守默认。
func TestEstimate_NilCapFor_UsesConservativeDefault(t *testing.T) {
	conv := &convdomain.Conversation{ID: "cv_nil01", UserID: "u_nil01"}
	chatRepo := &stubChatRepo{}
	convRepo := &stubConvRepo{conv: conv}

	m := newTestManager(t, chatRepo, convRepo)
	// capFor deliberately left nil.

	usable, _ := m.estimate(context.Background(), conv, nil, "", "")
	wantUsable := conservativeDefault.UsableInput()
	if usable != wantUsable {
		t.Errorf("nil capFor: usable = %d, want conservative default %d", usable, wantUsable)
	}
}
