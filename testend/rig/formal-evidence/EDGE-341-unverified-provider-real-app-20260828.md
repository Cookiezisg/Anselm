# EDGE-341 未验证供应商诚实徽标 · 真实 App L2

## 场景

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-030900`
- data: `/private/tmp/anselm-data-edge341-20260828-r1`
- workspace: `EDGE-341 Provider Trust`
- 操作：全新工作区进入「模型与密钥 → 添加密钥」，读取供应商目录，打开 `302.AI` 的添加密钥表单，检查名称、密钥、Base URL 和取消入口后取消。
- 未输入、上传或保存任何 API 凭证；取消后设置页恢复，受管 Anselm key 仍是唯一工作区密钥。

## 产品观察

- 目录显示 `0-100 of 213 items`，各供应商卡片同时展示名称、模型数量和 `未验证` 徽标。
- `302.AI`、`Abacus` 等目录项没有被伪装成已验证能力；受管 Anselm 条目在已配置区单独显示。
- 添加表单提供明确的 `名称`、`密钥`、`Base URL`、`保存并测试` 与 `取消` 结构；本轮沿取消路径退出，没有副作用。
- 本轮真实观察确认了 L1 用户目的与 L2 数据真相；没有把未独立 hover tooltip、延迟测量、ROI craft 审查或从零盲走可发现性写成通过。

## 五通道证据

- 帧：`screen.mov` 由 conductor 绑定 Anselm window `4428` 连续录制 `143.845000s`；关键帧为 `evidence/provider-catalog.png` 与 `evidence/provider-302ai-form.png`。
- 后端：`backend.log` 为 conductor 归属的 PID `49187`，监听 `:8742`；健康检查通过，无 panic/FATAL/应用级错误。
- SSE：`sse.jsonl` 由独立 `ssetap` PID `49207` 连接当前 workspace 的 `messages`、`entities`、`notifications` 三流；无本场景业务 mutation，不伪造 durable frame。
- 前端：`frontend.log` 由 conductor 启动的 App PID `49651` 捕获；无 Flutter/Dart/RenderFlex/Unhandled/Exception 应用级红线。
- LLM：`llm.jsonl` 由独立 `llmtap` PID `49162` 接线至真实受管网关；challenge/install/models 均为 `200`。本场景没有模型调用，不把 `event=ready` 冒充 completion。
- 收台：`rig-check.sh` 与 `rig-down.sh` 均通过；录屏可读，所有 backend/tap/App/recorder 进程均已停止。

## 裁决边界

`judge.py` 仅写入 `EDGE-341` 的 L2/F1。L3（顺滑）、L4（视觉 craft）和 L5（可发现性）继续保持 `na`，因为本轮没有独立的首反馈帧量测、ROI 视觉测量或从零无提示探索。
