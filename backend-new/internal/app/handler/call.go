package handler

import (
	"context"
	"errors"
	"fmt"
	"time"

	"go.uber.org/zap"

	handlerdomain "github.com/sunweilin/forgify/backend/internal/domain/handler"
	handlerinfra "github.com/sunweilin/forgify/backend/internal/infra/handler"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// CallInput is the request shape for Service.Call. TriggeredBy is the execution body;
// empty is derived from ctx (subagent → agent, else chat). HTTP passes manual.
//
// CallInput 是 Service.Call 的请求形状。TriggeredBy 是执行体；空则按 ctx 推（有 subagent → agent，
// 否则 chat）。HTTP 传 manual。
type CallInput struct {
	HandlerID   string
	HandlerName string
	Method      string
	Args        map[string]any
	TriggeredBy string
	OnProgress  func(any)
}

// Call dispatches a method on the handler's resident instance (spawning it if needed),
// records one Call audit row, and maps crash / timeout to domain errors.
//
// Call 在 handler 的常驻实例上派发方法调用（需要则起实例）、写一行 Call 审计、把 crash / timeout
// 映射成 domain 错误。
func (s *Service) Call(ctx context.Context, in CallInput) (any, error) {
	h, err := s.resolveHandler(ctx, in.HandlerID, in.HandlerName)
	if err != nil {
		return nil, fmt.Errorf("handlerapp.Call: %w", err)
	}
	if h.ActiveVersionID == "" {
		return nil, fmt.Errorf("handlerapp.Call: %w", handlerdomain.ErrNoActiveVersion)
	}

	inst, err := s.manager.Get(ctx, h.ID)
	if err != nil {
		return nil, fmt.Errorf("handlerapp.Call: %w", err)
	}

	startedAt := time.Now().UTC()
	var result any
	if in.OnProgress != nil {
		result, err = inst.Client.StreamCall(ctx, in.Method, in.Args, in.OnProgress)
	} else {
		result, err = inst.Client.Call(ctx, in.Method, in.Args)
	}
	endedAt := time.Now().UTC()

	callErr := s.mapCallErr(ctx, err)
	s.recordCall(ctx, h, inst, in, startedAt, endedAt, result, callErr, ctx.Err())
	return result, callErr
}

// mapCallErr maps infra client errors to domain errors for HTTP status mapping.
//
// mapCallErr 把 infra client 错误映射成 domain 错误，以便 HTTP 状态码映射。
func (s *Service) mapCallErr(ctx context.Context, err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(ctx.Err(), context.DeadlineExceeded) {
		return fmt.Errorf("%w: %v", handlerdomain.ErrInstanceRPCTimeout, err)
	}
	if errors.Is(err, handlerinfra.ErrCrashed) {
		return fmt.Errorf("%w: %v", handlerdomain.ErrInstanceCrashed, err)
	}
	return err // ErrCallFailed (the method raised) — passes through with the Python traceback
}

func (s *Service) resolveHandler(ctx context.Context, id, name string) (*handlerdomain.Handler, error) {
	switch {
	case id != "":
		return s.repo.GetHandler(ctx, id)
	case name != "":
		return s.repo.GetHandlerByName(ctx, name)
	default:
		return nil, fmt.Errorf("handlerName or handlerID required")
	}
}

func (s *Service) recordCall(ctx context.Context, h *handlerdomain.Handler, inst *Instance, in CallInput, startedAt, endedAt time.Time, result any, callErr, runCtxErr error) {
	status := handlerdomain.CallStatusOK
	errMsg := ""
	if callErr != nil {
		status = handlerdomain.CallStatusFailed
		errMsg = callErr.Error()
		if errors.Is(runCtxErr, context.DeadlineExceeded) {
			status = handlerdomain.CallStatusTimeout
		} else if errors.Is(runCtxErr, context.Canceled) {
			status = handlerdomain.CallStatusCancelled
		}
	}

	triggeredBy := in.TriggeredBy
	if !handlerdomain.IsValidTrigger(triggeredBy) {
		triggeredBy = triggerFromCtx(ctx)
	}
	input := in.Args
	if input == nil {
		input = map[string]any{}
	}

	convID, _ := reqctxpkg.GetConversationID(ctx)
	msgID, _ := reqctxpkg.GetMessageID(ctx)

	call := &handlerdomain.Call{
		ID:             idgenpkg.New("hcl"),
		HandlerID:      h.ID,
		VersionID:      h.ActiveVersionID,
		Method:         in.Method,
		Status:         status,
		TriggeredBy:    triggeredBy,
		Input:          input,
		Output:         result,
		ErrorMessage:   errMsg,
		ElapsedMs:      endedAt.Sub(startedAt).Milliseconds(),
		StartedAt:      startedAt,
		EndedAt:        endedAt,
		InstanceID:     inst.ID,
		ConversationID: convID,
		MessageID:      msgID,
	}

	wsID, _ := reqctxpkg.GetWorkspaceID(ctx)
	detached := reqctxpkg.SetWorkspaceID(context.Background(), wsID)
	if err := s.repo.SaveCall(detached, call); err != nil {
		s.log.Warn("handlerapp.recordCall: save failed (best-effort)",
			zap.String("handlerId", h.ID), zap.String("method", in.Method), zap.Error(err))
	}
}

// triggerFromCtx derives the execution body: a subagent context means an agent run,
// otherwise a chat turn. (Workflow / manual callers set TriggeredBy explicitly.)
//
// triggerFromCtx 按 ctx 推执行体：有 subagent 即 agent，否则 chat。（workflow / manual 显式设。）
func triggerFromCtx(ctx context.Context) string {
	if _, ok := reqctxpkg.GetSubagentID(ctx); ok {
		return handlerdomain.TriggeredByAgent
	}
	return handlerdomain.TriggeredByChat
}
