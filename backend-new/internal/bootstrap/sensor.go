package bootstrap

import (
	"context"
	"fmt"

	functionapp "github.com/sunweilin/forgify/backend/internal/app/function"
	handlerapp "github.com/sunweilin/forgify/backend/internal/app/handler"
	functiondomain "github.com/sunweilin/forgify/backend/internal/domain/function"
	handlerdomain "github.com/sunweilin/forgify/backend/internal/domain/handler"
	sensorinfra "github.com/sunweilin/forgify/backend/internal/infra/trigger/sensor"
)

// sensorInvoker adapts the function + handler Services to sensor.SensorInvoker: a sensor trigger
// polls a bound function/handler-method and feeds its result map into a CEL predicate. Routing by
// targetKind mirrors the Dispatcher's fn/hd branches (method only used for handler), reusing
// toResultMap for the same flat-map coercion.
//
// sensorInvoker 把 function + handler Service 适配成 sensor.SensorInvoker：sensor 触发器轮询绑定的
// function/handler-method，把结果 map 喂进 CEL 谓词。按 targetKind 路由（镜像 Dispatcher 的 fn/hd 分支，
// method 仅 handler 用），复用 toResultMap 做同样的扁平 map 强转。
type sensorInvoker struct {
	fn FunctionRunner
	hd HandlerCaller
}

// NewSensorInvoker wires the function + handler Services as the sensor invoker.
//
// NewSensorInvoker 把 function + handler Service 装成 sensor invoker。
func NewSensorInvoker(fn FunctionRunner, hd HandlerCaller) sensorinfra.SensorInvoker {
	return sensorInvoker{fn: fn, hd: hd}
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
	default:
		return nil, fmt.Errorf("sensor invoke: unknown target kind %q (want function|handler)", targetKind)
	}
}
