# EDGE-320 skill 双写者竞态：L5 真实 App 可发现性证据

## User goal

普通用户目标是：在 Library 找到一个 Skill，修改正文和可调用参数，离开页面后再次回来确认修改仍然存在。
本判定不要求用户知道“600ms 防抖”“双写者”或任何内部实现术语。

## Real App path

真实 session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-213424`。从 Library 的 Skills
列表选择 `edge320-race` 后，中心自然展示正文编辑区，右侧明确展示 `Properties`、`Arguments` 和
`Add an argument`；正文可直接点击键入，参数可直接输入并回车成为 chip。离开到另一个 Skill 后再返回，
用户无需刷新、命令或内部知识即可看到正文 `BODYCLEANX` 和参数 `cleanarg`、`racearg` 均保留。

## Judgment

路径从用户可见的 Library/Skills 入口开始，编辑目标和结果反馈均在界面中可见；返回后状态可复核，用户
可以完成目标而不会误以为只保存了一侧。Properties 的层级标签和 Arguments 的添加/删除 affordance
足够直接，未发现需要额外帮助、tooltip 或隐式操作才能完成任务的阻塞。L5=`G1`。

证据现场与 L4 共用同一 owned session，但本格只引用普通用户目标与可发现性，不将内部实现或模型
wire 当作发现性证据：`testend/rig/formal-evidence/EDGE-320-skill-dual-writer-window-l4-real-app-20260901.md`。
