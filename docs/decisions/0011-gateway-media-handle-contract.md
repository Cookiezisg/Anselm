---
id: DOC-058
type: decision
status: active
owner: @weilin
created: 2026-07-25
reviewed: 2026-07-25
review-due: 2099-12-31
audience: [human, ai]
---

# 0011 — 受管路由的媒体引用契约:网关必须消费自家签发的 lease

> **⚠️ 部分被取代**:本篇的**上游那半**(网关用 `MEDIA_PUBLIC_BASE_URL` 把引用绝对化、交 provider 回拉)已由
> [ADR 0012](0012-gateway-media-inline-upstream.md) 取代为**内联转发**——上游拉取器在其边缘按主机拒绝本网关,
> 线上判别实验实证。**入站那半仍是现行法且不可动摇**:桌面端→网关只接受**相对形** lease 引用,凡带 scheme/host
> 一律拒(那条形状约束本身就是 SSRF 的对策,见下文条目 2)。读本篇时请连 0012 一起读。

## 背景 / Context

WRK-078 的 M1 目标是「聊天请求退出大 base64 时代」。规范 §6.1 第 3 条写明:**completion 只引用网关签发的 handle**。

2026-07-25 的跨仓审计发现该目标**只建成了生产端**:

- **桌面端已按此发布**:受管路由(`caps.RemoteMedia != nil`)把 media lease 的绝对 HTTPS URL 直接写进 `ContentPart.ImageURL` / `VideoURL`(`backend/internal/app/attachment/attachment.go` 的 image/video 分支与 `stagedMediaURL`),`inspect_media` 的图像复查同理。
- **网关从未实现消费端**:`internal/domain/chat/content.go` 的 `validateImage` 对非 `data:` 前缀一律返错、`validateVideo` 必须 `data:video/mp4;base64,`;`internal/domain/chat/chat.go` 的 `InboundRequest` **没有任何 media handle 字段**。

后果:**受管路由每一次带图片或视频的对话都被网关 400 拒绝**。两仓各自门禁全绿——桌面端测试用 fake uploader 断言产出 HTTPS URL,网关测试用 data URI 断言非 data URI 必 400,**交界处无人守**(网关 e2e 对 `media/leases|fetchPath|leaseId` 零命中)。

## 决策 / Decision

**网关的 chat 内容契约接受一种、且仅一种非 data-URI 媒体引用:它自己签发的 lease fetch URL。**

1. **形状**:`/v1/media/leases/{leaseId}/content?token={fetchToken}` —— 即 `complete` 响应中 `fetchPath` **原样的相对形**(不绝对化,理由见第 2 条)。**除此之外不接受任何 http(s) URL**:凡带 scheme 或 host 的一律拒,与既有「网关绝不 fetch 客户端 URL」的护栏同向(SSRF、下载放大、MIME 欺骗;`明确不做` §1.2 第 3 条)。

2. **⚠️ host 绝不可由客户端提供 —— 采用相对路径形(实现调研后定案)**

   仅校验「路径形状 + lease 归属」**不足**:攻击者可以拿自己**合法**的 leaseId+token,拼成 `https://evil.example/v1/media/leases/{自己的id}/content?token={自己的token}` —— 归属校验会通过,而**上游 provider 会去拉 evil.example**。这是一条经由 provider 的 SSRF。

   **定案:客户端在 `image_url`/`video_url` 里发 `fetchPath` 的相对形**(`/v1/media/leases/{id}/content?token=…`),**网关校验形状 + 归属后,用自己配置的公开 base 绝对化再交给 provider**。

   **为什么不是「校验绝对 URL 的 host」**:实现调研查明,网关目前**只有上游的 base URL**(`DEEPSEEK_BASE_URL` / `DASHSCOPE_BASE_URL`),**没有任何关于自身公开 URL 的配置**。而无论选哪条路,网关都**必须**知道自己的公开 base——因为最终得交给 provider 一个可拉取的**绝对** URL。既然这项配置无论如何都要新增,那就选**从结构上消灭 host 这个变量**的那条:host 永不由客户端提供,SSRF 不是「被检查掉」而是「不可表达」。

   **两仓改动**:①网关新增 `PUBLIC_BASE_URL`(启动期硬配置,与既有 upstream base 同层)②桌面端 `infra/llm/media.go` 的 `Upload` 目前返回**已绝对化**的 URL(它已严格校验 `fetchPath` 必须相对且前缀 `/v1/media/leases/`)——改为受管路由下**保留相对形**上行;BYOK 路径不受影响。

3. **分层**:形状识别归 domain(纯函数,无 IO);**归属与时效校验归 app 层**——domain 不持有仓储。为此给 `app/chat.Deps` 增加一道 DIP 端口(如 `MediaLeases.Verify(ctx, installID, leaseID, token)`),由 media service 实现,复用 `OpenLease` 已有的复合谓词:**状态为 active、未过期、HMAC 签名对得上、token hash 匹配、且属当前 install**。任一不成立 → 归并为无信息泄露的 not-found 语义(与既有 lease fetch 一致,不作存在性预言)。

4. **计量**:lease 引用对 `MaxDecodedBytes` 记 **0 字节**——媒体字节从不经过 chat body,这正是 M1 的目的;体量护栏由 `MEDIA_UPLOAD_MAX_BYTES` 在上传侧承担。**但仍计入 `MaxParts`**:部件数是提示复杂度的护栏,与传输方式无关。

5. **渲染不变**:lease fetch URL 本就是**为上游拉取而签**的短期签名 URL,校验通过后原样透传给 provider,不重写、不内联、不代取。

6. **`data:` 路径保留不动**:BYOK 与非受管路径继续走内联 data URI。本决策只新增一条受管专用的引用形态。

## 后果 / Consequences

- 受管路由的图片/视频对话从「必 400」变为可用;`inspect_media` 的视觉复查随之恢复。
- 网关新增一处必须 install-bound 的授权判定。**它是新的攻击面**:未做归属校验就等于让任一 install 引用他人 lease,故第 3 条的复合谓词不可简化;而**第 2 条的 host 校验与它同等必要**——少了它,归属校验通过的请求仍能把 provider 引向任意 host;定案的相对路径形使该 host 不可由客户端表达,故这条风险是被**消灭**而非被检查。
- **必须同时补一条把 media lease 与 chat completion 串起来的 e2e**。这条 bug 之所以活到今天,正因为两仓测试各自只覆盖自己那半;没有跨接测试,同类问题会再次发生。
- `MEDIA_ENABLED=false` 的部署下 lease 无从签发,故该形态自然不出现;但 `anselm_capabilities.multimodal.available` 仍须并入 `MEDIA_ENABLED`(独立缺陷,见 PROGRESS 高危 1),否则桌面端会宣称支持却在上传第一步吃 503。

## 备选 / Alternatives

- **桌面端退回内联 data URI**:能立刻消除 400,但等于放弃 M1(每次 sampling 重传、base64 33% 膨胀、视频很快越过合理 body 上限),与 §6.3 逐条相悖。**否决。**
- **在 `InboundRequest` 新增顶层 `mediaId` 字段**:更「干净」,但要改客户端已发布的 wire、且偏离 OpenAI 兼容形状(`content parts` 是既有联合)。用既有 `image_url`/`video_url` 承载自家 lease URL 的侵入面更小。**否决,但若将来 wire 重整可重议。**
