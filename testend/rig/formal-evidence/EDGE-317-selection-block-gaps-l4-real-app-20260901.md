# EDGE-317 选区跨块缝隙：L4 真实 App 视觉 craft

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-210113`
- data: `/private/tmp/anselm-data-edge317-l4-20260901.u3vsRt`
- result: **pass (C1)**
- recording: `screen.mov`, `72.976667s`, 60fps
- stable frames: `/private/tmp/edge317-l4-frames-20260901.sZthLs/f0042.png`,
  `/private/tmp/edge317-l4-frames-20260901.sZthLs/f0066.png`

## Product path

从 Library 打开 `EDGE-317 正式多块选区夹具`，在正文第一段建立焦点，以 `Home` 后连续三次
`Shift+Down` 跨越三段内容和块间留白；等待稳定后离开文档，再从 Library 重新打开。该路径
模拟用户跨段复制、格式化或阅读时选择连续内容的真实操作。

## Visual craft judgment

稳定选区帧显示蓝色选区从第一段连续桥接到第二、第三段，块间 padding 没有白色断带；首段和中段
的选区高度一致，末段按真实文本宽度自然收束。浮动格式条位于选区下方，层级清楚且没有遮挡
选中文本；重新打开后的正文结构、段落间距和右侧 inspector 与进入前一致，清除选区后没有残留
蓝块、重排或内容位移。

`measure regions` 对稳定选区帧以目标色 `#cde0f8`、容差 `24`、最小区域 `16` 检出主连续组件
`x=880,y=530,w=540,h=216,pixels=69752`，覆盖三段选区和块间桥接；没有被间隙分裂成多个主组件。
这满足 CODEX `C1` 的等高连续律，也满足用户对“滑一下，高亮应当舒服且连续”的产品要求。

## Frame measurement

以内容 ROI `900,450,1500,900`、每通道容差 8、阈值 `0.0005` 抽取 1fps 进行 diff。变化仅出现在
真实打开、跨块选择、离开和重开动作窗口：

- `f0015→f0016`: `changedFrac=0.02152`，文档打开后的内容呈现。
- `f0040→f0041`: `changedFrac=0.07142`，跨块选择动作。
- `f0041→f0042`: `changedFrac=0.00248`，选区稳定化的局部变化。
- `f0064→f0065`: `changedFrac=0.07860`，离开/重开过程的内容切换。
- `f0065→f0066`: `changedFrac=0.01764`，重开后的局部恢复。

稳定段没有未归因的持续 ROI 变化；用户主动选择造成的变化没有被误判为非用户跳变。

## Five-channel and durable evidence

- **frames / Computer Use**: 真实 Library 打开、建立焦点、`Home`、三次 `Shift+Down`、离开、重开均在录屏中。
- **backend**: journal `283` 行，无应用级 WARN、ERROR、panic 或 fatal。
- **SSE**: ssetap 记录三路 `notifications`、`entities`、`messages` 连接，共 `8` 行；收台 EOF 为主动断开。
- **frontend**: journal `5` 行，无 Flutter、RenderFlex、Unhandled 或应用级异常；仅有已分类 macOS IMK 宿主诊断。
- **LLM wire**: llmtap `1` 行；本地 Library 选择不触发 completion，未把空 wire 当作模型证据。
- **durable truth**: SQLite 文档内容保持三段原文，`length(content)=46`、`size_bytes=124`，未发生选择或重开破坏。
- **rig lifecycle**: `rig-check.sh` 五通道通过，`rig-down.sh` 封口录屏并收台全部 owned processes。

## Verdict

L4 通过 `C1`。判定同时依赖真实选区稳定帧、连续区域测量、重开后结构、durable 原文和五通道健康，
不是用既有 L3 证据或单元测试替代真实 App craft 验收。
