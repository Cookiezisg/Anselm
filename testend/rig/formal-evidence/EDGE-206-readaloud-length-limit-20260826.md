# EDGE-206 · 朗读长度上限

## 判定范围

本证据覆盖 L1 输入边界与零上游副作用。独立真实 App 逐帧、SSE、语音网关线缆和视觉/可发现性 session 尚未为本格封存。

## 复现命令

```text
cd backend
mise exec -- go test ./internal/app/readaloud -run 'TestRead_ValidationAndAvailability' -count=1 -race -v
```

结果：`PASS`。

## 观察

- 空白文本被 `ErrTextRequired` 拒绝。
- 超过 4000 rune 的文本被 `READALOUD_TEXT_TOO_LONG` 拒绝。
- 两类非法输入均在合成器调用前结束；测试中的上游调用计数保持为零。

## 结论

L1 通过。L2-L5 暂不判定，等待后续正式台架 session。
