# EDGE-191 attachment sandbox extraction

- 结论：`pass`（L1 focused + real testend black-box）；L2-L5 按当前独立台架边界记 `na`。
- 目标：真实上传 `.docx`，由共享 Python sandbox（`python-docx`）抽取正文，注入聊天 LLM wire；正文超过
  400K rune 时只保留头部并明确标注 `truncated`。

## real testend regression

```text
cd testend && mise exec -- go test ./scenarios \\
  -run '^TestContractDocsAtt_DocxSandboxExtractionAndCap$' \\
  -count=1 -v -timeout 600s
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 7.817s
```

场景每次在隔离 harness 中动态构造最小合法 OOXML 包，上传为
`application/vnd.openxmlformats-officedocument.wordprocessingml.document`，发送带 `attachmentIds`
的真实聊天回合。后端日志确认 sandbox bootstrap ready；回合最终 `completed`。LLM prompt dump
包含 `office-191.docx`、`text-extracted, truncated` 和 `DOCX_EXTRACTION_HEAD_191`，而位于
400K rune 截断点之后的 `DOCX_EXTRACTION_TAIL_AFTER_CAP_191` 不在 wire 中。

## adjacent unsupported-format guard

同文件既有 `TestContractDocsAtt_AttachmentChatDegradeFaces` 真实覆盖 `.odt`：不支持的 MIME 只生成
诚实的 `could not be extracted` 占位，原始字节不上 wire，回合仍 `completed`。因此本格同时覆盖
支持格式的 sandbox 主线和不支持格式的安全降级，不把 ODT 误宣称为可抽取。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成 attachment sandbox 的五通道 App 录制
L3 na: 没有本格独立的等待提示、抽取耗时和截断反馈 Computer Use 测量
L4 na: 没有本格独立的附件预览、抽取标记与超长正文视觉 craft 比对
L5 na: 没有本格独立的新用户发现并理解 Office 抽取/降级能力的 discoverability session
```
