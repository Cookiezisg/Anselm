---
id: WRK-085
type: working
status: archived
owner: "@weilin"
created: 2026-07-28
reviewed: 2026-07-29
review-due: 2026-10-26
audience: [human, ai]
landed-into:
  - docs/references/backend/foundation/stream-llm.md
  - docs/references/backend/api.md
  - docs/references/frontend/features/settings.md
  - CLAUDE.md
---

# WRK-085 · BYOK 治理:「写」留给自己,「读」交给目录

> 用户 2026-07-28 拍板。**已 landed(2026-07-29)——本文档从此是历史记录,不再是事实源。**
> 当前事实在 `references/backend/foundation/stream-llm.md`(能力目录 / 方言 / 旋钮 / base URL 三层)、
> `references/backend/api.md`(`GET /providers` 契约)、`references/frontend/features/settings.md`
> (供应商市场 + 三种失败)与 `CLAUDE.md`。两个工单 **H11**(生成收归受管)、**H12**(BYOK 全覆盖)均已完成。
>
> **下文保留开工时的原样**,包括几处**后来被实测推翻**的判断——那些推翻本身是这份记录最值得留下的
> 部分,已在 §4 与 §11 就地标注。

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
| **有哪些思考旋钮** | models.dev **`reasoning_options`** | ❌ |
| **方言实现本身**(含旋钮在线缆上叫什么) | **我们的代码** | ✅ ← 唯一 |

> **「旋钮」这一行原本漏了**(H12-c 补)。它不是被豁免、是没写进来:WRK-082 的 P4「旋钮不折腾」是
> **迁移期**的决定(「别为了迁目录去扩建旋钮,也别让旋钮挡住迁移」),而 WRK-085 换治理时没人回头重审它。
> 代价在两个世界里不一样——十家时手写表覆盖得住,**173 家时它意味着一百多家的思考控件永远不出现**
> (批A 的 A4:未命中手写前缀 = 零旋钮)。目录在 **3744 个模型**上声明了这件事,逐模型、比我们的前缀表更准:
> 手写规则 `{"deepseek", …}` 匹配**所有** deepseek id,把思考控件也发给了 `deepseek-chat` ——而它根本不是
> 推理模型。**目录说有什么控件、取值是什么;我们说它在这条线缆上叫什么**(`reasoning_effort` /
> `thinking` / `enable_thinking` 三家三种拼法),后者仍属「方言实现」那一行。

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
| `@ai-sdk/google-vertex` `@ai-sdk/google-vertex/anthropic` | Vertex ×2 | **OpenAI 兼容 body + 服务账号 OAuth2**(H12-d 实测推翻本行原判) |
| **`@ai-sdk/azure`** | Azure ×2 | **deployment 在路径 + `api-version` query**(body 与 OpenAI 逐字相同) |
| `@ai-sdk/amazon-bedrock` | Bedrock | **OpenAI 兼容**(H12-d 调研推翻本行原判:Converse+SigV4 只是那个 SDK 的选择) |
| `@ai-sdk/cohere` | Cohere | OpenAI 兼容(**另一个 base**,见 §4.1) |
| `@jerome-benoit/sap-ai-provider-v2` `gitlab-ai-provider` `venice-ai-sdk-provider` | SAP / GitLab Duo / Venice | Venice = OpenAI 兼容;SAP / GitLab **留在未验证**(见 §4.1) |

**开工前写的这一行是错的,两个方向都错**:「真正要新写的只有 Azure 与 Bedrock」——
Bedrock **不必写**(它自己也在 `/openai/v1` 上讲 OpenAI 兼容、普通 bearer),
Vertex **必须写**(它看着像 Gemini 的表亲、实际要服务账号)。教训写进代码注释与 `stream-llm.md`:
**`npm` 说的是「存在哪个 SDK」、不是「这家能说什么」,而它两个方向都会误导。**
其余长尾**零新代码**,按 OpenAI 兼容默认即可。

### 4.1 三条方言的最终形状(H12-d 收口)

| 方言 | 家数 / 模型 | 与 OpenAI 兼容的差别 | 实现 |
|---|---|---|---|
| `openai-compatible` | 159 / 5293 | —— | `compat.go` 一份 |
| `anthropic` | 9 | Messages API | `anthropic.go` |
| `azure` | 2 | deployment 在路径 · `api-key` 头 · `api-version` query | `azure.go`(43 行 spec) |
| `google` | 1 | generateContent | `gemini.go` |
| `vertex` | 2 / 51 | URL 拼 project+location · 服务账号签 JWT 换 OAuth2 token | `vertex.go`(spec + 两个钩子) |

