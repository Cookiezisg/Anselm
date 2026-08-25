# SURF-107 · stage/trigger 调查与修复记录

## 结论

本格首轮的四类 trigger 构建路径与 cron listener 可用，但真实 App 的只读运行态展示暴露了一个产品级数据真相缺陷：`get_trigger` 返回的 `nextFireAt` 在后端最终答案脱敏阶段被当作普通 ISO 时间戳替换成了“相应时间”。用户明确要求“当前运行时状态”时，这使下次触发时间不可用，也使 UI 与 REST/LLM wire 不一致。该路径停止计绿。

修复位于 `backend/internal/app/loop/redact.go`：只保护带有明确 `nextFireAt`/“下次触发时间”标签的字段，并覆盖 direct field、翻译后的 Markdown table row 以及跨流式 chunk 边界；其它创建/更新时间仍照常脱敏。修复没有放开全局 ISO 时间戳，也没有改变工具结果或持久化真相。

## 真实重跑

- 修复前的四脸构建与 listener session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-090642`。
- 修复后的重新启动 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-092425`。
- 修复后的重跑使用同一隔离数据目录中已构建的四类 trigger，重新以真实 App、真实 managed gateway 和只读用户意图读取 `SURF107-cron`，没有把旧 session 的画面冒充为修复后的画面。
- 当前真实 REST 返回 `SURF107-cron`：`paused=false`、`listening=true`、`refCount=1`、`nextFireAt=2026-08-26T09:00:00+08:00`。
- 当前 App 画面与 AX 树显示：`下次触发时间 | 2026-08-26 09:00:00 (UTC+8)`；`最后更新`仍为脱敏的“相应时间”，证明字段级保护边界正确。
- 当前 LLM/SSE final close 显示完整的 `2026-08-26 09:00:00 (UTC+8)`，同一 close 中的 `最后更新`仍脱敏。

## 负向探针

- sensor 使用嵌套 target 形状时，后端明确拒绝 `sensor requires a function or handler target`，没有创建错误实体。
- 畸形 trigger ID 在读取前被拒绝，没有 retry 或副作用。
- 早期 Computer Use 输入桥丢失字符的请求保留在调查中，明确不计作产品绿证据；修复后的验证使用精确、只读请求。

## 定向验证

```text
go test ./internal/app/loop -run 'TestRedactOpaqueMachineValuesPreservesExplicitNextFireAt|TestRedactOpaqueMachineValuesPreservesTranslatedNextFireRow|TestTextRedactorPreservesSplitNextFireAtRow|TestRedactOpaqueMachineValuesPreservesExplicitLastMessageAt' -count=1  PASS
go test ./internal/app/loop -run 'Test(Redact|TextRedactor)' -count=1  PASS
flutter test frontend/test/features/chat/ui/tool_card_trigger_test.dart frontend/test/features/chat/ui/stages_w3_test.dart frontend/test/features/chat/ui/stage_alignment_test.dart  21/21 PASS
```

## 产品裁决

用户目的已经达成：可以在不修改任何 trigger 的前提下，找到指定 cron、确认它在线且被 workflow 引用，并看到准确的下一次触发时间。四类 trigger 的配置面、paused/listening 语义、cron 的真实 listener 与 R-16 的 GET 真相均已对账。没有发现新的 clipping、overlap、reflow 或非用户触发跳变。修复前的红事实保留，不以“模型后来自己解释”覆盖。
