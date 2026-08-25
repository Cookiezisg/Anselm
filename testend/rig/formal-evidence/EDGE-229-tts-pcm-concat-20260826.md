# EDGE-229 多块 TTS PCM 拼接

- 日期：2026-08-26
- 判定：L1 `pass`；L2-L5 `na`
- 法条：`measure:edge229-tts-pcm-concat`

## 目标

长文本被各供应商按单请求字符上限切成多块后，产物必须在 PCM 层重新连接，而不是把
多个 WAV/编码文件按字节追加。最终只保留一个 RIFF 头、样本连续；格式不一致必须拒绝，
不能静默变调或产生第二段不可播放的音频。

## 可复核命令与结果

```text
cd backend
mise exec -- go test ./internal/infra/llm \
  -run 'Test(BuildParseWAVRoundTrip|ParseWAVWalksChunks|ConcatAudioJoinsAtPCMLevel|ConcatAudioSinglePartPassesThrough|ConcatAudioRefusesMixedFormats|SpeechChunkLimitCoversEveryRoutedProvider)$' \
  -count=1 -race -v
```

结果：6 个测试均 `PASS`。

证据覆盖：双 WAV 变单 WAV 且仅一个 RIFF 头；LIST metadata chunk 不进入 PCM；混合采样率
被拒；单块原样透传；各可路由 provider 都有显式 chunk limit，未知 provider 取最小安全上限。

## 未声称的等级

本格本轮没有启动真实 App、真实 TTS 上游、Computer Use 录屏、独立 SSE witness、frontend
console 或 LLM wire session，因此 L2（五通道真相）、L3（顺滑）、L4（craft）、L5（可发现性）
均明确为 `na`。
