# EDGE-039 · `:retry` 编辑重发分支 · L3 真实 App 顺滑验证

## 结论

**L3 PASS，依据 CODEX `B2` 零跳变律。** 本证据覆盖真实 App 中编辑入口的可发现性、编辑态输入反馈、
提交后的即时反馈、版本链收尾和稳定尾帧；L4 craft 与 L5 discoverability 的独立判定仍不冒充通过。

## Formal session

- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-165831`
- screen recording=`screen.mov`, `3104x1844`, `240.328333s`, ffprobe 可读
- App window=`8028`; `rig-down.sh` 后 App、backend、ssetap、llmtap、recorder 进程组归零
- workspace=`ws_bf9aed46483af41a`
- conversation=`cv_8987af89f7bb21bf`

## 真实交互与逐帧测量

1. 真实 App 新建对话并发送 `Reply exactly L3BASELINEOK`，网关返回 `L3BASELINEOK`。assistant 已存在后，
   user 回合仍直接显示 `Edit and resend`，不是仅 hover 才出现；点击后进入原地编辑态，输入框与
   `Cancel`/`Resend` 在同一回合区域内稳定呈现。
2. 通过 Computer Use 真实键盘 `End` + `BackSpace` + 文本输入，将编辑值从
   `Reply exactly L3BASELINEOK` 改为精确的 `Reply exactly L3BASELINEOKEDITED`。编辑期间没有退回
   普通气泡、丢失文本或改变对话位置。
3. 点击 `Resend` 后 backend 在 `2026-08-30T17:02:13.580+0800` 记录
   `POST /api/v1/conversations/cv_8987af89f7bb21bf:retry`，状态 `202`，没有普通 `/messages` 替代请求。
   录屏以动作附近 `60fps` 帧 `158` 为动作帧、`ROI=(400,80,2400,1500)` 抽取，测量结果：

   ```text
   threshold=0.0005 -> feedbackFrame=201, latencyMs=716.7, changedFrac=0.04545
   ```

   反馈是编辑态收起并进入新回合；Computer Use 现场同时可见新的 `thinking`/处理中状态，约 2 秒内
   收到精确的 `L3BASELINEOKEDITED`，没有静默等待。
4. 完成后的 `218s..238s` 以 `2fps` 抽取 40 帧，在相同 ROI 执行
   `measure diff -threshold 0.0005`，无输出；稳定段没有非用户触发的历史内容位移、闪烁或视口跳变。
   关键帧复读确认最终 user/assistant 版本均显示 `2/2`，编辑入口仍可用。

## 五通道交叉证据

- REST/DB：新 user `msg_a2a64e05bbe2d9e8` 的内容为 `Reply exactly L3BASELINEOKEDITED`，其
  `retryOf=msg_f278eb651956333a`；旧 user 的 `supersededBy=msg_a2a64e05bbe2d9e8`。新 assistant
  `msg_ced6c1f6b9f205ca` 内容为 `L3BASELINEOKEDITED`，其 `retryOf=msg_f9264ca188628bd9`；旧
  assistant 的 `supersededBy=msg_ced6c1f6b9f205ca`。旧行没有被删除。
- SSE：`sse.jsonl` 共 211 行；messages 流 durable seq=`1..54` 单调，目标 conversation 的 durable
  seq=`39..54`，包含 `open/delta/close`；notifications/entities 各自完成 connect/disconnect 生命周期。
- Backend：同一隔离 session 的 backend journal 没有 WARN、ERROR、panic 或 FATAL；retry HTTP 为 `202`。
- Frontend：没有 FlutterError、DartError、RenderFlex、Unhandled 或断言错误；仅有 macOS IMK/TSM 宿主诊断，
  与应用渲染无关。
- LLM wire：`llm.jsonl` 中 challenge/install 与两次 chat completion 均为 HTTP `200`，请求经过真实
  managed Anselm gateway；没有失败重试风暴。

## Scope boundary

本格只判编辑重发的顺滑闭环。`L4` 的 craft 细节和 `L5` 的从零发现性仍按清册开放状态保留，不能因为
入口已常显就把它们写成通过。
