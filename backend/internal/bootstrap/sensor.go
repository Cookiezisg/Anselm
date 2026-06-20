package bootstrap

import (
	"context"
	"fmt"

	functionapp "github.com/sunweilin/anselm/backend/internal/app/function"
	handlerapp "github.com/sunweilin/anselm/backend/internal/app/handler"
	triggerapp "github.com/sunweilin/anselm/backend/internal/app/trigger"
	functiondomain "github.com/sunweilin/anselm/backend/internal/domain/function"
	handlerdomain "github.com/sunweilin/anselm/backend/internal/domain/handler"
	mcpdomain "github.com/sunweilin/anselm/backend/internal/domain/mcp"
	sensorinfra "github.com/sunweilin/anselm/backend/internal/infra/trigger/sensor"
)

// sensorInvoker adapts the function + handler + mcp Services to sensor.SensorInvoker: a sensor
// trigger polls a bound function / handler-method / mcp-tool and feeds its result map into a CEL
// predicate. Routing by targetKind mirrors the Dispatcher's branches (method = handler method or
// mcp tool name), reusing toResultMap for the same flat-map coercion.
//
// sensorInvoker 把 function + handler + mcp Service 适配成 sensor.SensorInvoker：sensor 触发器轮询绑定的
// function / handler-method / mcp-tool，把结果 map 喂进 CEL 谓词。按 targetKind 路由（镜像 Dispatcher 的
// 分支，method = handler 方法或 mcp 工具名），复用 toResultMap 做同样的扁平 map 强转。
type sensorInvoker struct {
	fn  FunctionRunner
	hd  HandlerCaller
	mcp MCPCaller
}

// NewSensorInvoker wires the function + handler + mcp Services as the sensor invoker.
//
// NewSensorInvoker 把 function + handler + mcp Service 装成 sensor invoker。
func NewSensorInvoker(fn FunctionRunner, hd HandlerCaller, mcp MCPCaller) sensorinfra.SensorInvoker {
	return sensorInvoker{fn: fn, hd: hd, mcp: mcp}
}

var _ sensorinfra.SensorInvoker = sensorInvoker{}

func (s sensorInvoker) Invoke(ctx context.Context, targetKind, targetID, method string) (map[string]any, error) {
	switch targetKind {
	case "function":
		res, err := s.fn.RunFunction(ctx, functionapp.RunInput{FunctionID: targetID, TriggeredBy: functiondomain.TriggeredByWorkflow})
		if err != nil {
			return nil, err
		}
		if res == nil {
			return map[string]any{}, nil
		}
		if !res.OK {
			return nil, fmt.Errorf("sensor function %s failed: %s", targetID, res.ErrorMsg)
		}
		return toResultMap(res.Output), nil
	case "handler":
		out, err := s.hd.Call(ctx, handlerapp.CallInput{HandlerID: targetID, Method: method, TriggeredBy: handlerdomain.TriggeredByWorkflow})
		if err != nil {
			return nil, err
		}
		return toResultMap(out), nil
	case "mcp":
		// method carries the tool name (trigger config requires it for mcp targets). The tool's
		// text result rides as {text: ...} via toResultMap for the CEL predicate.
		//
		// method 携工具名（trigger config 对 mcp 目标必填）。工具文本结果经 toResultMap 以 {text: ...}
		// 喂 CEL 谓词。
		out, err := s.mcp.CallTool(ctx, targetID, method, nil, mcpdomain.CallTriggeredByWorkflow)
		if err != nil {
			return nil, err
		}
		return toResultMap(out), nil
	default:
		return nil, fmt.Errorf("sensor invoke: unknown target kind %q (want function|handler|mcp)", targetKind)
	}
}

// --- eager sensor-target existence validation (F102) ------------------------

// funcGetter / handlerGetter / mcpResolver are the existence-check surfaces the sensor-target
// validator needs — the read side of the same fn/hd/mcp services the invoker calls. Narrow so the
// validator is unit-testable with fakes.
//
// funcGetter / handlerGetter / mcpResolver 是 sensor 目标校验器所需的存在性查询面——与 invoker 调的
// 同一批 fn/hd/mcp 服务的读侧。收窄以便用 fake 单测校验器。
type funcGetter interface {
	Get(ctx context.Context, id string) (*functiondomain.Function, error)
}
type handlerGetter interface {
	Get(ctx context.Context, id string) (*handlerdomain.Handler, error)
}
type mcpResolver interface {
	ResolveServerID(ctx context.Context, token string) (string, error)
}

type sensorTargetValidator struct {
	fn  funcGetter
	hd  handlerGetter
	mcp mcpResolver
}

// NewSensorTargetValidator wires the function/handler/mcp existence lookups behind the trigger
// service's eager sensor-target check.
//
// NewSensorTargetValidator 把 function/handler/mcp 的存在性查询装到 trigger 服务的 eager sensor 目标校验后。
func NewSensorTargetValidator(fn funcGetter, hd handlerGetter, mcp mcpResolver) triggerapp.SensorTargetValidator {
	return sensorTargetValidator{fn: fn, hd: hd, mcp: mcp}
}

var _ triggerapp.SensorTargetValidator = sensorTargetValidator{}

func (v sensorTargetValidator) ValidateSensorTarget(ctx context.Context, targetKind, targetID, method string) error {
	switch targetKind {
	case "function":
		if _, err := v.fn.Get(ctx, targetID); err != nil {
			return fmt.Errorf("function %s not found", targetID)
		}
	case "handler":
		if _, err := v.hd.Get(ctx, targetID); err != nil {
			return fmt.Errorf("handler %s not found", targetID)
		}
	case "mcp":
		if _, err := v.mcp.ResolveServerID(ctx, targetID); err != nil {
			return fmt.Errorf("mcp server %s not found", targetID)
		}
	default:
		return fmt.Errorf("unknown target kind %q (want function|handler|mcp)", targetKind)
	}
	return nil
}
