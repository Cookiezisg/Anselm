package aispawn

import (
	"context"
	"errors"
	"strings"
	"testing"

	mentiondomain "github.com/sunweilin/foryx/backend/internal/domain/mention"
)

type starter struct {
	gotSystemPrompt string
	convID          string
}

func (s *starter) StartSeeded(_ context.Context, systemPrompt string) (string, error) {
	s.gotSystemPrompt = systemPrompt
	if s.convID == "" {
		s.convID = "cv_new"
	}
	return s.convID, nil
}

type sender struct {
	gotConvID   string
	gotContent  string
	gotMentions []mentiondomain.MentionInput
	sent        bool
}

func (s *sender) SendSeed(_ context.Context, convID, content string, mentions []mentiondomain.MentionInput) (string, error) {
	s.sent = true
	s.gotConvID = convID
	s.gotContent = content
	s.gotMentions = mentions
	return "msg_1", nil
}

type renderer struct {
	out   string
	gotID string
	err   error
}

func (r *renderer) Render(_ context.Context, executionID string) (string, error) {
	r.gotID = executionID
	return r.out, r.err
}

// TestIterate_SeedsEntityMentionAndSteer: iterate opens a conversation stamped with the generic
// iterate steer and sends the user's request carrying an @-mention of the target entity (whose
// definition the mention resolver freezes in) — no per-entity context building.
//
// TestIterate_SeedsEntityMentionAndSteer：iterate 开一个打上通用 iterate steer 的对话、发用户请求并携带目标实体的
// @-mention（其定义由 mention resolver 冻结进来）——无 per-entity 上下文构建。
func TestIterate_SeedsEntityMentionAndSteer(t *testing.T) {
	st := &starter{}
	sd := &sender{}
	svc := NewService(st, sd, nil, nil)

	convID, err := svc.Iterate(context.Background(), mentiondomain.MentionFunction, "fn_42", "make it batch-capable")
	if err != nil {
		t.Fatalf("Iterate: %v", err)
	}
	if convID != "cv_new" {
		t.Fatalf("convID = %q", convID)
	}
	if !strings.Contains(st.gotSystemPrompt, "edit_function") || !strings.Contains(st.gotSystemPrompt, "Do NOT call any create_*") {
		t.Fatalf("system prompt should carry the generic iterate steer, got: %q", st.gotSystemPrompt)
	}
	if sd.gotContent != "make it batch-capable" {
		t.Fatalf("first message should be the user's request, got %q", sd.gotContent)
	}
	if len(sd.gotMentions) != 1 || sd.gotMentions[0].Type != mentiondomain.MentionFunction || sd.gotMentions[0].ID != "fn_42" {
		t.Fatalf("entity should be @-mentioned into the first message, got %+v", sd.gotMentions)
	}
}

// TestIterate_EmptyRequestRejected: iterate needs a request (the entity rides the message's mention,
// so there must be a message).
//
// TestIterate_EmptyRequestRejected：iterate 需要一个请求（实体随消息的 mention 上行，故必须有消息）。
func TestIterate_EmptyRequestRejected(t *testing.T) {
	svc := NewService(&starter{}, &sender{}, nil, nil)
	if _, err := svc.Iterate(context.Background(), mentiondomain.MentionAgent, "ag_1", ""); !errors.Is(err, ErrEmptyRequest) {
		t.Fatalf("empty request should be rejected, got %v", err)
	}
}

// TestTriage_RendersExecutionIntoSystemPrompt: triage renders the execution (resolved by id) into
// the system prompt and opens the conversation; the execution kind is irrelevant to aispawn (the
// renderer port handles prefix dispatch).
//
// TestTriage_RendersExecutionIntoSystemPrompt：triage 把执行（按 id 解析）渲进 system prompt 并开对话；执行类型对
// aispawn 不相关（renderer 端口管前缀分发）。
func TestTriage_RendersExecutionIntoSystemPrompt(t *testing.T) {
	st := &starter{}
	sd := &sender{}
	rd := &renderer{out: "Status: failed\nError: boom"}
	svc := NewService(st, sd, rd, nil)

	convID, err := svc.Triage(context.Background(), "fne_7", "")
	if err != nil {
		t.Fatalf("Triage: %v", err)
	}
	if convID != "cv_new" {
		t.Fatalf("convID = %q", convID)
	}
	if rd.gotID != "fne_7" {
		t.Fatalf("renderer should be asked for the execution id, got %q", rd.gotID)
	}
	if !strings.Contains(st.gotSystemPrompt, "diagnose") || !strings.Contains(st.gotSystemPrompt, "boom") {
		t.Fatalf("system prompt should carry the triage steer + the rendered execution, got: %q", st.gotSystemPrompt)
	}
	if !sd.sent || sd.gotContent != "Please diagnose this execution." {
		t.Fatalf("triage should send a default first message, got sent=%v content=%q", sd.sent, sd.gotContent)
	}
	if len(sd.gotMentions) != 0 {
		t.Fatalf("triage carries context via the system prompt, not a mention; got %+v", sd.gotMentions)
	}
}

// TestTriage_RendererErrorBubbles: a renderer failure (e.g. unknown id prefix) aborts before any
// conversation is created.
//
// TestTriage_RendererErrorBubbles：renderer 失败（如未知 id 前缀）在建任何对话前中止。
func TestTriage_RendererErrorBubbles(t *testing.T) {
	st := &starter{}
	rd := &renderer{err: errors.New("unknown execution id prefix")}
	svc := NewService(st, &sender{}, rd, nil)
	if _, err := svc.Triage(context.Background(), "zzz_1", ""); err == nil {
		t.Fatal("a renderer error should bubble")
	}
	if st.gotSystemPrompt != "" {
		t.Fatal("no conversation should be created when rendering fails")
	}
}
