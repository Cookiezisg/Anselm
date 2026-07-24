---
id: WRK-080
type: working
status: active
owner: "@weilin"
created: 2026-07-25
reviewed: 2026-07-25
review-due: 2026-10-23
audience: [human, ai]
landed-into:
---

# WRK-078 收口 · 进度台账

> **这一页是收口战役的唯一进度真相。** 每完成一批更新一次。用户起床只读这一页即可知道:
> 哪批完了、发现了什么、修了什么、还剩什么、哪些必须用户本人来做。
>
> **诚实律(最高优先级)**:本页**绝不**把未跑的写成跑过了。「代码完成」与「真实环境验收」物理分栏,
> 任何一项在没有真实证据前一律留在右栏。

## 总览

| 阶段 | 内容 | 状态 |
|---|---|---|
| **A** | 收掉 audio playback lease 片 | ✅ **完成**(`623c3746`,已推送) |
| **B** | 跨两仓审计(跨仓契约 / §13 测试矩阵 / §3.3 不变量守卫) | 🔨 进行中 |
| **C** | 按发现分批修 | ⏳ 待 B |
| **D** | 收口(§15 订正 / 台账 / ADR / CLAUDE 重述 / 归档) | ⏳ 待 C |
| **E** | 真机端到端验收 + 《真实环境验收指南》 | ⏳ 待 D |
| **F** | WRK-077 十七步(见 `working/frontend/chat-iteration.md` §7) | ⏳ 待 E |

---

## A · audio playback lease 片 ✅

**提交**:`623c3746 feat(audio): stream attachments through playback leases`(已 push)
**门禁**:根 `make verify` 四门全绿(backend / frontend / docs / demo)

### 接手复核发现与处置

| # | 发现 | 处置 |
|---|---|---|
| 1 | **前缀豁免的安全性无测试钉死**。`/api/v1/attachment-playback/` 是按**原始路径**前缀豁免 bearer 的;穿越写法(`…/attachment-playback/../attachments/{id}/content`)确实会被中间件放行,真正的闸在下一层(ServeMux 清理路径后只回重定向,干净路径不再命中豁免)。**这条链此前只存在于推断中,没有任何测试**。 | ✅ 已补 `TestRequireBearerToken_playbackPrefixTraversalCannotReachProtected`,断言穿越请求拿不到受保护内容 |
| 2 | **「省内存」的说法与实现不符**。交接把动机写成"大音频额外占内存",但 `svc.Download` 仍**整份**读入内存,播放器 seek 发的**每个 Range 请求都会重读整个对象**。`ServeContent` 保证的是 206/Content-Range 语义正确,**不是流式**。 | ✅ 诚实边界写进代码注释 + working §M1;新增「待落地:播放路径真流式化(CAS 上开 `io.ReadSeeker` 缝)」 |
| 3 | 交接文档缺 frontmatter,`make -C docs verify` 红 | ✅ 已补(WRK-079) |
| 4 | ~~Kimi/Moonshot 未从 `apikey/providers.go` 删除~~ | ❌ **自我证伪,撤回**:那是 BYOK 用户自带 key 的 provider 目录,合法保留;§1.2 要删的是**网关的 Kimi route**,属另一仓 |

### 代码质量复核(逐项亲读,无阻断)

token 256 位 `crypto/rand` + URL-safe base64 · `kind=audio` 在签发与取用**两处**都校验(纵深防御)· 租约绑 workspace+attachment · TTL 5min 且签发/取用两处都扫过期 · 两处豁免沿用既有 webhooks 先例且注释写清 why · 日志脱敏有测试 · 刻意不做一次性 token(否则 seek 碎)· 构造函数返回指针,内嵌 mutex 不触发 vet copylocks · 文档三处登记内容充实。

---

## B · 跨两仓审计 🔨

**范围**(按用户 0725 指示收紧,不做穷举扇出——「那边写得真的不错」):

1. **跨仓契约一致性** — Anselm ↔ Anselm-API-Serve:capabilities/route profile、media upload+lease 协议、ASR WebSocket、错误码全集、device proof、quota 口径。**这是横跨两仓最容易烂、且没有编译器和门禁能发现的地方。**
2. **§13 测试矩阵** — 约 60 条逐条判定 已覆盖/部分/未覆盖/不适用,要求给出测试 file:line 与实际断言。
3. **§3.3 十条不变量守卫** — §16 硬性要求「有自动守卫」。逐条判定守卫是否存在、**是否真能挡住新的违反写法**。

