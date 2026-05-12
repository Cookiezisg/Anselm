// Package workflow (app layer) orchestrates the trinity workflow
// authoring domain: CRUD, version + pending lifecycle, ops engine,
// graph validation, slim notifications. Execution (scheduler / trigger
// / flowrun) lives in Plan 05.
//
// All three workflow packages (domain / app / store) declare
// `package workflow`; importers alias as workflowapp / workflowdomain /
// workflowstore at import sites per §S13.
//
// Package workflow(app 层)负责 Service 编排 workflow 锻造域。三个 workflow
// 包均 `package workflow`;外部按角色起别名。
package workflow

import (
	"context"

	"go.uber.org/zap"

	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
	notificationspkg "github.com/sunweilin/forgify/backend/internal/pkg/notifications"
)

// Service orchestrates the workflow domain.
//
// Service 编排 workflow domain。
type Service struct {
	repo    workflowdomain.Repository
	checker CapabilityChecker
	notif   notificationspkg.Publisher
	log     *zap.Logger
}

// NewService wires Service dependencies. Panics on nil log / notif.
// checker may be nil — Service uses NopChecker as fallback so unit tests
// don't need to wire function / handler / mcp / skill services.
//
// NewService 装配 Service 依赖;nil log/notif panic。checker 可 nil(用
// NopChecker),单测无须接外部 service。
func NewService(
	repo workflowdomain.Repository,
	checker CapabilityChecker,
	notif notificationspkg.Publisher,
	log *zap.Logger,
) *Service {
	if log == nil {
		panic("workflowapp.NewService: logger is nil")
	}
	if notif == nil {
		panic("workflowapp.NewService: notif is nil")
	}
	if checker == nil {
		checker = NopChecker()
	}
	return &Service{
		repo:    repo,
		checker: checker,
		notif:   notif,
		log:     log.Named("workflowapp"),
	}
}

// WorkflowReader is the read-only contract Plan 05 (scheduler / trigger /
// flowrun) consumes to look up active versions and enabled workflows
// without depending on the full Service.
//
// WorkflowReader 是 Plan 05 (scheduler/trigger/flowrun) 消费的只读契约;
// 拿 active version + enabled 列表,不依赖完整 Service。
type WorkflowReader interface {
	GetActiveVersion(ctx context.Context, workflowID string) (*workflowdomain.Version, error)
	GetWorkflow(ctx context.Context, workflowID string) (*workflowdomain.Workflow, error)
	ListEnabled(ctx context.Context) ([]*workflowdomain.Workflow, error)
}

// Compile-time assertion that *Service satisfies WorkflowReader so Plan 05
// callers can take the interface and feed *Service through.
//
// 编译期断言 *Service 满足 WorkflowReader。
var _ WorkflowReader = (*Service)(nil)
