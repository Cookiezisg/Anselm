---
id: DOC-059
type: decision
status: active
owner: @weilin
created: 2026-07-25
reviewed: 2026-07-25
review-due: 2099-12-31
audience: [human, ai]
---

# 0012 — 受管路由媒体的上游运输形态:内联,不再要求 provider 回拉

> Supersedes [ADR 0011](0011-gateway-media-handle-contract.md) 的**上游那半**(网关→provider 的运输形态)。
> 0011 的**入站那半**——桌面端→网关只收**相对形** lease 引用、凡带 scheme/host 一律拒——**原样有效**,本 ADR 不动它。

## 背景 / Context

ADR 0011 落地后的架构是:桌面端把相对 lease 引用嵌进 chat 请求 → 网关校验归属与时效 → 用 `MEDIA_PUBLIC_BASE_URL` 把引用**绝对化** → 上游 provider(Qwen/DashScope)按 URL **回拉**网关的公开内容端点。

2026-07-25 A1 真机验收(第一次端到端跑通整条链)撞上稳定失败:上游对每个带 lease URL 的请求答 400 `Failed to download multimodal content`。

## 判别实验(全部生产环境实测,当日)

| # | 请求形态 | 结果 |
|---|---|---|
| A | 同端点 + base64 data URI | 通(到了维度校验) |
| D | 公网 JPEG URL(gstatic) | 200 |
| G | 公网 JPEG + `?token=abc` query | 200 |
| H | 同一张 JPEG 放 `anselm.website` 静态站 | 200 |
| I | lease 真实内容(16-bit PNG)放静态站 | 200 |
| K | 静态站 + **一模一样**的 token query | 200 |
| M | lease 形路径 `/v1/media/leases/.../content.png` 放静态站 | 200 |
| F | **`api.anselm.website` 上的真实 lease URL** | **稳定 400 ×3** |

决定性佐证:给 Caddy 临时开访问日志重跑 F——**源站从未收到拉取请求**;而同一 URL 本机 curl GET/HEAD 皆 200、content-type 正确。两域 DNS 完全相同(同一 Cloudflare zone),bot-UA 探测也全 200。

**结论**:拉取器对 `api.` 主机的拒绝发生在其边缘或策略层(合理猜测:防 SSRF 的 API 形主机黑名单),不可见、不可控、不可申诉。

## 决定 / Decision

**网关校验通过后,把 lease 内容读出来,以 `data:` URI 内联进上游请求。不再向 provider 暴露任何需要它回拉的 URL。**

1. **谓词不减一分**:内联入口 `OpenLeaseForInstall` 与 `VerifyLease` 同一严格谓词(含 `lease.InstallID` 归属;一切失败统一 404,不做存在性预言机)。未经校验的引用,无论 URL 形还是内联形,不得抵达上游。
2. **预算换位执行**:入站校验时 lease 引用计**零** decoded 字节(0011 原设计,媒体不过 chat body)。故 `MAX_MEDIA_DECODED_BYTES` 改在**内联处**按 lease 记录大小执行——否则 100MiB 的 lease 上传会膨胀成没有 provider 会接受的上游请求。
3. **`MEDIA_PUBLIC_BASE_URL` 拆除**(config 字段/校验/load/deploy env):唯一消费者就是被替换的绝对化。
4. **公开拉取口保留**:`GET /v1/media/leases/{id}/content?token=…` 仍在(capability 门控,运维/诊断可用),但模型侧不再经它取内容。若将来某个 provider 确需 URL 形态,再议专用媒体子域(非 `api.` 前缀)——那需要 DNS 配合,且仍受对方策略摆布,故不预建。

## 代价与取舍

- 上游请求体增大(base64 ≈ 4/3×)。上限即 `MAX_MEDIA_DECODED_BYTES`(部署值 3MiB)——与 0011 之前「桌面端直发 base64」时代抵达 provider 的体量完全相同,无回退。
- lease 的「一次上传、多次引用」桌面侧收益(去重缓存、断点续传、chat body 不携带媒体)**全部保留**——变的只是网关→provider 这一跳。
- 放弃的是「>3MiB 媒体经 provider 回拉」的将来路线;它从未真正可用(本 ADR 即其死因),需要时按第 4 条另立。

## 顺带修复(同批)

上游 4xx 拒绝此前**完全不留日志**——本次定位为此付了约一小时的线上黑盒探测。现 `UPSTREAM_REJECTED` 在网关本地 journal 记 `backend/status/reason/provider_message`(截断 300 字符)。GW-INV-11 管的是**转发**什么,不是自己日志里能看什么;调用方拿到的仍只有粗粒度枚举。
