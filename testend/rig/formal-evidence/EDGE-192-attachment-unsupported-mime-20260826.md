# EDGE-192 attachment unsupported MIME extraction

- 结论：`pass`（L1 focused extractor + real HTTP/chat black-box）；L2-L5 按当前独立台架边界记 `na`。
- 目标：抽取器对没有 handler 的 MIME 立刻返回 `ATTACHMENT_EXTRACTION_UNSUPPORTED`，不启动 Python
  环境；真实聊天遇到该 document MIME 时降级为诚实占位，原始字节不上 wire，回合不失败。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/attachment \\
  -run '^TestSandboxExtractor_UnsupportedMimeShortCircuits$' \\
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/attachment 1.781s
```

`application/vnd.oasis.opendocument.text` 不在 `isExtractableDoc` 的闭集内；测试确认返回
`ErrExtractionUnsupported`，且 `EnsureEnv` 没有被调用，故不会为无法处理的格式无谓安装/启动共享环境。

## real HTTP/chat regression

```text
cd testend && mise exec -- go test ./scenarios \\
  -run '^TestContractDocsAtt_AttachmentChatDegradeFaces$' \\
  -count=1 -v -timeout 600s
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 3.051s
```

真实场景上传 `book.odt`，以附件引用发送聊天回合。后端真实日志记录
`extraction unsupported for this mime`，wire 只有 `could not be extracted` 占位，不包含
`odt-raw-bytes-FAKE`，回合最终 `completed`。同一场景还确认缺失 blob 与软删附件均不阻断后续回合，
但本格只据 ODT unsupported 分支判定。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成 unsupported MIME 的五通道 App 录制
L3 na: 没有本格独立的格式拒绝/占位显示等待与反馈 Computer Use 时序测量
L4 na: 没有本格独立的 unsupported 文件卡片、占位文案与原始字节不泄漏的视觉 craft 比对
L5 na: 没有本格独立的新用户发现并理解不支持格式会如何处理的 discoverability session
```
