# LLM Provider 实现参考(施工图)— 2026-05-29

> **用途**:每家 provider 的完整 adapter + 黄金测试照着这份写。覆盖端点 / auth / 请求体(chat+tools+thinking)/ 响应流式解析 / quirk / 真实 golden fixture / 可抄参考代码。
> **方法**:5 路并行深挖各家官方文档 + LiteLLM/官方 SDK 源码。配套:`01-provider-capability-audit.md`(体检)、`02-build-vs-adopt.md`(选型)。
> **架构前提**:每家一个完整 adapter,挂在共享 `Provider` 接口下;真·铁律(HTTP 发送、SSE 扫描、tool 配对 sanitize)进 `transport.go` 共享。

---

## §0 怎么读 + 跨家通则

**两个线格式家族**:OpenAI-compat(9 家:openai/deepseek/gemini/qwen/zhipu/moonshot/doubao/openrouter/ollama)+ Anthropic-native(1 家:anthropic)。**Gemini 例外建议见 §12 — 应切到 native `generateContent`**。

**通则(写共享逻辑的依据)**:
1. **thinking 响应字段**:CN 家族(deepseek/qwen/zhipu/moonshot/doubao)+ OpenRouter(别名)用 `reasoning_content`;**Ollama /v1 用 `reasoning`(无下划线!)**;Anthropic 用 thinking block + signature;**OpenAI 不返回 reasoning**(只在 usage 给 token 数);**Gemini OpenAI-compat 也不返回 reasoning**(write-only,必须切 native 拿 `thought:true` parts)。
2. **reasoning 总在 content 之前流**(OpenAI-compat 家族)→ 一个共享 SSE reducer 够用,delta 结构加 `reasoning_content`/`reasoning` 字段即可。
3. **error envelope 分两种**:DashScope(Qwen)是**扁平** `{code,message,request_id}`;Ollama native 是**纯字符串** `{"error":"..."}`;其余都是 OpenAI 嵌套 `{error:{...}}`。errorMap 要兼容这三形。
4. **`/models` 列举**:仅 OpenAI/DeepSeek/Gemini/OpenRouter/Ollama 有可用列表端点;**Qwen/Zhipu/Moonshot/Doubao 无 → 硬编码 model 列表**(Doubao 探 `/models` 还会 404 假报失败)。
5. **thinking 能力判定**:各家 `/models` 都不带能力元数据(Anthropic 新版 `/v1/models` 例外,有 `capabilities.thinking`)→ 按 **model-id 前缀/约定**判定是否支持 thinking。

---

## §1 thinking 编码主表(最关键)

| Provider | 线面 | **thinking 请求编码** | thinking 响应字段 | 可关? | 仅 stream? |
|---|---|---|---|---|---|
| OpenAI | compat | `reasoning_effort: minimal/low/medium/high/none`;禁发 temperature/max_tokens,用 `max_completion_tokens` | 无(仅 `usage.completion_tokens_details.reasoning_tokens`) | 是(5.1+ 默认 none) | 否 |
| DeepSeek | compat | `thinking:{type:enabled/disabled}` + 顶层 `reasoning_effort:high/max`(V4);或换 model-id(reasoner/chat) | `reasoning_content` | 是 | 否 |
| Anthropic | **native** | `thinking:{type:enabled, budget_tokens:N}`(N≥1024 且 <max_tokens;开时省 temperature) | thinking block + **`signature`(须回传)** | 是 | 否 |
| Gemini | **native(建议)** | `generationConfig.thinkingConfig{thinkingBudget(2.5)/thinkingLevel(3.x), includeThoughts:true}`;budget -1=动态,0=关 | `thought:true` parts + thoughtSignature;`usage.thoughtsTokenCount` | 仅 2.5-flash/lite | 否 |
| Gemini | compat(现状) | `reasoning_effort` 或 `extra_body.google.thinking_config`(二选一) | **不返回(write-only)** | — | 否 |
| Qwen | compat | 顶层 `enable_thinking:bool`(+`thinking_budget`) | `reasoning_content` | 是(显式 false) | **是(非流式+thinking → 400)** |
| Zhipu GLM | compat | `thinking:{type:enabled/disabled}` | `reasoning_content` | 是 | 否 |
| Moonshot | compat | model-id `kimi-k2-thinking` 或 `thinking:{type:enabled/disabled}`(k2.5/6) | `reasoning_content` | 是(k2.5/6) | 否(建议 stream) |
| Doubao | compat | 顶层 `thinking:{type:enabled/disabled/auto}`(+`budget_tokens`) | `reasoning_content` | 是 | 否 |
| OpenRouter | compat | 顶层 `reasoning:{effort \| max_tokens, exclude, enabled}`(effort 与 max_tokens 互斥) | `reasoning` + `reasoning_details[]`(+`reasoning_content` 别名) | 是 | 否 |
| Ollama | compat /v1 | `reasoning_effort:high/medium/low/max/none`(**`think:true` 在 /v1 被拒**) | **`reasoning`** | 是(none) | 否 |

