// Package handler (app layer) owns the Service that orchestrates the handler
// trinity domain: CRUD, version/pending lifecycle, AES-GCM encrypted init-args
// config, in-memory Instance registry (caller-owns lifetime per D3), and the
// stdio JSON-line RPC to Python subprocess instances.
//
// All three handler packages (domain / app / store) declare `package handler`;
// importers alias at import-site (handlerapp / handlerdomain / handlerstore).
//
// Package handler(app 层)负责 Service 编排 handler trinity domain:CRUD、
// 版本/pending 生命周期、AES-GCM 加密 init-args config、in-memory Instance
// registry(caller-owns lifetime per D3)、跟 Python subprocess 实例的 stdio
// JSON-line RPC。
package handler

import (
	"context"
	"io"
	"time"

	"go.uber.org/zap"

	cryptodomain "github.com/sunweilin/forgify/backend/internal/domain/crypto"
	handlerdomain "github.com/sunweilin/forgify/backend/internal/domain/handler"
	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
	handlerinfra "github.com/sunweilin/forgify/backend/internal/infra/handler"
	notificationspkg "github.com/sunweilin/forgify/backend/internal/pkg/notifications"
)

// ── Ports ─────────────────────────────────────────────────────────────────────

// Sandbox is the port through which Service materializes handler venvs +
// spawns long-lived subprocesses. The infra/sandbox v2 service (wrapped by
// sandbox_adapter.go in Task 15) provides the concrete implementation.
//
// Sandbox 是 Service 物化 handler venv + 起长跑 subprocess 的端口。
// 具体实现由 infra/sandbox v2 经 sandbox_adapter.go 提供。
type Sandbox interface {
	// PythonPath returns the bundled Python interpreter path.
	//
	// PythonPath 返捆绑 Python 解释器路径。
	PythonPath() string

	// Sync materializes the venv for the given EnvID. Idempotent — already-built
	// venv returns immediately. Wraps adapter errors in *SyncError.
	//
	// Sync 物化指定 EnvID 的 venv;adapter 错误包成 *SyncError。
	Sync(ctx context.Context, req SyncRequest) error

	// SpawnLongLived starts a long-running subprocess for one HandlerInstance.
	// Returns a sandboxdomain.LongLivedHandle exposing Stdin/Stdout/Stderr/
	// Wait/Kill/PID. The caller (Service via registry) writes the class +
	// driver to a sandboxed file BEFORE spawn (WriteCodeFile) so the
	// subprocess can import it.
	//
	// SpawnLongLived 起单 HandlerInstance 的长跑子进程,返 LongLivedHandle
	// (Stdin/Stdout/Stderr/Wait/Kill/PID)。调用方 spawn 前先 WriteCodeFile
	// 把 class + driver 写入 sandbox 文件,子进程能 import。
	SpawnLongLived(ctx context.Context, req SpawnRequest) (sandboxdomain.LongLivedHandle, error)

	// WriteCodeFile writes user_handler.py + driver.py to the (handlerID,
	// versionID) sandbox dir without touching the venv.
	//
	// WriteCodeFile 写 user_handler.py + driver.py 到 (handlerID, versionID)
	// sandbox 目录;不动 venv。
	WriteCodeFile(ctx context.Context, handlerID, versionID, classCode string) error

	// Destroy removes the entire handler directory + every env owned by it.
	//
	// Destroy 删 handler 目录 + 其所有 env。
	Destroy(ctx context.Context, handlerID string) error

	// DestroyEnv removes a single (handlerID, envID) env.
	//
	// DestroyEnv 删单个 (handlerID, envID) env。
	DestroyEnv(ctx context.Context, handlerID, envID string) error
}

// ClientFactory builds a handlerinfra.Client wrapping the given pipes.
// Production uses handlerinfra.New; tests inject fakes that don't need
// real subprocesses.
//
// ClientFactory 把 pipe 包成 handlerinfra.Client。生产用 handlerinfra.New;
// 测试注入 fake。
type ClientFactory func(stdin io.WriteCloser, stdout io.Reader, log *zap.Logger) handlerinfra.Client

// DefaultClientFactory wraps handlerinfra.New.
//
// DefaultClientFactory 包 handlerinfra.New。
func DefaultClientFactory(stdin io.WriteCloser, stdout io.Reader, log *zap.Logger) handlerinfra.Client {
	return handlerinfra.New(stdin, stdout, log)
}

// ── Service ───────────────────────────────────────────────────────────────────

// Service orchestrates the handler domain.
//
// Service 编排 handler domain。
type Service struct {
	repo       handlerdomain.Repository
	sandbox    Sandbox
	clientFact ClientFactory
	encryptor  cryptodomain.Encryptor
	registry   *instanceRegistry
	notif      notificationspkg.Publisher
	log        *zap.Logger
}

// NewService wires Service dependencies. Panics on nil log / notif / encryptor
// (these are required dependencies — wiring bug should fail loud at boot).
//
// NewService 装配 Service 依赖。nil log / notif / encryptor panic
// (这些是必填依赖,nil 是装配 bug,启动时即 panic)。
func NewService(
	repo handlerdomain.Repository,
	sandbox Sandbox,
	clientFact ClientFactory,
	encryptor cryptodomain.Encryptor,
	notif notificationspkg.Publisher,
	log *zap.Logger,
) *Service {
	if log == nil {
		panic("handlerapp.NewService: logger is nil")
	}
	if notif == nil {
		panic("handlerapp.NewService: notif is nil")
	}
	if encryptor == nil {
		panic("handlerapp.NewService: encryptor is nil")
	}
	if clientFact == nil {
		clientFact = DefaultClientFactory
	}
	return &Service{
		repo:       repo,
		sandbox:    sandbox,
		clientFact: clientFact,
		encryptor:  encryptor,
		registry:   newInstanceRegistry(),
		notif:      notif,
		log:        log.Named("handlerapp"),
	}
}

// Shutdown drains the instance registry — destroys every live instance
// across owners. Called at process shutdown.
//
// Shutdown 把 instance registry 排空(destroy 全 owner 全 instance)。
// 进程退出时调用。
func (s *Service) Shutdown(ctx context.Context) {
	s.registry.DestroyEverything(ctx)
}

// _ = unused import guard for time during scaffolding (idle GC reaper would
// have used it; chat = per-call lifetime means we don't ship a reaper —
// owner-end hooks call DestroyOwner explicitly).
//
// _ time 占位防 unused import 警告。chat=per-call 不需要 idle reaper;
// owner-end 钩子显式调 DestroyOwner。
var _ = time.Second
