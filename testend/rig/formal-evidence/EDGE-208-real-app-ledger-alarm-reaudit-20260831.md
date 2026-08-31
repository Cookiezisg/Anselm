# EDGE-208 · 账本警报独立复审

## 复审结论

本记录复审 `gap-too-fast`。警报由本批次连续写入 EDGE-208 的四个等级触发：最近 44
个裁决的间隔中位数为 `5s`，低于既定阈值 `25s`。阈值、算法、法典和锚点均未修改。

## 逐项复核

- L2 `F2`：真实 App session=`20260831-101803`，正式五通道证据存在且路径位于该 session；
  REST/SQLite、SSE durable close 和 managed LLM wire 互相吻合。
- L3 `A4`：录屏与 SSE 都显示 `Searched tools` → `Searched function` → `Ran function` →
  成功收尾，没有重复 function call、retry 或错误终态。
- L4 `C4`：最终画面只有一个连贯的执行活动/结果层级，Composer 可用；截图和完整录屏均已
  封存。
- L5 `G1`：测试从普通 Chat 语言请求开始，用户不需要知道 provenance 字段、attachment ID
  或 media lease URL。

## 关键边界

绿场使用可被真实 vision route 接受的 `32x32` PNG。此前 `20260831-101345` 的 `1x1`
fixture 被真实网关拒绝，已作为独立 red discovery 保留，未混入本次绿证据。绿场 LLM wire
中的 tool result 同时含 foreign attachment ID 与当前调用铸出的 artifact ID，但后续 native
media parts 只有当前调用产出的那一件。

## 处理

该警报是写账节奏信号，不是产品失败。复审确认四格证据真实、独立且无历史 provisional
证据冒充通过；按既定流程 ack，随后再次运行 `alarms.py check` 验证清洁。未改阈值，也未
用警报 ack 替代任何产品证据。
