# EDGE-013 · ObjectMap 字符串化对象参数 · 非正式真实 App 复验

## Result

本次 session 不写入正式 `pass`。真实 App、受管网关、SSE witness、录屏和 LLM tap 均已接通，
但 Computer Use 的第一次输入丢失 JSON 标点，第二次输入丢失 function ID 中的下划线，造成两次
`run_function` 目标不存在并在 backend journal 留下真实 `WARN`。该 session 因此证明了台架的
fail-closed 行为，不证明产品的 ObjectMap 字符串化路径。

第二个干净对话使用 seed 中已存在的 `greet`，模型成功搜索并执行函数，实际 wire 形状是原生对象：

```text
{"name":"Alice"}
```

所以它证明正常 object schema 路径没有被 `ObjectMap` 改坏，但没有证明模型会主动选择 JSON-string
编码。该边界已由 `backend/internal/app/tool/objectmap_test.go` 的 focused tests 覆盖；本格的
真实字符串化输入仍保持未收口，不能把模型没有选择该形态解释为功能通过。

## Session

- `RIG_HOME`: `/private/tmp/anselm-rig-formal-20260801-3`
- session: `/private/tmp/anselm-rig-formal-20260830-015155`
- data: `/private/tmp/anselm-data-edge013-20260830-r1`
- workspace: `ws_69151039f4eeb305`
- recording: `240.456667s`
- `rig-check`: five channels physically observing
- `rig-down`: clean; journals retained

## Disposition

- 不把本次真实探针写成 stringified-object 的 `pass`；该探针仍作为负证据保留。
- `EDGE-013` 的 L2-L5 已由独立适用性复核通过 `judge.py` 正式记为 `na`，清册整行为 `✓~~~~`。
- 后续若产品协议改变、该边界获得独立用户表面，必须重新立项并补可审计的真实 stringified-object wire；当前不重复启动同一探针。

## Applicability decision

后续复核确认本条不是一个独立的用户产品表面：`ObjectMap` 只在 loop 的模型工具参数解码边界生效，
不新增或修改业务实体状态；持久化的 tool call/result 真相属于对应的 function/handler/agent 旅程。
因此本行的其余等级可以按适用性正式收口，而不是把缺少录屏写成通过：

- L2 `na`: 没有本条独有的持久化业务状态；数据真相由宿主工具旅程覆盖。
- L3 `na`: 参数解码没有独立的用户反馈时延或动画表面。
- L4 `na`: 参数解码没有独立的视觉几何、颜色或动效表面。
- L5 `na`: 参数解码不是用户可发现的入口，不能单独评估 discoverability。

L1 仍由 focused tests 证明两种 object encoding 等价且错误 shape 拒绝；这不是降低五级标准，
而是明确本条只有一个适用等级。
