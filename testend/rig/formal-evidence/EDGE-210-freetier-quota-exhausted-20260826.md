# EDGE-210 · 免费档配额耗尽

## 判定范围

本证据覆盖 L1 网关 402/流内耗尽信号的分类、用户错误码和不可重试策略。尚未在真实网关上消耗额度，因此不把模拟上游视为真实免费档扣费 session；L2-L5 后续补做。

## 复现命令

```text
cd backend
mise exec -- go test ./internal/infra/llm -run 'Test(ClassifyHTTPError_429SeparatesRateLimitFromExhaustedQuota|ClassifyHTTPError402QuotaExhausted|AnselmInStreamBudgetExhausted|QuotaExhaustedNotRetried)' -count=1 -race -v
mise exec -- go test ./internal/app/loop -run '^TestRun_StreamError_PreservesClassifiedProviderCodes$' -count=1 -race -v
```

结果：两组测试均 `PASS`。

## 观察

- 网关 HTTP 402、HTTP 429 `QUOTA_EXHAUSTED`/`INSTALL_CAP_REACHED` 和流内 `BUDGET_EXHAUSTED` 都归一到 `LLM_QUOTA_EXHAUSTED`。
- 瞬时 `RATE_LIMITED`/`UPSTREAM_BUSY` 仍保持可重试，耗尽额度不会被误重试。
- loop 将 quota exhausted 保留为用户可识别的终态，而不是泛化成 provider error。

## 结论

L1 通过。L2-L5 暂不判定，等待真实无配额网关的耗尽/拒绝 session。
