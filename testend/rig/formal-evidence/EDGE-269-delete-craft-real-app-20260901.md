# EDGE-269 L4 · 驻地分组批量删除范围 · 真实 App

## 视觉证据

证据来自同一真实 App 录屏的动作帧：

- `/private/tmp/edge269-measure-frames/f-0096.png`：确认框稳定可读。
- `/private/tmp/edge269-measure-frames/f-0097.png`：确认动作刚开始，界面仍保持完整层次。
- `/private/tmp/edge269-measure-frames/f-0098.png`：单次模态退出转场。
- `/private/tmp/edge269-measure-frames/f-0104.png`：最终稳定 Chat。

确认框的标题、线程数量、驻地名称、永久删除语义、磁盘不受影响语义和置顶例外均清晰分层；`Cancel` 与红色 `Delete all` 视觉角色明确，没有裁切、重叠或低对比度文字。背景被正确压暗，确认动作不会误把“删除驻地目录”混入用户心智模型。

最终状态只保留置顶 survivor、Recents 和其他正常导航内容。目标组消失后没有空组标题、重复线程、陈旧计数、空白主面板或加载残影；主区域的 composer 和 Chat 空态保持规整。

## 判定

`C4` pass：确认层级、危险色、文案边界、间距与最终落地状态形成一致的视觉语言；没有发现需要 stop-and-fix 的逐帧 craft 问题。
