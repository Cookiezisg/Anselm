---
id: DOC-064
type: decision
status: superseded
superseded-by: docs/decisions/0020-capability-decides-model-input.md
owner: @weilin
created: 2026-07-27
reviewed: 2026-07-27
review-due: 2099-12-31
audience: [human, ai]
---

# 0017 — 产地决定回不回喂:模型自己点的产物不作为它的输入

> **⚠️ 已被 [ADR 0020](0020-capability-decides-model-input.md) 取代(2026-07-28)。**
> 核心前提「模型自己写的 prompt,它已经知道内容」被成对真钱实验**证伪**:拿到没有图的 receipt,
> `qwen3-vl-plus` 把生成当失败、重画到 MAX_STEPS(否决开 4 次出图 vs 否决关 1 次,各跑两遍零分歧)
> ——**知道自己要什么 ≠ 知道做出来是什么**,产地否决正是「一个节点烧掉十张真图」那次事故的病灶。
> 本文档里那次 3.2MB 视频 400 的真因是**信封没查**(后已由 `fitsMediaEnvelope` 修掉),当时被误诊成
> 路线错误。仍然成立并由 0020 保留的:**大小只决定怎么降级、不决定走不走**(现由能力闸独家执行)。

## 背景 / Context

真机验收里,受管档生成一段 5 秒视频**成功了**——3,217,990 字节 mp4 落成附件——然后**那一轮死了**:

```
LLM_STREAM_ERROR  llm: bad request (400)      route: multimodal
```

链条是:`generate_video` 返回 receipt → loop 的 `MediaExpander` 把它展开成模型输入 → `ToContentParts`
见 `caps.Video && RemoteMedia != nil`,把 3.2MB 上传网关取 lease、以相对路径塞进 `video_url` → 网关按
[ADR 0012](0012-gateway-media-inline-upstream.md) **把 lease 内容内联进上游请求体**,并在那里执行
`MAX_MEDIA_DECODED_BYTES`(生产值 3 MiB)→ **超 72,262 字节** → 400。

**用户付了钱、片子在盘上,而看到的是一句报错。** 而且这不是偶发:免费档允许 15 秒,**5 秒 720p 就已经
超限**——每一次受管视频生成都会这样死。

第一反应的修法是「remote 分支漏了 `fitsMediaEnvelope`,补上」。那是**错的判断**:补上之后症状会从
「400 报错」变成「静默不给看」,而真正的问题是**这条路根本不该走**。

## 决策 / Decision

### 一、**产地**决定一份产物是不是模型输入,大小不决定

判据是一句话:**模型是否已经知道里面是什么。**

| 产地 | 模型知道内容吗 | 是否作为模型输入 |
|---|---|---|
| 生成族(`generate_image`/`generate_speech`/`generate_video`) | **知道**——prompt 是它自己写的 | **否**,只回 receipt |
| function / handler 沙箱产物 | **不知道**——那是它开口要的**证据** | 是(caps + 信封双门控) |
| MCP 二进制 | **不知道**——第三方返回之物 | 是(同上) |
| 朗读 | 不进 LLM 上下文(零 token) | 不适用 |

模型自己点的那张图,对它的下一轮毫无增益:描述是它写的。而 function 算出来的那张图表恰恰相反——那是它
**从未见过**的东西,也正是它开口要的理由(「计算↔感知闭环」)。

**大小只决定该走的怎么降级,绝不能成为决定走不走的判据。**

### 二、这与成熟实现一致

- **OpenAI Responses API 的 `image_generation` 工具**:多轮编辑靠 `previous_response_id` 或 **image ID**;
  模型下一轮拿到的是 `revised_prompt` 与调用元数据,**不是像素**。
- **Claude Code**:tool result 有硬性 ~25K token 上限,**在模型看到之前**由 harness 截断——上限归 harness
  管,不指望上游接受。
- 反面教材同样有据:MCP 返回的图被当成 base64 **文本**塞进 tool result(10–20× token 浪费,而模型**根本
  看不成图**),以及「tool result 上限挡住大 MCP 载荷往返」——都是公开在案的 issue。**这条路上大家都摔过。**

**字节是给「工具」的,不是给「模型」的。** H9 做改图时 `edit_image(attachmentId, prompt)` 会把字节交给
生成上游——那是对的;而推理模型全程只需要那个 `attachmentId`,receipt 里本来就有。**统一之后一点能力都不丢。**

模型真想看自己造的东西?**调 `inspect_media`**——**拉,不是推**。

### 三、否决施加在 **receipt** 上,不施加在 id 上;且**只在 loop 的 tool_result** 处

`mediaref.CollectExcept(v, SelfAuthored)` 逐 receipt 读 `source` 字段判定。**不按 id 判**:同一份附件完全
可以在一处是「自己点的」、在另一处是「证据」,故这个决定必须留在**产地还叫得出名字**的地方。

而否决**只**用于 `loop/history.go` 的 tool_result 收集——那是模型**刚走那一步**的结果。另一个模型侧入口
`agent/invoke.go`(invoke payload)**照旧全收**:上游节点生成的图递给**下游 agent** 时,下游那个模型
**并没有写过**那条 prompt,它确实需要看。

**同一个规则,两个位置,不同答案——因为「谁写的 prompt」不同。**

### 四、信封仍然要在 remote 路径上执行(另一半修复)

即便有了①,`agent/invoke.go` 与 MCP/function 产物仍可能过大。原代码里两个 remote 分支(image 与 video)
**都跳过了** `fitsMediaEnvelope`:lease 媒体过去计零解码字节(它是 provider 自己去取的引用),而 ADR 0012
把它变成了内联——字节回到了表上,而这里没跟上。现已补齐,并把远端字节**计入同一只表**。

## 影响 / Consequences

- **受管视频生成不再毁掉自己的那一轮**。产物落盘、receipt 回话、卡片渲出,回合正常完成。
- **一次多模态请求被省掉**:生成后的后续轮回到纯文本路由,省 token、省钱、省一次上传。
- **「计算↔感知闭环」完好**:function 的图表照常以真媒体 part 到达,守卫钉死(`TestRun_EvidenceMediaStillExpands`)。
- **两条守卫经变异验证**:抽掉 source 否决 → 自点产物又被回喂(测试红);抽掉 remote 信封 → 超限产物又被
  当媒体发出(测试红)。
- **代价:模型看不见自己刚生成的东西**,除非它主动调 `inspect_media`。「生成一张图,然后自己检查手指画对没有」
  这种自评循环因此**多一次工具调用**。这是刻意的:让每一次生成都自动付一次视觉 token,去补贴一个少数人才要
  的自评动作,是把成本放错了地方。

## 备选 / Alternatives

| 方案 | 为何未选 |
|---|---|
| 只给 remote 分支补 `fitsMediaEnvelope` | 症状从「400 报错」变成「静默不给看」;判据本身是错的——问题不是它太大,是它**根本不该走** |
| 调大 `MAX_MEDIA_DECODED_BYTES` | 15 秒视频十几 MB,没有哪个上限既容得下视频又安全;而每轮内联十几 MB base64 本身就荒唐 |
| 只对**视频**停止回喂 | 语音是模型自己写的文字的朗读版(听回去零信息)、图像连 OpenAI 都不回传像素——按模态划线会留下两个说不出理由的例外 |
| tool_result 里的媒体一律不展开 | 会杀掉 function 图表与 MCP 图像——那正是这套东西最有价值的部分 |
| 按 id 而非按 receipt 否决 | 同一份附件在不同位置身份不同;按 id 判会让它的命运取决于**先看到哪份 receipt** |
