# EDGE-344 · 直连生成整体退场 · 真实 App 五通道验收

## 环境与前置条件

- 使用全新隔离数据 `/private/tmp/anselm-data-edge344-byok-20260827`，真实 App onboarding
  创建 `EDGE-344 BYOK only` workspace。
- 首次 workspace provision 使用关闭的回环 gateway，后端真实记录 install 失败；该失败是本
  测试为了构造“无受管 install”的前置条件，属于预期降级，不是把 gateway 成功伪造成失败。
- 随后只添加一条 BYOK `qwen` key，probe 成功并返回 `qwen-plus`；workspace 的 key 列表没有
  `anselm` managed 行，model capabilities 只有该 BYOK 模型。
- 有效真实 App session 为
  `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-220925/`，录屏为 H.264、60fps、
  `2784x1808`、`156.893333s`。session 由 conductor 托管 backend、三路 SSE witness、LLM
  witness、frontend console 与录屏；运行中 `rig-check.sh` 通过，收台无残留。

## 产品路径

1. 真实 App 的模型菜单只显示 `自动` 与 `qwen-plus · EDGE-344 BYOK`，没有 `Anselm Free`。
2. 真实 App 选择 `qwen-plus`，请求“尝试使用 `generate_image`、`generate_speech`、
   `generate_video`”。界面没有生成入口、没有生成卡片，也没有让用户点击一个必然失败的隐藏
   工具；两轮请求都以普通文本完成，Composer 仍可继续使用。
3. provider wire `/private/tmp/edge344-provider-wire.jsonl` 记录两次实际 chat request：
   - 第一轮在能力目录尚未展开时 `tool_count=0`；
   - 第二轮 `tool_count=13`，工具名只有 `Read`、`Write`、`Edit`、`LS`、`Glob`、`Grep`、
     `Bash`、`BashOutput`、`KillShell`、`ask_user`、`todo_write`、`todo_read`、`search_tools`。
   两轮均不含 `generate_image`、`generate_speech`、`generate_video`。
4. SSE messages durable sequence 第一轮为 `1..6`，第二轮为 `7..12`；均为 user、assistant text
   和 completed message 的完整闭合链，没有 tool call/result 或生成附件。notifications 记录
   conversation 创建、model override、自动标题；seq=0 delta 不冒充 durable 事实。
5. backend journal 仅有两条预期的 free-tier install failed WARN（关闭 gateway 的构造条件），无
   panic/fatal/应用 ERROR；frontend console 无 Flutter/Dart/RenderFlex/Unhandled/Exception
   红线。`rig-check.sh` 五通道通过，`rig-down.sh` 正常封口。

## 交叉判定

- `TestGenerateImage_HonestAbsence`、`TestGenerateVideo_HonestAbsenceWithoutAKey`、
  `TestSpeech_HonestAbsence` 所锁定的静态能力契约，与真实 workspace key 状态、模型 wire、
  SSE、UI 和 backend journal 一致。
- 本条 L2 通过：无受管 install、仅 BYOK 时三种生成工具诚实缺席，普通聊天不受影响。
- L1 原有 focused 证据保留：
  `testend/rig/formal-evidence/EDGE-344-direct-generation-absence-20260826.md`。
- L3-L5 不由本条一次无生成路径冒充；跨场景顺滑、craft 与可发现性仍需对应法条和独立测量证据。
