# EDGE-179｜首用下载途中关停｜L3 修复后收口（2026-08-30）

## 判定

修复后 `L3 通过`，依据 `CODEX.md` 的 `A4`。这是一份新的真实 session revalidation，不覆盖此前的红证据：`EDGE-179-search-first-download-shutdown-l3-red-20260830.md`。

## 真实复验

- session：`/private/tmp/anselm-rig-formal-20260801-6/sessions/20260830-214132`
- 真实 Flutter App 完成 onboarding，创建 workspace `ws_936262f3b29a01a3`
- 真实文档夹具 `doc_47b81e8ee225bc00` 触发 builtin embedder 首用下载
- 真实 `/api/v1/search/settings` 返回 `engine.status=downloading`
- Computer Use 观察到下载窗口中的真实 Chat 后，向真实 backend PID `59897` 发送 SIGTERM；backend 在约 39ms 的原始时间戳差内退出，并记录 `context canceled`、lexical fallback 与有序 sandbox 收口

## 五通道与结果

1. **Frame**：`screen.mov`=`3104x1844 / 60fps / 85.275s`。关停后 `stable-error-75s.png` 真实画面显示全屏错误门：`Can't reach the local engine`、`The local engine is unavailable. Start it, then try again.` 和 `Retry`。没有继续展示正常 Chat，也没有空白等待态。
2. **Backend journal**：真实记录 SIGTERM、有序关停、下载 context cancellation、lexical fallback；无 panic/fatal。
3. **SSE tap**：messages/entities/notifications 三条均真实连接；独立 ssetap 按其观测职责继续记录 backend 不可用，前端三条 SSE 则在错误门收敛时随 gateway dispose 停止，不把独立 witness 的重试误算成 App UI 重连。
4. **Frontend console**：sidecar 退出后的检测窗口内仅 `8` 行连接拒绝（每个底层错误含 Dio/Socket 两行）；等待 5 秒复核仍为 `8`，不再增长。除已知 macOS IMK host diagnostic 外，无 Flutter/Dart/RenderFlex/Unhandled 应用红线。
5. **LLM wire**：managed gateway challenge/install/models 均 HTTP `200`；本场景没有聊天请求，未伪造 LLM 业务成功。

## 修复与回归

`BackendController` 对 `ANSELM_BACKEND_URL` 启动后的外接 backend 增加可取消连续健康监督：连续 3 次健康检查失败才转 `BackendPhase.crashed`，避免瞬时抖动误报；phase 变化后现有 Riverpod 门控销毁三条 SSE，并显示可理解、可恢复的错误门。focused Flutter 回归覆盖“ready 后 backend 消失 → crashed”，并验证监督器 teardown 不泄漏。

## 结论

真实 App 在后端不可用后收敛到明确的可恢复状态，终端错误有限且停止增长，用户拥有唯一明确的下一步 `Retry`。L3 通过；L4/L5 不由本证据代填。
