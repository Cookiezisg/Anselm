---
id: DOC-067
type: decision
status: active
owner: @weilin
created: 2026-07-28
reviewed: 2026-07-28
review-due: 2099-12-31
audience: [human, ai]
---

# 0020 — 能力决定回不回喂:产地否决被实验证伪,判据换成「模型接不接得住」

取代 [ADR 0017](0017-producer-decides-model-input.md)。

## 背景 / Context

ADR 0017 立了一条产地否决:生成族(`generate_image`/`generate_speech`/`generate_video`)的产物
**只回 receipt、不回字节**。论证是「prompt 是模型自己写的,它已经知道内容——像素毫无增益」。

它的代价直到真钱验收才现形:一个 workflow agent 节点(`qwen3-vl-plus`)拿到 `generate_image` 的
receipt 后**必定再调一次**,一路撞满步数顶——**一个节点烧掉十张真图**。当时跑了七组对照(补句号、
明写「已成功勿重调」、receipt 加人话前缀、去 `Input data` 块…),全部照常重调,于是错判成「模型习惯,
记档不修」。**七组对照没有一组动过「有没有图」这个变量——而那正是唯一起作用的那个。**

## 定罪实验 / The experiment

2026-07-28,真钱,成对单变量(`testend/scenarios/live_media_guard_test.go` 的前身
`exp_selfauthored_test.go`),同一句「画一座灯塔」、`MaxSteps` 钳 4 限爆炸半径:

| 臂 | ADR 0017 否决 | 出图调用 | 回合结局 |
|---|---|---|---|
| A(现行) | 开 | **4、4** | `MAX_STEPS_REACHED` |
| B(本地关一行) | 关 | **1、1** | `completed` |

各跑两遍,零分歧。**知道自己要什么 ≠ 知道做出来是什么**:模型看不见产物,唯一的「成功证据」是一段
没有图的 JSON,它便当没做成、再做一次。这与 agent 循环文献的教科书病症逐字吻合(tool result 失去
可见性 → 模型判定「还没调过」→ 再调)。

外部佐证:MCP 规范把「这份内容给谁看」做成**逐内容**的 `annotations.audience` 声明(`["user"]` /
`["assistant"]`,产地声明用途、不按模态硬编码);OpenAI Responses API 多轮出图默认只回引用,**但把
图递回去是官方支持的一等动作**(传 `image_generation_call` id 即可)。0017 的错不在「默认不回喂」,
在**把门焊死**。

## 决策 / Decision

**删掉产地否决,让既有能力闸裁决。** `loop` 的 tool_result 收集器(`history.go` `toolResultMediaIDs`)
对所有产地一视同仁地收集引用;一份产物到不到得了模型,由消费咽喉 `ToContentParts` 的**能力 + 信封**
门控决定——它按解析模型的 vision/video/audio flag 与 `maxMediaBytes` 信封判断,不满足即诚实降级为
文本 receipt。

判据从**「谁写的 prompt」**(产地)换成**「模型接不接得住」**(能力):

- 图 → 模型能看 → 喂回(确认信号,重画循环消失);
- 视频 → 能看且过信封 → 喂;超信封 → 文本 receipt(0017 当年那次 3.2MB 400 的真因是**信封没查**,
  已由 `fitsMediaEnvelope` 单独修掉——0017 把一次信封缺陷误诊成了路线错误);
- 音频 → 模型听不了 → 文本 receipt,与否决时代**一字不差**。

随之删除:`mediaref.SelfAuthored`、`CollectExcept` 的否决参数(折回 `Collect`)。H5.8 的归属收窄
(只展开本次调用自己铸出的附件)与 `MaxRefs=8` 不动——安全与数量的闸从来不是问题。

## 后果 / Consequences

- 一张回喂的图花几千 token;换掉的是 ¥0.25×N 的重画与一整轮浪费。净省。
- 0017 中仍然成立的部分被保留:**大小只决定怎么降级、不决定走不走**——这句现在由能力闸独家执行。
- 复发保险:mock 测试永远抓不到此病(脚本化模型不会因看不见图而重画),常驻 EVALS_MEDIA 守卫断言
  「一个 chat 回合内出图调用 == 1」。
- 若未来某个模态需要「默认不喂、按需可开」的中间态,方向是 MCP 式逐 receipt 的 audience 声明,
  不是恢复按工具族的硬否决。
