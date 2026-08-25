# EDGE-349 语音流中上游断线

- 判定对象：双工会话中上游连接关闭及心跳收尾。
- 证据：`TestSpeechHandlerHeartbeatsBothWebSocketLegs`、`TestSpeechHandlerProxiesClientFramesToManagedGateway`、前端 `second live socket loss falls back to retryable draft state` 通过。
- 产品判断：断线有明确终态、草稿可重试，不留下永远录音或 generating 状态。
- 法条：A4、F2。

