package handler

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strings"
	"time"

	"go.uber.org/zap"

	entitystreamapp "github.com/sunweilin/anselm/backend/internal/app/entitystream"
	loopapp "github.com/sunweilin/anselm/backend/internal/app/loop"
	handlerdomain "github.com/sunweilin/anselm/backend/internal/domain/handler"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	handlerinfra "github.com/sunweilin/anselm/backend/internal/infra/handler"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
	logtailpkg "github.com/sunweilin/anselm/backend/internal/pkg/logtail"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
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

	// Resolve the method's spec up front: a miss fails with the precise domain error before any
	// spawn/RPC, and the spec feeds the wall-clock deadline applied just below.
	//
	// 先解析 method 的 spec：未命中在任何 spawn/RPC 前以精确 domain 错误失败；spec 喂给紧接下面施加的墙钟 deadline。
	active, err := s.repo.GetVersion(ctx, h.ActiveVersionID)
	if err != nil {
		return nil, fmt.Errorf("handlerapp.Call: %w", err)
	}
	var spec *handlerdomain.MethodSpec
	for i := range active.Methods {
		if active.Methods[i].Name == in.Method {
			spec = &active.Methods[i]
			break
		}
	}
	if spec == nil {
		return nil, fmt.Errorf("handlerapp.Call: %q: %w", in.Method, handlerdomain.ErrMethodNotFound)
	}
	// Bound EVERY call by a wall clock: the method's own Timeout if it declared one, else the global
	// HandlerCallSec default — symmetric with FunctionRunSec for functions (F83). Without a default a
	// method with no per-method timeout (the common case) runs unbounded and a runaway/blocking one
	// pins the resident instance's single mutexed stdio pipe indefinitely.
	//
	// 每次调用都用墙钟封顶：method 声明了 Timeout 就用它，否则用全局 HandlerCallSec 默认——与 function 的
	// FunctionRunSec 对称（F83）。没有默认时，未声明 per-method timeout 的 method（常态）无界运行，失控/
	// 阻塞的会无限期钉死常驻实例的单 mutex stdio 管道。
	var cancel context.CancelFunc
	ctx, cancel = context.WithTimeout(ctx, methodCallTimeout(spec.Timeout, limitspkg.Current().Timeout.HandlerCallSec))
	defer cancel()

	// A spawn/__init__ failure (broken init body, missing required config, env-not-ready, sandbox
	// down) is a real call attempt that failed at the instance level — audit it as a failed
	// handler_calls row so it shows in call history + failedCount + :triage, instead of vanishing with
	// no trace (an operator debugging "why did my workflow node fail" had nothing to read). recordCall
	// is nil-instance-tolerant; pass the raw err (clean domain message) for the audit, return the
	// wrapped err for caller log breadcrumbs.
	// spawn/__init__ 失败（坏 init 体、缺必填 config、env 未就绪、sandbox 挂）是真实抵达实例层却失败的
	// 调用——记成 failed handler_calls 行，使其现身调用历史 + failedCount + :triage，而非无迹消失。
	spawnStartedAt := time.Now().UTC()
	inst, err := s.manager.Get(ctx, h.ID)
	if err != nil {
		s.recordCall(ctx, h, nil, in, spawnStartedAt, time.Now().UTC(), nil, "", err, ctx.Err())
		return nil, fmt.Errorf("handlerapp.Call: %w", err)
	}

	// Normalize nil args to {} BEFORE the RPC: the driver does method(**args), and a nil map
	// marshals to JSON `null` → method(**None) → TypeError. A no-arg caller (sensor poll,
	// workflow node with no input wiring) must not crash a zero-arg method (same as function).
	// RPC 前把 nil args 归一成 {}：driver 做 method(**args)，nil map 序列化成 JSON `null`
	// → method(**None) → TypeError。无参调用方不该把零参 method 搞崩（同 function）。
	if in.Args == nil {
		in.Args = map[string]any{}
	}

	// Tee the method's yields onto the handler's entities run terminal (entity panel, all callers)
	// and the call's capped logtail (persisted on the call record), in addition to the caller's
	// progress sink (messages, chat). Always StreamCall — doCall is safe for a non-streaming method
	// (no yields → onProgress never fires → plain return).
	//
	// 把 method 的 yield tee 到 handler 的 entities run 终端（实体面板，全 caller）+ 本次调用的限长
	// logtail（随 call 记录落盘）+ 调用方的进度 sink（messages，chat）。一律 StreamCall——doCall 对
	// 非流式 method 安全（无 yield → onProgress 不触发 → 正常返回）。
	runTerm := entitystreamapp.New(ctx, s.entities, streamdomain.Scope{Kind: streamdomain.KindHandler, ID: h.ID}, entitystreamapp.NodeRun, nil)
	logs := logtailpkg.New(logtailpkg.DefaultCap)
	onProgress := func(v any) {
		if in.OnProgress != nil {
			in.OnProgress(v)
		}
		line := yieldBytes(v)
		if len(inst.SecretValues) > 0 {
			line = []byte(scrubSecrets(string(line), inst.SecretValues))
		}
		_, _ = runTerm.Write(line)
		_, _ = logs.Write(line)
	}

	// Attach a per-call sink to the instance's stderr fan for the duration of the call: the
	// handler's print()/logging (stderr is its only reachable channel — the protocol owns stdout)
	// streams to chat progress + the run terminal and persists into the call's logs. Window
	// attribution: concurrent calls on the same instance each receive the window's lines.
	//
	// 调用存续期把 per-call sink 挂上实例 stderr 扇出：handler 的 print()/日志（stderr 是它唯一可达
	// 通道——协议占用 stdout）流到 chat 进度 + run 终端，并落盘进本次调用的 logs。窗口归属：同实例
	// 并发调用各收各窗口的行。
	prog := loopapp.ToolProgress(ctx)
	defer prog.Close()
	// Scrub injected secrets at the SOURCE — before the handler's print()/stderr reaches the live
	// messages SSE (prog), the entities SSE run terminal (runTerm), or the persisted progress block.
	// recordCall scrubs only the buffered audit copy AFTER the fact, so without this a secret printed by
	// user code would already have streamed in plaintext on both SSE channels (F108 — the live-stream
	// sibling of F82's call-log scrub). The audit-side scrub at recordCall still covers a secret split
	// across two Writes (it sees the full buffer).
	//
	// 在**源头**擦注入的 secret——先于 handler 的 print()/stderr 到达 live messages SSE(prog)、entities SSE
	// run 终端(runTerm)、或持久 progress block。recordCall 只**事后**擦缓冲审计副本，没有这里、用户代码打印的
	// secret 已在两条 SSE 上明文流出（F108——F82 call-log 擦除的 live-stream 兄弟）。审计侧 recordCall 仍兜
	// 跨两次 Write 切分的 secret（它见完整缓冲）。
	var fan io.Writer = io.MultiWriter(prog, runTerm, logs)
	if len(inst.SecretValues) > 0 {
		fan = &scrubbingWriter{w: fan, secrets: inst.SecretValues}
	}
	detach := inst.Stderr.attach(fan)
	defer detach() // panic-safety net: a panic between here and the explicit detach() below would
	//             otherwise leak this call's sink into the resident instance's fan forever (R18).
	//             detach is idempotent, so the explicit post-grace detach() below still controls timing.

	startedAt := time.Now().UTC()
	result, err := inst.Client.StreamCall(ctx, in.Method, in.Args, onProgress)
	endedAt := time.Now().UTC()
	// stderr grace before detach: stdout (the return frame) and stderr (the prints) are two
	// independent pipes read by independent goroutines — a print written BEFORE the return
	// can still arrive after it. A short quiesce keeps those lines inside this call's window.
	// detach 前的 stderr 宽限：stdout（return 帧）与 stderr（print）是两条独立管道、各自
	// goroutine 在读——先于 return 写出的 print 仍可能后到。短静默把这些行留在本调用窗口内。
	time.Sleep(stderrGrace)
	detach()
	if err != nil {
		runTerm.Close("error", nil)
	} else {
		runTerm.Close("completed", nil)
	}

	callErr := s.mapCallErr(ctx, err)
	if errors.Is(callErr, handlerdomain.ErrInstanceCrashed) {
		// The resident process died (discovered on this call; the manager reaps + respawns on the
		// next call). Notify so the handler row shows a live red dot now, instead of the crash only
		// surfacing on whoever's next :call.
		// 常驻进程已死（本次调用发现；manager 下次调用回收+重启）。发通知使 handler 行此刻就亮红点，
		// 而非等下一个 :call 才暴露崩溃。
		s.publish(ctx, "crashed", h.ID, nil)
	}
	s.recordCall(ctx, h, inst, in, startedAt, endedAt, result, logs.String(), callErr, ctx.Err())
	return result, callErr
}

