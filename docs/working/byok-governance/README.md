---
id: WRK-085
type: working
status: active
owner: "@weilin"
created: 2026-07-28
reviewed: 2026-07-28
review-due: 2026-10-26
audience: [human, ai]
landed-into:
---

# WRK-085 · BYOK 治理:「写」留给自己,「读」交给目录

> 用户 2026-07-28 拍板。本文档是这条治理的**唯一事实源**,直到它 landed 进
> `references/`。两个工单:**H11**(生成收归受管)、**H12**(BYOK 全覆盖)。

---

## 0. 一句话

**「写」留给自己,「读」交给目录。**

- **写**(生成图/语音/视频/音色)= 我们出钱、我们维护方言 → **只在受管档**
- **读**(文本、看图、看视频、听音频)= 目录给能力、方言零维护 → **BYOK 全开**

---

## 1. 判据是怎么来的

最初的候选判据是「文本 vs 多模态」——BYOK 只做文本。它**错在会误伤多模态输入**:
用户拿自己的 vision 模型看一张图,这件事没有方言问题、没有维护成本、不花我们的钱,
而且**今天就是通的**(本轮全部真钱验收都是 `qwen3-vl-plus` 在看图)。

真正的成本线在别处。2026-07-28 一天踩的坑:

| 坑 | 在哪一侧 |
|---|---|
| 同一供应商两个域名,工具参数一个发增量、一个发累积值 —— 七个方言全废 | 写 |
| `qwen-audio-3.0-tts-flash` **只有 WebSocket**,两条 HTTP 都答 `url error` | 写 |
| `voice-enrollment` **只收公网 URL**,data: 会被拿去跑 ASR 然后 500 | 写 |
| `qwen-tts` 这个 model id 在 customization 端点上**根本不存在** | 写 |
| 登记是**异步**的,DEPLOYING→OK 之前不可用 | 写 |

**五个坑,五个都在「写」那一侧,「读」那一侧一个都没有。**
这不是巧合——「读」是 OpenAI 兼容协议里最标准化的部分,五家写法一模一样。

---

## 2. 能力面

| 能力 | Anselm 受管 | BYOK |
|---|---|---|
| 文本对话 | ✅ | ✅ |
| **多模态输入**(看图/看视频/听音频) | ✅ | ✅ |
| 出图 / 改图 | ✅ | ❌ |
| 出语音 / 朗读 | ✅ | ❌ |
| 出视频 / 图生视频 | ✅ | ❌ |
| 参考音色 | ✅ | ❌ |

**朗读要单列一句**:它不是工具、是 `GET/POST /api/v1/read-aloud:*` 两条独立端点,UI 直调、零 token。
按「工具」去关会**漏掉它**。它是个功能,不是 chat 主链路,直接走受管。

**多模态输入关不掉、也不会报错**:`ToContentParts` 的能力闸**刻意降级成文本注记**
([ADR 0020](../../decisions/0020-capability-decides-model-input.md),由「一个节点烧掉十张真图」的
成对真钱实验定的)。故「不支持就报错、用户能清楚知道」这个假设**不成立**——这也正是不该主动去破坏
它的理由之一:**主动关掉它反而要写两处代码**(关能力 + 让它报错)。

---

## 3. 每一条信息从哪来

| 信息 | 来源 | 我们维护吗 |
|---|---|---|
| 有哪些 provider | models.dev | ❌ |
| 有哪些模型 | models.dev | ❌ |
| 模型能读什么(模态) | models.dev `modalities.input` | ❌ |
| 上下文 / 输出上限 | models.dev `limit` | ❌ |
| base URL | models.dev `api` | ❌ |
| 价格 | models.dev `cost` | ❌ |
| **用哪条方言** | models.dev **`npm`** | ❌ |
| **方言实现本身** | **我们的代码** | ✅ ← 唯一 |

### 3.1 我曾提「三处不能交出去」,已作废

逐条为什么错:

**① base URL** —— 我曾说 models.dev 给的是将下线的 `dashscope-intl`。但那个反对**默认了「我们的值更好」**,
而我们 hardcode 的是**北京**——对这把新加坡 key **更差**(H0 那次真 401 正是它造成的)。
moonshot 我们写 `.cn`、它写 `.ai`,至今不知谁对。
**没有任何一方权威**,故该交出去 + 把覆盖路径做扎实。

**② 价格只有 token 形状** —— H11 之后 BYOK **没有生成能力**,token 形状对 chat 恰好是对的。自动消解。

**③ 目录不描述方言** —— **概念混了**:方言是**代码**、不是配置,从来不在「配置」这个范畴里。
而且实测发现目录**连方言都给了**(见 §4)。

---

## 4. `npm` 字段就是方言标记

**关键认识:`npm` 说的是「用哪个 SDK 包」,不是「线缆协议」。**
22 个不同的 npm 值背后,真协议只有 3~4 种。

173 家分布(实测 2026-07-28):

```
@ai-sdk/openai-compatible    137 家
@ai-sdk/anthropic              9 家
@ai-sdk/openai                 4 家
@ai-sdk/google                 1 家
                             ─────
                             151 家  → 落在我们已有的三条方言上
```

映不上的 22 家 / 1518 模型,**大部分仍是 OpenAI 兼容**,只是各自发了个包:

