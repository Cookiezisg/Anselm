package bootstrap

import (
	"context"
	stderrors "errors"
	"strings"

	workflowapp "github.com/sunweilin/foryx/backend/internal/app/workflow"
	agentdomain "github.com/sunweilin/foryx/backend/internal/domain/agent"
	approvaldomain "github.com/sunweilin/foryx/backend/internal/domain/approval"
	controldomain "github.com/sunweilin/foryx/backend/internal/domain/control"
	functiondomain "github.com/sunweilin/foryx/backend/internal/domain/function"
	handlerdomain "github.com/sunweilin/foryx/backend/internal/domain/handler"
	relationdomain "github.com/sunweilin/foryx/backend/internal/domain/relation"
	triggerdomain "github.com/sunweilin/foryx/backend/internal/domain/trigger"
	workflowdomain "github.com/sunweilin/foryx/backend/internal/domain/workflow"
	errorspkg "github.com/sunweilin/foryx/backend/internal/pkg/errors"
)

// The narrow read ports the resolver inspects per entity family. The buildable five expose Get
// (entity header → ActiveVersionID); handler + agent additionally need GetVersion to read the
// active version's method/tool list. *functionapp.Service etc. satisfy these.
//
// 解析器按实体族查的窄读端口。可构建的五个暴露 Get（实体头 → ActiveVersionID）；handler + agent
// 另需 GetVersion 读 active 版本的方法/工具清单。
type FunctionVersionReader interface {
	Get(ctx context.Context, id string) (*functiondomain.Function, error)
}
type HandlerVersionReader interface {
	Get(ctx context.Context, id string) (*handlerdomain.Handler, error)
	GetVersion(ctx context.Context, versionID string) (*handlerdomain.Version, error)
}
type AgentVersionReader interface {
	Get(ctx context.Context, id string) (*agentdomain.Agent, error)
	GetVersion(ctx context.Context, versionID string) (*agentdomain.Version, error)
}
type ControlVersionReader interface {
	// Get attaches the active version (with its branches) in one round-trip.
	// Get 一趟附上 active 版本（含其分支）。
	Get(ctx context.Context, id string) (*controldomain.ControlLogic, error)
}
type ApprovalVersionReader interface {
	Get(ctx context.Context, id string) (*approvaldomain.ApprovalForm, error)
}
type TriggerExistence interface {
	Get(ctx context.Context, id string) (*triggerdomain.Trigger, error)
}
type MCPExistence interface {
	// NamesByIDs reports which of the given mcp_ ids exist (the relation Namer surface, reused
	// here as a by-id existence probe).
	// NamesByIDs 报告给定 mcp_ id 哪些存在（relation Namer 面，这里复用作按-id 存在性探针）。
	NamesByIDs(ctx context.Context, ids []string) (map[string]string, error)
}

// refResolver implements workflow.RefResolver by fanning a node ref out to the owning entity
// Service: it parses the ref prefix, looks the entity up, and reports its RefInfo (kind + active
// version + the per-kind extras CapabilityCheck/pin-closure read). It lives in the composition
// root because it is the one place allowed to import all seven entity packages at once.
//
// refResolver 实现 workflow.RefResolver：把 node ref 扇出到拥有它的实体 Service——解析前缀、查实体、
// 报 RefInfo（kind + active 版本 + CapabilityCheck/pin 闭包读的各 kind 附加项）。它住在 composition
// root，因为这是唯一允许一次 import 全部七个实体包的地方。
type refResolver struct {
	fn  FunctionVersionReader
	hd  HandlerVersionReader
	ag  AgentVersionReader
	ctl ControlVersionReader
	apf ApprovalVersionReader
	trg TriggerExistence
	mcp MCPExistence
}

// NewRefResolver wires the seven entity readers into workflow.RefResolver.
//
// NewRefResolver 把七个实体 reader 装成 workflow.RefResolver。
func NewRefResolver(fn FunctionVersionReader, hd HandlerVersionReader, ag AgentVersionReader, ctl ControlVersionReader, apf ApprovalVersionReader, trg TriggerExistence, mcp MCPExistence) workflowapp.RefResolver {
	return refResolver{fn: fn, hd: hd, ag: ag, ctl: ctl, apf: apf, trg: trg, mcp: mcp}
}

var _ workflowapp.RefResolver = refResolver{}

