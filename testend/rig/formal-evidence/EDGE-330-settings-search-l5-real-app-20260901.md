# EDGE-330 设置项搜索索引漂移：L5 真实 App 可发现性证据

- session: `/private/tmp/anselm-rig-formal-20260901-13/sessions/20260901-232852`
- recording: `screen.mov`, `84.398333s`
- law: `G1`（普通用户路径可发现）
- verdict: `pass` for L5

## Ordinary user path

用户目标是“找到重置缩放的快捷键设置”，不使用 anchor、panel enum、widget 名称或任何内部 ID。真实 App 的底部齿轮入口表达 Settings；进入后搜索框有可读 placeholder `Search settings...`，用户输入 `zoom` 后立即看到按 `General`、`Storage & logs`、`Shortcuts` 分组的结果，其中 `Reset zoom` 语义明确。

点击 `Reset zoom` 后，App 自动跳到 Shortcuts 面板并洗亮目标行，搜索框清空；用户能直接判断自己已经到达正确设置，而不是停留在搜索结果列表。输入不可能命中的词时只显示 `No matching settings`，清空后恢复完整目录，空结果、恢复动作和入口含义都没有依赖工程知识。

## Five-channel cross-check

- **frames / Computer Use**: 真实 App 录屏覆盖 Settings 入口、可读搜索 placeholder、`zoom` 分组结果、目标跳转、无匹配和清空恢复；AX 同时确认对应文本。
- **backend**: `backend.log` 共 `338` 行，无应用级 `WARN`、`ERROR`、`panic` 或 `fatal`。
- **SSE**: `sse.jsonl` 共 `8` 帧，`entities`、`messages`、`notifications` 三流各真实连接；本路径无业务 durable 事件。
- **frontend console**: `frontend.log` 共 `5` 行；无 Flutter/Dart、RenderFlex、RenderBox、Unhandled、Exception 或 overflow 错误，已知 macOS 输入法宿主诊断原样保留。
- **LLM wire**: managed gateway challenge/install/models 均为 `200`；设置搜索不调用模型，未出现多余 completion。
- **durable truth**: 搜索/跳转只改变前端 settings panel 与一次性 wash，不创建对话、消息或实体；画面与产品状态边界一致。
- **rig lifecycle**: `rig-check.sh` 操作前全项通过，`rig-down.sh` 正常封口并回收 conductor-owned 进程，五通道日志和录屏完整。

## Verdict

`L5 pass (G1)`。普通用户可以从可读入口进入设置、搜索、理解分组结果并定位目标项；本格只结算可发现性，不重复结算 L3 时延和 L4 craft。
