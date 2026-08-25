# EDGE-324 · 窗角半径 swizzle 失效

## L1 focused evidence

- `frontend/lib/app/window_setup.dart` 的私有 API 判空/失败回退路径通过静态复核：外窗圆角仅为装饰，swizzle 不可用时回落原生默认，不让启动崩溃。
- `frontend/test/core/design/window_corner_guard_test.dart` 通过：Dart token 与原生默认 20pt 保持同心；`frontend/test/core/ui/an_shell_test.dart` 全部通过。

## 判定

L1=`C4`：窗角使用产品 token 阶梯，平台私有实现失效时保持可用而不引入第二套视觉值。L2-L5 本批未启动真实 App，记 `na`。