**主会话亲读(不外包)**:§12 每条「已落地」声明 vs 代码实际、§16 九类文档落点、T5.1 按域前缀搜 testend。

### 已确认的事实(主会话亲查)

| 项 | 结论 |
|---|---|
| 生产网关存活 | ✅ `https://api.anselm.website/healthz` → 200;`/v1/models` 无 device proof → 401,**与 §12 C3 记载一致** |
| 网关仓可达 | ✅ `../Anselm-API-Serve` 在本机,跨仓审计可行 |
| 本战役 ADR | ❌ **零篇**。C0 要求「产出 ADR 清单」、§16 完成定义要求「新 ADR」;现有最新 `0010`(2026-07-21)早于战役起始(07-23),属上一轮 device proof 工作。战役做了媒体三层模型、一次性 lease 协议、profile 学习机制、ASR 代理链等架构级取舍,**一篇未沉淀** → 归 C4 补 |
| eval 环境 | `EVALS_KEY` / `EVALS_BASE_URL` / `DEEPSEEK_API_KEY` / `EVALS_ASR_WAV` **本机全部 unset** → `make evals`、`make qwen-evals`、`make qwen-asr-evals` 当前**跑不了**(会安全跳过,不产生计费) |
| §15 决策状态 | 用户 0725 确认**决策已定、代码按其执行**;文档里 8 条仍标「是否确认」是**标记滞后**,归 D 订正 |

---

## E · 必须用户本人来做的(边界,提前登记)

经查证后**收窄**到三项——其余我可驱动 app 走真实生产路径自验(app 自带真凭证并做 device proof,比 eval harness 更贴近真实):

| 项 | 为什么我做不了 |
|---|---|
| **Windows / Linux 真机录音 smoke** | 本机是 macOS,物理不可能 |
| **正式新 key 轮换** | 密钥操作,不碰 |
| **麦克风里的真人语音内容** | 我能点录音、验权限流程与状态机,但发不出声音;转写准确率需真人说一句 |

详见收口时产出的《真实环境验收指南》。

---

## B · 审计结论(2026-07-25)

三路审计 + 主会话亲验。**每条阻断/高危均经主会话逐行复证**,非采信子代理结论。

### 🔴 阻断 1 — M1 只建成了一半:受管路由带图/视频的对话 100% 失败

**主会话已亲自证实两侧代码**:

| 侧 | 事实 | 证据 |
|---|---|---|
| 桌面端 | 受管路由(`caps.RemoteMedia != nil`)把 **lease 的绝对 HTTPS URL** 塞进 `ContentPart.ImageURL` / `VideoURL` | `backend/internal/app/attachment/attachment.go:275-281`(image)、`:289-295`(video)、`stagedMediaURL` `:353-370` |
| 网关 | `validateImage` **非 `data:` 前缀一律 400**;`validateVideo` 必须 `data:video/mp4;base64,`;`InboundRequest` **无任何 media handle 字段** | `Anselm-API-Serve/internal/domain/chat/content.go:514-521,548-553`、`internal/domain/chat/chat.go:37-46` |

**后果**:生产上(`MEDIA_ENABLED=true`)每一次带图片或视频的受管对话被网关 400 `BAD_REQUEST: image_url must be a base64 data URI` 拒绝;`inspect_media` 的图像复查同样 100% 失败。

**规范原文**(§6.1 第 3 条):「completion 只引用网关签发的 handle」——**网关侧从未实现消费端**,只实现了 upload/lease 的生产端 + 上游拉取端。桌面端却已按「lease URL 即 image_url」发布。

**为什么门禁抓不到**:网关 e2e 对 `media/leases|fetchPath|leaseId` 零命中——没有任何测试把 media lease 与 chat completion 串起来;桌面端测试用 fake uploader 断言 HTTPS URL,网关测试用 data URI 断言非 data URI 必 400。**两仓各自全绿,交界处无人守。**

### 🔴 阻断 2 — `make -C backend testend` 红着 4 个场景(主会话亲跑证实)

`TestPromptR6_PostCompactionView` / `TestChat_CompactionWatermark` / `TestContractChat_GeneratingFlagAndFinalizeWindow` / `TestContractChat_MessagesPhysicalTruth`

全在 chat/压缩/prompt 域(非 audio 片)。**testend 不进 `make verify`**(T5 明文),所以这四条红了没有任何信号——正是 CLAUDE.md T5.1 警告的「测试红了 11 天没人知道」。

