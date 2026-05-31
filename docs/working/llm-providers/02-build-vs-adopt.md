---
id: WRK-002-02
type: working
status: archived
owner: @weilin
created: 2026-05-25
reviewed: 2026-05-30
review-due: never
audience: [human, ai]
landed-into: docs/concepts/architecture.md
---
# 自己写 vs 用开源：LLM 多厂商方案选型（2026-05-29）

> **问题**：配 key 配模型要完美无 bug，这层我们是不是不用自己写？有没有开源能替掉手写的 `infra/llm`？
> **方法**：三路并行核实——Go 多厂商库 / 自托管网关 / OpenRouter 兜底，全部查官方文档与源码。
> **状态**：调查完成，结论驱动选型。配套审计见 `01-provider-capability-audit.md`。

---

## §0 结论

1. **没有任何 Go 进程内库能干净替掉手写 `infra/llm` 而不倒退。** 唯一成熟的（Bifrost）对我们**一半的厂商（DeepSeek/Qwen/智谱/Kimi/豆包）不是一等公民**，落到通用 OpenAI-compat 透传、零 thinking 归一——对这半边它给的比现状**更少**；且它在 reasoning+工具循环接缝处有**活着的漏抽象 bug（#3688）**，正是当年踢掉 Eino 的那类后悔。
2. **手写 client 是对的决定**——代价（per-provider 正确性自己保）有限、可控。
3. **但长尾可以外包**：OpenRouter（你已经支持了）一个 key 通 300+ 模型含全部中国厂商,且**统一 `reasoning` 参数**把 thinking 编码归一。**BYOK 让它与"用自己的 key"身份和解**（用户挂自己的上游 key、账单走自己的 provider、单用户每月 100 万次免费 ≈ 永久免费）。代价:云中转(削弱 local-first)+ 费率模型在变(见 §3)。
4. **→ 推荐混合策略(§4)**:手写核心只需**修 3 个真 bug + 搭零-key 测试骨架**;长尾 + thinking 归一交给 OpenRouter 兜底;自己写 thinking 编码可**推迟**。你的 build 范围因此缩小。

---

## §1 候选对比

### Go 进程内库

| 库 | 中国厂商一等公民? | thinking 归一? | 抽象重量 | 健康度 | 判决 |
|---|---|---|---|---|---|
| **Bifrost** (maximhq) | 🔴 否(DeepSeek/Qwen/智谱/Kimi/豆包走通用透传) | ✅ 对西方厂商真归一 | 重(gateway 架构 + OpenAI schema 世界观;拉 AWS/Azure/GCP SDK 树几十 MB;go 1.26) | 5.3k★,活跃 | **不适配**:对半数 provider 倒退 + 漏抽象 bug #3688 = Eino 翻版 |
| **any-llm-go** (Mozilla) | 🔴 缺 Qwen/Kimi/豆包/OpenRouter | ✅ 但单一 effort 旋钮、有损 | 轻 | 126★,pre-1.0 | 理念最对、太年轻、覆盖不够 |
| **llmhub** (gotoailab) | ✅ 唯一全列中国厂商 | 🔴 完全没有 | 轻 | 54★,无 release | 覆盖对、reasoning 与维护双崩 |
| **langchaingo** | 🔴 | 🔴 无统一 | 重(链/agent 框架) | — | 既无覆盖也无 thinking,不是这类工具 |
| 单厂商 SDK(go-openai 等) | — | — | — | — | 是"原料"不是"成品",你已在用 |

> 设计标杆(非 Go):Vercel AI SDK(TS,8 家统一 reasoning)、LiteLLM(Python,100+ 家 + reasoning)。**Go 进程内无人达到此线**;Go 世界的等价物是个**服务**(Bifrost),不是库。

### 自托管/嵌入网关

| 网关 | 语言/运行时 | 形态 | 能塞进单二进制桌面 app? |
|---|---|---|---|
| LiteLLM proxy | **Python** | pip/Docker(+Postgres) | 🔴 要 Python 运行时,违反纯 Go 打包 |
| Portkey gateway | **TS/Node** | npx/Node/Workers | 🔴 要 JS 引擎 |
| Cloudflare AI Gateway | SaaS | **仅托管** | 🔴 不能自托管 |
| Helicone | Rust | sidecar 进程(npx/Docker 分发) | ⚠️ 能交叉编译但是独立进程 + IPC,观测向、无 thinking 归一,不值 |
| **Bifrost /core** | **Go** | 可 import,`bifrost.Init()` 进程内 | ✅ 唯一 Go-native 可嵌入——但见上表"不适配" |

### OpenRouter(托管,已集成)
见 §3。

---

## §2 为什么"手写仍是对的"(证据)

