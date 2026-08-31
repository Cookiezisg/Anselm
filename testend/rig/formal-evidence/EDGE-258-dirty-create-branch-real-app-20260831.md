# EDGE-258 新建分支不受脏区门：真实 App 验收

正式 session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-205254`，workspace=`ws_0f27f9cfd230884e`，conversation=`cv_92dce39cd5570793`。

真实 fixture 是 `/private/tmp/anselm-edge258-repo.yK8jXF`：一次 `main` 初始提交后留下未跟踪的 `in-progress.txt`。真实 Flutter macOS App 在脏状态下打开驻地 Git 菜单，展示 `Branch main`、`Uncommitted changes`、禁用的已有分支切换提示 `Commit or stash changes before switching`，同时保留可用的 `New branch...`。新建分支对话框明确说明未提交改动会随新分支带走且不会冲突。

Computer Use 用真实键盘输入 `feature/edge258` 并执行 `Create and switch`。对话框收口后，后端投影与 `git branch --show-current` 均为 `feature/edge258`，`git status --short` 仍为 `?? in-progress.txt`；没有 commit、stash、数据丢失或误切已有分支。重新打开菜单显示 `Branch feature/edge258` 与 `Uncommitted changes`。AX 树同时暴露 `Open a worktree for this conversation...`，菜单无布局塌陷；最终帧=`EDGE-258-dirty-create-branch-final.png`。

focused 后端 conversation/HTTP/gitinfo 回归通过；真实 session 录屏=`201.396667s / 3104x1844 / 60fps`。backend journal 无应用级 WARN/ERROR/panic/FATAL；三路 SSE 均连接，notifications durable seq=`16,17` 单调，收台为 clean EOF；frontend 无 Dart/Flutter/RenderFlex/overflow/Unhandled 应用红线，仅有已知 macOS IMK 诊断；managed LLM tap 的 challenge/install/models 均成功，本场景不需要 chat completion，故不虚构聊天调用。`rig-check.sh` 与 `rig-down.sh` 均通过，收台无残留进程。

本格没有发现需要 stop-and-fix 的产品问题；本证据只主张“脏区允许新建分支”及其真实结果，不把创建请求前一次错误 payload（创建端点只接受 `title`，已按契约修正为 create 后 PATCH）计入产品红线。
