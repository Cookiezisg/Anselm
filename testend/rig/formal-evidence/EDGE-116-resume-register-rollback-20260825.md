# EDGE-116 `resume` 的 Register 失败回滚

- 结论：`pass`（L1 可验证行为）；L2-L5 按当前台架边界记 `na`，没有真实 Computer Use/视觉路径证据，不扩大结论。
- 预期：source 拒绝重新注册时，`:resume` 必须显式报错，持久行仍为 paused，竞态报告不能产生 firing；source 恢复后再次 resume 必须可成功。

## 证据

```text
cd backend && mise exec -- go test ./internal/app/trigger -run '^TestResume_RegisterFailureRollsBackAndStaysRetryable$' -count=1 -race -v
=== RUN   TestResume_RegisterFailureRollsBackAndStaysRetryable
--- PASS: TestResume_RegisterFailureRollsBackAndStaysRetryable (0.04s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/app/trigger 1.744s
```

测试使用拒绝注册的 source：首次 `Resume` 返回错误且状态回滚到 paused，报告被丢弃；清除 source 故障后再次 `Resume` 成功，恢复 listening，后续报告只产生一个 firing。

## 判定边界

L2-L5 暂记 `na`：当前仓库没有能从真实 UI/网关稳定制造 source register failure 的产品场景；不能把 fake listener 的应用回归冒充 Computer Use、时延、视觉或 discoverability 证据。后续若补齐真实失败注入路径，必须重新裁决。