| npm | 谁 | 真协议 |
|---|---|---|
| `@openrouter/…` `@ai-sdk/gateway` `ai-gateway-provider` `merge-gateway…` `@aihubmix/…` | OpenRouter / Vercel / Cloudflare / Merge / AIHubMix | OpenAI 兼容 |
| `@ai-sdk/groq` `xai` `togetherai` `cerebras` `deepinfra` `perplexity` `mistral` `vercel` | Groq / xAI / Together / Cerebras / DeepInfra / Perplexity / Mistral / v0 | OpenAI 兼容 |
| `@ai-sdk/google-vertex` | Vertex | Google generateContent |
| `@ai-sdk/google-vertex/anthropic` | Vertex(Anthropic) | Anthropic Messages |
| **`@ai-sdk/azure`** | Azure ×2 | **deployment 在路径 + `api-version` query** |
| **`@ai-sdk/amazon-bedrock`** | Bedrock | **AWS SigV4 签名** |
| `@ai-sdk/cohere` | Cohere | 待调研 |
| `@jerome-benoit/sap-ai-provider-v2` `gitlab-ai-provider` `venice-ai-sdk-provider` | SAP / GitLab Duo / Venice | 待调研 |

**真正要新写的只有 Azure 与 Bedrock**——它们差在 URL 形状与鉴权方案,**没有任何目录能表达那两样**。
其余长尾**零新代码**,按 OpenAI 兼容默认即可。

---

## 5. 现状:10 份 ParseStream,其中 8 份重复

```
anthropic.go   custom.go   deepseek.go   gemini.go   moonshot.go
ollama.go      openai.go   openrouter.go qwen.go     zhipu.go
```

**除 anthropic / gemini 外的 8 份都是 OpenAI 兼容的近似重复。**
今天那个工具参数线缆 bug 因此要修**七遍**——重复的代价已经被自己证明完了。

⚠️ **`anselmProvider` 内嵌 `deepseekProvider`**:受管路由复用那份实现。合并时一起处理,
否则会顺手改坏受管侧。

---

## 6. UI —— 照 MCP 市场那一页的文法

`McpMarket`(`features/settings/ui/panels/mcp_forms.dart:294`)已经是这个形状,**照抄、不新造**:

- **全部供应商一上来就铺开**(不是「只显示已配的」),`AnAutoGrid(minColWidth: AnSize.block)` 自动双列
- 每张卡:**ICON + 名字 + 信息**(模型数、能力摘要、是否已配 key)
- 顶部 `AnInput` 搜索框 `autofocus`,输入**逐渐收窄**(匹配名字 + 描述)
- 空结果落 `AnState(kind: empty, size: inset)`
- 卡片 hover / 键盘 focus **揭示 CTA**(「配置」),整卡点击进详情表单——与 `_MarketCard` 同一套 App-Store 文法
- **不做分组、不维护任何名单**——分组本身就是一张要维护的表
- **模型选择同构**:选定 provider 后同样的双列 + 搜索

> 数量提醒:151 家里排前面的是聚合器(NanoGPT 617 模型、Kilo Gateway 346、LLM Gateway 185),
> 一手厂商会被埋。搜索框是唯一的答案——用户来配 BYOK 时**心里已经有一家了**,他不是来浏览的。

---

## 7. 三种失败必须分清

我们**一家都没真验过**——只知道「目录说它是 openai-compatible」。故报错要能区分:

1. **你的 key 不对** —— 上游 401/403
2. **这家我们没试过** —— 长尾按 OpenAI 兼容猜的,标「未验证」
3. **这条方言我们不会说** —— 映不上且用户没自定义

对用户是三件不同的事,合并成一个「连接失败」等于把责任推回给他却不告诉他往哪查。

**base URL 空着时不猜**:现在 qwen 会回落到北京(必然 401)。改成直说
「去控制台复制你的 API Host」——**没有任何一方**知道用户的工作区域名,猜就是错。

---

## 8. 用户覆盖

**JSON 里一切都能改**,包括 base URL、模型 id、能力声明、**强行指定方言**。
覆盖之后**责任归他**。

唯一表达不了的是「新增一条方言」——那是代码。文档里要写死这一点,
否则用户会以为写个 JSON 就能接任意 provider。

---

## 9. 工单

### H11 · 生成收归受管(#31)

- 六工具 + 朗读的 `Available()` 收窄到 `route.provider == "anselm"`
- 删直连生成方言:`imagegen.go`(460) / `speechgen.go`(513) / `videogen.go`(620) / `voiceclone.go` 残余 ≈ **1700 行**
- 连带删:`gen_spend` 直连支出台账、`prices.go` 整表、前端支出卡的生成品类
- **多模态输入一行都不动**

### H12 · BYOK 全覆盖(#30)

| 步 | 事 |
|---|---|
| a | 8 份 OpenAI-compat 合并成 1(**先做**,否则后面每加一家都是七倍工作量) |
| b | 目录裁剪放宽;无 `tool_call` 的模型标「能聊天、不能当 agent」 |
| c | `npm` → 方言映射,长尾默认 OpenAI 兼容并标「未验证」;删手写 provider 表与 `DefaultBaseURL` 常量 |
| d | Azure(URL 形状)+ Bedrock(SigV4)+ 三家待调研 → **173/173** |
| e | UI 照 §6;报错分三种;base URL 空着不猜 |

**覆盖率**:现在 10 家 → a·b·c 后 169 家 / ~5800 模型 → d 后 **173/173**。

---

## 10. 顺带要清的

- `prices.go` 注释说「models.dev 的 chat 谓词把纯生成模型整个滤出了目录」——**那是我们 vendor 时的裁剪**,
  不是上游的缺失。上游 5802 个模型里 **284 个输出 image/audio/video**。随 H12-b 改掉。
- 手写 `prices.go` 整表随 H11 删除。
- 查实 moonshot 我们写 `.cn` / models.dev 写 `.ai`,哪个对。
