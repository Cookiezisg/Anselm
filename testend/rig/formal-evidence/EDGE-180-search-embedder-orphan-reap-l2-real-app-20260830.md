# EDGE-180 embedder 孤儿回收：L2 真实 App 数据真相

- 结论：`pass`。
- 真实第一段 session：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-215722`。
- 真实恢复段 session：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-215934`。
- 数据目录在两次启动间保持为同一个独立副本：`/private/tmp/anselm-data-edge180-real-20260830`；没有用 sleep、fake repository 或临时伪 PID 代替真实引擎。

## 真实链路

1. 第一段真实 App 使用已有的 `EmbeddingGemma-300m` 缓存。workspace-scoped 的真实 `GET /api/v1/search?q=Acceptance%20Live` 返回两个命中，搜索设置从 `engine.status=absent` 变为 `ready`；`embedder.pid` 记录真实 `llama-server` PID `62153`。
2. 对 conductor 亲启的 backend PID `61568` 发送真正的 `SIGKILL`。backend 消失而 `llama-server 62153` 仍存活，且仍在同一数据目录的 `embedder.pid` 中；这证明了非优雅崩溃后的持久残留，而非优雅关停顺带清理。
3. 第二段真实 App 以同一数据目录重新启动，再执行同一个真实搜索。返回结果仍为相同的两个实体；backend journal 明确记录 `reaped a stale embedder ... pid 62153`，随后记录新 embedder ready，设置 endpoint 返回 `engine.status=ready`。
4. 第二段收台后由 `rig-down.sh` 正常清理新 embedder，相关进程归零；第一段的崩溃段和第二段的恢复段均保留，不覆盖旧证据。

## 五通道

第二段的 `manifest.json`、`backend.log`、`sse.jsonl`、`frontend.log`、`llm.jsonl` 和可读 `screen.mov` 均属于同一 manifest；SSE witness 连接 `notifications`、`entities`、`messages` 三流。LLM tap 至少记录 `event=ready`，本场搜索不产生模型聊天请求，未把 ready 事件冒充业务流量。

判定依据：`CODEX F2`。第一段 SIGKILL 后的残留、第二段回收日志、搜索 REST 结果与持久 PID 变化相互一致。
