# SURF-096 i18n/startup 调查与账本重审

## Stop-and-fix

`frontend/lib/app/app_startup_gate.dart` 原先把 `backendStartupProvider.error` 作为 `AnState.detail` 渲染。真实 App-first 运行确认这会把 `Bad state: backend did not become healthy at http://127.0.0.1:8742` 直接暴露在启动页。已停止红测并删除该绑定；诊断仍由前端日志和后端 journal 留存。`app_startup_gate_test.dart` 现在锁定内部错误不可见，启动标题、提示和重试按钮仍可见；相关 focused Flutter tests 共 `12` 项通过。

## Real App evidence

Session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-061312` 使用全新数据目录与真实 macOS App，`RIG_APP_FIRST=1`、后端延迟 `25s`。录屏中的错误门控只显示本地化用户文案，Computer Use 点击真实 `重试` 后恢复到创建工作区页。帧 `evidence/frames/SURF-096-35.png` 与 `evidence/frames/SURF-096-50.png` 已人工复核；录屏时长 `73.485000s`，分辨率 `2784x1808`，H.264。

为满足 L2 的 SSE 硬门禁，同样的场景另以预置 workspace 重跑于 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-061754`：三条 SSE 均真实连接，重试后恢复到实体总览；该 session 的完整五通道证据见其 `evidence/SURF-096-i18n-startup-five-channel.md`。

## Five channels

- Backend D1 归属为 PID `83740`，`61` 行，无应用错误红线。
- SSE tap 进程与收台正常；无 workspace，因而没有业务 durable SSE 帧，本记录不把空场景写成三流业务通过。
- Frontend console `3` 行，无 Flutter/Dart/布局/未处理异常红线。
- LLM tap 已连接真实 Anselm 网关，但本确定性启动路径不需要 completion，不冒充 completion 证据。

`rig-check.sh` 和 `rig-down.sh` 均通过；`startup-gate.jsonl` 记录 App 先起、后端延迟启动、health 恢复和 ssetap 启动顺序。

## Alarm re-audit

本格写入后按既有五格节奏重跑锚点与警报检查；不修改阈值、算法、法典或锚点。
