# EDGE-210 · 免费档配额耗尽：修复后真实 App 五通道验收

## 结论

修复后通过 L1-L5。真实 App 在真实 managed gateway 线路上分别接收 HTTP `402
QUOTA_EXHAUSTED` 与流内 `BUDGET_EXHAUSTED`，最终主时间线不泄漏内部错误码、HTTP 状态或网关
原文，而是给出额度恢复时间和替代配置的可执行路径。Composer 在错误收尾后保持可发送，未出现
重试风暴、重复用户行或残留 loading。

本项使用无配额网关，因此没有把真实网关额度烧尽。两个故障信号由本地 `llmtap` 在真实
`https://api.anselm.website` 线路上只对 `/v1/chat/completions` 做一次受控注入；challenge、
install、models、三路 SSE、真实 App、backend 和 frontend 仍是真实链路。该证据证明产品对网关
定义的耗尽协议的端到端处理，不冒充真实网关扣费耗尽事实。

## 正式 sessions

- HTTP 402：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-142137`
- 流内 `BUDGET_EXHAUSTED`：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-142343`
- HTTP session workspace：`ws_6ac85a0a0793ae7e`
- stream session workspace：`ws_012812f79f3a5b40`
- 两个 session 均由 rig conductor 启动、录制、检查和收台；录屏分别为 `44.931667s` 和
  `28.458333s`，均为 `3104x1844 / 60fps`。
- 最终关键帧：
  `sessions/20260831-142137/evidence/frames/edge210-20260831-142137-final.png`
  与 `sessions/20260831-142343/evidence/frames/edge210-20260831-142343-final.png`。

## 产品观察与 stop-and-fix

修复前，主时间线把 `LLM_QUOTA_EXHAUSTED`、`402` 和 `llm: free-tier quota exhausted` 直接
展示给用户；红证据保留在 `EDGE-210-quota-copy-red-20260831.md`。修复后的两个真实 App 画面
均显示：

> This month's free-tier quota is used up. Try again after it resets, or open Settings → Models & keys to choose another model or key.

该文案不把额度耗尽说成瞬时繁忙，不邀请无意义的重复重试，并明确告诉用户替代配置的入口。

## 五通道交叉核验

- **Frame**：两个最终帧均保留用户原话，错误行稳定、可读、完整换行；Composer 可继续输入，没
  有内部码、HTTP 状态、原始 provider message、遮挡或布局溢出。
- **Backend**：两个 session 的 backend journal 无 `WARN`、`ERROR`、`FATAL` 或 panic；回合以
  `LLM_QUOTA_EXHAUSTED` 终态收口。
- **SSE**：每个 session 的 `sse.jsonl` 都有 messages、entities、notifications 三路连接和
  clean disconnect，消息 durable 状态与错误终态一致。
- **Frontend console**：两个 `frontend.log` 均无 Flutter/Dart exception、RenderFlex、Unhandled、
  ERROR 或 FATAL；录屏均由窗口级 recorder 归属并正常封口。
- **LLM wire**：两个 session 的 `llm.jsonl` 都记录真实 managed `proof/challenge=200`、
  `install=200`、`models=200`；HTTP session 有一次 `POST /v1/chat/completions=402` 的
  `fault_injected`，stream session 有一次 `POST /v1/chat/completions=200` 的
  `fault_injected`，其余请求仍透明通过真实上游。

## 判定

- **L1**：沿用并扩展既有 `EDGE-210-freetier-quota-exhausted-20260826.md` 的分类回归；HTTP
  402、HTTP 429 耗尽码和流内 `BUDGET_EXHAUSTED` 均保持 `LLM_QUOTA_EXHAUSTED`，且不进入瞬时限流重试。
- **L2 / F2**：真实 App、受管线路、独立三流 SSE、backend journal、frontend console、LLM tap
  和两种协议输入对账一致。
- **L3 / A4**：错误在回合收尾后立即给出明确下一步；无等待假象、无 retry loop，Composer 立即
  恢复可用。
- **L4 / C4**：修复后的文案层级稳定，主时间线只保留用户可行动的说明；两行换行自然，无泄漏字段、
  溢出、遮挡或残留状态。
- **L5 / G1**：新用户无需了解网关协议即可知道两条安全路径：等待额度恢复，或打开
  `Settings → Models & keys` 选择替代模型/密钥。