Azure 与 Vertex **都不是新的 ParseStream**——它们各自只填 `compatSpec` 的 `chatURL` / `auth` 两个钩子,
因为**它们与 OpenAI 的差别全在 URL 与头上、body 逐字相同**。这正是 H12-a 把八份实现并成一份时
买到的东西:**新增一条「方言」的代价降到了一份 spec。**

**四家 base URL 的出处**(读官方文档、非凭记忆):cohere 的 OpenAI 兼容端点与其原生 `/v2/chat`
**不是同一个 base**;venice 是 `api/v1`;gitlab / sap 的 base **因实例而异**,归用户填 ——
后两家因此**留在未验证**(`Curated=false`),UI 会说「这家我们没试过」。

### 4.2 base URL 三层兜底(H12-f)

目录 `api`(149 家) → `knownBaseURLs` 预填 → `knownBaseURLHints` 形状 → 空着要用户填。

`knownBaseURLs` 的每一行都是**从已发布的 SDK 包源码里读出来的**:

```
curl https://cdn.jsdelivr.net/npm/<pkg>/dist/index.mjs
grep 'baseURL = withoutTrailingSlash(options.baseURL) ?? "…"'
```

**凭记忆写不算证据。** 一个记错的 URL 会以「你的 key 无效」的形态失败,而那句话是**假的**——
用户会跑去重抄一把本来就没错的 key。读源码当场逮到两个反直觉的事实:

| 家 | 我以为 | 包里真正写的 |
|---|---|---|
| perplexity | `https://api.perplexity.ai/v1` | `https://api.perplexity.ai`(**没有 `/v1`**) |
| deepinfra | `https://api.deepinfra.com/v1` | `https://api.deepinfra.com/v1/openai`(`/v1` 是它的**原生** inference API) |

`knownBaseURLHints` 是**地址真的没法预填**的那些家:azure 的 resource、bedrock 的 region、
cloudflare gateway 的 account+gateway、vertex 的 region。它们拿到**形状**、仍然必填。
光一句「必填」**没法照着做**——一个盯着空栏的用户不知道该填的是他自己的 resource 名;模板说了。

顺带修掉两个:**ollama** 拿到 `http://localhost:11434/v1`(它自己文档每个例子都印着的标准端口——
让用户手打一个刚装好的 daemon 的标准端口,等于要求他知道一个我们已经知道的常量);
**vertex 的区域解析**补上 `aiplatform.{eu|us}.rep.googleapis.com` 这一形状——
它里面**没有** `-aiplatform.`,只认第三种形状的解析器会静默答 "global"、去为错误的 location 拼 URL。

收口:**166 家预填 / 10 家给形状 / 5 家纯空**(custom · mock 按定义无址可填;
gitlab · sap-ai-core 的 base 在客户自己的实例里)。

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

> **落地订正**:这句「一家都没真验过」写于开工时。收口时 8 家已带 `curated=true`
> (openai / anthropic / google / deepseek / alibaba / moonshotai / zhipuai / openrouter——手写过
> spec、多数用真 key 跑过),其余约 160 家仍是「未验证」。三种失败的分法**不变**,它正是为这个
> 8 : 160 的分布而设计的。

1. **你的 key 不对** —— 上游 401/403
2. **这家我们没试过** —— 长尾按 OpenAI 兼容猜的,标「未验证」
3. **这条方言我们不会说** —— 映不上且用户没自定义

对用户是三件不同的事,合并成一个「连接失败」等于把责任推回给他却不告诉他往哪查。

**配置项一律「目录值预填 + 表单可改」**(用户 2026-07-28 指定):base URL、模型 id、能力声明——
每一项都从 models.dev 取默认值**填进表单**,用户随时改。留空反而让用户无从下手,而目录值对绝大多数
供应商**就是对的**。

现在的做法是错的另一种:qwen 回落到一个**硬编码的北京地址**(必然 401),既不是目录值、也不可见、
更不可改。换成预填目录值之后,那个值至少是**看得见、改得动**的。

**但预填不等于正确**——DashScope 的工作区专属域名**每账号一个**,任何目录都给不了。故第 7 节那条
「三种失败要分清」在这里落地成:鉴权类失败的报错要**指向 base URL 这一栏**,让用户知道往哪改,
而不是我们去维护一张「哪几家需要自己填」的名单。

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
| e | UI 照 §6;报错分三种;配置项**目录值预填 + 表单可改**(§7) |

