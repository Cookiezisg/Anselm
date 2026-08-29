# EDGE-293 · 删被依赖实体：真实 App L2

## 目的

验证删除一个仍被多个 Agent 挂载的 Function 后，产品以一次聚合通知诚实说明影响范围，而不是发出多条无法关联的警告，或静默留下悬空引用。

## 正式 session

- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-145009`
- data=`/private/tmp/anselm-data-edge293-real-20260829-r1`
- workspace=`ws_68ea73847fa70778`
- App/window=`35155/6138`；录屏=`214.191667s`
- 关键帧=`sessions/20260829-145009/evidence/EDGE-293-notification-aggregate.jpeg`

## 场景

1. 真实 seed workspace 中取得 Function `fn_60afa16282a3a131`（`greet`）。
2. 通过真实 API 创建三个 Agent，并让它们都挂载该 Function：
   - `ag_5b16bba4d84aa5f4` · `EDGE293 dependent one`
   - `ag_74a65eaba0a147e2` · `EDGE293 dependent two`
   - `ag_f1cce4d727d05955` · `EDGE293 dependent three`
3. 删除该 Function，HTTP 返回 `204`。
4. 真实 App 打开 Notifications，逐帧观察顶部通知。

## 五通道证据

- **Channel 1 / Computer Use + 录屏**：App 通知中心显示：`Function "fn_60afa1..." was deleted, leaving 4 references dangling`，并列出 `deploy-helper`、三个 EDGE293 Agent；下方另有 `Function "greet" deleted`。关键帧没有裁切、遮挡或残留 loading。
- **Channel 2 / backend journal**：删除请求 `204`；relation purge 记录 `removed: 4`；无应用级 WARN/ERROR/panic。
- **Channel 3 / SSE tap**：notifications 只有一条 `relation.dependency_broken`，`seq=21`，payload 的 `dependents` 恰为四项，包含三个 Agent 及既有 `deploy-helper`；另有独立 `function.deleted`，没有重复的 dependency 聚合。
- **Channel 4 / frontend 错误面**：`rig-check` 通过真实 App/window 归属和录屏遮挡检查；backend journal 错误扫描无应用级红线。
- **Channel 5 / LLM tap**：本场景不触发 LLM；session 的 llmtap 仍完成 challenge/install/models `200`，无虚假模型调用或未观察调用。
- **耐久对账**：`GET /api/v1/notifications?limit=50` 与 SSE payload 一致；SQLite `PRAGMA integrity_check`=`ok`，`foreign_key_check` 为空。

## 判定

本证据只支持 L2 `F1`：真实 App 的用户可见通知、REST 持久化通知与 SSE 聚合事实一致，并点名所有四个悬空引用。L3-L5 不在本次证据中猜测，继续保持 `na`。
