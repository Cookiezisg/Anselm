# EDGE-341 · 未验证供应商诚实徽标 · real App L4

## 现场与证据

- session=`/private/tmp/anselm-rig-formal-20260902-07/sessions/20260902-012607`
- 录屏：`screen.mov`，`3104x1848 / 60fps / 90.246667s`。
- 目录代表帧：`evidence/edge341-2fps/frame-0041.png`；动作接触表：
  `evidence/edge341-contact.png`、`evidence/edge341-action-contact.png`。
- 保存与失败代表帧：`evidence/edge341-save60/frame-0157.png`；保存状态帧
  `frame-0140.png` 显示 `Saving & probing…` 和 spinner。

## L4 判定（C4）

供应商目录使用统一的双列卡片：供应商身份、模型数量和 `Untested` 徽标保持一致的
垂直节奏，卡片等高、圆角和内边距统一。进入 302.AI 后，名称、Key、Base URL 和动作
区仍按同一表单网格排列；探针失败增加说明时，字段没有跳列，错误没有遮住按钮。

逐帧复核确认：

- 目录卡片的徽标颜色、形状、字号层级一致，供应商名与模型数没有被徽标挤压或裁切；
- 保存中状态只在动作区增加 spinner/状态文字，未引起整页闪烁或字段高度变化；
- 失败反馈按“保存结果 → 原始探针事实 → 未验证供应商诊断”分层，长文案在表单宽度内
  自然换行，未出现重叠、截断或持续 reflow；
- Save & test 仍保持可重试，Cancel 的相对位置稳定。

动作区局部差分（每通道容差 8）仅报告表单区域：

- `frame-0141→0142` changedFrac=`0.00730`，框=`(1200,856)-(1681,912)`；
- `frame-0143→0144` changedFrac=`0.00246`，框=`(1234,524)-(1446,896)`；
- `frame-0156→0157` changedFrac=`0.01670`，框=`(1200,538)-(2156,1128)`。

没有发现需要 stop-and-fix 的布局或视觉缺陷。本记录只评价当前真实 App 的 craft，
不把后端 422 冒充成功。

## 五通道

- 帧：连续 `screen.mov`、目录/动作抽帧与最终稳定帧。
- backend：真实 302.AI key 创建 `201`、探针 `422`，反馈与持久事实一致。
- SSE：messages/entities/notifications 三流连接并正常收台；本设置场景无 durable 业务帧。
- frontend：无 Dart/Flutter/RenderFlex/overflow/Unhandled/Exception 应用级红线；macOS
  IMK 提示已分类为宿主噪声。
- LLM wire：managed challenge/install/models/quota=`200`，无 completion 需求。
