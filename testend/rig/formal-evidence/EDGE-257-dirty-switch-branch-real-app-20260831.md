# EDGE-257 · 脏区切分支被拒 · 真实 App 复验

## Session

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-203407`
- workspace: `ws_d2881afb14aad58a`
- conversation: `cv_9c40d911faad719c`
- workdir: `/private/tmp/anselm-edge257-repo.XeJksd`
- fixture: Git `main` with local `feature` branch and uncommitted `dirty.txt`
- recording: `screen.mov`, `218.643333s`, `3104x1844`, `60fps`

## Journey and result

从真实 App 的普通 Chat 对话打开驻地菜单。菜单显示 `Branch main`、`Uncommitted changes`，
并用完整可读的 `Commit or stash changes before switching` 解释为什么没有提供已存在分支
切换行；`New branch...` 和 `Open a worktree for this conversation...` 仍然可用。键盘导航
滚到菜单尾部后，worktree 行真实出现在画面中，未被不可达地藏掉。服务端拒绝契约由
`TestSwitchBranch_DirtyIsRefusedWithANextStep` 与
`TestChatWorkDirGit_SwitchBranchMovesTheProjectionAndDirtyIsRefused` 锁定为
`422 CONVERSATION_WORK_DIR_DIRTY`；真实 App 的脏态产品面没有发起一条必定失败的分支行。

首轮同场发现英文阻断提示被菜单宽度截为 `...then switc...`，保留在
`EDGE-257-dirty-switch-branch-red-20260831.jpg` 和首场录屏中。停止推进后将文案收窄为
`Commit or stash changes before switching`，重新生成翻译并以本场录屏复验完整可读。
修复后的稳定帧为 `EDGE-257-dirty-switch-branch-fixed-20260831.jpg`。

## Five channels

- frames: window-only recorder，稳定帧无空白、旧状态闪回、文字越界或重排。
- backend: backend journal 无 WARN、ERROR、panic 或 FATAL；真实工作目录投影请求正常。
- SSE: messages/entities/notifications 三流均连接；notifications durable seq `16..17` 单调。
- frontend: 无 Dart/Flutter/RenderFlex/overflow/Unhandled 应用红线；AX bridge 观测器同步噪声由
  `evidence/frontend-ax-review.md` 明确分类，不静默吞掉。
- LLM wire: managed gateway challenge/install/models 均成功；本格不需要聊天 completion，
  不虚构一次 LLM 产品调用。

`rig-check` 在 AX review 文件存在后五通道通过，`rig-down` 正常封口且 owned processes 全部
退出。focused backend/frontend 套件均通过。
