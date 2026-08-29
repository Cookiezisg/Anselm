# EDGE-316 行内代码 CJK 断盒：L3 真实 App 逐帧证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-231212`
- data: `/private/tmp/anselm-data-edge316-physical-20260828-r1`
- workspace: `ws_896c9b8c0a5f48aa`
- recording: `screen.mov`, `98.760000s`, `2784x1808`, `60fps`
- L2 foundation: `testend/rig/formal-evidence/EDGE-316-inline-code-cjk-real-app-20260828.md`
- stable frames: `EDGE-316-l3-cjk-inline-code-stable.png`, `EDGE-316-l3-cjk-inline-code-rest-stable.png`, `EDGE-316-l3-cjk-inline-code-reopened-stable.png`

## Product path

真实 App 打开包含中文行内代码 `中文注释：计算总数并返回结果` 的文档，观察代码灰底的首次呈现和稳定态；离开文档，再重新打开并观察恢复态。目标是确认用户在阅读和重开后不会看到 script-run 之间的断盒、白缝、文字遮挡或背景粘连。

## Frame review and measurement

录屏抽取为 1fps，并对内容区域使用 ROI `900,500,1250,320`，通道容差为 8、阈值为 `0.0005`。测量结果：

- 首次打开内容的 `000033→000034` 为 `changedFrac=0.06979`，变化覆盖目标文档区域，是用户打开文档后的内容首次出现。
- 离开文档的 `000078→000079` 为 `0.06982`；重新打开的 `000079→000080` 为 `0.01144`、`000080→000081` 为 `0.06721`，均发生在用户导航/重开窗口，不是静止期自发重排。
- `000034`、`000050`、`000081` 稳定帧显示同一行内代码灰底完整包住中文文本，左右普通中文保持清晰；跨 CJK script-run 没有白缝或灰底断裂。文档重开后仍为 `44 chars`、`130 B`。
- 录屏中没有进入稳定状态后持续超过阈值的内容区变化，没有发现背景晚到、文字跳位、前后文被覆盖或行内代码宽度二次抖动。

本格把打开/离开/重开造成的内容切换与稳定态动态分开判断；没有把合法的用户导航 diff 误报成 B2 缺陷。

## Five-channel cross-check

- **frames / Computer Use**: 真实 App 打开、离开、重开均在连续录屏中；稳定帧已封存，视觉与 AX 文本一致。
- **backend**: journal `181` 行；fixture 和重开后的文档内容一致，无应用级 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- **SSE**: messages/entities/notifications 三流均连接；notifications durable `seq=16` 为 document.created，单调且无 gap；收台 EOF 由 conductor 主动关闭。
- **frontend console**: `3` 行；无 Flutter/Dart、RenderFlex/RenderBox、overflow、Unhandled 或应用异常。
- **LLM wire**: llmtap proof challenge/install/models 全部 HTTP `200`；本格是本地文档视觉路径，不伪造 completion。
- **rig lifecycle**: startup gate 确认屏幕权限、backend health、ssetap、App 和录屏均启动；`rig-down.sh` 正常封口且无残留。

## Judgment boundary

- **L3 `pass (B2)`**：行内 CJK 灰底在首次出现、稳定阅读和重开恢复后保持连续，用户导航造成的整块 diff 不构成非用户跳变。
- 本证据只覆盖动态稳定性；视觉 craft 的更高要求和从零盲走可发现性不冒充 L4/L5，L4/L5 保持 `na`。
