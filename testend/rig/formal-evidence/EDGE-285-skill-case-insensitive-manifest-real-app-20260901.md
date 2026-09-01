# EDGE-285 · 大小写不敏感 FS 上的 skill.md

## 现场

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-123103`
- 真实 App: macOS debug bundle，Library 中实际打开 `edge285-casefold`
- workspace/data: `ws_352b0d50478cf0ef` / `/private/tmp/anselm-edge285-data`
- 录像: `screen.mov`, 77.006667s；五通道由同一 conductor manifest 归属

## 操作与结果

1. 通过真实 sidecar API 创建 skill，平台先生成 `SKILL.md`。
2. 在隔离 workspace 的实际 skill 目录把文件名改为小写 `skill.md`，模拟 macOS 默认大小写不敏感文件系统上的存量文件。
3. 经真实 App 所接 sidecar 的 `PUT /api/v1/skills/edge285-casefold/files/SKILL.md` 写入新 manifest，响应 `204`。
4. 物理检查显示目录只有一个文件项 `skill.md`；大小写路径 `SKILL.md` 与 `skill.md` 解析到同一 inode，`same_inode=true`，没有被清理逻辑误删。
5. `GET /api/v1/skills/edge285-casefold/files/SKILL.md` 返回 `200`，正文为新 description/body；真实 App Library 中标题、描述和正文均同步显示新内容。

## 五通道交叉证据

- channel 1: `screen.mov` 已封口，真实 App 从启动到 Library 展示均在录制区域内。
- channel 2: `backend.log` 含真实 `GET /skills/.../files`、`GET /skills/...` 请求；无 `ERROR`、`WARN`、`panic`。
- channel 3: `sse.jsonl` 记录同一 workspace 的 entities、notifications、messages 三流连接，以及 `skill.created`/`skill.updated` durable signal（seq 16/17）。
- channel 4: `frontend.log` 记录真实 macOS App PID；无 `FlutterError`、`DartError`、`RenderFlex`、`RenderBox` 或未处理异常。
- channel 5: `llm.jsonl` 记录真实 managed gateway challenge/install/models wiring，均为 `200`；本场景无模型调用，不能伪造聊天 wire 证据。
- `rig-check.sh` 通过五通道归属；`rig-down.sh` 正常收台并封存录像，owned processes 已收尸。

## 判定

- L1=`F1`: manifest 的大小写差异不改变结构化 skill 真相；已有 focused evidence 保留。
- L2=`F2`: 真实 App/sidecar/SSE/LLM tap/录屏 session 完整，写回后文件与 UI 真相一致。
- L3=`~`: 本条验证的是 macOS 文件系统大小写与 manifest 持久化边界，没有独立的用户交互等待或动画路径；编辑体验由其他 skill files/editor 条目覆盖。
- L4=`~`: 本条不产生独立视觉组件；Library 展示已作为持久化交叉证据观察，视觉 craft 由其他 Library/editor 条目覆盖。
- L5=`~`: 本条没有独立用户入口或发现性决策；大小写兼容性由平台写入内部保证，入口可发现性由 skill/files 条目覆盖。

未改阈值、法典、锚点、五级标准或顺序 gate。
