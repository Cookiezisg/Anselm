# EDGE-204 read-aloud cache hit

- 结论：`pass`（L1 zero-upstream-repeat invariant）；L2-L5 按当前独立台架边界记 `na`。
- 目标：同一段文本、同一音色和同一路由连续朗读时，第二次在合成之前命中缓存，返回 `cached=true`，
  不增加上游 Speech 合成调用、不重复上传附件，也复用第一次的可播放附件。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/readaloud \
  -run '^TestRead_(SecondListenCostsNothing|ConcurrentIdenticalPressesCostOnce)$' \
  -count=1 -race -v
=== RUN   TestRead_ConcurrentIdenticalPressesCostOnce
--- PASS: TestRead_ConcurrentIdenticalPressesCostOnce (0.05s)
=== RUN   TestRead_SecondListenCostsNothing
--- PASS: TestRead_SecondListenCostsNothing (0.00s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/readaloud 1.865s
```

顺序回归断言第一次是 `Cached=false / synth.calls=1 / uploads=1`，第二次是 `Cached=true`，且合成与上传
计数仍分别为 1、1，附件 ID 相同。并发回归进一步验证两次同时 miss 只会触发一次上游合成并共享同一
附件；cache lookup 在 synthesis 前完成，命中不会先付费再回查。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中用真实前端连续点击朗读、SSE 和网关语音线缆完成五通道观察
L3 na: 没有本格独立的第二次点击到 cached 首帧、上游调用计数和播放开始时序测量
L4 na: 没有本格独立的朗读按钮反馈、cached 状态和音频播放控件视觉 craft 比对
L5 na: 没有本格独立的新用户发现并理解重复朗读零上游花费的 discoverability session
```

## source anchors

- `backend/internal/app/readaloud/readaloud.go`: synthesis 前 route identity probe 与 keyed miss gate
- `backend/internal/app/readaloud/readaloud_test.go`: sequential cache hit 与并发单飞回归
