# EDGE-228 ASR sidecar 无受管凭证

- 日期：2026-08-26
- 判定：L1 `pass`；L2-L5 `na`
- 法条：`measure:edge228-asr-no-managed-credential`

## 目标

语音输入只走受管 Anselm Auto，不拿 BYOK 做适配。清掉 managed key 后，ASR 入口必须
诚实返回 `503 SPEECH_UNAVAILABLE`，不能显示一个注定失败的输入入口、不能偷偷走 BYOK、
也不能建立半配置 WebSocket。

## 可复核命令与结果

```text
cd backend
mise exec -- go test ./internal/app/speech ./internal/transport/httpapi/handlers \
  -run 'Test(ManagedGatewayUnavailableWithoutManagedKey|SpeechHandlerWithoutManagedCredentialIsHonestAbsence|SpeechHandlerProxiesClientFramesToManagedGateway)$' \
  -count=1 -race -v
```

结果：3 个测试均 `PASS`。

新增 handler 回归直接调用 `GET /api/v1/speech/asr`，使用空 managed key 集合，验证 HTTP
状态 `503` 和 envelope 错误码 `SPEECH_UNAVAILABLE`；正常 managed proxy 测试同时通过，
证明缺席分支不是把整个 ASR handler 拆坏。

## 未声称的等级

本格本轮没有启动真实 App、真实语音输入/受管网关、Computer Use 录屏、独立 SSE witness、
frontend console 或 LLM wire session，因此 L2（五通道真相）、L3（顺滑）、L4（craft）、L5（可发现性）
均明确为 `na`。
