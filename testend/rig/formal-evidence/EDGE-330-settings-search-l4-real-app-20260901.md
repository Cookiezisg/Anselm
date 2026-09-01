# EDGE-330 设置项搜索索引漂移：L4 真实 App 视觉 craft 证据

- session: `/private/tmp/anselm-rig-formal-20260901-13/sessions/20260901-232852`
- representative frame: `/private/tmp/anselm-rig-formal-20260901-13/sessions/20260901-232852/evidence/edge330-l3-frames-late/frame-0900.png`
- contact sheet: `/private/tmp/anselm-rig-formal-20260901-13/sessions/20260901-232852/evidence/edge330-l3-contact-late.jpg`
- law: `C4`（圆角与视觉尺度阶梯）
- verdict: `pass` for L4

## Visual craft review

真实 App 的设置搜索结果保持明确的三层关系：左侧搜索框、按 panel 分组的结果列表、右侧被定位的设置面板。结果组标题、条目文本和快捷键 chip 的层级清楚，行高一致，列表没有因 query 变化产生挤压或重叠。

点击 `Reset zoom` 后，搜索框回到 placeholder，Shortcuts 面板标题和设置行落在同一稳定几何中；目标行的浅蓝 wash 覆盖整行、圆角与行容器协调，快捷键 chip 与文字基线对齐。稳定画面没有截断、溢出、白屏、旧 query、重复结果或残留旧面板。

对 `screen.mov` 的 `35s..65s` 窗口抽取 `900` 个 30fps 帧，在 `0,0,1440,800` ROI、逐通道容差 `8`、阈值 `0.001` 下，变化只出现在三个用户动作窗口：设置打开、输入 `zoom`、点击跳转；最后一个动作后没有非用户触发的连续变化。代表帧与 contact sheet 保留了目标行、面板头和完整导航，用于复查间距、圆角和对齐，而不是只看 AX 文本。

## Five-channel cross-check

- **frames / Computer Use**: 真实 App 逐帧覆盖完整目录、分组搜索结果、目标跳转洗亮、无匹配和清空恢复；代表帧显示设置行与快捷键 chip 的视觉成品。
- **backend**: `backend.log` 共 `338` 行，无 `WARN`、`ERROR`、`panic`、`fatal` 或应用级异常。
- **SSE**: `sse.jsonl` 共 `8` 帧，`entities`、`messages`、`notifications` 三流各真实连接；本前端只读路径无业务 durable 事件。
- **frontend console**: `frontend.log` 共 `5` 行；只有正常 Flutter VM 与已知 macOS 输入法宿主诊断，无 Flutter/Dart、RenderFlex、RenderBox、Unhandled、Exception 或 overflow。
- **LLM wire**: managed gateway challenge/install/models 均为 `200`；设置搜索没有 completion 请求。
- **durable truth**: 结果列表、目标面板和 wash 只来自同一 settings index/anchor 关系，不创建或修改消息与后端实体。
- **rig lifecycle**: 操作前 `rig-check.sh` 全项通过，`rig-down.sh` 封口并停止全部 conductor-owned 进程，录屏与 journals 完整保留。

## Verdict

`L4 pass (C4)`。设置搜索的结果层级、行几何、洗亮容器、快捷键 chip 对齐和稳定尾帧达到视觉 craft bar；本格不重复结算 L3 时延或 L5 发现性。
