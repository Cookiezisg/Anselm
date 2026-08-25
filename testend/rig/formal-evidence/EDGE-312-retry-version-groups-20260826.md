# EDGE-312 · 版本组走 retryOf

## L1 focused evidence

- `frontend/test/features/chat/model/conversation_transcript_test.dart` 通过：retry/edit-resend 版本链沿 `attrs.retryOf` 合并，旧版副本的 stale `supersededBy` 不破坏分组。
- `frontend/test/features/chat/ui/chat_transcript_test.dart` 通过：retry 只渲染一行 pager，旧版可回看且线程基于关系可解释。

## 判定

L1=`F1`：版本分组以 durable back pointer 为真相，不依赖可能过期的正向指针。L2-L5 本批未启动真实 App，记 `na`。
