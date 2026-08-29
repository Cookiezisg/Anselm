# EDGE-341 · 账本与统计警报独立复核

## 复核对象

- 新增裁决：`EDGE|未验证供应商诚实徽标|L2|pass|F1`
- 真实 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-030900`
- 证据：`EDGE-341-unverified-provider-real-app-20260828.md`

## 复核结论

- 裁决前已经完成真实 App 操作：全新工作区、供应商目录、`302.AI` 添加表单和取消路径。
- `screen.mov`、backend、SSE、frontend、LLM 五通道来自同一 conductor session；`rig-check` 和 `rig-down` 均通过。
- L2 只确认用户目的与持久/线缆真相；L3-L5 没有被误写为通过。

## 警报处置

- `pass-burst`：本次裁决有独立真实 session 和封存证据，不是批量猜测；速率异常只反映观察完成后的账本写入时点，已 ack。
- `discovery-collapse`：近窗无 fail 不被解释为产品无缺陷；本格保留真实取消负路径且未放宽覆盖、法典、锚点或裁决标准，已 ack。

未修改警报阈值、算法、CODEX、锚点集或历史 journal。
