# EDGE-196 attachment managed media lease

- 结论：`pass`（L1 managed-media contract and wire-boundary regression）；L2-L5 按当前证据边界记 `na`。
- 目标：受管图片经过 device-proof resumable staging 后，只把网关签发的相对 lease path 交给模型，拒绝任何
  scheme/host，且不把图片 bytes/base64 放进受管媒体引用。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/attachment \
  -run '^TestToContentParts_Managed' -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/attachment 1.961s

cd backend && mise exec -- go test ./internal/infra/llm \
  -run '^TestMediaClientUpload_' -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/infra/llm 2.073s

cd backend && mise exec -- go test ./internal/infra/deviceproof \
  -run '^(TestTransport|TestProofHostOverride)' -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/infra/deviceproof 1.604s
```

`MediaClient` 的 resumable 测试覆盖 create → chunk → complete、chunk cursor reconciliation、短 lease
刷新边界，并断言 complete 返回的 `/v1/media/leases/...?...` 保持相对形且没有 host。device-proof 回归
确认上传请求按具体 method/path/body 签名；`TestProofHostOverrideBindsTrueAudience` 锁住真实网关经过本地
记录 proxy 时的 audience 仍不漂移。

应用层现在再做一道 fail-closed：`ToContentParts` 只接受 `/v1/media/leases/` 前缀、带 query 的相对路径，
绝对 URL、`//host`、userinfo、错误前缀和空 query 都在构造 `ContentPart` 前拒绝。测试 fixture 已改为
真实相对 lease 形，并以 `TestToContentParts_ManagedMediaRejectsAbsoluteLeasePath` 锁住装配错误不会进入
模型 wire。`inspect_media` 现在复用同一个校验 primitive，并以
`TestInspectMedia_ManagedRejectsAbsoluteLeasePath` 锁住视觉复查旁路也不会进入模型 wire。remote
image/video 仍只传引用字符串，图片 bytes 不会由这条路径编码为 base64。

## real-route boundary

仓内 `testend/scenarios/live_managed_test.go` 已有真实 managed 图片聊天场景，覆盖 upload → media lease →
网关 multimodal route → durable turn；此前正式现场证据也记录过相对 lease、无 base64/绝对 host。当前工作区
没有 `EVALS_MANAGED=1` 所需的凭证或 `.env`，本轮没有冒充新一次真实网关/Computer Use 录制，故不把它升级为本格
独立的 L2 证据。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成受管图片 lease 的 App 五通道录制
L3 na: 没有本格独立的 staging 等待、lease 生成和 wire 首帧时序测量
L4 na: 没有本格独立的受管媒体卡片、相对引用与无 base64 的视觉 craft 比对
L5 na: 没有本格独立的新用户发现并理解受管媒体准备及失败恢复路径的 discoverability session
```
