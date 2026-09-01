# EDGE-282 · skill 本地改动漂移：真实 App 修复后验收

- 日期：2026-09-01
- 现场：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-114010`
- 结论：已安装 skill 的本地改动被明确保护；用户确认后强制更新，文件恢复为上游版本。

## 现场事实

- 真实 App、conductor-owned backend、三路 SSE witness、LLM tap、frontend console 和窗口录屏属于同一 session；
  `rig-check.sh` 通过，`rig-down.sh` 已封存录屏并收尸 owned processes。
- 通过同场 REST 安装本机 HTTP 来源 `edge282`，随后直接在该 session 的 workspace skill 目录修改
  `scripts/check.py` 为 `print("local edit")`；GET 读取确认本地改动存在。
- Computer Use 打开 `Library → edge282`，点击 `Check for updates`。真实 App 展示确认框：
  `Local edits exist — updating will overwrite them. Force update?`，同时提供 `Cancel` 和
  `Force update`，没有静默覆盖。
- 点击 `Force update` 后 App 显示 `Updated to the upstream version`；同场 REST 再读
  `scripts/check.py` 得 `print("upstream")`，与来源归档内容一致。本地改动未在用户确认前丢失。
- 稳定帧=`sessions/20260901-114010/evidence/edge282-local-drift-dialog.jpeg`；成功帧=
  `sessions/20260901-114010/evidence/edge282-force-update-success.jpeg`。两帧均无裁切、重叠、
  空白、持续 loading 或错误页。

## 五通道核对

- 帧：冲突确认框的警告、取消与强制更新动作完整可读；成功 toast 与恢复后的 skill 详情可见。
- 后端：同场安装、文件修改后的读取、更新和更新后读取均有 backend journal；更新成功且无
  panic/fatal/应用级错误。
- SSE：同场 `entities`、`messages`、`notifications` 三流真实连接并留有 journal；skill
  更新通知与最终实体状态可追溯。
- 前端：`frontend.log` 无 Dart/Flutter/RenderFlex/RenderBox/Unhandled 应用异常。
- LLM：`llm.jsonl` 由透明 tap 持有；本场以 REST/Library 更新路径为主，不把无关的模型调用冒充
  产品证据。

## 修复与回归

- 冲突确认框是用户可见的产品保护：本地编辑存在时不自动覆盖，必须由用户选择 `Force update`。
- 更新成功后的文件由 REST 直接读取核对，而不是只依据 toast；上游来源与最终文件内容一致。
- 录屏、backend/SSE/frontend/LLM 五类 journal 与 session manifest 均由台架封口；源码 focused
  回归和文档同步在本格判定前保持通过。

## 判定映射

- L2 `F2`：同场真实 UI、后端、SSE、前端 console、LLM wire 和封口录屏均可追溯。
- L3 `B2`：本地漂移被发现后，更新流程在同一上下文内明确停住并等待选择，确认后单向收敛到上游，
  无静默覆盖、重复更新或卡死。
- L4 `C4`：警告文本、危险动作和取消动作有清晰层级；成功反馈与恢复后的内容一致，稳定帧可复核。
- L5 `G1`：用户无需理解文件校验或内部状态，只需看到“本地编辑将被覆盖”的明确提示即可做出安全
  决策；更新完成后有直接成功反馈。
