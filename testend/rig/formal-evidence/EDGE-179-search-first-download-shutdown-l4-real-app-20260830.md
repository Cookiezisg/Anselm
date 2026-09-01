# EDGE-179｜首用下载途中关停｜L4 真实 App 视觉收口（2026-08-30）

## 判定

`L4 通过`，依据 `CODEX.md` 的 `C4`，并以 `A4` 错误门的真实稳定画面作为视觉对象。L3 的状态转移与本格的 craft 分开判定。

## 视觉证据

- 正式 session：`/private/tmp/anselm-rig-formal-20260801-6/sessions/20260830-214132`
- 稳定关键帧：`sessions/20260830-214132/frames-edge179-l4/stable-error-75s.png`
- 录屏：`screen.mov`=`3104x1844 / 60fps / 85.275s`
- 关停后的 `67s..80s` 区间抽取 `13` 张 1fps 帧，在内容 ROI=`200,150,2700,1500` 执行 `testend/cmd/measure diff -threshold 0.0005`，无变化输出；稳定错误门没有晚到重排、闪烁或漂移

逐帧复核确认：

- 错误图标、标题、说明和 `Retry` 组成单一垂直层级，整体居中，留白均匀
- 标题和提示换行稳定，没有截断、重叠、按钮位移或二次 reflow
- 正常 Chat 被整面替换，不留下旧 Composer、SSE loading 或半壳元素
- `Retry` 作为唯一明确的下一步，尺寸、圆角、颜色和文字对齐符合既有按钮系统
- 未见错误状态与普通内容卡片混用造成的层级误读

## 量化检查

使用 `testend/cmd/measure contrast`：

- 正文 `#1C1C1E` / 白底：`17.01:1`，达到 WCAG AA normal `4.5:1` 与 AAA `7:1`
- fatal 图标 `#D70015` / 白底：`5.38:1`，达到 AA normal `4.5:1`
- `Retry` 白字 / `#0071E3`：`4.70:1`，达到 AA normal `4.5:1`

## 五通道边界

同一 manifest 下的 backend、三路 SSE、frontend console、managed gateway wire 和录屏均已封存；frontend console 在检测窗口内仅有有限的连接拒绝，5 秒后不再增长，无 Flutter/Dart/RenderFlex/Unhandled 应用红线。L4 只评价稳定错误门的视觉 craft，不把未执行聊天请求冒充为 LLM 业务证据。

## 结论

错误门的信息层级、几何、间距、对比度和稳定性均通过；L5 仍需独立验证用户从零能否发现并理解这条反馈。
