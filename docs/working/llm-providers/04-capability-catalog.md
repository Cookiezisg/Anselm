---
id: WRK-002-04
type: working
status: archived
owner: @weilin
created: 2026-05-25
reviewed: 2026-05-30
review-due: never
audience: [human, ai]
landed-into: docs/concepts/architecture.md
---
# LLM 能力目录:上下文窗口 + thinking 粒度 — 2026-05-29

> **用途**:配置最细单元 `(厂家/key, 模型, thinking-effort, 上下文模式)` 背后的能力数据。哪个模型能 thinking、effort 收哪些值、窗口多大、1M 怎么(还能不能)开——按**模型家族/前缀规则**组织,抗月度阵容漂移。
> **方法**:3 路并行深挖各家官方文档 + LiteLLM/SDK 源 + 对抗性 GitHub issue 核验。
> **关系**:本文件的窗口/能力数据**取代** `01-provider-capability-audit.md` 里零散提及的窗口信息(01 是更早快照);thinking 编码线格式见 `03-implementation-reference.md`。

---

## §0 三个改变设计的发现

### 发现 1:"1M / 上下文" 对多数家**不是开关**了
- 现世代多是**原生 1M、选模型即得、无 flag**:`gpt-5.5`、`deepseek-v4-*`、`claude-*-4-6/7/8`+`sonnet-4-6`、`gemini-2.5-*`+`gemini-3*`、`qwen-plus/flash`。
- 🔴 **Anthropic `context-1m-2025-08-07` beta 头已退役**:只有老 Sonnet 4/4.5 曾用它(还带 >200K 阶梯涨价 2×/1.5×);现已**no-op**,那俩模型硬顶 200K;现世代 1M 原生平价(900k 请求与 9k 同单价)。token 还在 enum 里但**静默忽略**。
- **真正还有"上下文模式"开关的只有两家**:
  - **Qwen**:1M 模型默认夹到 **~129K**,要显式抬 `max_input_tokens` 才拿满 1M;`qwen-turbo` 窗口还随 thinking 开关变(thinking 时输入夹 131072)。
  - **Ollama**:窗口 = 本地 `num_ctx`,**默认仅 4096 且超了静默截断**(著名坑),要按需抬到模型 `/api/show` 报的 `context_length` 上限。
- → **你 tuple 里的 "1m" 对 8/10 家是"展示属性 + 喂 compaction",不是 toggle**;只有 Qwen(`max_input_tokens`)和 Ollama(`num_ctx`)是真 knob。这大幅简化了配置。

### 发现 2:thinking 粒度是 **3 种形状**(UI 要 3 种控件)
| 形状 | 控件 | 谁用 |
|---|---|---|
| 数值预算 | slider/number | Gemini 2.5(thinkingBudget)、Anthropic enabled(budget_tokens)、Qwen(thinking_budget)、Doubao 1.6(budget_tokens) |
| effort 枚举 | 分段选择 | OpenAI(reasoning_effort)、Gemini 3.x(thinkingLevel)、Anthropic adaptive(effort)、OpenRouter、DeepSeek(high/max)、Ollama、Doubao 1.8+ |
| 二元开关 | toggle | 智谱 GLM、Kimi(`thinking:{type}` 或换 `*-thinking` model-id) |

Gemini 一家就按**代际**分叉(2.5=数值预算 / 3.x=effort 枚举),且两者同发会 400。

### 发现 3:能力**能实时读 vs 必须硬编码** 是分裂的 → 目录架构 = 家族规则 + 能读则读 + 用户覆盖
| 实时可读(fetch 别硬编码) | 只能硬编码(/models 仅 id) |
|---|---|
| **Anthropic** `/v1/models`→`capabilities.thinking` + `max_tokens` + `max_input_tokens` | OpenAI(/models 仅 id) |
| **Gemini** `models.get`→`inputTokenLimit/outputTokenLimit/thinking` 布尔 | DeepSeek(同) |
| **OpenRouter** `/api/v1/models`→`context_length` + `top_provider` + `supported_parameters` | Qwen / 智谱 / Kimi / Doubao(都 /models 仅 id 或无) |
| **Ollama** `/api/show`→`capabilities[]` + `model_info.<arch>.context_length` | |

---

## §1 能力目录(家族规则表,抗漂移)

> 匹配:小写 model-id,**最具体前缀优先**。`thinking` 列形状:`none` / `effort(值)` / `budget(范围)` / `toggle`。

