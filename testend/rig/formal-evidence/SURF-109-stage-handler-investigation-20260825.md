# SURF-109 stage/handler investigation

## Scope

验收 Handler 舞台的完整生命周期与版本编辑：`set_init_args_schema(args)`、`set_init(initBody)`、`add_method(method)`、`update_method(name + RFC-7396 patch)`、`set_shutdown(shutdownBody)`，并确认敏感参数、方法输入输出、timeout、人话时钟、版本历史和运行态在 App、REST、SSE、LLM wire、前端日志五通道一致。

## Static contract

- `frontend/lib/features/chat/ui/stages/handler_stage.dart` 从 `ops` 构造单一 Handler 舞台；`update_method` 的真实形状是 `{op:"update_method", name, patch}`，不是嵌套 `method` 对象。
- `set_init_args_schema` 的真实键是 `args`；`add_method` 的方法定义位于 `method`；`set_init`/`set_shutdown` 分别使用 `initBody`/`shutdownBody`。
- timeout 以毫秒持久化，舞台以秒钟词渲染；敏感 init arg 只显示掩码。
- 后端 `handler/apply.go` 对错误操作 fail-loud，并对 `update_method` 执行 RFC-7396 合并。

## Real run

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-095228`
- workspace: `ws_40865e568cbd7b05`
- conversation: `cv_a42047bac38cf401`
- app window: `2079`; backend `13068`; ssetap `13090`; llmtap `13045`
- recording: `screen.mov`, finalized `334.810000s`, `2784x1808`
- handler: `hd_ceb934861c29695d`, `surf109_notifier`

### Positive path

1. 真实 App 通过 managed gateway 先执行 Handler 创建。模型初次错误地发送 `set_method` 和错误的元数据名称，后端诚实拒绝；模型随后修正为合法 slug，并以 `args`、`initBody`、嵌套 `method`、`shutdownBody` 的正确契约创建 v1。
2. App 真实展示 v1 的 `init`、`send`、`shutdown`、`apikey ••••`、`region`、`30s` 和 Python 代码；REST active version、entities close 和 message close 同为 v1。
3. 编辑首发错误地把方法字段嵌入 `method`，后端返回 `method alias must be a non-empty string`；该红事实保留在活动区和 SSE，不计绿。
4. 模型按工具 schema 自纠，发送 `{op:"update_method",name:"send",patch:{body,timeout:45000}}`。后端生成 v2，环境 ready、runtime running；REST 与 SSE close 均确认 `timeout=45000`、`status='updated'`，输入输出、init/shutdown、敏感标记均保持不变。
5. 重新点击实体查看后，右侧舞台追加当前 v2 卡片，显示 `45s`、更新后的代码与 v2/running；旧 v1 仍保留为历史活动，未被错误覆盖。最终截图为 `sessions/20260825-095228/evidence/SURF-109-stage-handler-settled.png`。

## Five-channel evidence

- **Frames / Computer Use**: AX 在最终状态同时可见历史失败、v1 历史和 v2 当前卡；v2 的 `45s`、updated body、`apikey ••••` 和 lifecycle code 可读，无布局红线。截图分辨率 `2784x1808`。
- **Backend journal**: 仅保留三条预期的负路径 WARN（错误 create shape、非法名称、错误 update shape）；无 panic/fatal/应用级 error。
- **SSE**: `entities` 记录 build open/close、`handler.edited`、env installing→ready；`messages` 记录错误 close、成功 edit close、tool_result 和最终 get_handler close；durable seq 单调。最终 close 快照为 v2。
- **Frontend console**: `frontend.log` 无 Flutter/Dart/RenderFlex/Unhandled 错误；唯一 error 是已知 macOS `IMKCFRunLoopWakeUpReliable` 平台噪声。
- **LLM wire**: `llm.jsonl` 与逐调用 request/response 文件记录真实 managed gateway；proof/install/models 与 chat completions 均 HTTP 200，编辑后的工具 arguments 是正确的 `name + patch`。

## Product verdict

正向路径满足“创建→查看→编辑→重载查看”的用户目的。失败尝试不会伪装成成功，且不会污染实体；版本历史和当前真相分层清楚。敏感值不泄漏，timeout 不显示裸毫秒，v2 变更后的舞台与 REST/SSE/LLM wire 对齐。该格可进入五级账本。