→ **6 种请求形状**。归一意图(`auto/on/off` + 可选 effort/budget)在每家 adapter 的 `BeforeRequest`/`EncodeThinking` 翻译成上表对应形状。

**黄金测试稳定锚点**(避开易变 model 名):`gpt-5.1`(或 o-series)、`deepseek-v4-pro`、`claude-sonnet-4-5`、`gemini-2.5-flash`、`qwen-plus`、`glm-4.6`、`kimi-k2-thinking`、`doubao-seed-1-6-thinking`、`anthropic/claude-sonnet-4`(OpenRouter)、`qwen3`/`deepseek-r1`(Ollama)。

---

## §2 OpenAI

- **端点**:`https://api.openai.com/v1` + `POST /chat/completions` + `GET /models`。(Responses API `/responses` 才返回 reasoning 摘要,但 Chat Completions 不需要。)
- **Auth**:`Authorization: Bearer`(可选 `OpenAI-Organization`/`OpenAI-Project`)。
- **参考代码**:[go-openai reasoning_validator.go](https://github.com/sashabaranov/go-openai/blob/master/reasoning_validator.go)(推理模型参数限制的 Go 现成逻辑)· [chat.go/chat_stream.go](https://github.com/sashabaranov/go-openai/blob/master/chat.go)(struct tag)· [openai-go 官方 SDK](https://github.com/openai/openai-go) · [streaming-events ref](https://developers.openai.com/api/reference/resources/chat/subresources/completions/streaming-events)。
- **thinking**:`reasoning_effort: none/minimal/low/medium/high`(per-model;5.1+ 默认 `none`)。**硬约束**:推理模型禁发 `temperature/top_p/penalties/logprobs/max_tokens`,改用 `max_completion_tokens`,否则 400。**reasoning 文本不回**(只 `usage.completion_tokens_details.reasoning_tokens`)。
- **tools**:标准 OpenAI(`tools[].function`,`tool_calls`,`role:"tool"`)。`arguments` 是 JSON 字符串。流式 tool delta **带 `index`**。
- **golden 请求**:
```json
{"model":"gpt-5.1","messages":[{"role":"developer","content":"You are helpful."},{"role":"user","content":"Weather in SF?"}],
 "tools":[{"type":"function","function":{"name":"get_weather","parameters":{"type":"object","properties":{"location":{"type":"string"}},"required":["location"]}}}],
 "tool_choice":"auto","reasoning_effort":"high","max_completion_tokens":2048,"stream":false}
```
(注意:无 `temperature`、无 `max_tokens` — 都会 400。)
- **坑**:`developer` 与 `system` 不可同时发;`finish_reason:"length"` 可能是 reasoning 吃光预算;thinking 能力按 model-id 前缀(`o1/o3/o4/gpt-5*`,排除 `*-chat`)判定。

---

## §3 DeepSeek

- **端点**:`https://api.deepseek.com` + `POST /chat/completions` + `GET /models`(beta base `…/beta`;anthropic-compat surface `…/anthropic` 忽略)。
- **Auth**:`Authorization: Bearer`。
- **参考代码**:[LiteLLM deepseek transformation.py](https://github.com/BerriAI/litellm/blob/main/litellm/llms/deepseek/chat/transformation.py)(reasoning_content 回传规则的权威实现,但它有损映射 effort→thinking,别照抄那点)· [issue #26395](https://github.com/BerriAI/litellm/issues/26395)(多轮 reasoning_content 剥离 bug)。
- **thinking**:V4 用顶层 `thinking:{type:enabled/disabled}`(默认 enabled)+ `reasoning_effort:high/max`;旧版用 model-id(`deepseek-reasoner`/`deepseek-chat`)。
- **reasoning_content 回传规则(关键,与 Anthropic 镜像)**:
  - 旧 `deepseek-reasoner`:输入消息含 `reasoning_content` → **400**,必须剥。
  - V4 thinking + **非工具轮**:可省略(被忽略),建议剥。
  - V4 thinking + **工具调用轮**:**必须原样回传**带 tool_calls 的那条 assistant 的 `reasoning_content`,否则 400。
  - → adapter 规则:**普通 assistant 轮剥 `reasoning_content`;带 `tool_calls` 的 assistant 轮保留**。
- **tools**:OpenAI 一致;content 必须是字符串(不收 content-part 数组,要拍平)。
- **golden 请求**(官方 curl 原样):
```json
{"model":"deepseek-v4-pro","messages":[{"role":"system","content":"helpful"},{"role":"user","content":"Weather in SF?"}],
 "tools":[{"type":"function","function":{"name":"get_weather","parameters":{"type":"object","properties":{"location":{"type":"string"}},"required":["location"]}}}],
 "tool_choice":"auto","thinking":{"type":"enabled"},"reasoning_effort":"high","stream":false}
```
- **golden SSE**:`delta.reasoning_content` 先流完,再流 `delta.content`;`finish_reason:"insufficient_system_resource"` 是 DeepSeek 专属(可重试)。

---

## §4 Anthropic(最不同,native)

- **端点**:`https://api.anthropic.com` + `POST /v1/messages`(`stream:true` 同路径)+ `GET /v1/models`(返 `capabilities.thinking` + per-model `max_tokens`)。请求体 32MB 上限。
- **Auth**:`x-api-key`(**不是** Bearer)+ `anthropic-version: 2023-06-01`(必填,最稳定的串,pin 它)+ 可选 `anthropic-beta`(如 `interleaved-thinking-2025-05-14`)。
- **参考代码**:[anthropic-sdk-go message.go](https://github.com/anthropics/anthropic-sdk-go/blob/main/message.go)(struct + JSON tag 真相)· [message_test.go](https://github.com/anthropics/anthropic-sdk-go/blob/main/message_test.go)(golden payload,含 signature)· `Message.Accumulate`(SSE 状态机逻辑直接抄)· [LiteLLM anthropic transformation.py](https://github.com/BerriAI/litellm/blob/main/litellm/llms/anthropic/chat/transformation.py)(tool_choice 映射、tool 名 sanitize `^[a-zA-Z0-9_-]{1,128}$`)。
- **chat 关键差异**:`max_tokens` **必填**(OpenAI 是可选);`system` 是**顶层字段**(string 或 block 数组,非 message role);messages 仅 user/assistant 交替(连续同角色被合并,须 user 起头);图片 `{"type":"image","source":{"type":"base64","media_type":...,"data":...}}`。
- **tools**:字段是 **`input_schema`**(非 parameters);`tool_use` block 在 assistant;`tool_result` block 在**下一条 user**、**必须排在 content 数组最前**且**紧跟**对应 assistant、`tool_use_id` 匹配。开 thinking 时 `tool_choice` **只能 auto/none**。
- **thinking**:`thinking:{type:"enabled", budget_tokens:N}`,N≥1024 且 **< max_tokens**,开时 **temperature 须省/=1、top_k 禁、top_p∈[0.95,1]**。默认关。
- **🔴 signature 回传(必须做对)**:响应 thinking block 带不透明 `signature`;多轮工具循环里回传 assistant 那条时**必须原样带回 thinking block + signature 且保持在 tool_use 之前**,否则 400。`redacted_thinking` 的 `data` 也要原样带。→ 历史模型必须**无损存 thinking block + signature** 并重放。
- **prompt caching**:`cache_control:{type:"ephemeral"}`(可 `ttl:"1h"`)挂在 system/最后一个 tool/message block;最多 4 个断点。
- **golden 请求**:
```json
{"model":"claude-sonnet-4-5","max_tokens":16000,
 "system":[{"type":"text","text":"weather assistant","cache_control":{"type":"ephemeral"}}],
 "thinking":{"type":"enabled","budget_tokens":5000},
 "tools":[{"name":"get_weather","input_schema":{"type":"object","properties":{"location":{"type":"string"}},"required":["location"]}}],
 "tool_choice":{"type":"auto"},
 "messages":[{"role":"user","content":"Weather in SF?"}],"stream":true}
```
- **golden SSE**(逐事件,reducer 照折叠):`message_start` → `content_block_start`(thinking) → `thinking_delta`* → `signature_delta` → `content_block_stop` → `content_block_start`(tool_use) → `input_json_delta`*(partial JSON 拼) → `content_block_stop` → `message_delta`(stop_reason) → `message_stop`。错误事件:`event: error\ndata:{"type":"error","error":{"type":"overloaded_error",...}}`。
- **坑(都 400)**:缺 max_tokens / budget≥max_tokens / 开 thinking 带 temperature≠1 / 开 thinking 用 tool_choice any|tool / orphan tool_use / tool_result 非最前 / 丢或改 signature / 新模型(4.6+)不支持 prefill。
- **解析须容错**:`stop_reason` 新增 `pause_turn`/`refusal`;未知 block/event/delta 类型要优雅忽略(官方版本策略允许枚举增长)。

---

## §5 Google Gemini(建议切 native)

- **端点**:
  - OpenAI-compat(现状):`https://generativelanguage.googleapis.com/v1beta/openai/`(**带尾斜杠**)+ `chat/completions`。**🔴 Forgify 现存的 base 缺 `/v1beta/openai` → 404**;另一个坑:多拼一个 `/v1` 也 404。
  - native:`…/v1beta/models/{model}:generateContent` / `:streamGenerateContent?alt=sse`(**不带 `?alt=sse` 返 JSON 数组不是 SSE**)。
- **Auth**:compat `Authorization: Bearer`;native `x-goog-api-key` 头或 `?key=`。
- **参考代码**:[官方 OpenAI-compat 纯文本 spec](https://ai.google.dev/gemini-api/docs/openai.md.txt) · [thinking doc](https://ai.google.dev/gemini-api/docs/thinking) · [LiteLLM vertex_and_google_ai_studio_gemini.py](https://github.com/BerriAI/litellm/blob/main/litellm/llms/vertex_ai/gemini/vertex_and_google_ai_studio_gemini.py)(`_map_reasoning_effort_to_thinking_budget` + 解析 `thought:true`→reasoning_content,native 转换的范本)。
- **thinking**:
  - compat:`reasoning_effort` 或 `extra_body:{google:{thinking_config:{thinking_budget/thinking_level, include_thoughts:true}}}`(两者互斥)。**但 compat 响应不返回 reasoning**(write-only)。
  - native:`generationConfig.thinkingConfig{thinkingBudget(2.5,整数;-1 动态,0 关)| thinkingLevel(3.x,minimal/low/medium/high), includeThoughts:true}`。2.5-pro 与所有 3.x **不可关**。
- **响应**:native 的 `candidates[].content.parts[]` 里 `text+"thought":true` 是推理摘要;`usageMetadata.thoughtsTokenCount` 单列;Gemini-3 工具循环须回传 `thoughtSignature` 否则 400(compat 信封装不下 → 多轮工具脆)。
- **golden(native)请求**:
```json
{"contents":[{"role":"user","parts":[{"text":"List 3 physicists"}]}],
 "generationConfig":{"thinkingConfig":{"thinkingBudget":1024,"includeThoughts":true}}}
```
- **建议(见 §12)**:dedicated adapter 走 **native**,才能拿到 reasoning 文本 + thoughtsTokenCount + thoughtSignature 回传。compat 仅作 base-url 修复的临时止血。

---

## §6 通义千问 Qwen(DashScope compatible-mode)

- **端点**:`https://dashscope.aliyuncs.com/compatible-mode/v1` + `/chat/completions`(国际 `dashscope-intl`/`dashscope-us`)。**无 `/models` → 硬编码**。
- **Auth**:`Authorization: Bearer`。
- **参考代码**:[LiteLLM dashscope transformation.py](https://github.com/BerriAI/litellm/blob/main/litellm/llms/dashscope/chat/transformation.py) · [Deep thinking 文档](https://www.alibabacloud.com/help/en/model-studio/deep-thinking)。
- **thinking**:顶层 **`enable_thinking:bool`**(+`thinking_budget:int`)。**🔴 `enable_thinking:true` 必须 `stream:true`**,非流式 → 400 `"parameter.enable_thinking must be set to false for non-streaming calls"`。开源 qwen3 默认 thinking **ON**,要关须显式 `false`。
- **响应**:`reasoning_content`(流式先于 content)。**error 是扁平** `{code,message,request_id}` 不嵌 `error`。
- **golden 请求**(必 stream):
```json
{"model":"qwen-plus","messages":[{"role":"user","content":"Weather in Shanghai?"}],
 "stream":true,"enable_thinking":true,"thinking_budget":512,
 "tools":[{"type":"function","function":{"name":"get_weather","parameters":{"type":"object","properties":{"location":{"type":"string"}},"required":["location"]}}}]}
```

---

## §7 智谱 GLM(BigModel paas/v4)

- **端点**:`https://open.bigmodel.cn/api/paas/v4` + `/chat/completions`。**无 `/models` → 硬编码**。
- **Auth**:`Authorization: Bearer <raw key>`(**直接用原始 key**;JWT 是 legacy,不用实现)。
- **参考代码**:[对话补全 API ref](https://docs.bigmodel.cn/api-reference) · [z.ai GLM-4.6 guide](https://docs.z.ai/guides/llm/glm-4.6)。GLM 在 LiteLLM 走通用 openai config,无专属文件。
- **thinking**:`thinking:{type:enabled/disabled}`(+`clear_thinking`)。GLM-4.5/4.6 默认 auto/enabled;**stream 与非 stream 都支持**(无 Qwen 那种约束)。
- **tools**:OpenAI 一致,但 **`tool_choice` 只支持 `"auto"`**(发别的可能 400)。
- **响应**:`reasoning_content`(GLM-4.5+);`finish_reason` 多 `sensitive`/`network_error`;error 用 OpenAI 嵌套形。
- **golden 请求**:
```json
{"model":"glm-4.6","messages":[{"role":"user","content":"Weather in Beijing?"}],
 "thinking":{"type":"enabled"},"do_sample":true,"stream":true,
 "tools":[{"type":"function","function":{"name":"get_weather","parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}}],"tool_choice":"auto"}
```

---

## §8 Moonshot Kimi

- **端点**:`https://api.moonshot.cn/v1` + `/chat/completions`(国际 `api.moonshot.ai`)。`/v1/models` 可能在但不在 chat ref → 倾向硬编码。
- **Auth**:`Authorization: Bearer`。
- **参考代码**:[Kimi chat API](https://platform.kimi.ai/docs/api/chat) · [thinking 指南](https://platform.kimi.ai/docs/guide/use-kimi-k2-thinking-model)。**别抄 Together/NIM 的字段名**(它们把 reasoning_content 改名成 `reasoning`)。
- **thinking**:两路 —— ① model-id `kimi-k2-thinking`(内禀,无参数);② `thinking:{type:enabled/disabled}`(+`keep:"all"` 保留历史 thinking)用于 k2.5/k2.6(默认 ON)。
- **响应**:**官方 `api.moonshot.cn` 用 `reasoning_content`**(下划线!),流式先于 content。`max_tokens` 弃用 → `max_completion_tokens`;thinking 模型 temperature 锁 1.0、建议 `max_completion_tokens≥16000`。tool 名正则 `^[a-zA-Z_][a-zA-Z0-9-_]{2,63}$`;支持 `partial:true` 续写(Moonshot 扩展)。
- **golden 请求**(内禀 thinking 模型):
```json
{"model":"kimi-k2-thinking","messages":[{"role":"system","content":"You are Kimi."},{"role":"user","content":"9.11 or 9.9 bigger?"}],
 "stream":true,"temperature":1.0,"max_completion_tokens":16384,
 "tools":[{"type":"function","function":{"name":"calculator","parameters":{"type":"object","properties":{"expr":{"type":"string"}},"required":["expr"]}}}]}
```

---

## §9 字节豆包 Doubao(Volcengine Ark)

- **端点**:`https://ark.cn-beijing.volces.com/api/v3` + `/chat/completions`。**🔴 `GET /api/v3/models` → 404**(真实列表在 `ListFoundationModels`,要 AK/SK)→ 硬编码 model,别探 `/models`(否则假报测试失败)。
- **Auth**:`Authorization: Bearer`。
- **参考代码**:[LiteLLM volcengine transformation.py](https://github.com/BerriAI/litellm/blob/main/litellm/llms/volcengine/chat/transformation.py)(校验 `thinking.type∈{enabled,disabled,auto}`)· [spring-ai #4296](https://github.com/spring-projects/spring-ai/issues/4296)(原始顶层 `thinking` JSON + `reasoning_content` delta,最佳 fixture 源)。
- **thinking**:**顶层** `thinking:{type:enabled/disabled/auto}`(+ 可选 `budget_tokens`)。Seed-1.6 默认 auto(自适应);`doubao-seed-1-6-thinking-*` 恒思考。非 Seed 模型发 `thinking` 会错 → 按 model family gate。**响应是 `reasoning_content`**(请求 `thinking` / 响应 `reasoning_content` 不对称)。
- **golden 请求**:
```json
{"model":"doubao-seed-1-6-thinking-250715","messages":[{"role":"user","content":"Weather in Toronto?"}],
 "stream":true,"stream_options":{"include_usage":true},"thinking":{"type":"enabled","budget_tokens":32000},
 "tools":[{"type":"function","function":{"name":"get_current_weather","parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}}]}
```

---

## §10 OpenRouter(聚合器,= 长尾兜底)

- **端点**:`https://openrouter.ai/api/v1` + `/chat/completions` + `GET /models`(每 model 带 `supported_parameters`)。
- **Auth**:`Authorization: Bearer`(+ 可选 `HTTP-Referer`/`X-Title`)。
- **参考代码**:[reasoning-tokens doc](https://openrouter.ai/docs/guides/best-practices/reasoning-tokens)(权威)· [parameters](https://openrouter.ai/docs/api/reference/parameters) · [ai-sdk-provider reasoning DeepWiki](https://deepwiki.com/OpenRouterTeam/ai-sdk-provider/4.4-reasoning-features)。
- **thinking**:顶层 `reasoning:{effort:xhigh/high/medium/low/minimal/none | max_tokens:int, exclude:bool, enabled:bool}`(**effort 与 max_tokens 互斥**)。跨上游归一(同一 shape 通 Anthropic/OpenAI/Gemini/DeepSeek)。
- **响应**:`message.reasoning`(纯文本)+ `reasoning_content`(别名)+ **`reasoning_details[]`**(结构化,round-trip 优先用它,含 `type:reasoning.summary/encrypted/text`、`signature`、`data`)。
- **🔴 round-trip 坑**:续推理对话须**原样回传 `reasoning_details`**(顺序不可改);Anthropic 的 `reasoning.encrypted`(base64 `data`)不透明且必带;无 `signature` 的 `reasoning.text` 回传前要剥。
- **SSE 坑**:有 `: OPENROUTER PROCESSING` **注释心跳行**(`:` 开头),裸 `data:` parser 会被它噎到 → 须跳过 `:` 行。很多 model 静默丢 reasoning → 先查 `/models` 的 `supported_parameters`。
- **golden 请求**:
```json
{"model":"anthropic/claude-sonnet-4","messages":[{"role":"user","content":"2+2 and why?"}],
 "reasoning":{"effort":"high"},"stream":true,"usage":{"include":true},
 "tools":[{"type":"function","function":{"name":"calculator","parameters":{"type":"object","properties":{"expr":{"type":"string"}},"required":["expr"]}}}]}
```

---

## §11 Ollama(本地,无 key)

- **端点**:compat `http://localhost:11434/v1` + `/chat/completions` + `/v1/models`;native root `http://localhost:11434` + `/api/chat`、`/api/tags`(已装模型)、`/api/show`(能力)。**🔴 base-path 矛盾**:`/api/tags` 在 native 根、chat 在 `/v1` → 一个 `base_url` 字符串喂不了两头;adapter 须持 root,按需拼 `/api/tags` 或 `/v1/chat/completions`。
- **Auth**:无(`/v1` 收但忽略任意 Bearer,客户端塞 `"ollama"`)。
- **参考代码**:[openai/openai.go 源](https://github.com/ollama/ollama/blob/main/openai/openai.go)(`/v1` 线格式 + effort→Think 映射的权威 Go 源)· [官方 compat doc](https://docs.ollama.com/api/openai-compatibility) · [thinking blog](https://ollama.com/blog/thinking)。
- **thinking**:`/v1` 用 `reasoning_effort:high/medium/low/max/none`(**`think:true` 在 /v1 被拒**;`none`=关);native `/api/chat` 用顶层 `think:bool`。
- **响应**:**`/v1` 是 `choices[].message.reasoning`(不是 reasoning_content!)**;native `/api/chat` 是 `message.thinking`,且**返 NDJSON 不是 SSE**(按 `\n` 拆行逐个 JSON 解);native tool `arguments` 是对象、`/v1` 是字符串(要归一)。
- **修正旧premise**:"带工具必须关 stream" 在新版 native `/api/chat` **已不成立**(2025-05-28 起流式带 tool_calls)。adapter **不要无脑 `stream:false`**;真要兼容老 daemon 就按版本 gate。
- **坑**:某些 model(Gemma 类)开 thinking 时全文落 `reasoning`、`content` 空 → 防御:`content` 空但 `reasoning` 非空时呈现 `reasoning`。error:native 纯字符串 `{"error":"..."}`、`/v1` OpenAI 嵌套形。
- **可做免费 keyless e2e smoke**:chat 用 `http://localhost:11434/v1`,gate 在 `GET /api/tags` 含目标 tag(否则 `t.Skip`),thinking 路径 gate 在 `qwen3`/`deepseek-r1`。

---

## §12 跨家施工指引

**架构落地**:`Provider` 接口(`Name/BaseURL/BuildRequest/ParseStream`)+ 每家一个 `xxx.go` 完整实现 + `transport.go` 放铁律(http 发送、SSE 行扫描含跳 `:` 注释行、tool 配对 sanitize)。Anthropic 与(建议)Gemini-native 是两个非-OpenAI-compat 的完整实现。

**共享 vs 独有**:
- **可共享**:OpenAI-compat 家族的 chat/tools 信封、SSE reducer(reasoning-before-content,delta 加 `reasoning_content`/`reasoning` 字段)。
- **必独有**(每家 adapter):thinking 请求编码(§1 的 6 形)、base-url/path、error envelope 解析(3 形)、各家 quirk(Qwen stream-only、Doubao 无 /models、Ollama base-path、DeepSeek/Anthropic 的 reasoning/signature 回传)。

**3 个真 bug(各自在对应 adapter 修)**:
1. 🔴 Gemini base-url 缺 `/v1beta/openai`(`providers.go:43` 覆盖了 `adapter.go:40` 的正确值)→ 修 base + `:test` 端点对齐;dedicated adapter 直接切 native。
2. 🔴 Ollama base-path 矛盾 → `:test` 用 root 拼 `/api/tags`,chat 用 root 拼 `/v1/...`。
3. 🔴 custom anthropic-compat 死路 → `Credentials` 加 `APIFormat` 透传到 `Config`。
+ Anthropic signature 全链路(解析 `signature_delta`→ 无损存 → 回传)是 thinking 功能的硬前置。

**Gemini 建议**:dedicated adapter 走 **native `generateContent`**(理由:compat 不回 reasoning 文本/thoughtsTokenCount;native 才有完整 thinking 控制 + Gemini-3 工具循环要的 thoughtSignature 回传)。compat base 修复仅作止血。

**验证(零 key)**:每家两类测试 —— L1 黄金线格式(`BuildRequest` 输出 JSON 对官方 curl 字节)+ L2 httptest 回环(各家 golden SSE → `ParseStream` 断言),用本文件每节的 golden fixture 当夹具。Ollama 额外可做 L3 本地真飞。

---

## 参考来源
见各节内联链接(官方文档 + LiteLLM/官方 SDK 源码 + 关键 issue)。所有 golden fixture 的请求体与官方 curl 一致;SSE 片段的 JSON 字段忠于官方 schema(部分 `data:` 框架是按文档 schema 重构,官方多以 SDK 迭代示例呈现而非裸事件行 — 若要字节级锚定,实现时各家用一次真 key 抓一条冻成 canonical 夹具)。
