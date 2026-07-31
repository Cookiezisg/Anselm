---
id: DOC-071
type: reference
status: active
owner: @weilin
created: 2026-07-31
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# 已部署 Anselm API——主仓接缝与责任边界

> 本篇只登记本仓必须与已部署 Anselm API 保持一致的公开接缝。网关的 provider key、路由、费率、账本、运维与 CI/CD 由同级 `Anselm-API-Serve` 仓库独立治理；主仓不得复制其私密配置或把其内部实现当本地契约。

## 1. 默认产品路径

Anselm 桌面端默认使用受管 `anselm` provider 与逻辑模型 `anselm-auto`。新 workspace 由 Go sidecar best-effort 开通受管 install、创建不可编辑的 managed api-key 行，并只为尚未设置的 scenario 播种默认值。

用户不需要为默认路径提供 OpenAI、Gemini、Qwen、DeepSeek 或其他 provider key。provider secret 只存在于部署网关，既不进入 Flutter，也不进入主仓 `.env`、数据库、日志或诊断复制。

## 2. 本仓拥有

| 责任 | 物理位置 |
|---|---|
| 机器级 Ed25519 device-proof 私钥的创建、加密落盘与逐请求签名 | `backend/internal/infra/deviceproof/` |
| install 登记、managed 行创建/修复、scenario 默认播种 | `backend/internal/app/freetier/` |
| managed provider 适配、公开模型能力读取与错误归一 | `backend/internal/infra/llm/anselm.go` |
| workspace、对话、附件、MediaRef、工具、flowrun 等本地业务真相 | 本仓 backend 各 domain/app/store |
| 本地上传转 managed media staging/lease、产物回收为附件 | `infra/llm/media.go` 与生成工具族 |
| quota、ASR、生成工具等供 Flutter 使用的 loopback API | 本仓 `/api/v1/*` |
| BYOK key 的本地加密存储、probe、能力目录与直连读取 | apikey/model/llm |

Flutter 只调用本地 sidecar。它不持 device-proof 私钥，也不直接调用部署网关。

## 3. API Serve 拥有

- 公网业务入口与 install/device-proof 验证；
- provider credential、provider 路由和上游协议适配；
- per-install 配额、全局成本护栏、账本与退款/结算语义；
- managed 图片、语音、视频、实时语音及相关 staging/lease；
- 公网 TLS、部署、回滚、监控、管理后台与 secret 管理；
- 其公开 API、配置、数据库、不变量和错误码文档。

这些事实以 `Anselm-API-Serve` 当前代码和 reference 为准。主仓只依赖公开 wire，不复制上游 provider 名单、模型数量、价格或部署 secret。

## 4. 运行时配置

| 配置 | 语义 |
|---|---|
| 无配置 | 使用编译进代码的生产 Anselm API base |
| `ANSELM_GATEWAY_URL` | 显式覆盖受管网关 origin，供隔离测试/本地网关；不是 provider base URL |
| `ANSELM_GATEWAY_INTEGRATION_URL` | 只启用独立 gateway integration test |

主仓不需要 `DASHSCOPE_API_KEY`、`ANSELM_DASHSCOPE_BASE` 或部署网关的任意 provider secret。若某个 BYOK provider 需要 key/base URL，它通过产品的 Models & Keys 写入本地加密存储，而不是作为默认受管路径的启动前提。

## 5. Managed 与 BYOK

| 能力 | Managed 默认路径 | BYOK |
|---|---|---|
| 文本/多模态读取 | 可用能力由网关 `/models` 投影 | 按本地 provider 目录与 probe 能力 |
| 图像/语音/视频生成与编辑 | 受管 capability tool | 不提供生成方言；工具诚实缺席 |
| provider 费用与密钥 | 网关承担并按受管配额治理 | 用户自己的 provider 账户；key 本地加密 |
| 设备证明 | 必须 | 不使用 |

生成能力与输入理解分开：BYOK 模型可以读取支持的文本/图片/视频/文档，并可作为 planner 消费 managed 生成产物；它不因此获得本仓未实现的 BYOK 生成工具。

## 6. 失败与恢复

- 开通是 best-effort：网关不可达不能阻塞本地启动或 onboarding。
- 已有 managed 行只有在网关明确返回 `INVALID_INSTALL` 时才重新登记并原位轮换 install id；网络闪断、限流或临时 5xx 不得毁掉有效 install。
- managed 行对用户不可编辑/删除；quota 与能力由 sidecar 代理读取。
- 默认 live/evals 通过部署网关验证受管路径；BYOK 对照必须显式开启并自行提供测试 key，不能由 managed fallback 代跑。
- 任何测试、日志与文档都不得输出或提交用户 key、device-proof 私钥或网关 secret。
