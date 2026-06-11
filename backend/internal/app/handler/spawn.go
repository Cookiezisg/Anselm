package handler

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"

	"go.uber.org/zap"

	handlerdomain "github.com/sunweilin/forgify/backend/internal/domain/handler"
	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
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

	go captureStderr(handle.Stderr(), s.log.With(zap.String("handlerId", handlerID), zap.Int("pid", handle.PID())))

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
	}, nil
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

// captureStderr scans the subprocess stderr line-by-line into the log (crash diagnosis).
//
// captureStderr 行扫子进程 stderr 进 log（崩溃诊断）。
func captureStderr(r io.ReadCloser, log *zap.Logger) {
	if r == nil {
		return
	}
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 4096), 64*1024)
	for sc.Scan() {
		log.Info("handler.stderr", zap.ByteString("line", sc.Bytes()))
	}
}
