---
kind: formal-evidence
campaign: WRK-087
date: 2026-08-26
status: green-after-fix
---

# EDGE-354 · 真实生图→改图回合红绿证据

## 红场

旧 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260826-064151`
的真实 App 回合完成了生图和改图，但暴露两个产品问题：

1. `edit_image` 成功后，模型同一回合再次发出完全相同调用。后端正确抑制了第二次副作用，
   但 transcript 仍显示第二张橙色“未执行”卡，用户会误以为改图失败或执行不完整。
2. 中文回答中的“图像已保存并可通过附件 ID `att_...` 引用”经过 opaque ID 脱敏后变成
   “图像已保存并可通过附件 ID 这个输入 引用”，语义和中文都不成立。

红场录屏与原始 LLM wire 保留在该 session；wire 证明上游原文包含真实附件 ID，问题发生在
用户可见文本的脱敏层，不是生成服务返回错误。

## 修复

- `frontend/lib/features/chat/ui/chat_tool_card.dart` 对所有 `ToolCardPhase.suppressed` 隐藏
  第二张 transcript 卡；抑制结果仍保留在 durable blocks 和 wire journals。
- `backend/internal/app/loop/redact.go` 将中文“附件 ID/标识符 + opaque value + 引用/查看/打开/下载/访问”
  整段重写为“附件卡片 + 动词”，并在跨 provider chunk 时暂存前缀，避免半句泄漏。
- 补充 backend redactor 回归测试、frontend tool-card gate 测试，并同步 Chat/Loop 参考文档。

## 绿场

Session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260826-230803` 使用新二进制、
真实 Flutter App、真实 managed gateway、Computer Use 和连续录屏完成：

- 用户目的达成：真实生成横向深海蓝/琥珀圆环图片，再以真实 `edit_image` 改小并左移 12%，
  改图作为新附件落地；App 显示 `generated-20260826-151041.png · 1344×768`，打开大图确认构图、
  留白、颜色和无文字要求成立。
- 用户可见 transcript 只有一张“已改图”结果卡，没有“未执行”重复卡，也没有“附件 ID 这个输入”。
- LLM tap 记录 `/v1/images/generations` 和 `/v1/images/edits` 均为 `200`；改图请求体为
  `1,488,569` bytes，响应为 `251` bytes，真实 source/new attachment ID 在 SSE durable result 中一致。
- SSE witness 共 `172` 帧；本路径 `messages` durable `1..28`、`notifications` durable `1..2` 单调，
  未发现 `Duplicate tool call suppressed`、`duplicateSuppressed`、`这个输入` 或 `附件 ID` 泄漏。
- `backend.log`、`ssetap.log`、`llmtap.log` 无 panic/fatal/error/warn；`frontend.log` 仅有已知 macOS
  `IMKCFRunLoopWakeUpReliable` 系统噪声，无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线。
- 录屏为 H.264 `2784×1808 / 60fps / 169.813333s`；rig-check 在会话存活期间通过五通道物理检查，
  rig-down 后无 backend、tap、App、recorder 残留。

## 判定

这是一次真实产品 stop-and-fix：旧红场不计绿，修复后绿场证明用户目的、可见结果、媒体上游、SSE
durable truth 和前端/backend 健康同时成立。该证据用于后续 `TOOL-119`、`TOOL-122` 和 `SURF-070`
的复审，不扩大未实际覆盖的其他媒体或生成路径结论。
