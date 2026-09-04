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
> 设备身份取舍见 [`ADR 0010`](../../decisions/0010-device-bound-gateway-proof.md)，
> 受管视频句柄与计费提交语义见
> [`ADR 0015`](../../decisions/0015-managed-video-signed-handle.md)。

## 1. 默认产品路径

Anselm 桌面端默认使用受管 `anselm` provider 与逻辑模型 `anselm-auto`。新 workspace 由 Go sidecar best-effort 开通受管 install、创建不可编辑的 managed api-key 行，并只为尚未设置的 scenario 播种默认值。桌面端在首次创建或发现 dialogue 默认尚未落下时，会在释放 Chat 壳前调用既有 `POST /freetier:provision` 做一次前台就绪检查；同一 workspace 的后台 hook 与前台检查由 provisioner 单飞合并，避免首发竞态与重复登记。若 workspace 在异步开通期间被删除，workspace reaper 会先取消并收束该单飞，再删除 workspace 行；晚到的 hook 不得为已删除根登记 install 或写 managed key。

配额是每次从网关读取的 live 视图。网关暂时不可达、响应损坏等上游故障统一为 `LLM_PROVIDER_ERROR`（HTTP 502）；设置页会清掉旧额度并显示可重试的 Repair 入口，而不是把旧的绿色额度继续当成当前真相。请求取消和超时仍分别保留 `CLIENT_CLOSED` / `REQUEST_TIMEOUT` 语义。

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

受管 media staging 使用一个闭合的规范 MIME 集合：`image/jpeg`、`image/png`、`image/webp`、
`video/mp4`、`audio/wav`、`audio/mpeg`。本地附件元数据可以来自桌面文件选择器，因此可能保留
标准兼容别名（例如 `audio/x-wav` 或带参数的 `audio/x-wav; charset=binary`）；sidecar 在
`infra/llm/media.go` 的网关边界将这些 WAV 别名规范化为 `audio/wav`，但不改写本地附件行。
这样登记音色和其他需要公开 staging lease 的媒体都以网关实际接受的 MIME 发起上传，原始附件
仍可按用户上传时的元数据读取。

媒体 lease 的复用只适用于可重复读取的聊天媒体。API Serve 会在音色登记的上游取样完成后立即
撤销该 lease，因此 `enroll_voice` 必须使用 `MediaClient.UploadFresh` 为每次登记重新上传同一附件；
不能把普通 `Upload` 的内容哈希缓存路径用于第二次登记。该区别由
`backend/internal/infra/llm/media_test.go` 的 `TestMediaClientUploadFresh_DoesNotReuseSpentLease`
锁定。

Cloned voice 的本地删除是两段式资源收口：sidecar 先向网关发送 `POST /voices:delete`，body
为 `{\"voiceId\":\"...\"}`，并携带当前 install 的 `X-Anselm-Install-ID`；网关在 provider 已明确报告
该 `delete_voice` 目标不存在时也按幂等删除处理，成功返回
`204 No Content`（无 body）后，sidecar 才删除 workspace 内的本地 voice 指针。网关返回非 2xx
时，sidecar 将有限的状态/原因保留在 `VOICE_CLONE_FAILED.details.upstream`，本地行保持可重试，
不得把失败误归为图像生成错误或先删本地行。该边界由
`backend/internal/infra/llm/voiceclone_test.go` 的真实 HTTP 夹具锁定。

本地指针写入也可能在上游已经成功后暂时失败；这不是把远端资源当作仍存在的理由，而是一个
必须能重试收敛的半提交状态。下一次删除仍先调用网关，网关对已不存在的精确登记返回同样的
`204`，随后 sidecar 再次删除本地行。`backend/internal/app/voice/voice_test.go` 的
`TestDelete_LocalFailureCanConvergeOnRetry` 锁住这一条，防止未来把一次本地写失败误改成永久
占位或不可重试错误。

## 3. API Serve 拥有

- 公网业务入口与 install/device-proof 验证；
- provider credential、provider 路由和上游协议适配；
- per-install 配额、全局成本护栏、账本与退款/结算语义；
- managed 图片、语音、视频、实时语音及相关 staging/lease；
- 公网 TLS、部署、回滚、监控、管理后台与 secret 管理；
- 其公开 API、配置、数据库、不变量和错误码文档。

