# EDGE-324 · discovery-collapse 警报复审

## Scope

本复审对应账本新增 `EDGE|窗角半径 swizzle 失效|L4=na` 后触发的
`discovery-collapse`。警报只观察最近 50 条 live judgment 的 `fail` 占比；本次窗口为
`43 pass / 7 na / 0 fail`，并非把失败产品路径改写成通过。

## Re-audit

- 近期 50 条裁决逐条有独立法条、证据指针或明确适用性说明；没有批量猜测或无证据绿格。
- `EDGE-324 L4` 的 `na` 只针对未来 macOS 私有 getter 改名后的故障态：系统回退圆角由 macOS
  接管，产品没有可单独验收的 craft surface；对应 L2/L3 的真实 App 降级与稳定性证据仍保留。
- 该警报反映当前尾窗以已通过项和明确不适用项为主，不是把“没有发现缺陷”当成产品正确性的充分证明。
- 锚点校准仍为 `10/10`，未修改警报阈值、法典、证据要求或顺序门。

## Decision

本次仅销账当前 journal 水位的 `discovery-collapse`，保留它对后续新证据的重新触发能力；下一格
仍需独立判定，不能因为本次复审而自动通过。

## L5 follow-up

`EDGE-324 L5` 写账后重新检查尾窗，当前为 `42 pass / 8 na / 0 fail`。新增 `na` 与 L4 使用同一
平台故障态适用性边界，理由明确且不属于缺证据占位；该复审不改变 `discovery-collapse` 的阈值，
也不将任何开放产品路径视为已通过。
