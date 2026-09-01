# EDGE-290 · skill 未知 frontmatter 键保真 · 真实 App 证据

- 日期：2026-09-01
- session：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-131705`
- workspace：`ws_bfdfce4f45a6dcf4`
- 结论：通过；右岛 Properties 的结构化编辑没有丢失 typed 视图之外的 YAML 元数据。

## 场景

在隔离 workspace 创建 `edge290-fidelity`，再通过同一 sidecar 的文件 API 写入带有注释、`license`、`x-vendor-thing`、`author`、`version` 等未知键的 `SKILL.md`。真实 App 打开 Library 中的该 skill，确认中心显示描述和正文、右岛显示 Properties，然后只在右岛将 `User-invocable` 从 `On` 改为 `Off`，等待自动保存完成。

## 观察结果

- 保存后的原始 `SKILL.md` 仍保留注释、`license: MIT`、`x-vendor-thing: keepme`、`author: acceptance`、`version: "1.0"`、原有键序和正文。
- 结构化写入按设计补充 `source: user`，并移除已关闭的 `user-invocable`；这是受控字段变化，不是未知键丢失。
- `GET /skills/edge290-fidelity` 的 typed 视图仍返回原描述、原正文、`context=inline`、`source=user`；未知键不被错误投影成受控字段。
- 稳定画面显示中心标题、描述、正文与右岛 `Properties` 对齐，`User-invocable` 明确为 `Off`，无空白、跳变或错误提示。
- 录屏已由台架正常封口：`screen.mov` 时长约 103.165 秒；稳定帧为 `evidence/EDGE-290-properties-after-edit.jpeg`。

## 五通道

1. 画面：`screen.mov` 与稳定帧记录了 Library skill、中心正文/描述和右岛字段。
2. 后端：`backend.log` 非空且无应用级 `WARN`、`ERROR`、`panic` 或 `FATAL`；健康检查通过。
3. SSE：`sse.jsonl` 记录 `messages`、`entities`、`notifications` 三流连接；同一 workspace 收到 `skill.created` 及两次 `skill.updated` durable signal，收台时三流正常 EOF。
4. 前端：`frontend.log` 仅有启动/运行记录，无 Flutter、Dart、RenderFlex 或未处理异常。
5. LLM 线缆：`llm.jsonl` 记录真实 managed gateway 的 challenge、install、models 请求均为 `200`；本场不发送聊天请求，因此没有伪造 completion 证据。

## 级别裁决

- L1 `F1`：既有 focused/race 回归覆盖 `license`、厂商键、键序、注释保留及安装 provenance 不写回原始文件。
- L2 `F2`：真实 macOS App、真实 sidecar、真实三路 SSE、LLM tap 和封口录屏在同一台架 session 内闭合。
- L3 `A1`：右岛字段点击后有即时菜单反馈，选择后状态稳定收敛；自动保存后无重复请求造成的可见抖动。
- L4 `C4`：稳定帧中右岛卡片、字段控件、文字和中心内容层级符合既有圆角与间距尺度；无新增视觉缺陷。
- L5 `G1`：新用户可从 Library → skill → Properties 直接发现并操作配置字段，无需阅读内部 API 或 frontmatter 规则。

本场未修改产品代码；未发现需要 stop-and-fix 的产品问题。
