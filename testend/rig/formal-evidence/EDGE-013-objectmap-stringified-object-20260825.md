# EDGE-013 · ObjectMap 字符串化对象参数

## Verification

静态追踪确认 `run_function.args` 的 schema 是 object，执行边界使用公共
`tool.ObjectMap`。该类型接受原生 JSON object，也接受一个**解码后仍是 object 的 JSON 字符串**；
数组、数字、普通非 JSON 字符串和无法修复的非 JSON 不会被猜成对象。该类型同时被
`call_handler.args`、`update_handler_config.config` 等同类 object 参数复用，避免每个工具各自漂移。

Focused verification passed:

```text
go test ./internal/app/tool -run 'TestObjectMap' -count=1  PASS
go test -race ./internal/app/tool -run 'TestObjectMap' -count=1  PASS
```

新增回归同时断言：

- `{"points":6,"label":"probe"}` 与 `"{\"points\":6,\"label\":\"probe\"}"` 解码为同一 map；
- `[...]`、`6`、`"not-json"`、字符串化数组均明确失败；
- 修复只改变编码，不把错误值猜成对象。

## Five-level applicability

- L1 `pass`: 原生对象与字符串化对象落入同一参数 map，错误形状拒绝；测量法
  `measure:edge013-objectmap-stringified-object`。
- L2 `na`: 本条是公共参数解码边界，本轮没有为它单独启动真实 managed gateway 五通道 session。
- L3 `na`: 没有真实 App 录屏或动作到首反馈帧时延数据；focused test 不冒充逐帧证据。
- L4 `na`: 本条没有独立视觉几何/动效表面；工具错误回显由对应工具卡旅程覆盖。
- L5 `na`: `args` 的编码容错是模型协议边界，不是用户可导航入口。
