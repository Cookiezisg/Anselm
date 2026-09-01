# EDGE-178 · 搜索 embedder 缺席降级 · L4 真实 App craft 证据

## 结论

`pass`，依据 CODEX `C4`。本格只评价 fallback 用户路径在真实 Chat 中的可见呈现，不把没有
search/embedder Settings 控件的事实改写成视觉通过，也不把 L4 扩张为 L5 discoverability。

## Session 与范围

- Formal session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-205857`
- Screen recording: `screen.mov`, `3104x1844`, `60fps`, `171.086667s`
- Workspace: `ws_8e2b400de75043d1`
- Stable frame set: `sessions/20260830-205857/evidence/EDGE-178-l3-stable-frames/`
- L2 数据真相证据: `testend/rig/formal-evidence/EDGE-178-search-embedder-off-fallback-l2-real-app-20260830.md`
- L3 动态证据: `testend/rig/formal-evidence/EDGE-178-search-embedder-off-fallback-l3-real-app-20260830.md`

## 真实产品画面复核

1. Computer Use 在真实 App 发送词法 fallback 请求并等待真实工具链完成。最终 transcript 保留
   用户问题、助手的事实边界、三段编号解释、代码样式 token 和结论；没有裸 JSON、原始异常或
   中间 tool payload 泄漏到默认用户呈现。
2. 稳定尾段的代表帧显示：正文阅读列有明确的标题/正文/列表层级，列表缩进和行间距连续，
   `search_documents` 等工具名以统一的行内 code 胶囊呈现；正文没有被侧栏、Composer 或滚动
   条覆盖。长标题在顶栏按既有单行省略收束，不把导航高度撑破。
3. 三岛壳层的 island/card/pill 圆角层级、内缩和细边界在稳定帧中保持一致；Composer 仍为统一
   胶囊形状，发送/语音入口与输入基线对齐。未发现 clipping、重叠、残留 loading、非用户重排
   或因 fallback 结果引入的额外视觉噪声。
4. 以上判断由 `f000001..f000032` 稳定帧复读支持；同一 ROI 的 `measure diff` 在阈值 `0.0005`
   下无输出。动态变化已由 L3 单独测量，不用稳定段零 diff 冒充 craft 数字。

## 五通道交叉证据

- **frames / Computer Use**: 真实 onboarding、发送、工具链和最终 Chat 画面来自窗口 `8651`
  的绑定录屏；稳定帧已复制进 session evidence。
- **REST/DB**: fixture、`embedder=off`、唯一搜索命中和 `read_document` 结果与 L2 证据一致；
  视觉复核没有把模型自述当作数据真相。
- **SSE**: 同一 session 的 messages durable `1..33`、notifications `1..3` 单调，无 gap；
  三流连接生命周期完整。
- **Backend / frontend**: backend `271` 行、frontend `5` 行；无应用级 panic、Flutter/Dart、
  RenderFlex、RenderBox、Unhandled 或异常红线。已知 macOS IMK 宿主诊断已在 L2/L3 证据中披露。
- **LLM wire**: llmtap `28` 条，challenge/install/models 与四次 streamed chat completion 均为
  HTTP `200`；工具链和最终呈现属于同一次 managed gateway 交互。

## Judgment boundary

- **L4 `pass (C4)`**：真实 Chat 结果的几何层级、圆角/内缩、文本与 code token 呈现一致，长标题
  收束不破坏布局；没有 clipping、overlap、残留忙态或 fallback 专属视觉噪声。
- 这不是 search/embedder 设置入口的评价。当前 Settings 没有该面板，用户从零发现并理解语义
  搜索缺席的 L5 仍开放；L5 不得由本证据代填。
