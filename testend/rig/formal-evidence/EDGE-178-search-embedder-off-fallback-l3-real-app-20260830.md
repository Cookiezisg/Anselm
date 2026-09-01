# EDGE-178 · 搜索 embedder 缺席降级 · L3 真实 App 逐帧证据

## 结论

`pass`，依据 CODEX `B2` 零跳变律。本格只判定搜索降级路径的真实 App 动态反馈与稳定性；不把
L4 的视觉 craft 或 L5 的从零可发现性冒充为通过。设置页没有 search/embedder 控件的边界仍由
L2 证据明确保留，不在本格中偷换成 discoverability 通过。

## Session

- Formal session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-205857`
- Data: `/private/tmp/anselm-data-edge178-l2-20260830`
- Workspace: `ws_8e2b400de75043d1`
- Fixture document: `doc_4b5e232e3db894bf`
- Screen recording: `screen.mov`, `3104x1844`, `60fps`, `171.086667s`
- App window: `8651`; recorder PID `56176`; `rig-down.sh` 后 App、backend、ssetap、llmtap、recorder 均归零

## 产品路径与逐帧测量

1. 真实 App 完成 onboarding 后进入 Chat。由于当前前端 settings catalog 没有 search/embedder
   面板，本次仅用 workspace-scoped `PATCH /api/v1/search/settings` 将 embedder 设为 `off`；这
   是测试夹具准备，不是用户可发现性证据。随后创建含精确 token
   `EDGE178LEXICALFALLBACK` 的文档，并以 `POST /api/v1/search:reindex` 完成索引。
2. 通过 Computer Use 在真实 App 输入并发送：

   ```text
   Find the document containing EDGE178LEXICALFALLBACK and explain whether semantic search is unavailable but lexical search still works.
   ```

   模型实际执行 `search_documents`（精确 token 命中）后执行 `read_document`，最终回答区分了
   “词法精确命中已证明”与“该单次命中不能证明语义路径状态”，没有把降级路径过度解释成语义搜索故障。
3. 从同一绑定录屏以 `10fps` 抽取 `95s..125s` 的 `300` 帧，内容 ROI 为
   `(1000,120,1900,1400)`，每通道容差为 8。`f000155` 是最后一个发送前稳定态；以该帧为动作
   锚点执行：

   ```text
   measure latency -fps 10 -action 155 -roi 1000,120,1900,1400 -threshold 0.0005
   {"feedbackFrame":169,"latencyMs":1400.0,"changedFrac":0.00267,"box":"(1040,129)-(2423,564)"}
   ```

   `f000156` 起用户消息和 `thinking` 已出现，但低于该阈值的局部变化不被误写成“实质反馈”；
   `f000169` 是首个超过预先给定阈值的内容反馈。这个 `1.4s` 是保守的可见反馈上界，不是
   上游请求耗时，也不把等待工具链伪装成即时反馈。
4. 完成后的 `155s..171s` 以 `2fps` 抽取 `32` 帧，在相同 ROI 执行：

   ```text
   measure diff -dir frames-edge178-stable -roi 1000,120,1900,1400 -threshold 0.0005
   ```

   命令无输出。稳定尾段的用户消息、思考/工具活动、最终回答和 Composer 均没有超过阈值的
   非用户触发变化；没有发现历史内容位移、Composer 重排、迟到背景跳变或残留 loading。

## 五通道交叉证据

- **frames / Computer Use**: 真实 onboarding、文档 fixture 的搜索问句、工具链和最终回答均在
  绑定到窗口 `8651` 的录屏中；关键帧和稳定尾段已封存。
- **REST/DB**: `PATCH search/settings` 返回 `embedder=off`；`search:reindex` 返回 `204`；
  直接 search 返回唯一 fixture 文档和高亮 token；对话工具链随后读取同一文档。
- **SSE**: `sse.jsonl` 共 `294` 条；messages durable seq=`1..33`，notifications durable
  seq=`1..3`，无 gap；entities 流完成连接但本路径没有实体 durable mutation。
- **Backend**: `backend.log` 共 `271` 行；未发现 panic、fatal、error、exception 或 warn。
- **Frontend console**: `frontend.log` 共 `5` 行；未发现 FlutterError、DartError、RenderFlex、
  RenderBox、Unhandled 或 application exception。唯一的 `IMKCFRunLoopWakeUpReliable` 是已分类
  的 macOS 输入法宿主诊断，不是 Flutter 应用错误，原样披露。
- **LLM wire**: `llmtap` 共 `28` 条；challenge/install/models 与四次 streamed chat completion
  均为 HTTP `200`，搜索工具参数、工具结果和最终回答均可追溯。

## Judgment boundary

- **L3 `pass (B2)`**：真实 App 中，词法 fallback 的用户动作有可测可见反馈；收敛后的稳定尾段
  没有非用户触发的超过阈值变化，未发现跳变、抖动、覆盖或残留忙态。
- 本证据不宣称 search/embedder 设置入口可发现，也不宣称语义检索可用性；L4/L5 仍保持 `na`，
  等待后续真实产品路径与对应证据。
