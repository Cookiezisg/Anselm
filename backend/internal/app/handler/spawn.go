package handler

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"

	"go.uber.org/zap"

	handlerdomain "github.com/sunweilin/anselm/backend/internal/domain/handler"
	sandboxdomain "github.com/sunweilin/anselm/backend/internal/domain/sandbox"
)

// spawnInstance builds one fresh resident Instance for handlerID: load active version +
// decrypted config, verify required init-args present, ensure env, assemble the class,
// spawn the long-lived driver, and Init it. It is the manager's spawnFn.
//
// spawnInstance 为 handlerID 构造一个新常驻 Instance：加载 active 版本 + 解密 config、校验必填
// init-args、装 env、组装类、起长跑 driver、Init。它是 manager 的 spawnFn。
func (s *Service) spawnInstance(ctx context.Context, handlerID string) (*Instance, error) {
	if !s.runner.Ready() {
		return nil, handlerdomain.ErrSandboxUnavailable
	}
	h, err := s.repo.GetHandler(ctx, handlerID)
	if err != nil {
		return nil, err
	}
	if h.ActiveVersionID == "" {
		return nil, handlerdomain.ErrNoActiveVersion
	}
	active, err := s.repo.GetVersion(ctx, h.ActiveVersionID)
	if err != nil {
		return nil, err
	}

	config, err := s.LoadConfig(ctx, handlerID)
	if err != nil {
		return nil, fmt.Errorf("handlerapp.spawnInstance: load config: %w", err)
	}
	for _, arg := range active.InitArgsSchema {
		if arg.Required && (config == nil || config[arg.Name] == nil) {
			return nil, fmt.Errorf("%w: missing required init arg %q", handlerdomain.ErrConfigIncomplete, arg.Name)
		}
	}
	// Pass ONLY the args the active schema declares: __init__ has a named parameter list, so an
	// orphaned config key (its arg removed by a later version, or left behind by a revert) would
	// be an unexpected kwarg → Python TypeError → permanent spawn failure. Filtering at the single
	// spawn choke point defends against every drift source, with no stored-config rewrite.
	//
	// 只传 active schema 声明的 args：__init__ 是命名参数列表，孤儿 config key（arg 被后续版本删、或
	// revert 留下）会成为意外 kwarg → Python TypeError → spawn 永久失败。在 spawn 这个唯一咽喉点过滤，
	// 防住所有漂移来源，且无需改写存储的 config。
	config = filterConfigToSchema(config, active.InitArgsSchema)

	if active.EnvStatus != handlerdomain.EnvStatusReady {
		if ready, errMsg := s.ensureEnv(ctx, active, nil); !ready {
			return nil, fmt.Errorf("handlerapp.spawnInstance: %s: %w", errMsg, handlerdomain.ErrEnvNotReady)
		}
	}

	classCode := AssembleClass(activeToDraft(active))
	owner := envOwner(handlerID, active.EnvID)

	handle, err := s.runner.Spawn(ctx, owner, handlerID, active.ID, classCode)
	// Env reclaimed externally (GC): rebuild from the version snapshot and retry once.
	// env 被外部回收（GC）：按版本快照重建并重试一次。
	if err != nil && errors.Is(err, sandboxdomain.ErrEnvNotFound) {
		s.log.Info("handler env reclaimed; rebuilding then retrying spawn", zap.String("handlerId", handlerID))
		if ready, _ := s.ensureEnv(ctx, active, nil); ready {
			handle, err = s.runner.Spawn(ctx, owner, handlerID, active.ID, classCode)
		}
	}
	if err != nil {
		return nil, fmt.Errorf("%w: %v", handlerdomain.ErrInstanceSpawnFailed, err)
	}

	fan := newStderrFan()
	go captureStderr(handle.Stderr(), s.log.With(zap.String("handlerId", handlerID), zap.Int("pid", handle.PID())), fan)

	client := s.clientFact(handle.Stdin(), handle.Stdout(), s.log)
	if err := client.Init(ctx, config); err != nil {
		_ = handle.Kill()
		return nil, fmt.Errorf("%w: init: %v", handlerdomain.ErrInstanceSpawnFailed, err)
	}

	return &Instance{
		ID:        newInstanceID(),
		HandlerID: handlerID,
		VersionID: active.ID,
		Client:    client,
		Kill:      handle.Kill,
		Stderr:    fan,
	}, nil
}

// filterConfigToSchema drops config keys not declared by the schema (nil-safe both ways).
//
// filterConfigToSchema 丢弃 schema 未声明的 config key（双向 nil 安全）。
func filterConfigToSchema(config map[string]any, schema []handlerdomain.InitArgSpec) map[string]any {
	if config == nil {
		return nil
	}
	declared := make(map[string]bool, len(schema))
	for _, a := range schema {
		declared[a.Name] = true
	}
	out := make(map[string]any, len(config))
	for k, v := range config {
		if declared[k] {
			out[k] = v
		}
	}
	return out
}

func activeToDraft(v *handlerdomain.Version) *VersionDraft {
	return &VersionDraft{
		Imports:        v.Imports,
		InitBody:       v.InitBody,
		ShutdownBody:   v.ShutdownBody,
		Methods:        v.Methods,
		InitArgsSchema: v.InitArgsSchema,
		Dependencies:   v.Dependencies,
		PythonVersion:  v.PythonVersion,
	}
}

// captureStderr scans the subprocess stderr line-by-line into the log (crash diagnosis)
// AND the instance's stderr fan (per-call attribution: live progress + persisted call
// logs). The protocol owns stdout, so stderr is the ONLY channel a handler's print()/
// logging reaches — the fan makes it user-visible instead of zap-only.
//
// captureStderr 行扫子进程 stderr 进 log（崩溃诊断）**并**进实例 stderr 扇出（per-call 归属：
// 实时进度 + 调用日志落盘）。协议占用 stdout，stderr 是 handler 的 print()/日志唯一能到达的
// 通道——扇出让它对用户可见、而非只进 zap。
func captureStderr(r io.ReadCloser, log *zap.Logger, fan *stderrFan) {
	if r == nil {
		return
	}
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 4096), 64*1024)
	for sc.Scan() {
		log.Info("handler.stderr", zap.ByteString("line", sc.Bytes()))
		// Copy before appending: sc.Bytes() views the scanner's internal buffer, and an
		// in-place append could clobber the next buffered token.
		// 先拷再补换行：sc.Bytes() 是 scanner 内部缓冲的视图，原地 append 可能踩到下一个 token。
		line := make([]byte, len(sc.Bytes())+1)
		copy(line, sc.Bytes())
		line[len(line)-1] = '\n'
		_, _ = fan.Write(line)
	}
}
