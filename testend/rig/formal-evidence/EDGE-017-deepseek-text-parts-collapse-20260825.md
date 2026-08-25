# EDGE-017 · DeepSeek 全文本 parts 坍缩

## Verification

DeepSeek-compatible wire 在 user message 的 parts 中没有媒体幸存时，将全部文本按 `\n\n` 顺序拼接为
JSON string `content`；有媒体时仍保留原生 parts array。这样附件在无 vision 模型上降级成文本占位后，
冻结历史每次重放都能走 text-only wire，不会因 array-form content 反复 400。

Focused verification passed:

```text
go test ./internal/infra/llm -run 'TestDeepSeekAllTextPartsCollapse' -count=1  PASS
go test -race ./internal/infra/llm -run 'TestDeepSeekAllTextPartsCollapse' -count=1  PASS
```

回归直接解析实际 DeepSeek request body，断言 `content` 是字符串、保留两段文本的原顺序，并严格使用
两个换行连接；同时保留“不含 text-part array”的 wire 断言。

## Five-level applicability

- L1 `pass`: 全文本 parts 坍缩为有序 string content，避免无视觉路由的历史回放 400；测量法
  `measure:edge017-deepseek-text-parts-collapse`。
- L2 `na`: 本轮未为该 provider wire seam 单独启动真实 managed gateway 五通道 session。
- L3 `na`: focused wire test 无真实 App 录屏、帧时延或模型响应视觉数据。
- L4 `na`: 本条验证 provider 编码，不含独立视觉几何/动效 surface。
- L5 `na`: wire 兼容是内部 provider 边界，不是用户可导航入口。