| 前缀规则 | 默认窗口 | 扩展/1M | 怎么开 | 输出上限 | thinking | 源 |
|---|---|---|---|---|---|---|
| **OpenAI** |
| `o1*/o3*/o4*` | ~200K | — | 原生 | model-set | effort(low/med/high) | live? 否→硬编码 |
| `gpt-5`(5.0) | 400K | — | 原生 | 128K | effort(minimal/low/med/high) | 硬编码 |
| `gpt-5.1*` | 400K | — | 原生 | 128K | effort(none*/low/med/high) | 硬编码 |
| `gpt-5.2*` | 400K | — | 原生 | 128K | effort(none*/low/med/high/xhigh) | 硬编码 |
| `gpt-5.5*`+ | **1M** | 原生 | — | 128K+ | effort(none/low/med*/high/xhigh) | 硬编码 |
| `*-pro` | 继承 | — | — | 继承 | effort 锁高端(5-pro 仅 high) | 硬编码 |
| **DeepSeek** |
| `deepseek-v4*` | **1M** | 原生 | — | 384K | toggle `enabled/disabled` + effort(high/max,默认high;low/med→high,xhigh→max) | 硬编码 |
| `deepseek-reasoner`(别名,2026-07-24 退) | 128K | — | — | — | thinking ON | 硬编码 |
| `deepseek-chat`(别名) | 128K | — | — | — | OFF | 硬编码 |
| **Anthropic**(代际边界在 4.6) |
| `claude-opus-4-(7\|8)` | **1M** | 原生平价 | 无头 | 128K(beta→300K) | **adaptive 必须** effort(low/med/high,默认high);**manual budget→400** | **live** /v1/models |
| `claude-opus-4-6`/`sonnet-4-6` | **1M** | 原生平价 | 无头 | 128K/64K | adaptive(荐)或 enabled-budget(弃用,min1024,<max_tokens) | live |
| `claude-sonnet-4-5`/`-4` | **200K** | ❌1M 头**已死** | — | 64K | budget(min1024,<max_tokens);interleaved 头 | 硬编码 |
| `claude-opus-4-5/4-1/4` | 200K | — | — | 64K/32K | budget | 硬编码 |
| `claude-haiku-4-5` | 200K | — | — | 64K | budget(无 adaptive) | live |
| **Gemini**(代际分叉) |
| `gemini-2.5-pro*` | 1M | 原生 | — | ~65K | budget(128–32768,**不可关**,-1动态) | **live** models.get |
| `gemini-2.5-flash*`(非lite) | 1M | 原生 | — | ~65K | budget(0–24576,0=关,-1动态) | live |
| `gemini-2.5-flash-lite*` | 1M | 原生 | — | ~65K | budget(512–24576,默认关) | live |
| `gemini-3*` | 1M | 原生 | — | ~64K | effort(minimal/low/med/high) | live |
| **Qwen**(窗口模式真 knob) |
| `qwen3-max*` | 256K | — | — | 32K | budget(≤81920)+`enable_thinking`默认**off** | 硬编码 |
| `qwen-plus*`/`qwen3.5-plus*` | **1M** | 抬 `max_input_tokens`(默认夹~129K) | param | 32–65K | budget+enable_thinking(商用off/3.5 on) | 硬编码 |
| `qwen-turbo*` | 1M | thinking 时输入夹131072 | 非thinking 才满1M | 16K | budget(≤38912) | 硬编码 |
| `qwen-flash*`/`qwen3.5-flash*` | 1M | 抬 `max_input_tokens` | param | 32–65K | budget+enable_thinking(3.5默认on) | 硬编码 |
| `qwen-long*` | 10M | **仅 file-id 注入**(非裸 token) | 上传→system msg | 32K | none | 硬编码 |
| `qwq-*/*-thinking/deepseek-r1`(on DashScope) | per | — | — | per | thinking-only(不可关) | 硬编码 |
| `qwen-max`(老 v2.5) | 32K | — | — | 8K | none/limited | 硬编码 |
| **智谱 GLM**(二元) |
| `glm-4.5*`(含 air/x/airx/flash) | 128K | — | — | 96K | toggle(默认 enabled) | 硬编码 |
| `glm-4.6*` | 200K | — | — | 128K | toggle(默认 enabled) | 硬编码 |
| **Kimi**(双路) |
| `moonshot-v1-{8k/32k/128k}` | =后缀 | — | — | 32K | none | 硬编码 |
| `kimi-k2*`(非thinking:k2.5/k2.6/0905/turbo) | 256K | — | — | 32K | toggle(默认 enabled)+k2.6 `keep` | 硬编码 |
| `kimi-k2-thinking*` | 256K | — | — | 32K | thinking-only(model-id 内禀) | 硬编码 |
| **Doubao**(1.6 vs 1.8 机制切换) |
| `doubao-seed-1.6*`(含 thinking/flash/lite/vision) | 256K | — | — | 16K | budget(0–32768)`thinking:{type:enabled/disabled/auto,budget_tokens}` | 硬编码 |
| `doubao-seed-1.8*`/`-2*` | 256K | — | — | ~64K | **effort**(`reasoning_effort`:no_think/low/med/high)——换了机制 | 硬编码 |
| `doubao-seed-code*` | 256K | — | — | ~16K | budget(同1.6) | 硬编码 |
| **OpenRouter**(全 live) |
| 任意 | `context_length`(live) | 上游决定;`provider` 偏好可钉 | — | `top_provider.max_completion_tokens` | gate `supported_parameters`∋reasoning→effort(none..xhigh);Anthropic/Gemini→`reasoning.max_tokens`(1024–128000) | **全 live** |
| **Ollama**(窗口=num_ctx) |
| 任意本地 | **=用户 `num_ctx`(默认4096!超了静默截断)** | 抬 num_ctx 至 `/api/show` 的 context_length 上限 | `options.num_ctx`(native)/ `OLLAMA_CONTEXT_LENGTH` 或 Modelfile(/v1) | `num_predict`(-1) | gate `/api/show` `capabilities`∋thinking;native `think`(bool 或 high/med/low/max);/v1 `reasoning_effort`(high/med/low/none) | **per-model live** |

