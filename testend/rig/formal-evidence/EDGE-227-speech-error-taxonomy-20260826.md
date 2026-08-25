# EDGE-227 语音配额与限流分流

- 日期：2026-08-26
- 判定：L1 `pass`；L2-L5 `na`
- 法条：`measure:edge227-speech-error-taxonomy`

## 目标

语音网关的错误码不能全部压成“不可用”：额度耗尽是硬墙、短暂限流是可重试、安装被封
是权限问题，三者要给用户不同的事实和后续动作。握手前错误、HTTP 402/429 和流内错误
都必须保持这套区分。

## 可复核命令与结果

```text
cd backend
mise exec -- go test ./internal/app/speech ./internal/infra/llm \
  -run 'Test(ClassifyHandshakeCodeSeparatesActionableRefusals|ClassifyHTTPError_429SeparatesRateLimitFromExhaustedQuota|ClassifyHTTPError402QuotaExhausted|AnselmInStreamBudgetExhausted|QuotaExhaustedNotRetried)$' \
  -count=1 -race -v
```

结果：全部测试 `PASS`。

- `QUOTA_EXHAUSTED`、`BUDGET_EXHAUSTED`、`INSTALL_CAP_REACHED` → `SPEECH_QUOTA_EXHAUSTED`，
  且 `ErrQuotaExhausted` 不可重试。
- `RATE_LIMITED`、`UPSTREAM_BUSY`、`INSTALL_RATE_LIMITED` → `SPEECH_RATE_LIMITED`，保留可重试。
- `ACCOUNT_BANNED` → `SPEECH_ACCOUNT_BANNED`。
- HTTP 402、429 和 Anselm 流内 budget/upstream 错误保持同样的 provider taxonomy。

## 未声称的等级

本格本轮没有启动真实 App、真实语音输入/网关、Computer Use 录屏、独立 SSE witness、frontend
console 或 LLM wire session，因此 L2（五通道真相）、L3（顺滑）、L4（craft）、L5（可发现性）
均明确为 `na`。
