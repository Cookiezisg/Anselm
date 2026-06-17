package bootstrap

import (
	"context"
	"fmt"

	functionapp "github.com/sunweilin/anselm/backend/internal/app/function"
	handlerapp "github.com/sunweilin/anselm/backend/internal/app/handler"
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
