package chat

import (
	"testing"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
)

// TestSweepOrphansCancelsNonTerminalTurnsPerWorkspace proves boot reconciliation handles both
// pending and streaming crash-shaped rows, closes streaming blocks, and does not cross workspace
// boundaries.
// TestSweepOrphansCancelsNonTerminalTurnsPerWorkspace 验证 boot 对账同时收扫 pending/streaming 孤儿、
// 收尾 streaming block，并且不越 workspace 边界。
func TestSweepOrphansCancelsNonTerminalTurnsPerWorkspace(t *testing.T) {
	svc, store := newSvc(t, &fakeClient{script: textTurn()}, newRecordBridge())
	crashCtx := ctxWS("ws_crash")
	otherCtx := ctxWS("ws_other")

	for _, message := range []*messagesdomain.Message{
		{ID: "msg_pending_crash", ConversationID: "cv_crash", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusPending},
		{ID: "msg_stream_crash", ConversationID: "cv_crash", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusStreaming},
		{ID: "msg_stream_other", ConversationID: "cv_other", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusStreaming},
	} {
		ctx := crashCtx
		if message.ID == "msg_stream_other" {
			ctx = otherCtx
		}
		var blocks []messagesdomain.Block
		if message.ID != "msg_pending_crash" {
			blocks = []messagesdomain.Block{{
				ID: "blk_" + message.ID, MessageID: message.ID, ConversationID: message.ConversationID,
				Type: messagesdomain.BlockTypeText, Content: "partial", Status: messagesdomain.StatusStreaming,
				ContextRole: messagesdomain.ContextRoleHot,
			}}
		}
		if err := store.CreateMessage(ctx, message, blocks); err != nil {
			t.Fatalf("seed %s: %v", message.ID, err)
		}
	}

	svc.SweepOrphans(crashCtx)

	for _, id := range []string{"msg_pending_crash", "msg_stream_crash"} {
		got, err := store.GetMessage(crashCtx, id)
		if err != nil {
			t.Fatalf("GetMessage %s: %v", id, err)
		}
		if got.Status != messagesdomain.StatusCancelled || got.StopReason != messagesdomain.StopReasonCancelled {
			t.Fatalf("crash orphan %s not cancelled: status=%q stop=%q", id, got.Status, got.StopReason)
		}
	}
	streamed, err := store.GetMessage(crashCtx, "msg_stream_crash")
	if err != nil {
		t.Fatalf("GetMessage streamed crash orphan: %v", err)
	}
	if len(streamed.Blocks) != 1 || streamed.Blocks[0].Status != messagesdomain.StatusCancelled {
		t.Fatalf("streaming block not cancelled: %+v", streamed.Blocks)
	}

	other, err := store.GetMessage(otherCtx, "msg_stream_other")
	if err != nil {
		t.Fatalf("GetMessage other workspace: %v", err)
	}
	if other.Status != messagesdomain.StatusStreaming || len(other.Blocks) != 1 || other.Blocks[0].Status != messagesdomain.StatusStreaming {
		t.Fatalf("workspace isolation broken: %+v", other)
	}
}