这些责任以 `Anselm-API-Serve` 代码和 reference 为准。主仓只依赖公开 wire，
不复制上游 provider 名单、模型数量、价格或部署 secret。

**源码 HEAD 不等于线上版本。** 主仓默认 base 当前指向
`https://api.anselm.website/v1`。2026-08-06 的明确部署记录将 API Serve 提交
`0d06f6e58615fec2fd04e3c15d16aea2edaf4aef` 发布到生产：CI run `31029509745` 与
deploy run `31029785594` 均成功，部署器和独立公网请求均确认 `/healthz` 为 200。
该记录只证明这个精确提交已发布和进程在线。因此：

- 线上能力只能由 live wire / managed eval 与明确部署记录证明；
- 只有被明确部署记录点名的 API Serve SHA 才能视作线上实现；其后的 `main` 仍不能自动冒充线上版本；
- health 200 只证明进程在线，不证明 provider、费率、模型能力或部署 SHA；
- 部署切换后必须在 Backend Evolution 重新跑受影响 managed lane，再把交集写回本页。

## 4. 运行时配置

| 配置 | 语义 |
|---|---|
| 无配置 | 使用编译进代码的线上 Anselm API base |
| `ANSELM_GATEWAY_URL` | 显式覆盖受管网关 origin，供隔离测试/本地网关；不是 provider base URL |
| `ANSELM_PROOF_HOST` | 覆盖 device-proof `htu` 签进的主机（`deviceproof.EnvProofHost`）。htu 按 DPoP 式点名请求目标，受管流量因此**天生反代理**；唯一正当例外是设备自己的本地录制代理（验收台架线缆见证者，WRK-087）——请求物理上途经 127.0.0.1，证明仍点名真实受众。只放宽请求**途经**哪里、不放宽证明能**花在**哪里；不设 = 行为逐字不变 |
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

其中 `animate_image` 的受管能力门槛比 `generate_video` 更窄：`/models` 必须同时声明
`anselm_capabilities.video_generation.available=true` 与 `image_to_video=true`。只有
`video_generation.available=true` 时，网关仍可能提供文生视频，但桌面端必须隐藏
`animate_image`，不把未知的图生视频契约猜成已支持。

这不是桌面端对厂商模型名的臆测：上游模型目录将 `wan2.7-t2v` 列为文生视频，将首帧图生视频
列为独立的 `wan2.7-i2v` 模型。Wan 2.7 I2V 的请求协议也独立：首帧必须是
`input.media=[{"type":"first_frame","url":"data:..."}]`，不是旧版 `img_url`。因此网关若只配置
`wan2.7-t2v`，即使提交端点相同，也不能向桌面宣告 `image_to_video=true`。参见阿里云
[视频生成与编辑模型选择](https://help.aliyun.com/zh/model-studio/video-generate-edit-model)、
[Wan 2.7 图生视频 API](https://help.aliyun.com/en/model-studio/image-to-video-general-api-reference)
和 [Wan 2.7 文生视频 API](https://help.aliyun.com/en/model-studio/text-to-video-api-reference)。

## 6. 失败与恢复

- 后端自动 hook 的开通是 best-effort：网关不可达不能阻塞本地启动或 API workspace 创建；桌面首启会在 Chat 壳内显示「正在准备工作区…」，等待前台检查返回，最多 20 秒，降级后仍释放本地壳供 BYOK/设置恢复。
- workspace 删除先停止并等待该 workspace 的异步 provision flight；取消属于生命周期收束，不作为免费档故障 WARN，也不允许在删除行之后写入 managed key。
- 已有 managed 行只有在网关明确返回 `INVALID_INSTALL` 时才重新登记并原位轮换 install id；网络闪断、限流或临时 5xx 不得毁掉有效 install。
- managed 行对用户不可编辑/删除；quota 与能力由 sidecar 代理读取。
- 默认 live/evals 通过部署网关验证受管路径；BYOK 对照必须显式开启并自行提供测试 key，不能由 managed fallback 代跑。
- 任何测试、日志与文档都不得输出或提交用户 key、device-proof 私钥或网关 secret。