### 🟠 高危(跨仓)

| # | 发现 |
|---|---|
| 高-1 | `multimodal.available` 只看有无 Qwen key,**不看 `MEDIA_ENABLED`**;桌面端据此宣称 Vision/Video。`MEDIA_ENABLED=false` 的部署 → 用户每次发图吃 503 硬中断整回合 |
| 高-2 | 网关 `supportedMIME` 只六项白名单 vs 桌面端 `image/*` 前缀判据;HEIC(iPhone 默认)/AVIF/未 ready 的 GIF → `Create` 400 → **硬中断整回合**(已被单测固化) |

### 🟡 中危

`QUOTA_EXHAUSTED`(429) 被桌面端当可重试限流并退避重试 3 次(语义正好相反)· `MEDIA_UPLOAD_NOT_FOUND`(404) 被归成「模型不存在」· `version==1` 硬相等,网关按计划升 v2 会静默丢弃全部 route profile · 受管 key 能力档案是桌面端本地合成常量、开通后不再向网关拉 · ASR 握手期 quota/ban/rate 全被压平成 `SPEECH_UNAVAILABLE` · 网关用 `server_vad` 而规范 §8.3 写 Manual mode(文档↔代码) · `MEDIA_UPLOAD_MAX_BYTES` 从不发布 · 网关 PoW 领号闸是热开关而桌面端零 PoW 实现(现关闭,一开即静默失败)

### §13 测试矩阵:51 条 → 已覆盖 9 · 部分 23 · 未覆盖 19

19 条未覆盖分三类:**需真实环境 5**(全在 13.5)· **功能未建成、测试无从写 7**(OCR/视频 probe/音频感知 M3/perception 生命周期/网关双账/离线 fallback)· **纯代码可补但没补 7**(`CONTEXT_INPUT_TOO_LARGE` 终态、utility 不可用降级、网关 `OpenLease` 谓词、麦克风设备类故障、cancel 与迟到 partial/final、mic 连点、录音中切会话/后台/关窗)。

**三处「看起来覆盖了其实没有」**(尤其值得记住):
1. `anselm_test.go:128` 把 text 与 multimodal 预算**都设成 1_000_000**,`ActiveInputBudgetTokens()` 两条分支返回同一个数 → **证明不了 route 切换选对了预算**
2. `chat_composer_test.dart:1329` 测试名写 "uploading gates the send",正文只测了 ready 与 **failed** chip,`uploading` 分支从未走到
3. `testend/fixtures/manifest.json` 的 10 条媒体金标里 **7 条只有生成器 sha256 自测、无任何消费断言**

**门禁归属提醒**:`testend/scenarios`、`testend/golden`、网关 `internal/e2e`(build tag)、网关 live ASR、`deploy/*_test.sh` **五套都不在 `make verify` 里**。§16「§13 无未解释红项」若以 verify 全绿为准,会漏掉这五套的全部证据。

### 🔴 §3.3 十条不变量守卫:**0/10 达标**(§16 硬性要求)

第三路审计结论,已抽验其最高影响的几条。**两个仓都有写这类守卫的成熟手艺**(`backend/internal/pkg/errors/standard_test.go:33` 的 AST 全仓扫描、frontend 的 `convergence_guard` / `no_emoji_guard` / `demo_parity_guard`)——**一条都没用在这十条上**。

三条框架事实(决定了每条的上限):**主仓无 CI 也无 git hook**(`.github` 不存在),全靠人手跑 `make verify`;网关仓有真 CI。`testend`/`evals` 按 T5 明文不入 verify,守卫若只活在那里就是弱守卫。主仓无不变量登记册(`grep WRK-078` 零命中);网关有 `invariants.md`(GW-INV-01..48,71 处代码引用)但 `cmd/docs` 不校验登记册与代码的对应。

