# Batch 73 · ledger alarm independent re-audit

本批 10 个 EDGE 行均有独立证据文件、可定位测试和 CODEX 法条；L1 为聚焦/黑盒证据，L2-L5 明确 `na`，未把代码测试冒充真实 App 逐帧观察。账本由 `judge.py` 写入，覆盖清册由 `gen_coverage.py` 校验，不手改 verdict。

集中施工会触发 `gap-too-fast`，并可能触发 `discovery-collapse`/`pass-burst`。这些警报只描述裁决时间分布，不能通过改阈值消除；本复审重新检查每个证据文件、测试输出和法条，再以独立本文件作为销账依据，最终 `alarms.py check` 必须 clean。

测试范围：workspace app/store、ORM transaction/keyset、conversation workdir Git，以及 testend 的 workspace lifecycle/cascade、rail name sort、branch/worktree 黑盒场景；测试中关闭 loopback gateway 导致的 free-tier provision warning 属隔离 teardown 预期，不是待修产品错误。
