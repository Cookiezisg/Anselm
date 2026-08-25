# EDGE-207 · 朗读可用性诚实缺席

## 判定范围

本证据覆盖 L1 后端能力判定与前端入口投影。独立真实 App、SSE、网关探测线缆和视觉/可发现性 session 尚未为本格封存。

## 复现命令

```text
cd backend
mise exec -- go test ./internal/app/readaloud -run 'TestRead_ValidationAndAvailability' -count=1 -race -v

cd ../frontend
mise exec -- flutter test test/features/chat/ui/chat_transcript_test.dart --plain-name 'read-aloud'
```

结果：Go 与 Flutter 均 `PASS`；Flutter 两项朗读测试全部通过。

## 观察

- 没有可用语音路由时，服务 `Available` 返回 false。
- availability 探测失败也投影成 false，不启动自动重试循环。
- 前端在 false 或 loading 状态不渲染朗读按钮；有语音路由时，正常朗读入口仍出现。

## 结论

L1 通过。L2-L5 暂不判定，等待后续正式台架 session。
