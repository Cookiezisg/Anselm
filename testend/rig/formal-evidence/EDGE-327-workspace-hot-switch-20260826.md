# EDGE-327 · workspace 热切换三拍

## L1 focused evidence

- `frontend/test/core/workspace/hot_switch_test.dart` 通过：切换动作先离开深链、同步清理旧 workspace 的对话与右岛记忆，再翻 workspace 轴；post-frame 后才重建新 workspace 依赖。
- `frontend/test/app/workspace_switcher_test.dart` 通过：切换后 kept-alive sidestage 被解除，不再请求旧对话；工作区列表与激活动作也通过。

## 判定

L1=`F5`：切换不会把旧 workspace 的活动状态带进新世界，旧深链和驻留侧幕均可被重建为新轴状态。L2-L5 本批未启动真实 App，记 `na`。