1. **覆盖**:每个 Go 多厂商库要么跳过我们的中国厂商(Bifrost 一等公民表、any-llm-go、langchaingo),要么当通用 OpenAI-compat 零特化(llmhub 还零 reasoning)。手写代码对这半边做得**比它们都多**(Anthropic 原生线 + 各家 OpenAI-compat 微调)。
2. **thinking 归一恰好在"覆盖"与"归一"分叉处**:Bifrost 只对它觉得容易的厂商归一 thinking;覆盖难厂商的(llmhub)啥都不归一。**没有 Go 库对中国厂商集同时给到这两样。**
3. **Eino 教训重演**:唯一成熟候选(Bifrost)gateway 形状、schema 强意见、且在 reasoning+tool-use 接缝有**活 bug #3688**(Bedrock 适配器 toolUse/reasoningContent 错序 → 400)。换它 = 拿小而可控可调的自有面,换一个大的外部面再去打补丁——正是后悔模式。
4. **架构错配**:Bifrost 的价值(负载均衡/故障转移/治理/可观测/5k RPS)是 fleet/gateway 价值,单用户单二进制 local-first 桌面 app 不需要;它的库模式仍把那套世界观带进来。

---

## §3 OpenRouter 当兜底——一等的"懒人逃生口"

| 维度 | 结论 |
|---|---|
| 覆盖 | ✅ 一个 key 通 300+ 模型,含 DeepSeek/Qwen/智谱/Kimi/豆包 + Gemini/Anthropic/OpenAI,全归一到 OpenAI 线(我们已会说) |
| thinking 归一 | ⚠️ 统一 `reasoning:{effort\|max_tokens, exclude, enabled}`,**省掉大部分 per-provider 编码**;但非零:OpenAI 不回 reasoning 文本、Gemini 预算不精确、round-trip 要处理 encrypted/signed `reasoning_details` |
| 价格 | ✅ token **无加价**(直传上游价);仅充值时收 ~5-5.5% |
| **BYOK** | ✅✅ **关键**:用户挂自己上游 key → 账单走用户自己的 provider 账户、不烧 OR credit;**每月 100 万次 BYOK 免费**(单用户 ≈ 永久免费)。这就是与"用自己的 key"和解的机制 |
| 隐私/local-first | ⚠️ **即便 BYOK + ZDR,每个 token 仍明文过 OpenRouter 云**——与"你的 key 你的机器"本质不同,只能披露不能消除 |
| 费率稳定性 | 🔴 OpenRouter **已公告** BYOK 费要从"5% + 100 万免费"转向**固定月费订阅**(价格未定)→ 兜底依赖可能将来被加墙 |
| 可靠性 | ✅ 池化 uptime + 自动 fallback(但 BYOK 固定上游时 fallback 关闭) |

**用法**:作为**显式、opt-in、UI 明确标注"云中转(非 local-first)"**的一个 provider 入口,覆盖"其它一切";强引导 BYOK;默认 `zdr:true`;不把 1% 日志折扣做成默认。**不当默认路径。**

---

## §4 推荐:混合策略(build 范围收缩)

| 层 | 做法 | 谁来 |
|---|---|---|
| **直连核心(local-first 卖点)** | 保留手写 `infra/llm`;**只修 3 个真 bug**(Gemini 404 / Ollama base-path / custom 死路);搭**零-key 黄金 + httptest 骨架**钉死正确性 | **自己写**(这就是"配 key 配模型无 bug"的诉求,且 local-first 直连不可外包) |
| **长尾厂商 + 模型** | OpenRouter(已集成),opt-in + BYOK + 标注云中转。**不必自己完美化豆包/Kimi/Qwen 等长尾** | **外包给 OpenRouter** |
| **thinking 开关** | 长尾经 OpenRouter `reasoning` 自动归一;直连 3-4 家的自写 thinking 编码(含 Anthropic signature)**可推迟**,想做再做 | **推迟 / 部分外包** |

**这答了"我是不是不用全自己写":对——长尾不用,thinking 归一长尾也不用。但你直连提供的那几家的 bug 必须自己修(它们就是 local-first 直连路径,且确实坏)。**

→ 落地 spec 范围因此从"排雷 + 全 thinking"收缩为:**修 3 真 bug + 零-key 测试骨架 + OpenRouter 兜底 UX(BYOK/标注)**;thinking 编码独立推迟。

---

## 参考来源
- Go 库:[Bifrost](https://github.com/maximhq/bifrost) · [reasoning 映射](https://docs.getbifrost.ai/providers/reasoning) · [漏抽象 bug #3688](https://github.com/maximhq/bifrost/issues/3688) · [any-llm-go](https://github.com/mozilla-ai/any-llm-go) · [llmhub](https://github.com/gotoailab/llmhub) · [langchaingo](https://pkg.go.dev/github.com/tmc/langchaingo)
- 网关:[LiteLLM](https://github.com/BerriAI/litellm) · [Portkey](https://github.com/Portkey-AI/gateway) · [Helicone](https://github.com/Helicone/ai-gateway)
- OpenRouter:[models](https://openrouter.ai/docs/guides/overview/models) · [reasoning](https://openrouter.ai/docs/guides/best-practices/reasoning-tokens) · [BYOK](https://openrouter.ai/docs/guides/overview/auth/byok) · [平台费/将转月订阅](https://openrouter.ai/announcements/simplifying-our-platform-fee) · [ZDR](https://openrouter.ai/docs/guides/features/zdr)
- 标杆:[Vercel AI SDK reasoning](https://ai-sdk.dev/v7/docs/ai-sdk-core/reasoning) · [LiteLLM reasoning_content](https://docs.litellm.ai/docs/reasoning_content)
