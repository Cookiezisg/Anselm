# EDGE-267 · 切分支不落 marker · 真实 App 验收

## 场景

真实 Flutter macOS App 打开专用空线程 `cv_cb9d986e2daae9a0`，驻地为
`/private/tmp/anselm-edge261-repo.JMXK9e`。台架先准备本地分支 `edge267`，再在 App 菜单中
打开 Git 分支列表并切回 `main`。分支投影发生变化，但驻地路径没有变化；因此不应写入
`kind=workdir` marker，也不应改变消息历史。

## 产品观察

- App 菜单在切换前显示 `Branch edge267`，并提供 `main` 作为可操作分支。
- 通过真实 App 点击 `main` 后，菜单重新显示 `Branch main` 和 `No uncommitted changes`。
- 当前线程始终保持空历史，没有出现“驻地变化”或其他伪 marker。
- 最终画面：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-233046/evidence/EDGE-267-branch-no-marker-real-app.png`。

## 五通道证据

- **屏幕 / Computer Use**：真实 App 的分支菜单从 `edge267` 切换到 `main`，最终驻地路径与 Git 状态可读，消息区为空。
- **后端 journal**：真实 branch switch 请求成功；没有工作目录迁移错误、panic 或应用级红线。
- **SSE witness**：仅观察到线程创建和驻地投影的 notifications durable 帧，没有 messages 流帧、marker 帧或伪造的 transcript 更新。
- **前端 console**：只有 macOS IMK 系统诊断，没有 Flutter/Dart/RenderFlex/overflow/Unhandled 错误。
- **LLM wire**：本场景不需要模型调用；llmtap 只记录真实 managed bootstrap 接线，不伪造 completion。

## 数据真相

```text
GET /conversations/cv_cb9d986e2daae9a0/workdir
  path=/private/tmp/anselm-edge261-repo.JMXK9e
  branch=main
  dirty=false
GET /conversations/cv_cb9d986e2daae9a0/messages = {data: [], hasMore: false}
SQLite message_blocks for conversation = 0
SQLite marker blocks for conversation = 0
```

`rig-check.sh` 通过全部五通道归属检查，`rig-down.sh` 将录屏封存为 `98.133333s`；本 session
没有启动 chat completion，也没有将无关的 gateway 流量冒充为本场景证据。

## 五级判定

- L1 `F5`：分支是驻地内的 Git 投影，不是驻地迁移；切换分支不写 marker。
- L2 `F2`：App、REST、SQLite、SSE、backend/frontend/LLM journals 一致。
- L3 `B2`：切换动作完成后菜单状态一次性更新，无旧分支闪回、空白或历史跳变。
- L4 `C5`：分支信息、脏状态和驻地路径层级稳定，空历史不被无意义状态行污染。
- L5 `G1`：Git 区域在驻地菜单中可发现，用户能直接看到当前分支并选择另一条本地分支。

## 本地验证

- `backend/internal/app/conversation/workdir_test.go` branch/no-marker focused coverage
- `testend/rig/rig-check.sh`：passed
- `testend/rig/rig-down.sh`：passed
- `testend/rig/gen_coverage.py --check`：passed after ledger write
- `make -C docs verify`：passed
