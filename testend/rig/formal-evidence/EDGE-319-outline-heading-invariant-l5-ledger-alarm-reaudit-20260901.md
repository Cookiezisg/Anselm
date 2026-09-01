# EDGE-319 大纲下标不变式 L5 账本警报独立复核

## 结论

本文件是 `EDGE-319|大纲下标不变式` L5 进入账本前的独立警报复核，不是产品现场的替代证据。
第一次尝试写入 L5 时，`judge.py` 按机制拒绝，原因是 `discovery-collapse` 警报仍开放；因此没有绕过
门禁、没有改写阈值、没有修改法典或锚点。

## 复核对象

- L5 产品证据：`testend/rig/formal-evidence/EDGE-319-outline-heading-invariant-l5-real-app-20260901.md`
- 真实 App session：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-212449`
- 覆盖清册校验：`gen_coverage.py --check` 应为 `848/848/0`
- 锚点校验：`anchors.py check` 应为 `10/10`

## 警报解释

`discovery-collapse` 的触发条件是近 50 个裁决的 fail share 低于既定 5% 下限。该条件表达的是统计
判断力异常，需要重新检查金标准，而不是证明当前产品有失败。这里重新核对了完整的 10 个锚点、848/848
清册行和现行 CODEX 法条；没有发现锚点漂移、覆盖生成漂移或将 provisional 证据当成通过的情况。

复核只确认当前警报属于可解释的低失败样本，不降低后续门槛。ack 仅记录本次复核结论，下一次真实失败
仍会重新打开警报并阻止新的 pass。

## 复核命令与结果

```text
anchors.py check: 10/10
gen_coverage.py --check: 848/848/0
judge.py first L5 attempt: REFUSED while discovery-collapse was open
```

本复核完成后才允许重新执行同一条 `judge.py` L5 pass；若该 pass 再次触发同一统计警报，仍须重新
复核并 ack，不能把警报隐藏在一次成功裁决后。