| # | 不变量 | 守卫 | 能挡住新违反写法 |
|---|---|---|---|
| 1 | DB 行是真相 | **无** | 否 |
| 2 | 原件本地唯一 | **无**;现行代码四处违反字面表述,**两处被测试锁成了正确行为** | 否 |
| 3 | 每媒体每任务一次感知 | 部分(传输半真守卫;**感知半守着一条生产里没人走的通道**) | 否 |
| 4 | 证据可回溯 | 部分;**反例已在测试套件里跑绿** | 否 |
| 5 | inspect_media 存在 | 部分(挡得住删工具) | 否(默认关的 flag 可全绿绕过) |
| 6 | 窗口诚实 | 部分(主仓 Omni `65_536` 是唯一真钉死;**网关侧全是同义反复**——断言「目录值 == 同一个目录常量」) | 否 |
| 7 | provider 是 hard-limit 权威 | 部分(只覆盖当初被修的那条路径) | 否 |
| 8 | 安全护栏保留 | 部分(body cap 链级继承 + 字面量钉死是真的;限流/磁盘/配额/并发/超时全无) | 部分 |
| 9 | 密钥不下沉 UI | 部分(服务端 `RequireLoopbackHost` 有真守卫;**Flutter 侧零守卫**) | 否 |
| 10 | 内容不进观测面 | 部分(**网关有运行时脱敏底座**;**主仓后端零脱敏**;两仓均无调用点扫描) | 否 |

**最该先处理的两条**:
- **#10 主仓后端零脱敏**:`infra/logger/zap.go` 无任何字段钩子,任何 `zap.String("prompt", …)` 原样写进 stderr **与轮转文件**;content-adjacent 的 37 处日志里 26 处直传 `zap.Error(err)`(如 `attachment.go:459` 把沙箱抽取器错误原文入日志,极易嵌文件路径/文件名/内容片段)。网关那套 `logx.redactAttr` 运行时底座值得移植。
- **#9 Flutter 侧零守卫**:`ANSELM_BACKEND_URL` dev 逃生口**不做任何 scheme/host 校验**,设成 `https://evil.example` 则全 app(含 bearer 与 ASR WebSocket)整体打过去;现有测试只断言正路径产出 `127.0.0.1`。

---

## C · 修复进行中

### C-1 ✅ playback lease 的 testend 契约覆盖(T5.1 缺口)

`TestContractDocsAtt_AudioPlaybackLease` 已补(`3bc3282b`):只有 audio 可签发 / 签发仍走 workspace 门 / 无 header fetch 可取原字节 / Range 得 206+Content-Range / 未知 token 与软删后一律 404 不作存在性预言。单跑绿。

### C-2 🔨 四条红 testend 的诊断(**已定性:陈旧测试,非回归**)

**根因**(主会话逐层追证):`bootstrap/model_info.go:74-80` 的 `windowResolver.ContextBudget` 对 `provider != "anselm"` 返 `(0,0)` → `contextUsage.inputBudgetTokens` 为 0 → `contextmgr.MaybeCompact`(`:175-177`)走「unknown budget — don't compact blind」直接返回。testend 用的是 mock BYOK 模型(`dlgModel = "gpt-4o"`),**故持久压缩整条链不再运行**。

**一次被我撤回的错误修法(记录以免重犯)**:我曾判定该 anselm-only 守卫「打错了对象」——admission 路径在 `resolvers.go:76` 调用点已按 anselm 门控,而本 resolver 的唯一接口消费者是**持久压缩(非准入闸)**,故 contextmgr 里那段写明的 catalog 兜底成了永不可达的死代码。**但 `resolvers_test.go:165` 有一条故意的断言**要求外部 provider 必返 `(0,0)`,且规范 §4.2 明写「外部模型未知/低置信 → **不因本地窗口猜测压缩**;完整尝试」——**规范与既有测试站在一边,我的判断错了,已 `git checkout` 撤回**。

设计其实自洽:模型不抱怨就不必压;真撞墙 → 透明恢复 → 学到软预算(`loop.go:172-177` 的 `RuntimeInputBudget` 覆盖后经 `ObserveContext(InputBudget: budget)` 落进 `contextUsage`)→ 此后持久压缩正常工作。

**待办(下一段接手即可照做)**:四条测试(`TestChat_CompactionWatermark` / `TestPromptR6_PostCompactionView` / `TestContractChat_MessagesPhysicalTruth` / `TestContractChat_GeneratingFlagAndFinalizeWindow`)须按 C1.5 设计重写为「**先驱动一次真 overflow 让模型学到预算,再断言持久压缩**」。前置改动:`testend/harness/llmmock.go:266-272` 的脚本化失败目前把 message 硬编码成 `"scripted provider failure"`,需加一个可自定义错误文案的字段(如 `LLMTurn.ErrorMessage`),使其能被 `IsContextLengthError`(`infra/llm/llm.go:82`,判 `RequestRejectedError.Reason == RejectionContextLength`)识别。**顺带闭合 §13.1 的一条缺口**——「provider 首次 overflow」此前在 testend 无法黑盒。
