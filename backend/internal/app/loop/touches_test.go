package loop

import (
	"context"
	"testing"

	"go.uber.org/zap"

	touchpointapp "github.com/sunweilin/anselm/backend/internal/app/touchpoint"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	touchpointdomain "github.com/sunweilin/anselm/backend/internal/domain/touchpoint"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// The choke-point tap's contract: success-only, ctx-derived actor/anchors, silent no-op on
// recorder-less or conversation-less paths.
// 咽喉水龙头契约:只记成功、actor/锚点取自 ctx、无记账器或无对话路径静默无操作。

type captureRepo struct{ touches []touchpointdomain.Touch }

func (c *captureRepo) Upsert(_ context.Context, t *touchpointdomain.Touch, id string) (*touchpointdomain.Touchpoint, error) {
	c.touches = append(c.touches, *t)
	return &touchpointdomain.Touchpoint{ID: id}, nil
}

func (c *captureRepo) ListByConversation(context.Context, string, string, string, string, int) ([]*touchpointdomain.Touchpoint, string, error) {
	return nil, "", nil
}
func (c *captureRepo) PurgeConversation(context.Context, string) error { return nil }

func touchCtx(repo *captureRepo) context.Context {
	svc := touchpointapp.NewService(touchpointapp.Config{Repo: repo, Log: zap.NewNop()})
	ctx := touchpointapp.With(context.Background(), svc)
	ctx = reqctxpkg.SetConversationID(ctx, "cv_1")
	ctx = reqctxpkg.SetMessageID(ctx, "msg_9")
	return ctx
}

func tc(name string, args map[string]any) messagesdomain.ToolCallData {
	return messagesdomain.ToolCallData{ID: "tc_1", Name: name, Arguments: args}
}

func TestRecordTouches_BooksSuccessWithCtxAnchors(t *testing.T) {
	repo := &captureRepo{}
	recordTouches(touchCtx(repo), fakeTool{name: "get_function"}, tc("get_function", map[string]any{"functionId": "fn_1"}), "", true)
	if len(repo.touches) != 1 {
		t.Fatalf("touches = %d", len(repo.touches))
	}
	got := repo.touches[0]
	if got.ConversationID != "cv_1" || got.MessageID != "msg_9" ||
		got.Actor != touchpointdomain.ActorAssistant ||
		got.ItemKind != "function" || got.ItemID != "fn_1" || got.Verb != touchpointdomain.VerbViewed {
		t.Errorf("touch: %+v", got)
	}
}

func TestRecordTouches_SubagentActor(t *testing.T) {
	repo := &captureRepo{}
	ctx := reqctxpkg.SetSubagentID(touchCtx(repo), "subagt_1")
	recordTouches(ctx, fakeTool{name: "edit_document"}, tc("edit_document", map[string]any{"id": "doc_1"}), "", true)
	if repo.touches[0].Actor != touchpointdomain.ActorSubagent {
		t.Errorf("actor: %+v", repo.touches[0])
	}
}

func TestRecordTouches_SilentSkips(t *testing.T) {
	// Failed call records nothing. 失败调用不记。
	repo := &captureRepo{}
	recordTouches(touchCtx(repo), fakeTool{name: "get_function"}, tc("get_function", map[string]any{"functionId": "fn_1"}), "", false)
	if len(repo.touches) != 0 {
		t.Error("failed call must not record")
	}
	// Recorder-less ctx no-ops. 无记账器无操作。
	ctx := reqctxpkg.SetConversationID(context.Background(), "cv_1")
	recordTouches(ctx, fakeTool{name: "get_function"}, tc("get_function", map[string]any{"functionId": "fn_1"}), "", true) // must not panic 不炸即过
	// Conversation-less ctx no-ops even with a recorder. 有记账器但无对话仍无操作。
	svc := touchpointapp.NewService(touchpointapp.Config{Repo: repo, Log: zap.NewNop()})
	recordTouches(touchpointapp.With(context.Background(), svc), fakeTool{name: "get_function"}, tc("get_function", map[string]any{"functionId": "fn_1"}), "", true)
	if len(repo.touches) != 0 {
		t.Error("conversation-less path must not record")
	}
}

// markerTool mimics an agent-mounted tool: runs under the ENTITY'S OWN name, self-reports
// its bound entity. markerTool 模拟挂载工具:以实体名运行、自报绑定实体。
type markerTool struct{ fakeTool }

func (m markerTool) TouchEntity() (string, string, string) { return "function", "fn_9", "user_fn" }

func TestRecordTouches_EntityMarkerBypassesCatalog(t *testing.T) {
	repo := &captureRepo{}
	// The tool's NAME collides with a catalog key on purpose — the marker must win (no
	// mis-extraction from a user entity named like a system tool).
	// 工具名故意撞目录键——标记必须赢(用户实体撞系统工具名不得误提取)。
	recordTouches(touchCtx(repo), markerTool{fakeTool{name: "delete_agent"}},
		tc("delete_agent", map[string]any{"agentId": "ag_victim"}), "", true)
	if len(repo.touches) != 1 {
		t.Fatalf("touches = %d", len(repo.touches))
	}
	got := repo.touches[0]
	if got.ItemKind != "function" || got.ItemID != "fn_9" || got.ItemName != "user_fn" ||
		got.Verb != touchpointdomain.VerbExecuted {
		t.Errorf("marker must define the touch (not the colliding catalog rule): %+v", got)
	}
}
