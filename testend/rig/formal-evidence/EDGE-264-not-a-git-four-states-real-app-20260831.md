# EDGE-264 · 「这里没有 git」四情形

## 现场

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-224712`
- workspace: `ws_3aadf4d05fc4258a`
- ordinary conversation: `cv_62650b86741eeb17`
- unmounted conversation: `cv_186a37a8eb990c94`
- gone conversation: `cv_6ebd512b02493b36`
- ordinary directory: `/private/tmp/anselm-edge264-ordinary-v4`
- fixed frame: `EDGE-264-not-a-git-menu-fixed.jpeg`

## Stop-and-fix

后端原有契约已经把未挂载、路径消失、普通目录、无 Git 二进制四种环境形态统一为
`CONVERSATION_WORK_DIR_NOT_GIT_REPO`，写动作不会静默成功。真实 App 首次观察普通目录时发现产品
可发现性不足：菜单直接省略 Git 区域，用户无法知道这是“不支持”还是“没加载完”。因此没有放出
任何假操作，而是增加只读状态行 `Not a Git repository` 与短提示 `Choose a repo`；截图复验确认提示
在菜单中完整显示。

## Result

三种 HTTP 可见状态分别执行 `switch-branch`、`create-branch`、`add-worktree`，九次请求均为 HTTP
`422 CONVERSATION_WORK_DIR_NOT_GIT_REPO`，且没有创建分支、worktree、marker 或改变 residency。
第四种无 Git 可执行文件由 `TestGitActions_NoGitBinaryUsesTheSameAnswer` 在真实进程中以空 `PATH`
覆盖，三个写动作同样返回该领域错误。读侧仍成功返回诚实的 `isGitRepo=false` 投影。

## 五通道

- frame: Computer Use 打开真实 App 菜单；最终截图显示 Git 状态与完整下一步提示，无裁切或重排。
- backend: 真实 sidecar 健康，日志无 panic/fatal/unmapped/application error。
- SSE: 三路 resident stream 全部连接；通知流收到三条测试对话及驻地信号，无虚假 Git mutation。
- frontend: 只有已知 macOS IMK 平台诊断，无 Dart/Flutter/RenderFlex/overflow/Unhandled 应用红线。
- LLM wire: 受管网关的 challenge/install/models 通过 `llmtap`，无绕过记录。

`rig-check` 在 App、SSE、backend、llmtap、录屏全部存活时通过；`rig-down` 正常收台并回收导演器
持有的进程。

## 五级判定

- L2 `F2`：三态 HTTP 真值、无 Git 二进制 focused 真进程测试与菜单状态一致。
- L3 `B2`：菜单稳定地解释不可用状态，并给出选择仓库这一明确下一步。
- L4 `C5`：短提示在固定菜单次级栏完整显示，没有省略号、溢出或布局跳变。
- L5 `G1`：用户不需要知道 Git 内部或验收台架，就能理解为什么没有分支/worktree，并知道如何恢复。