---

## §2 各家关键坑(实现/UX 必读)

- 🔴 **Ollama `num_ctx` 默认 4096 + 静默截断**:模型号称大窗,实际只给 4096,超了悄悄丢老 token、模型"失忆"。UI 必须暴露 num_ctx 并警示;`/v1` 面无 num_ctx 字段,要靠 `OLLAMA_CONTEXT_LENGTH` 或 Modelfile。
- 🔴 **Anthropic 代际边界 4.6**:`≤4.5`(含 sonnet-4-5)= 200K + manual budget + 1M 头**已死**;`≥4.6` = 1M 原生平价 + adaptive effort;**Opus 4.7/4.8 拒绝 manual `budget_tokens`(400),必须 adaptive**。占位名 `claude-opus-4-8` 落在新分支。
- **Qwen 1M 默认夹 129K**:不抬 `max_input_tokens` 拿不到满 1M;`qwen-long` 的 10M 是**文件 file-id 注入**,不是裸 token 窗口。Qwen 开 thinking 还强制 streaming。
- **Doubao 机制按代切**:`seed-1.6` 用 `thinking:{type,budget_tokens}`;`seed-1.8/2.0` 改用 `reasoning_effort`。`/api/v3/models` 还 404(别探,硬编码)。
- **DeepSeek effort 只认 high/max**:foreign 值会 clamp(low/med→high,xhigh→max),不报错。
- **OpenRouter effort 按上游 gate**:`xhigh`/`minimal` 是新值,某些上游拒;`xhigh`→上游 `max` 可能被拒。靠 `/models` 的 `supported_parameters` 实时判,别硬编码哪个模型收哪个 effort。

---

## §3 设计落地

**配置 tuple**:`(key/provider, model, thinking, [context-mode])`。其中 **context-mode 只对 Qwen(`max_input_tokens`)和 Ollama(`num_ctx`)是真 knob**;其余只**展示窗口** + 喂 compaction。

**thinking 三 render-mode**(按 family 选,Gemini 按代分叉):
- budget slider:Gemini 2.5 / Anthropic enabled / Qwen / Doubao 1.6
- effort 枚举:OpenAI / Gemini 3.x / Anthropic adaptive / OpenRouter / DeepSeek / Ollama / Doubao 1.8+
- toggle:GLM / Kimi
归一意图仍是 `{none/off | effort | budget}` 三态联合体,adapter 翻译成各家形状(见 03 §1)。

**目录架构**(治"月月烂"):
1. **静态家族规则表**(本文件 §1)= 兜底,按前缀匹配,占位/未来名继承家族机制。
2. **能读则实时读**:Anthropic/Gemini/OpenRouter/Ollama 启动时拉一次缓存,覆盖静态值(窗口/输出/thinking 能力)。
3. **用户可覆盖**:目录陈旧时,用户能手动标"这模型支持 thinking / 窗口 = N"。

**compaction 联动**:用窗口数值定压缩阈值——大窗晚压、少切;**Ollama 尤其要按用户的 `num_ctx` 而非模型理论上限**(否则按 1M 算却实际 4096,必崩)。现在 compaction 若用统一阈值,大窗模型被压早了、小 num_ctx 的 Ollama 会溢出。

---

## 参考来源
各节内联。关键:Anthropic [pricing(平价1M)](https://platform.claude.com/docs/en/about-claude/pricing) · [models-list(live caps)](https://platform.claude.com/docs/en/api/models-list) · 1M 头退役([Apr 30 2026 迁移](https://www.riptideconsulting.com/insights/april-30-context-beta-migration));Gemini [models API](https://ai.google.dev/api/models) · [thinking](https://ai.google.dev/gemini-api/docs/thinking);Qwen [model-studio/models](https://www.alibabacloud.com/help/en/model-studio/models) · [deep-thinking](https://www.alibabacloud.com/help/en/model-studio/deep-thinking);GLM [z.ai 4.6](https://docs.z.ai/guides/llm/glm-4.6);Kimi [chat API](https://platform.kimi.ai/docs/api/chat);Doubao [Ark guide](https://www.huasheng.ai/insights/volcengine-ark-api-guide/);OpenRouter [models endpoint](https://openrouter.ai/docs/api/api-reference/models/get-models);Ollama [FAQ(num_ctx)](https://docs.ollama.com/faq) · [api.md](https://raw.githubusercontent.com/ollama/ollama/main/docs/api.md)。