// stderrGrace bounds how long a call waits for straggler stderr lines before closing its
// log window (pipe-ordering race, see Call).
//
// stderrGrace 限定调用收尾时等迟到 stderr 行多久（管道乱序竞态，见 Call）。
const stderrGrace = 30 * time.Millisecond

// yieldBytes renders a streaming method's yield (any) as one line for the entities run terminal:
// a string goes verbatim, anything else as compact JSON.
//
// yieldBytes 把流式 method 的 yield（any）渲成 entities run 终端的一行：string 原样，其余 compact JSON。
func yieldBytes(v any) []byte {
	if s, ok := v.(string); ok {
		return []byte(s + "\n")
	}
	b, _ := json.Marshal(v)
	return append(b, '\n')
}

// mapCallErr maps infra client errors to domain errors for HTTP status mapping.
//
// mapCallErr 把 infra client 错误映射成 domain 错误，以便 HTTP 状态码映射。
func (s *Service) mapCallErr(ctx context.Context, err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(ctx.Err(), context.DeadlineExceeded) {
		return errorspkg.Wrap(handlerdomain.ErrInstanceRPCTimeout, err)
	}
	if errors.Is(err, handlerinfra.ErrCrashed) {
		return errorspkg.Wrap(handlerdomain.ErrInstanceCrashed, err)
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

func (s *Service) recordCall(ctx context.Context, h *handlerdomain.Handler, inst *Instance, in CallInput, startedAt, endedAt time.Time, result any, logs string, callErr, runCtxErr error) {
	status := handlerdomain.CallStatusOK
	errMsg := ""
	if callErr != nil {
		status = handlerdomain.CallStatusFailed
		// Persist the CLEAN surfaced message (Message + Details, e.g. the Python traceback), NOT the raw
		// .Error() chain — which leaks Go-layer breadcrumbs ("handler.Client:", "context deadline
		// exceeded") into the durable record that get_handler_call / REST / the LLM read back, while the
		// live LLM error surface already strips them via Surface. Now the record matches (F159).
		// 持久化**清洗后**的消息（Message + Details，如 Python traceback），而非裸 .Error() 链——后者把 Go 层面包屑
		// （"handler.Client:"、"context deadline exceeded"）漏进 get_handler_call/REST/LLM 读回的耐久记录，而实时
		// LLM 错误面已用 Surface 剥掉。现记录与之一致（F159）。
		errMsg = errorspkg.Surface(callErr)
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

	// Scrub the platform's OWN injected sensitive config values from the persisted audit — a secret it
	// gave __init__ may surface verbatim in a user-code exception URL or a print(); redact the value
	// while keeping the rest of the trace debuggable. Cannot redact arbitrary user secrets, only these
	// (F82, defense-in-depth — config-at-rest is encrypted + read-masked separately).
	if inst != nil && len(inst.SecretValues) > 0 {
		errMsg = scrubSecrets(errMsg, inst.SecretValues)
		logs = scrubSecrets(logs, inst.SecretValues)
		if out, ok := result.(string); ok {
			result = scrubSecrets(out, inst.SecretValues)
		}
	}

	// Provenance comes off ctx: chat identity (conversation/message/toolCall) from the loop,
	// flowrun identity from the scheduler's dispatch injection — whichever path ran us.
	// 溯源取自 ctx：chat 身份（conversation/message/toolCall）来自 loop，flowrun 身份来自调度器
	// 派发注入——哪条路径跑的就带哪份。
	convID, _ := reqctxpkg.GetConversationID(ctx)
	msgID, _ := reqctxpkg.GetMessageID(ctx)
	toolCallID, _ := reqctxpkg.GetToolCallID(ctx)
	flowrunID, _ := reqctxpkg.GetFlowrunID(ctx)
	flowrunNodeID, _ := reqctxpkg.GetFlowrunNodeID(ctx)

	// inst is nil on the spawn-failure audit path (no instance was ever obtained) — record an empty
	// instance id rather than dereferencing nil.
	// 在 spawn 失败的审计路径上 inst 为 nil（从未取得实例）——记空实例 id，不解引用 nil。
	instanceID := ""
	if inst != nil {
		instanceID = inst.ID
	}

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
		Logs:           logs,
		ElapsedMs:      endedAt.Sub(startedAt).Milliseconds(),
		StartedAt:      startedAt,
		EndedAt:        endedAt,
		InstanceID:     instanceID,
		ConversationID: convID,
		MessageID:      msgID,
		ToolCallID:     toolCallID,
		FlowrunID:      flowrunID,
		FlowrunNodeID:  flowrunNodeID,
	}

	wsID, _ := reqctxpkg.GetWorkspaceID(ctx)
	detached := reqctxpkg.Detached(wsID)
	if err := s.repo.SaveCall(detached, call); err != nil {
		s.log.Warn("handlerapp.recordCall: save failed (best-effort)",
			zap.String("handlerId", h.ID), zap.String("method", in.Method), zap.Error(err))
	}
}

// scrubSecrets masks every known injected sensitive config value in s — the platform redacts its OWN
// injected secrets from the call audit (a value it gave __init__ that user code leaked into a
// traceback / print), keeping the rest of the trace intact. No-op when secrets is empty (F82).
//
// scrubSecrets 把 s 里每个已知的平台注入 sensitive config 值掩成 ********——保留其余 trace。空即原样（F82）。
func scrubSecrets(s string, secrets []string) string {
	for _, sec := range secrets {
		if sec != "" {
			s = strings.ReplaceAll(s, sec, "********")
		}
	}
	return s
}

// scrubbingWriter masks known injected secrets in a byte stream before it reaches the live progress /
// SSE sinks, so a handler's print()/stderr carrying an injected secret never streams in plaintext
// (F108). Per-Write scrubbing catches the common case (a secret within one print); a secret split
// across two Writes is still masked in the durable audit copy by recordCall's full-buffer scrub.
//
// scrubbingWriter 在字节流到达 live progress / SSE sink 前掩去已知注入 secret，使 handler 的 print()/stderr
// 携带的注入 secret 绝不明文流出（F108）。逐 Write 擦覆盖常态（secret 在一次 print 内）；跨两次 Write 切分的
// secret 仍由 recordCall 的全缓冲擦在持久审计副本里兜住。
type scrubbingWriter struct {
	w       io.Writer
	secrets []string
}

func (sw *scrubbingWriter) Write(p []byte) (int, error) {
	if _, err := sw.w.Write([]byte(scrubSecrets(string(p), sw.secrets))); err != nil {
		return 0, err
	}
	return len(p), nil // report the original input length (masking changes the byte count)
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

// methodCallTimeout picks the wall clock for one handler method call: the method's own timeout (ms)
// when it declared one, else the global HandlerCallSec default — so every call is bounded (a method
// with no per-method timeout no longer runs unbounded, symmetric with FunctionRunSec for functions).
//
// methodCallTimeout 为一次 handler 方法调用挑墙钟：method 声明了 timeout(ms) 就用它，否则用全局
// HandlerCallSec 默认——使每次调用都有界（未声明 per-method timeout 的 method 不再无界运行，与
// function 的 FunctionRunSec 对称）。
func methodCallTimeout(specTimeoutMs, globalSec int) time.Duration {
	if specTimeoutMs > 0 {
		return time.Duration(specTimeoutMs) * time.Millisecond
	}
	return time.Duration(globalSec) * time.Second
}