**覆盖率**:现在 10 家 → a·b·c 后 169 家 / ~5800 模型 → d 后 **173/173**。

---

## 10. 顺带要清的

- `prices.go` 注释说「models.dev 的 chat 谓词把纯生成模型整个滤出了目录」——**那是我们 vendor 时的裁剪**,
  不是上游的缺失。上游 5802 个模型里 **284 个输出 image/audio/video**。随 H12-b 改掉。
- 手写 `prices.go` 整表随 H11 删除。
- 查实 moonshot 我们写 `.cn` / models.dev 写 `.ai`,哪个对。

---

## 11. 落地状态(2026-07-29 收口)

### 11.1 两个工单

| 工单 | 状态 | 收口事实 |
|---|---|---|
| **H11** 生成收归受管 | ✅ | 六个生成工具 + 朗读的 `Available()` 收窄到受管档;直连生成方言约 1700 行整体删除;`prices.go` 整表与直连支出台账随之消失;**多模态输入一行未动** |
| **H12** BYOK 全覆盖 | ✅ | **173/173**、5585 模型 |

### 11.2 H12 逐步

| 步 | 状态 | 结果 |
|---|---|---|
| a | ✅ | 8 份 OpenAI-compat 合并成 1 份 `compat.go` |
| b | ✅ | 裁剪谓词放宽成「输出含 text ∧ id 不含 realtime ∧ `limit.context > 0`」;`tool_call` 从**过滤器**变成随行事实 `tools`,无工具的模型标「仅聊天 · 不能当 agent」 |
| c | ✅ | `npm` → 方言;**三张手写表**(provider 白名单 / 方言 / 旋钮)退役;旋钮 = 目录 `reasoning_options` × 方言拼法 |
| d | ✅ | Azure ✓ · Bedrock **不必写** · Vertex **必须写** · Cohere/Venice 确认 · GitLab/SAP 留在未验证 |
| e | ✅ | 供应商市场 + 三种失败 + 目录值预填可改 |
| f | ✅ | base URL 三层兜底,**166 预填 / 10 给形状 / 5 纯空** |

### 11.3 开工时判断错、被实测推翻的三条

**这三条是本记录最值得留下的部分。**

1. **「真正要新写的只有 Azure 与 Bedrock」——两个方向都错。** Bedrock 不必写(它自己也在 `/openai/v1`
   上讲 OpenAI 兼容、普通 bearer),Vertex 必须写(看着像 Gemini 的表亲,实际要服务账号文件)。
   教训:**`npm` 说的是「存在哪个 SDK」、不是「这家能说什么」,而它两个方向都会误导。**
2. **凭记忆写下的 base URL 有两条是错的。** perplexity 没有 `/v1`;deepinfra 的 OpenAI 兼容面是
   子路径 `/v1/openai`。读源码当场逮到。教训:**一个记错的 URL 会以「你的 key 无效」的形态失败,
   而那句话是假的**——用户会跑去重抄一把本来就没错的 key。
3. **c 步把三家「已验证」的家静默变成了未验证的实现。** app 开始下发目录 id(`alibaba` /
   `zhipuai` / `moonshotai`)而注册表还按我们自己的名字建键,于是它们跌到合成的通用 provider 上:
   base URL 对、模型列得出来、卡上写着「已验证」,而**旋钮拼法、编码器、线缆掩码全是通用的那一套**。
   构建绿、测试绿,第一个症状会是一个 400。教训:**「手写过 spec」是一句关于派发的断言,而只有
   比指针的守卫能了断它。**

### 11.4 诚实缺口(留给用户)

- **azure / bedrock / vertex 三家按官方文档实现、尚未真钱验收**——需要用户自己的 Azure / AWS / GCP
  凭证,而买资源与密钥留给用户(本会话纪律)。三家的形状风险不同:azure 的 `api-version` 会过期
  (已给逐 key 覆盖)、bedrock 的 base URL 因区域而异(已给形状)、vertex 的 token 换取是唯一一处
  **网络调用发生在鉴权里**的路径(失败消息已与「key 不对」分开)。
- **gitlab / sap-ai-core 留在未验证**:两家的 base URL 都在客户自己的实例里,任何表都装不下;
  sap 的「key」还是一份自带 URL 与 OAuth client credentials 的 service key,是**第三种凭证形状**,
  今天没有它的控件。
