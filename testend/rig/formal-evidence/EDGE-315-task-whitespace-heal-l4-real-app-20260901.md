# EDGE-315 空 task 尾空格腐化：L4 真实 App 视觉 craft

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-204203`
- result: **pass (C4)**
- recording: `screen.mov`, `70.660000s`, 60fps
- frame samples: `/private/tmp/edge315-l4-frames-20260901.QOeyek/f0018.png`, `f0049.png`, `f0056.png`, `f0071.png`
- measured action windows: `f0017→f0018 changedFrac=0.01825 box=(152,92)-(2980,1689)`;
  `f0048→f0049 changedFrac=0.02185 box=(152,156)-(2934,893)`;
  `f0055→f0056 changedFrac=0.02185 box=(152,156)-(2934,893)`

## Product path

从 Library 打开 `EDGE-315 task fixture`，在三个待办行中定位中间的空 task。先在空行输入
`temp`，再立即连续按四次 BackSpace 清空；随后离开文档，再重新打开同一文档验证 round-trip。
这是普通用户维护待办清单的真实 App 路径，不依赖内部 markdown 或修复函数名称。

## Visual craft judgment

输入和清空只发生在对应动作窗口；稳定帧中三行 checkbox 保持同一 x 对齐和相同的行高，空的中间行
仍保留可编辑的行结构，不塌陷、不产生额外空行。离开并重开后，首行、中间空行、末行的垂直节奏不变，
没有字面量 `[ ]`、checkbox 位移、行高漂移、行合并、重复空行或右侧 inspector 的布局跳变。
这满足 CODEX `C4` 的几何尺度与同心布局要求；本项关注的是空 task 的结构恢复后仍然具有稳定、
可读、可继续编辑的视觉形态，而不是只验证字符串被保存。

## Five-channel and durable evidence

- **frames / Computer Use**: 真实打开、输入、原位清空、离开、重开均在录屏中；稳定收尾帧为 `f0071.png`。
- **backend**: journal `280` 行，无应用级 WARN、ERROR、panic 或 fatal。
- **SSE**: ssetap 记录 `notifications`、`entities`、`messages` 三路连接，共 `10` 行。
- **frontend**: journal `5` 行，无 Flutter、RenderFlex、Unhandled 或应用级异常；仅有已分类 macOS IMK 宿主诊断。
- **LLM wire**: llmtap `1` 行；Library 编辑不触发 completion，记录为健康的空交互 wire，而非遗漏观测。
- **durable truth**: SQLite 最终正文精确为 `- [ ] first task\n- [ ] \n- [ ] last task`，共 `39` bytes，
  没有 `temp`、字面量 `[ ]` 或结构丢失。
- **rig lifecycle**: `rig-check.sh` 五通道通过，`rig-down.sh` 封口录屏并收台全部 owned processes。

## Verdict

L4 通过 `C4`。判断覆盖了真实用户动作、稳定视觉几何、离开重开后的可继续编辑形态，以及 durable
正文与观测通道的一致性；不以单元测试或单张静态截图替代真实 App 证据。
