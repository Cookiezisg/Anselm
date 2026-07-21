---
id: DOC-057
type: decision
status: active
owner: @weilin
created: 2026-07-21
reviewed: 2026-07-21
review-due: 2099-12-31
audience: [human, ai]
---

# 0010 — 将受管免费档绑定到安装密钥

## 决策 / Decision

Go sidecar 为每次安装创建一对 Ed25519 密钥。它用现有 master-key `Encryptor` 仅加密 32-byte seed，以 `0600` 权限保存至 `$ANSELM_DATA_DIR/device-proof.key`，并把所有签名限制在 Go 进程内；Flutter 永不接触私钥。

受管 `anselm` API-key 行只保存 Gateway 的公开 `installId`，不保存可复用 bearer credential。`infra/deviceproof.Transport` 获取并缓存 Gateway 的五分钟 challenge，再签署 method、小写 authority 与 request target、精确 body hash、签发时间及随机 request id。nonce 失效时，它在 Gateway 执行业务前刷新并最多重试一次。

同一 transport 注入 install、chat、quota 与受管 key 的 `/models` probe；其他 provider 原样通过。产品未上线，因此不提供 bearer 兼容模式。

该 profile 采用 [RFC 9449 DPoP](https://www.rfc-editor.org/rfc/rfc9449.html) 的 `jti`、`iat`、`htm`、`htu` 与服务端 nonce 思路，并按 [RFC 9421 HTTP Message Signatures](https://www.rfc-editor.org/rfc/rfc9421.html) 的消息完整性原则额外绑定精确 body digest；它不是 OAuth token flow，也不宣称 wire-level RFC 兼容。

## 后果 / Consequences

复制数据库行或捕获单次请求不能获得可复用的免费档访问权。加密 seed 丢失会产生新的安装身份，Gateway 按设计无法恢复私钥。这是 possession proof，不是 platform attestation：能够控制并修改开源客户端的攻击者仍可注册另一把密钥，因此 Gateway 的 issuance PoW/rate gate 继续承担批量滥用成本层。