// Resolve maps a node ref (trg_/fn_/hd_<id>.method/mcp:<id>/<tool>/ag_/ctl_/apf_) to its RefInfo.
// A not-found entity becomes workflowdomain.ErrRefNotFound (CapabilityCheck reports it, pin
// closure skips it); any other store error propagates.
//
// Resolve 把 node ref 映射成 RefInfo。实体不存在 → workflowdomain.ErrRefNotFound（CapabilityCheck
// 报告、pin 闭包跳过）；其它存储错误透传。
func (r refResolver) Resolve(ctx context.Context, ref string) (workflowapp.RefInfo, error) {
	ref = strings.TrimSpace(ref)
	switch {
	case strings.HasPrefix(ref, workflowdomain.RefPrefixFunction):
		f, err := r.fn.Get(ctx, ref)
		if err != nil {
			return refMiss(err)
		}
		return workflowapp.RefInfo{
			Kind:             relationdomain.EntityKindFunction,
			HasActiveVersion: f.ActiveVersionID != "",
			ActiveVersionID:  f.ActiveVersionID,
		}, nil

	case strings.HasPrefix(ref, workflowdomain.RefPrefixHandler):
		id := ref
		if i := strings.IndexByte(ref, '.'); i > 0 {
			id = ref[:i] // drop the .method suffix — the handler entity id is the bare hd_<id>
		}
		h, err := r.hd.Get(ctx, id)
		if err != nil {
			return refMiss(err)
		}
		info := workflowapp.RefInfo{
			Kind:             relationdomain.EntityKindHandler,
			HasActiveVersion: h.ActiveVersionID != "",
			ActiveVersionID:  h.ActiveVersionID,
		}
		// MethodNames feeds CapabilityCheck's ".method exists?" reconciliation — best-effort: a
		// version read miss leaves the list empty (structural check still runs).
		if h.ActiveVersionID != "" {
			if v, verr := r.hd.GetVersion(ctx, h.ActiveVersionID); verr == nil && v != nil {
				for i := range v.Methods {
					info.MethodNames = append(info.MethodNames, v.Methods[i].Name)
				}
			}
		}
		return info, nil

	case strings.HasPrefix(ref, workflowdomain.RefPrefixAgent):
		a, err := r.ag.Get(ctx, ref)
		if err != nil {
			return refMiss(err)
		}
		info := workflowapp.RefInfo{
			Kind:             relationdomain.EntityKindAgent,
			HasActiveVersion: a.ActiveVersionID != "",
			ActiveVersionID:  a.ActiveVersionID,
		}
		// AgentCallables (the fn_/hd_ refs this agent mounts) drives pin-closure's depth-2
		// recursion — so a flowrun pins the exact versions of the tools its agent will call.
		if a.ActiveVersionID != "" {
			if v, verr := r.ag.GetVersion(ctx, a.ActiveVersionID); verr == nil && v != nil {
				for i := range v.Tools {
					info.AgentCallables = append(info.AgentCallables, v.Tools[i].Ref)
				}
			}
		}
		return info, nil

	case strings.HasPrefix(ref, workflowdomain.RefPrefixControl):
		c, err := r.ctl.Get(ctx, ref)
		if err != nil {
			return refMiss(err)
		}
		info := workflowapp.RefInfo{
			Kind:             relationdomain.EntityKindControl,
			HasActiveVersion: c.ActiveVersionID != "",
			ActiveVersionID:  c.ActiveVersionID,
		}
		// BranchPorts feeds CapabilityCheck's edge-port reconciliation (every ctl_ out-edge port
		// must name a real branch). Get already attached the active version.
		if c.ActiveVersion != nil {
			for i := range c.ActiveVersion.Branches {
				info.BranchPorts = append(info.BranchPorts, c.ActiveVersion.Branches[i].Port)
			}
		}
		return info, nil

	case strings.HasPrefix(ref, workflowdomain.RefPrefixApproval):
		a, err := r.apf.Get(ctx, ref)
		if err != nil {
			return refMiss(err)
		}
		return workflowapp.RefInfo{
			Kind:             relationdomain.EntityKindApproval,
			HasActiveVersion: a.ActiveVersionID != "",
			ActiveVersionID:  a.ActiveVersionID,
		}, nil

	case strings.HasPrefix(ref, workflowdomain.RefPrefixTrigger):
		if _, err := r.trg.Get(ctx, ref); err != nil {
			return refMiss(err)
		}
		// Triggers are intentionally version-less (config entity, not built). Existence = usable:
		// HasActiveVersion=true keeps CapabilityCheck from flagging a phantom missing version;
		// the empty ActiveVersionID makes pin-closure record a no-op (a trigger is the seeded
		// entry node, never dispatched — there is no version to freeze).
		return workflowapp.RefInfo{Kind: relationdomain.EntityKindTrigger, HasActiveVersion: true}, nil

	case strings.HasPrefix(ref, workflowdomain.RefPrefixMCP):
		id := strings.TrimPrefix(ref, workflowdomain.RefPrefixMCP)
		if i := strings.IndexByte(id, '/'); i > 0 {
			id = id[:i] // drop /tool — the mcp entity id is the bare server id
		}
		names, err := r.mcp.NamesByIDs(ctx, []string{id})
		if err != nil {
			return workflowapp.RefInfo{}, err
		}
		if _, ok := names[id]; !ok {
			return workflowapp.RefInfo{}, workflowdomain.ErrRefNotFound
		}
		// Version-less like trigger: existence = usable, nothing to pin.
		return workflowapp.RefInfo{Kind: relationdomain.EntityKindMCP, HasActiveVersion: true}, nil

	default:
		return workflowapp.RefInfo{}, workflowdomain.ErrRefNotFound
	}
}

// refMiss maps an entity "not found" store error to workflowdomain.ErrRefNotFound (so the
// resolver's callers treat every unresolvable ref uniformly); any other error (e.g. DB failure)
// propagates verbatim.
//
// refMiss 把实体「不存在」存储错误映射成 workflowdomain.ErrRefNotFound（使调用方统一对待不可解析
// ref）；其它错误（如 DB 故障）原样透传。
func refMiss(err error) (workflowapp.RefInfo, error) {
	var e *errorspkg.Error
	if stderrors.As(err, &e) && e.Kind == errorspkg.KindNotFound {
		return workflowapp.RefInfo{}, workflowdomain.ErrRefNotFound
	}
	return workflowapp.RefInfo{}, err
}
