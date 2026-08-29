# EDGE-318 · 原子块双/三击真实 App L2

## 场景与范围

- 独立正式台架 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-000303`
- 真实 App：`website.anselm.app`，直接 macOS 窗口录制，窗口 PID `16790`，录制窗口 `5826`
- 后端：PID `16268`，由 D1 归属检查锁定到 `:8742`
- 被测文档：`doc_b202c03c26a70ca4`，包含正文、可编辑 Dart 代码块、可编辑表格、水平分隔线和后续正文
- 原始夹具通过 REST 恢复后核对为 `312 B`；测试结束时未把探针编辑留在文档中

## 五通道观察

1. **Frame**：代码块内部双击选中的是代码词，符合嵌入式代码编辑器的产品语义；表格单元格由单元格编辑器接管。对代码块、表格和分隔线分别执行双击/三击后拖动，画面没有出现卡死、异常 overlay 或视口跳变。
2. **Backend journal**：测试期间没有应用级 `WARN`、`ERROR`、`panic` 或 `fatal`。
3. **SSE tap**：三条流均已连接；session 记录了文档建立以及恢复夹具产生的 durable `document.updated`，无异常断流。
4. **Frontend console**：没有 Flutter/Dart、RenderFlex、RenderBox、Unhandled 或 Exception 错误；仅有已知 macOS IMK 主机日志。
5. **LLM wire**：台架启动阶段 challenge/install/models 均为 HTTP 200；本场景不需要调用模型，未伪造模型成功证据。

## 行为判定

- 分隔线在双击/三击后拖动没有把上游 word/paragraph 状态机推入毒态；退格探针没有删除相邻正文，编辑器仍可继续取得焦点。
- 代码块和表格内部双击继续保留其有意设计的原生编辑行为，而不是错误地被外层文档整块选择吞掉。
- 本证据**不宣称**代码块或表格内部会出现整块蓝色高亮；它们的有效命中区由嵌入编辑器占用。水平分隔线的组件 selection color 为透明，截图也不能单独证明颜色反馈。
- 该格的 L2 判定仅覆盖“手势不毒化、拖动后可恢复、真实 App 五通道无错误”；整块选择的视觉反馈若未来成为独立产品要求，应另立可观测的交互契约。

## 证据文件

- `EDGE-318-restored-fixture.jpeg`
- `EDGE-318-after-atomic-probes.jpeg`
- `frontend/test/core/editor/an_editor_caret_test.dart`
- `frontend/test/core/editor/an_editor_table_test.dart`
- `testend/rig/rig-check.sh`：五通道均通过
- `testend/rig/rig-down.sh`：结束时封存录制生命周期

## 判定

- L1：`A5`，已有 focused/editor regression evidence
- L2：`A5`，真实 App + 五通道 session evidence
- L3-L5：`na`，本格不单独宣称动效、美学或新入口发现性
