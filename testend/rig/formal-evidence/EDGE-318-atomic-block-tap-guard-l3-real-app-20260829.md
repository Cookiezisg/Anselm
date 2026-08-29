# EDGE-318 原子块双/三击：L3 真实 App 逐帧证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-000303`
- data: `/tmp/anselm-data-edge318-physical-20260829-r1`
- workspace: `ws_7dab956978704245`
- recording: `screen.mov`, `777.831667s`, `2784x1808`, `60fps`
- L2 foundation: `testend/rig/formal-evidence/EDGE-318-atomic-block-tap-guard-real-app-20260829.md`
- stable frames: `EDGE-318-l3-initial-stable.png`, `EDGE-318-l3-code-selection-stable.png`, `EDGE-318-l3-table-selection-stable.png`, `EDGE-318-l3-divider-probe-stable.png`, `EDGE-318-l3-final-stable.png`

## Product path

真实 App 打开包含正文、可编辑 Dart 代码块、可编辑表格、水平分隔线和后续正文的文档。依次对代码块、表格和分隔线执行双击/三击后拖动；对分隔线做退格探针；随后离开并回到文档，确认所有编辑器仍可取得焦点并恢复到原始 fixture。

## Frame review and measurement

对 `screen.mov` 抽取全程 `1fps`，并用 `threshold=0.0005` 对文档内容 ROI `800,400,1500,1000` 复核。捕获到的代表性变化全部落在明确的用户动作窗口：

- 文档进入后的 `000039→000040=0.00527`、`000040→000041=0.05985` 是文档内容首次呈现。
- 代码块和表格的双/三击与拖动产生的局部变化，例如 `000059→000060=0.00455`、`000076→000077=0.00498`、`000136→000137=0.01477`、`000143→000144=0.01574`，均只发生在当前嵌入字段或其编辑区域。
- 分隔线探针附近的 `000156→000157=0.00114` 只落在分隔线/邻近编辑位置；没有删除相邻正文或把外层文档状态机带入错误态。
- 稳定帧显示：代码块内选词保持代码编辑器自己的选择反馈，表格单元格继续保持单元格编辑；分隔线探针后正文、代码块、表格和后续正文仍在原位。最终 `000778` 恢复态可见完整文档和可继续编辑的 caret。
- 录屏没有观察到点击或拖动后持续的视口跳变、overlay 残留、焦点丢失、第二个编辑 caret 或“点着点着鼠标失灵”。

本格 L3 只判断交互状态的动态收敛和恢复性。代码块/表格内部的整块蓝色高亮不是本场景的既定语义，分隔线 selection color 也为透明，因此不把不存在的视觉反馈冒充为通过。

## Five-channel cross-check

- **frames / Computer Use**: 双击、三击、拖动、退格、离开和返回均在连续录屏中；五张稳定状态帧已封存，无外部遮挡。
- **backend**: journal `883` 行；fixture 最终恢复为原始 `312 B`；无应用级 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- **SSE**: messages/entities/notifications 三流均连接；durable document created/updated 序列单调，无异常 gap；收台 EOF 由 conductor 主动关闭。
- **frontend console**: `5` 行；无 Flutter/Dart、RenderFlex/RenderBox、overflow、Unhandled 或应用异常；IMK 为已分类 macOS 宿主诊断。
- **LLM wire**: llmtap proof challenge/install/models 全部 HTTP `200`；本格是本地编辑器路径，不伪造 chat completion。
- **rig lifecycle**: startup gate、`rig-check` 和 `rig-down.sh` 均通过，App、backend、ssetap、llmtap、录屏归属一致，收台无残留。

## Judgment boundary

- **L3 `pass (B2)`**：原子块双/三击和拖动后的编辑状态稳定收敛，分隔线探针不破坏相邻内容，离开/返回后编辑器可继续工作。
- 本证据不宣称整块高亮的 craft，也不宣称从零路径的发现性；L4/L5 保持 `na`。
