# SURF-098 i18n/status 调查

## 结论

本格先发现并修复了真实产品问题：日志明细行直接拼接 backend raw status，导致中文界面出现 `manual · failed`。修复后四类日志行统一使用五态本地化词，真实 app 画面显示 `manual · 完成/失败`，不再泄漏英文状态。

## 修复与回归

- `frontend/lib/features/entities/state/detail/log_list_provider.dart` 新增统一 `_statusWord`，function/handler/agent/workflow 用户可见主行均经 `AnStatus.fromRaw` → `t.status.*`。
- `frontend/test/features/entities/state/detail/log_list_provider_test.dart` 新增 English/简体中文双语断言。
- focused Flutter suite 全绿；`dart format` 无改动。
- 旧会话中一次 `sky.set_value` 对自定义 JSON editor 未触发 Flutter `onInput`，已通过真实坐标点击 + 键盘输入复核为台架操作差异，不计为产品缺陷。

## 五通道真实证据

修复后正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-064736`，workspace=`ws_4c8a6c08c07f6523`。screen/backend/SSE/frontend/LLM 五通道均由 `rig-check.sh` 通过并由 `rig-down.sh` 收台。最终录屏帧为 `sessions/20260825-064736/evidence/frames/SURF-098-i18n-status-final.png`；backend=`207` 行，frontend=`3` 行，SSE=`192` 行，LLM=`13` 行。

真实 UI 路径为 Entities → `surf041_terminal_function` → 日志，聚合为 `2 完成 / 1 失败`，明细为 `manual · 完成`、`manual · 失败`、`manual · 完成`。SSE 还保留了专门 fixture 的 workflow 失败 `entry.body.count` 缺失 `body`，该红事实用于覆盖真实失败状态，不被隐藏，也不归因于 i18n。

## 边界

detail rows 中的 id、时间戳、原始 JSON 和 raw status 属于诊断 chrome，保持机器事实；本格的用户主行和通用状态词已完成本地化。未修改 CODEX、anchors、alarm 算法或阈值。
