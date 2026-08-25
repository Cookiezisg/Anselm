# EDGE-348 语音双工握手拒绝闭集

- 判定对象：语音 WebSocket 握手遇到 401、配额或未知上游拒绝。
- 证据：`TestSpeechHandlerRelaysGatewayErrorsVerbatim`、`TestClassifyHandshakeCodeSeparatesActionableRefusals`、`TestValidSpeechControl_AllowsKnownControlsOnly` 通过。
- 产品判断：用户面只接收稳定的 handshakeRefusal 闭集码，不泄漏 provider 散文；前端可据此给出下一步。
- 法条：E1。

