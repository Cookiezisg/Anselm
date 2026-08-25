# EDGE-230 ParseWAV 遍历 chunk 表

- 日期：2026-08-26
- 判定：L1 `pass`；L2-L5 `na`
- 法条：`measure:edge230-parse-wav-chunks`

## 目标

真实 WAV 不保证只有 44 字节 header 后马上是 data；`LIST`、`fact` 等 metadata chunk 可能
夹在 `fmt` 与 `data` 之间。解析器必须遍历 chunk 表并只提取 data 样本，不能把元数据静默
交给播放器造成噪声。

## 可复核命令与结果

```text
cd backend
mise exec -- go test ./internal/infra/llm \
  -run 'Test(ParseWAVWalksChunks|ParseWAVWalksFactChunk|BuildParseWAVRoundTrip)$' \
  -count=1 -race -v
```

结果：3 个测试均 `PASS`。测试分别覆盖标准 round-trip、插入 `LIST` chunk 和插入 `fact`
chunk，均取回精确 PCM 字节，不把 metadata 当作样本。

## 未声称的等级

本格本轮没有启动真实 App、真实 TTS/播放、Computer Use 录屏、独立 SSE witness、frontend
console 或 LLM wire session，因此 L2（五通道真相）、L3（顺滑）、L4（craft）、L5（可发现性）
均明确为 `na`。
