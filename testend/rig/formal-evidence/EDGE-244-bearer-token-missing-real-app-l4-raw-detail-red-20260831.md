# EDGE-244 bearer token 缺失：L4 红证据

- 发现于正式 session=`/private/tmp/anselm-rig-formal-20260831-12/sessions/20260831-174529` 的稳定尾帧及 Computer Use AX 复核。
- 认证专用标题和恢复提示已经正确，但错误页第三行仍显示
  `ApiException(UNAUTH_BAD_TOKEN, http=401): unauthorized: invalid or missing bearer token`。
- `frontend/lib/core/ui/an_state.dart` 的既有契约明确说明启动/工作区 fatal screen 的 detail 是 debug detail，raw URL、内部实现错误不应进入产品面；`AppStartupGate` 也已遵守同一规则。因此该原始异常是用户可见的产品 craft/文案缺陷，不是可接受的诊断层。
- 该红事实不否定 L2 的认证语义修复，也不否定 L3 的 loading 反馈；它使此前 L4 绿色判断失效，必须 stop-and-fix 后以新 session/新稳定帧重跑 L4。

## Verdict

- L4 `fail`，原因：用户面泄漏内部异常类型、HTTP 状态和 provider 诊断原文，不符合启动/工作区错误态的产品契约。
- L4 原通过证据保留为历史记录，不删除、不覆盖；修复后的视觉证据必须重新验证。
