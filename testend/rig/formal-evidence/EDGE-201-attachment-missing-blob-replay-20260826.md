# EDGE-201 missing or unreadable blob during replay

- 结论：`pass`（L1 best-effort replay integrity）；L2-L5 按当前独立台架边界记 `na`。
- 目标：metadata 行仍存在但对应 blob 被手工删除或不可读时，重放附件不应让整轮失败；模型必须收到
  一个明确的“附件不可用”说明，后续仍可用的附件保持原顺序继续进入回合。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/attachment \
  -run '^TestToContentParts_Notes(UnreadableBlob|Missing)' \
  -count=1 -race -v
=== RUN   TestToContentParts_NotesMissingPreservingOrder
--- PASS: TestToContentParts_NotesMissingPreservingOrder (0.02s)
=== RUN   TestToContentParts_NotesUnreadableBlobPreservingOrder
--- PASS: TestToContentParts_NotesUnreadableBlobPreservingOrder (0.01s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/attachment 1.933s
```

测试先上传一个 image，再用真实 CAS `Sweep` 删除其 blob、保留 metadata 行；随后上传一个正常 text
附件并按 `[missing, live]` 重放。`ToContentParts` 对 metadata 缺失和 `BlobStore.Get` 失败都写
warning、插入 `no longer available` 文本说明，且不会丢掉后续正常 text part。该行为与 chat history
的单一 attachment renderer 咽喉一致，因此完整性缺口不会被误包装成 provider 失败。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中用真实 App、重启后数据和五通道观察缺失 blob 重放
L3 na: 没有本格独立的 blob 删除到重放首帧、SSE 和后端告警时序测量
L4 na: 没有本格独立的不可用附件说明、正常附件续送和聊天布局视觉 craft 比对
L5 na: 没有本格独立的新用户发现并理解附件不可用但回合仍可继续的 discoverability session
```

## source anchors

- `backend/internal/app/attachment/attachment.go`: `ToContentParts` 对 metadata/blob 两类缺口的 best-effort 分支
- `backend/internal/app/attachment/attachment_test.go`: metadata 缺失与 CAS blob 被清扫后的顺序回归
