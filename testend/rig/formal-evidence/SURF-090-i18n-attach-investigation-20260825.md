# SURF-090 i18n/attach — investigation and ledger note

The first real App session showed a visible attachment preparation/failure chip with no corresponding macOS AX node. This was a real discoverability defect, not an observer omission: Computer Use screenshots showed the chip and action while `get_app_state` exposed only the composer text field.

The fix added stable state/action semantics and explicit boundaries around the attachment strip and composer Stack. After rebuilding the real App, AX exposed the complete lifecycle labels and controls:
`正在准备媒体…`, `取消媒体准备`, `媒体准备失败`, `重试媒体准备`, and `关闭`.

The invalid fixture fails too quickly for a deterministic UI cancellation request: the worker reaches failed state in about one second, even after immediate clicks. This is retained as a timing boundary, not upgraded into a false green cancellation HTTP observation. Retry is proven by repeated real App clicks and backend `POST .../preparation/retry` 200 responses; cancellation is covered by `testend/scenarios/media_preparation_test.go` while the UI affordance is proven discoverable in the real AX tree.

The session still completes the user purpose with a valid image, real managed media upload and visual gateway call, SSE durable close, and final Chinese image description.
