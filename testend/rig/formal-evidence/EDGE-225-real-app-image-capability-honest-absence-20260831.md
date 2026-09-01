# EDGE-225 · 能力工具诚实缺席：真实 App stop-and-fix 后五通道收口

## 结论

`L1`、`L2`、`L3`、`L4`、`L5` 通过。首场真实回合暴露了错误的产品引导：能力缺席时模型把用户引向
MCP 市场，而 Anselm 内置生图的真实入口是 `Settings → Models & keys → Image generation`。
修复 `backend/internal/app/chat/prompt.go`、Chat prompt 回归测试及 Chat domain 文档后，用新构建的
真实 App 和同一受管网关重跑；最终画面、SSE close、LLM wire 与后端状态一致，未发生生图调用。

## 正式 session

- session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-123648`
- workspace=`ws_9afa71bd3908f6d8`，data=`/private/tmp/anselm-rig-formal-20260831-11/data-edge225-fix`
- 首场错误前置条件与原始结果保留在 session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-122936`
- 修复场景通过真实 App 创建 workspace；对 image scenario 显式选择不支持生图的 DeepSeek route，dialogue 仍使用受管 `anselm-auto`
- `rig-check` 五通道通过；`rig-down` 正常封口，录屏=`117.461667s`，收台后无 Anselm/llmtap/ssetap/recorder 残留进程

## L1 · stop-and-fix 与回归

首场回合的状态确实没有错误调用，但最终引导错误地建议安装 MCP server。修复后的定向回归通过：

```text
mise exec -- go test ./internal/app/chat -run 'TestBuildSystemPrompt_Sections|TestSystemPromptPreview' -count=1
ok github.com/sunweilin/anselm/backend/internal/app/chat
```

新增规则要求：生图工具不在当前列表时，明确说明 workspace 暂不可生图，指向真实 Settings 路径，
不得把内置生图说成 MCP 安装，也不得把 speech/video/animate 当作文生图替代品。

## L2 · 真实用户目的与工具边界

真实 App 发送：

```text
Please generate an image of a quiet paper boat. If image generation is unavailable, say so clearly and explain how I can enable it.
```

最终画面=`evidence/edge225-fixed-app-final.png`，显示：

```text
Image generation is unavailable in this workspace — there's no image-capable model configured.

To enable it, go to Settings → Models & keys → Image generation and choose or configure an image-capable route there. Once that's set up, I'll be able to generate images for you.
```

没有生成图片卡、没有假成功、没有将“不可用”转成内部错误。该答复直接完成了用户在请求中指定的
“说明不可用并告知如何启用”的目的。

## L3 · 时序、SSE 与 LLM wire

SSE messages 流记录 user close 后 assistant close；user close 时间为 `12:38:25.069131`，
assistant text close 为 `12:38:28.962783`，约 `3.894s` 完成。第二个 sampling 请求同样返回
`200`，没有工具循环和图片上游请求。

LLM body 的工具 schema 名称为：

```text
Bash BashOutput Edit Glob Grep KillShell LS Read Write animate_image ask_user enroll_voice generate_speech generate_video search_tools todo_read todo_write
```

其中没有 `generate_image`；llmtap 全量 journal 没有 `/v1/images/generations`。challenge/install/models
与两次 chat completion 均由真实受管网关返回 `200`。

## L4 · 视觉与前端健康

最终截图=`evidence/edge225-fixed-app-final.png`。视觉检查确认：用户气泡、助手说明、设置路径和
composer 层级清楚，文字在内容列内完整换行，没有溢出、遮挡、空白错误态、残留 loading 或错误卡。
`frontend.log` 只有已知 macOS `IMKCFRunLoopWakeUpReliable` 平台诊断，没有 Flutter/Dart、RenderFlex
或未处理异常；backend journal 也没有 WARN/ERROR/FATAL/panic。

## L5 · 可发现性

最终答复给出可执行且准确的路径 `Settings → Models & keys → Image generation`，用户无需猜测 MCP、
provider 名称或内部错误码即可恢复能力。路径与前端实际 Settings 文案一致；这比首场“安装 MCP”
更短、更准确，也不会把可用的其它媒体工具误呈为生图替代品。

## 五通道交叉核验

- screen：同一 session 的 Anselm-window 录屏与 Computer Use 最终帧
- backend：sidecar journal、workspace image default 与 dialogue default 真实状态一致，无异常
- SSE：messages/entities/notifications 三流均连接；消息 user open/close、assistant open/text close 完整
- frontend：真实 macOS App build/launch/console journal；无 Flutter/Dart/布局红线
- LLM wire：受管 challenge/install/models/chat 均经 llmtap；无 `generate_image` schema、tool call 或图片上游请求
