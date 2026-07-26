---
id: DOC-061
type: decision
status: active
owner: @weilin
created: 2026-07-27
reviewed: 2026-07-27
review-due: 2099-12-31
audience: [human, ai]
---

# 0014 — MediaRef 是媒体在系统里唯一的货币:生成即工具,产物即附件

## 背景 / Context

WRK-082 要让全部四种模态(图/语音/视频/文档)**产出**媒体,并让这些产物在整个系统里流通:聊天里看得见、
workflow 下游 agent 看得见、右岛调试台与 approval 门渲得出、文档里嵌得进。

「产出」的入口最终有**五个**:chat 的生成工具、agent 的 `sys:` 挂载、MCP server 返回的二进制、
function 的沙箱产物、朗读(不经 LLM)。「消费」的入口有**三个**:agent invoke payload、loop 的
tool_result、附件文档注入。五乘三是十五条可能的路径,而它们**必须**是同一条。

本篇记录使那十五条塌缩成一条的三个决定。

## 决策 / Decision

### 一、生成是**工具**,不是新实体

`generate_image` / `generate_speech` / `generate_video` 是 Tool(S18 五方法),不是 Quadrinity 的
第五个成员,也不是 chat 的特殊分支。

**为什么不是新实体**:设计原则 #1 的封闭集是四项全能,而「生成一张图」不是一个用户会**编辑、版本化、
挂载、被 workflow 引用**的东西——它是一次调用。给它一张表,就要给它版本、给它 relation 边、给它
`:iterate`,而这些没有一个是用户会用的。

**为什么不是 chat 的分支**:分支意味着 agent 与 subagent 各自要再实现一遍。做成工具,它们经
`sys:` 挂载与 `CapabilityTools` 缝**免费**得到同一件东西——这一点在批B' 已经兑现:subagent 拿到能力
工具只用了一个 `SetMultimodal`。

**代价**:模型必须**知道**自己会画。故能力工具是**逐请求 resident**(完整 schema 随请求走)而不是走
lazy 的「发现」舞步——一个要先搜索才能发现自己会画图的模型,在用户说「画只猫」时不会去搜。

### 二、产物一律进**同一间**附件库,引用一律是 `attachmentId`

五个产地全部落 `attachments` 表(内容寻址 blob + 元数据行),而它们交给下游的**唯一**东西是一份携
`attachmentId` 的 JSON receipt。文法定义在 `pkg/mediaref`(后端)与 `core/media/media_ref.dart`(前端),
两份互为孪生件。

**为什么是引用而不是字节**:一段 20 秒 1080p 视频是几十 MB。让它在 tool_result 里、在 flowrun 节点行里、
在 SSE 帧里以 base64 流动,等于让每一次重放、每一次压缩读、每一次 UI reload 都付一遍那笔钱。引用是
常数大小的。

**为什么是 `attachmentId` 而不是新 id 空间**:附件已经有内容寻址去重、有 GC(`Sweep`)、有播放租约、
有 workspace 隔离、有软删。发明第二个媒体身份,就要把这五样各造一遍。

**代价与其边界**:receipt 在 workflow 节点之间是**以文本**流动的(agent 的终答成 `node.text`),故文法
必须认字符串形——这一条在批B' 是被一次黑盒验收逼出来的,不是设计出来的。

### 三、消费收在**一个咽喉**,按模型模态门控

三个消费入口(agent payload / loop tool_result / 附件文档)全部经
`attachment.ToContentParts(ids, caps)` 展开成原生 content part。看不了图的模型在此拿不到东西,**但仍
读得到文本 receipt**——诚实降级,绝不假装。

**为什么必须是一个**:门控规则(能不能看图/视频/音频、几件、多大)来自能力目录,而它会变。三份拷贝里
的任何一份忘了更新,表现都是「模型看得见而界面渲不出」或反过来——两者都不会让任何测试变红。

## 影响 / Consequences

- **不变量四条**(工单 §0.1)因此可以机械检查:①一个值类型 ②一间库 ③两个咽喉(produce/consume)
  ④一族卡。任何新模态只要接上这四条,它在系统里的流通是**免费**的——批C 的语音与批D 的视频各自证明了
  这一点:两者都没有为「让模型看见」「让 UI 渲出」写过一行新代码。
- **前端一族卡**(`AnMediaRefCard`)按**附件行的 mime** 分发,而不是按 receipt 的自称、也不是按 url 猜。
  文档编辑器因此不需要自己的音视频块:markdown 唯一的媒体槽 `![alt](url)` 配上行的 mime 就够了。
- **五个产地各自的失败是局部的**:MCP 逐件 best-effort、function 逐件记 log 不废整次运行、朗读缓存写
  失败不弄丢已合成的音频。没有任何一个产地能因为「媒体这一半出了问题」而毁掉它本来的工作。
- **代价:receipt 是可伪造的文本**。一个工具可以返回一段带 `attachmentId` 的 JSON 而那个附件属于别人。
  今天不构成风险(单用户单进程、workspace 物理隔离已在 orm 层),但如果本项目将来变成多用户,消费咽喉
  就必须在展开前校验归属——**那是届时第一件要做的事**,写在这里以免被忘掉。

## 备选 / Alternatives

| 方案 | 为何未选 |
|---|---|
| 生成作为第五个 Quadrinity 实体 | 违反 #1 封闭集;而「一次调用」不需要版本/relation/`:iterate`,给它一张表是给它一套没人用的机制 |
| 产物以 base64 在 tool_result / frn 行里流动 | 一段 20 秒 1080p 是几十 MB,每次重放/压缩读/UI reload 都要再付一遍;引用是常数大小 |
| 媒体自己的 id 空间与存储 | 附件已有内容寻址去重、GC、播放租约、workspace 隔离、软删;第二套身份要把这五样各造一遍 |
| 三个消费入口各自展开 | 门控规则来自会变的能力目录;任一拷贝忘了更新,症状是「模型看得见而界面渲不出」——不会让任何测试变红 |
| 文档里另发明音视频块语法 | 文档将不再是 markdown(别处打不开、codec 三保真保不住);而 markdown 的唯一媒体槽配上**行**的 mime 已经够了 |
