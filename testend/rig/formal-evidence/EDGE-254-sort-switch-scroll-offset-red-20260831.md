# EDGE-254 · 排序切换保留旧滚动位置 · 红现场

## Session

- Formal session: `/private/tmp/anselm-rig-formal-20260831-15/sessions/20260831-195035`
- Recording: `screen.mov`，真实 macOS App，约 288 秒
- Fixture: 真实工作区中创建 60 条 `Sort Probe 01` … `Sort Probe 60` 对话，另含播种对话
- 五通道台架：backend journal、三路 SSE witness、Flutter console、LLM tap 均由该 session 的 manifest 归属

## Reproduction

1. 在真实 App 的对话 rail 打开 Display options，切换到 Name 排序。
2. 将 Name 排序列表滚动到中段/接近尾部。
3. 再切回 Recently active。

后端返回的 Recently active 顺序正确，但 App 没有把滚动位置重定到新轴的头部。Computer Use 截图中列表第一项为 `Sort Probe 47`（现场另一帧为 `Sort Probe 56`），而预期首屏应从最新项 `Sort Probe 60` 开始；画面仍处在旧 Name 轴的中段。

## 判定

这是一个真实的产品缺陷：排序轴已经改变，旧滚动偏移对新数据没有语义，导致用户看不到新排序的头部，违反“切换排序从头开始”的直觉和 EDGE-254 的 keyset 轴切换要求。问题归因于前端共享 `AnSidebarList` 保留了 `ScrollController` offset，而不是后端排序或游标复用错误。

本证据只记录失败，不写任何通过判断；L2-L5 在修复并以同一旅程重新跑通前不得判绿。
