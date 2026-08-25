# EDGE-197 attachment lease refresh

- 结论：`pass`（L1 lease refresh/cache lifetime regression）；L2-L5 按当前独立台架边界记 `na`。
- 目标：同一附件的 managed lease 进入 30 秒 safety window 时自动刷新，刷新上传仍是同一份字节；新
  `MediaClient` 模拟 sidecar 重启，不复用旧进程的内存 lease/bearer。

## focused regression

```text
cd backend && mise exec -- go test ./internal/infra/llm \
  -run '^TestMediaClientUpload_RefreshesLeaseInsideSafetyWindow$' \
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/infra/llm 1.809s

cd backend && mise exec -- go test ./internal/app/tool/attachment \
  -run '^TestInspectMedia_Managed' -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/tool/attachment 1.645s
```

测试让 complete 返回 `leaseRefreshSkew` 内即过期的 lease。连续两次同附件调用产生两个 lease，且两次
PUT body 都逐字节等于原始 `data`；随后用新建的 `MediaClient` 再调用，creates 继续增加，证明 lease
只存在于原 client 的内存缓存，不会跨 sidecar 重启携带 bearer。`MediaClient` 的 in-flight/cache key
仍绑定 gateway base、install、MIME 和内容 SHA，避免不同安装或不同字节误共享。

`inspect_media` 的 managed staging 也通过相同的 relative-lease 校验；绝对 URL 在视觉复查请求构造前
拒绝，避免刷新/重投影之外的媒体消费面绕过安全边界。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成跨 lease 临期的受管 App 五通道录制
L3 na: 没有本格独立的长 ReAct lease 临期、刷新完成和后续首帧时序测量
L4 na: 没有本格独立的刷新等待提示、附件状态和媒体引用视觉 craft 比对
L5 na: 没有本格独立的新用户发现并理解媒体刷新/重启后重新准备行为的 discoverability session
```
