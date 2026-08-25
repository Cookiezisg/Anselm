# EDGE-299 · 顶带 5000 条积压

## L1 focused evidence

- `frontend/test/core/notice/notice_center_test.dart` 通过：unbounded FIFO 在超过旧 cap 后不丢消息。
- 同文件 `ten thousand pending messages only two lightweight cues` 通过：积压只投影 current、最多两条 cue 与 pending count，widget 数不随积压增长。

## 判定

L1=`A5`：积压期间 UI 保持可交互且反馈投影有界。L2-L5 本批未启动真实 App，记 `na`。
