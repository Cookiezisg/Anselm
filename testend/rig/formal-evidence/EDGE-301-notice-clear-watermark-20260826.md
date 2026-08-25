# EDGE-301 · 顶带清场水位

## L1 focused evidence

- `frontend/test/core/notice/notice_center_test.dart` 通过：顶带队列采用清场快照与新队列分离，清场期间新事件不会被旧快照误删。
- `frontend/test/core/ui/an_notice_queue_tail_test.dart` 通过：尾部 cue 数量和清除语义在清场后仍保持有界、可访问。

## 判定

L1=`A5`：清场动画期间新消息仍可见且不被误伤。L2-L5 本批未启动真实 App，记 `na`。
