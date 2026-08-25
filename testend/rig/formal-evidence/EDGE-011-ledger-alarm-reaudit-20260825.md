# EDGE-011 ledger/alarm re-audit · 2026-08-25

## Trigger

EDGE-011 五个层级写入后，统计窗口打开 `gap-too-fast` 与 `discovery-collapse`；没有打开
`pass-burst`。本复审不改变阈值、检测算法、法典、锚点或 sequence gate。

## Evidence review

- 重新阅读 EDGE-011 证据：同组工具由屏障测试证明同时启动，结果按输入下标拍平；`go test -race`
  没有竞态报告。
- 这是内部并发正确性格，不把 focused test 冒充真实 managed gateway 五通道、视觉时延或可发现性
  旅程；L2-L5 的 `na` 理由明确且可审计。
- 本格没有发现应记为 fail 的产品红线；警报反映裁决时间窗口与判定分布，不是对实现结果的否决。

## Resolution

两条警报仅针对该写账窗口独立复审后销账，所有 detector 继续启用，统一长门禁按原规则执行。
