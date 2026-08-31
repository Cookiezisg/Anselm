# EDGE-266 · 空线程/重复 PATCH 不落 marker · 真实 App 验收

## 场景与边界

本次使用真实 Flutter macOS App、真实运行中的 Go sidecar、真实 Anselm managed gateway 接线，
在空线程 `cv_be98a3eee30d8c67` 上验证两条不应产生历史的路径：

1. 空线程首次挂载 `/private/tmp/anselm-edge265-first`。
2. 对已挂载的同一路径再次 PATCH。

第一条是一次真实状态迁移，但线程在迁移前没有消息，因此没有“from”历史可记录；第二条是
严格 no-op。两条都不得创建 marker 或普通消息。

## 修复后的真实产品观察

- 首次挂载后，App 面包屑立即显示 `anselm-edge265-first`，历史区保持空白。
- 同一路径再次 PATCH 后，App 仍显示同一个目录，历史区没有新增条目、空白区没有闪烁成一条伪历史。
- 最终屏幕证据：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-232410/evidence/EDGE-266-workdir-marker-noop-real-app.png`。

## 五通道证据

- **屏幕 / Computer Use**：真实 App 的 accessibility tree 在最终状态包含目标驻地按钮、`演示对话` 标题和空历史区；无 marker 文本。
- **后端 journal**：两次 PATCH 均为 200；第一次把 workdir 设为目标绝对路径，第二次重复同值仍为 200；没有错误或 panic。
- **SSE witness**：会话的两条 durable 帧均为 `notifications` 流的 `conversation.work_dir` 信号；没有 `messages` 流帧、没有 message marker 帧。
- **前端 console**：只有 macOS IMK 的系统诊断，没有 Flutter/Dart/RenderFlex/overflow/Unhandled 错误。
- **LLM wire**：本场景不需要模型调用；llmtap 只记录启动接线，没有伪造模型证据。

## 数据真相交叉核对

```text
PATCH 1 response.workDir = /private/tmp/anselm-edge265-first
PATCH 2 response.workDir = /private/tmp/anselm-edge265-first
GET /conversations/cv_be98a3eee30d8c67/messages = {data: [], hasMore: false}
SQLite message_blocks for conversation = 0
SQLite marker blocks for conversation = 0
```

`rig-check.sh` 在封存前通过全部台架检查：屏幕权限、D1 端口归属、后端健康、SSE 三流接线、
LLM tap 接线、App/window 归属、录屏生命周期和五通道观察均为 green。

## 五级判定

- L1 `F5`：只有真实驻地迁移才产生 marker；空线程与同值重复操作不会伪造历史。
- L2 `F2`：屏幕、后端 journal、SSE、frontend console、LLM wire 的结果相互一致。
- L3 `B2`：两次动作都在一次可观察的 UI 状态更新内完成，无历史闪入或空白区跳变。
- L4 `C5`：空状态保持干净，驻地面包屑与空历史区的几何关系稳定，不渲染无意义的 marker。
- L5 `G1`：打开空线程即可发现驻地入口；重复选择同一路径的结果可理解且不会制造误导反馈。

## 本地验证

- `backend/internal/app/conversation/workdir_test.go:TestUpdate_WorkDirNoopsAndAbsentKey`
- `frontend` stream/workdir focused suite：35/35 passed（本轮复核未改产品代码）
- `testend/rig/rig-check.sh`：passed
- `testend/rig/gen_coverage.py --check`：passed after ledger write
- `make -C docs verify`：passed
