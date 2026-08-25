# EDGE-323 · 进全屏白带

## L1 focused evidence

- `frontend/lib/app/window_setup.dart` 的原生过渡契约通过静态复核：macOS `willEnterFullScreen` 动画前移除 toolbar，`window_manager` 的动画后回调只作幂等兜底。
- `frontend/test/core/ui/an_shell_test.dart` 通过：fullscreen chrome collapse、灯位/品牌位和 reduced-motion 状态均保持壳体几何一致。

## 判定

L1=`B2`：全屏切换的白带风险由动画前撤 toolbar 与壳体状态守卫共同封住。L2-L5 本批未启动真实 App，记 `na`。
