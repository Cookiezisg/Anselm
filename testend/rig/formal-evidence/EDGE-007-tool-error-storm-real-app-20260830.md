# EDGE-007 · 工具错误风暴熔断真实 App 证据（2026-08-30）

## 结论

这是一次干净的真实 App + managed gateway 五通道复验，正式支持本格 L2（数据真相）。不把一次韧性边界场景冒充 L3 顺滑、L4 视觉 craft 或 L5 从零可发现性；这三个等级继续由清册中的 `~` 保持未结算。

## 台架

- session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-013849`
- data：`/private/tmp/anselm-data-edge007-20260830-r6`
- workspace：`ws_489c8efd436de833`
- conversation：`cv_34f750e0035efce8`
- function fixture：`edge007r6` / `fn_0afe8cf80c4d19ed`，函数体故意抛出 `EDGE007 deliberate tool failure`
- 应用由本次前端重建产物启动；没有人工授权、密码或安全确认动作

## 真实结果

1. 用户通过真实 App 发起回合；模型连续三步各调用一次 `edge007r6`，参数为 `nonce=701`、`702`、`703`，每次均真实执行并失败，第三次后停止继续调用。
2. SQLite `pragma integrity_check` 为 `ok`；assistant 行为 `status=error`、`stop_reason=error`、`error_code=TOOL_ERROR_STORM`，`error_message` 为“3 consecutive turns where every tool call failed; aborting to prevent runaway”；三张 `tool_result` 均为 `status=error` 且 `error` 非空。
3. ssetap 的 messages durable 序列为 `1..40`，无 gap；最终 `message close` 携带同一 `TOOL_ERROR_STORM` 终态。entities 与 notifications 流也正常连接并落帧。
4. LLM tap 的 challenge/install/models 与真实 completion 请求均返回 HTTP `200`；请求和响应均留存于 session。
5. backend journal 无 `WARN|ERROR|panic`；frontend journal 无 `Error|Exception|SEVERE|Unhandled|FlutterError`；录屏为 `138.893333s / 3104x1844 / 60fps`。

## 产品画面

- 实时回合画面：`EDGE-007-storm-banner-live.png`。滚到终态位置后，红色提示为“工具持续失败，因此暂停本次回复。请检查输入后重试。”，下方保留恢复操作。
- 离开该会话再返回后的水化画面：`EDGE-007-storm-banner-rehydrated.png`。同一提示从 SQLite 恢复，未产生第二条助手回合。
- 这同时验证了本轮修复的两个缺陷：业务失败信封不再被当作 transport 成功；REST settled 根与迟到 durable message close 合并时，终态提示不再被身份缓存遮蔽。

## 顺滑测量

- 从 `screen.mov` 抽取 `139` 个 `1fps` 样本，运行 `(cd testend && go run ./cmd/measure diff ...)`，通道容差为 8、阈值为 `0.0005`。
- `changedFrac` 较大的变化只出现在真实发送、模型流式输出、终态滚动以及离开/返回会话的用户动作窗口；返回故障会话后的 `f-0126.png` 至 `f-0139.png` 连续约 `13s` 无超过阈值的变化。
- 未观察到终态提示出现后继续自动滚动、重复渲染、回跳或既有内容非用户位移。

## 记账边界

- L1：沿用既有确定性 loop 证据，不在本文件重复覆盖。
- L2：本文件支持 `F1`，由 `judge.py` 写入正式账本。
- L3：本 session 的独立录屏 diff 支持 `B2`；用户动作后的终态提示在实时和重新水化画面均稳定，写入正式 `pass`。
- L4：已目视核对错误提示的产品文案和红色状态，但未做本格独立 ROI/几何测量，保持 `~`。
- L5：用户不能从普通入口主动导航到“连续三次工具失败”故障注入，保持 `~`。
