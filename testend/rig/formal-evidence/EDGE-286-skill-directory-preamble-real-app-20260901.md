# EDGE-286 · skill 目录前导兜底

## 现场

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-123754`
- 真实 App: macOS debug bundle，Library 中实际打开 `edge286-bundle`
- workspace/data: `ws_ddc63bb0b75fca69` / `/private/tmp/anselm-edge286-data`
- 录像: `screen.mov`, 61.950000s；五通道由同一 conductor manifest 归属

## 操作与结果

1. 通过真实 sidecar API 创建 `edge286-bundle`，正文为 `Use references/notes.md before answering.`，不含 `${CLAUDE_SKILL_DIR}`。
2. 通过真实 files API 写入 `references/notes.md`，响应 `204`；文件清单真实返回 `SKILL.md` 与 `references/notes.md` 两个文件。
3. 用正确的原样路径 `POST /api/v1/skills/edge286-bundle:activate` 激活，响应 `200`，渲染文本以一行
   `This skill's directory (its bundled files live here): <absolute skill dir>` 开始，随后是原正文；没有重复占位符，也没有丢失正文。
4. 真实 App Library 读取同一 workspace，显示 `2 files`、`SKILL.md`、`references/` 和 `notes.md`，skill 标题/描述/正文一致。

现场早期两次错误请求使用了 zsh 的 `$SKILL:activate` 展开，实际 URL 被改写为错误路径并得到 `301/404`；这是台架命令插值错误，不是产品请求，已更正为 `${SKILL}:activate` 后以原样 URL 重跑并取得上述 `200`，不纳入产品裁决。

## 五通道交叉证据

- channel 1: `screen.mov` 已封口，真实 App 从启动到 Library 文件树展示均在录制区域内。
- channel 2: `backend.log` 记录真实 skill 创建、附属文件写入、正确 `:activate` `200` 及 Library 读取；无 `ERROR`、`WARN`、`panic`。
- channel 3: `sse.jsonl` 记录同一 workspace 的 entities、notifications、messages 三流连接及正常断开。
- channel 4: `frontend.log` 记录真实 macOS App PID；无 `FlutterError`、`DartError`、`RenderFlex`、`RenderBox` 或未处理异常。
- channel 5: `llm.jsonl` 记录真实 managed gateway challenge/install/models wiring，均为 `200`；本场景没有模型调用，不伪造聊天 wire 证据。
- `rig-check.sh` 通过五通道归属；`rig-down.sh` 正常收台并封存录像，owned processes 已收尸。

## 判定

- L1=`H1`: 已有 focused 测试确认单文件不加前导、带捆绑文件且未写占位符时添加一次目录前导，`${CLAUDE_SKILL_DIR}` 路径则替换且不重复。
- L2=`F2`: 真实 App、sidecar、三路 SSE witness、LLM tap 和窗口录屏同场，正确激活响应与 Library 文件树均与文件真相一致。
- L3=`~`: 本条验证的是激活文本投影，没有独立可测的用户等待或动画路径；激活交互顺滑度由 skill/chat 条目覆盖。
- L4=`~`: 目录前导是注入给模型的文本，不产生独立视觉组件；Library 文件树仅作实体存在性证据，视觉 craft 由 Library/editor 条目覆盖。
- L5=`~`: 本条没有独立用户入口或发现性决策；skill 的入口发现由 catalog/mention 条目覆盖。

未改阈值、法典、锚点、五级标准或顺序 gate。
