# EDGE-314 编辑器唯一光标：L5 取证场无效记录

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-203233`
- result: **invalid, not judged, not counted**

本场普通用户编辑路径本身完成了代码块与表格之间的焦点切换，但收尾阶段使用了
Computer Use 的 `select_text`/`set_value` 语义桥清理临时字符。最后截图和 AX 文本显示代码为
`var x = 1;`，而封口后同一 session 的 SQLite 文档实际为 `var x Y 1;`。这证明该清理动作
没有形成可接受的 durable 证据，不能写入 L5，也不能把它当作产品通过或产品缺陷。

处置：丢弃本场 L5 证据，不写 `judge.py`，不推进批次；使用干净 fixture 以真实字符输入和原位
`BackSpace` 重跑，并在收台后以 SQLite/REST 复核 UI 最终状态。
