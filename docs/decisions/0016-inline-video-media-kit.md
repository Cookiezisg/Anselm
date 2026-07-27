---
id: DOC-063
type: decision
status: superseded
owner: @weilin
created: 2026-07-27
reviewed: 2026-07-27
review-due: 2099-12-31
audience: [human, ai]
---

# 0016 — 内联播放:引入 media_kit(libmpv),视频经 loopback HTTP 流式取

> **⚠️ 已被 [ADR 0018](0018-playback-video-player-per-platform.md) 取代(2026-07-27,同日)。**
> 本篇的**目标**仍然成立(内联播放、播放器惰性构造、loopback HTTP 取流、红绿灯不受影响),被取代的是
> **底座选择与选它的判据**:本篇筛选「Flutter 桌面视频哪家成熟」时**漏掉了 SPM 支持**这一条,而本项目
> macOS 侧早已全面走 Swift Package Manager。media_kit 因此把一具本已只管空壳的 CocoaPods 残骸重新变成
> 承重结构,并 vendored 一个 Mpv framework 进 `ephemeral` 目录——随后一次「删生成目录」就打断了整个
> macOS 构建。保留本篇原文与那次错误的筛选条件,不抹掉。

## 背景 / Context

[ADR 0013](0013-video-generation-synchronous-tool.md) 把「视频内联播放」明确划成一次**独立的依赖决策**:

> **产物渲染**:V1 落 mp4 附件、渲文件卡(可在外部打开)。**内联播放另作决定**——它要引入桌面视频播放栈
> (`media_kit`/`video_player` 的原生依赖),那是一次独立的依赖决策,不该搭在本批里。

用户在 WRK-082 H5.5 拍板要做:「没有内联播放,这个我们要做进来的」。本篇即那次独立决策。

## 决策 / Decision

### 一、用 `media_kit`,不手搓、也不用 `video_player`

`media_kit`(libmpv 底座)是 Flutter **桌面**视频的成熟答案:三平台真支持、硬件解码。`video_player`
是官方插件但重心在移动端,桌面支持历来薄弱。按原则 #8——**有成熟包就用它,而非抄它的实现**。

### 二、播放器**只在用户点击时**才构造

`Player()` 会伸到原生层,而 widget test 里**没有**那一层。一张急切构造播放器的卡片,会炸掉每一个恰好
渲到视频附件的既有测试——它不是「断言失败」,是**崩**。

惰性同时**本就正确**:一份滚过十段片子的 transcript,不该起十个 libmpv 实例。

守卫因此写成「**渲得出来**」而不是「渲成什么样」:能渲出来这件事本身就证明没碰原生层。

### 三、视频**不走字节**,走 loopback HTTP + 鉴权头

这条是**跑出来的,不是想出来的**。前两次探针都以 `Operation not permitted` 失败:

**沙箱化的 macOS app 不能把任意文件路径交给 libmpv**,也不能从 Dart 读它——entitlements 只授了
`files.user-selected.read-only`,`/private/tmp` 下的东西一律被拒。

而 `com.apple.security.network.client` **本来就开着**(为让 app 够得着自己的 sidecar 而授)。故播放器
就像本应用其余每一次读取那样,从 sidecar 流式拉这份附件:

- **流式**:一段 20MB 的片子在下完之前就开播;
- **零重复落盘**:不必先materialize 成临时文件再播;
- **同一条边界**:前端与 sidecar 之间**只有 HTTP**,不共享文件系统路径——`ANSELM_BACKEND_URL` 可以指向
  一个外部后端,那时任何「共享 blob 路径」的假设都会碎。

sidecar 做了 loopback 加固(`RequireBearerToken`),故 URL 必须带头。**libmpv 是否真的会送这些头,是整个
设计所依赖的那个假设**,已用一个「无头即 401」的本地服务器实测:它送了。这条不验,视频会在每个测试里
都绿、只在真后端面前死。

### 四、音频**一并**并过来,只剩一套播放栈

> **本节当日修订(2026-07-27)**。初稿写的是「音频暂不并过来」,理由是「证据只覆盖 macOS,而音频今天在
> 三平台都好好的」。**那个理由不成立**:这个项目在 macOS 上开发,桌面真跑不入门禁,没有任何 CI 构建过
> Linux/Windows 的 Flutter 桌面端——audioplayers 的真实状态与 media_kit **完全一样**(用过的地方能用,
> 别处未知)。我拿来支撑「不换」的那个不对称性根本不存在。保留原文与修订理由,而不是抹掉它。

`AttachmentAudioDriver` 这层缝早就在(注释写明存在理由就是换后端)。合并的账:

- **libmpv 现在无论如何都要打进包**(视频要用)。留着 audioplayers 不是「零成本保守」,是**额外**再背
  一套原生音频栈——合并反而**删掉**一个依赖。
- 两套原生音频栈可能互抢音频设备;一套没有这个问题。
- media_kit 是**为桌面造的**,audioplayers 的桌面支持是后补的、更薄。

**唯一真正的技术疑虑已经量过**:朗读是**短音频 + 高频**(重听同一条是常见动作),而每个 `Player()` 是一个
完整 mpv 实例——起它要多久?探针在朗读规格的片子(24kHz/16bit/mono,2 秒)上测得 **open→playing 7ms**。
可以忽略。这是一个有数据支撑的决定,不是又一次断言。

顺带清掉的:`playBytes` / `toggle(loadBytes:)` **生产零调用**(两个真实调用点都走播放 lease URL),只有
测试在用它——按零历史包袱一并删除,端口只剩 `playUrl` 一种源形状。

## 影响 / Consequences

- **原生依赖进来了,同时走掉一个**:`media_kit_libs_video` 每平台分发 libmpv(安装包变大;**Linux 构建要
  libmpv 开发包**),而 `audioplayers` 被移除。这是本决策买下的代价与找回的零头,写在这里以免将来有人以为
  它是免费的。
- **门禁看不见这一层**。`flutter analyze` + `flutter test` 跑在 Dart VM 上、没有 platform channel——一个
  原生那半缺失或被沙箱拒掉的插件,**照样全绿**。故本批交付了一个真桌面探针
  `lib/dev/probe_media_kit.dart`(自带素材、机器可判、双段:文件路径 + HTTP 带头),它是这一层唯一的证据来源。
  CLAUDE.md 早就写着「桌面真跑不入门禁」——探针是对那句话的补齐,不是绕过。
- **红绿灯不受影响**,且这是**查证过的**:`media_kit_video` 经 Flutter Texture Registry 渲染
  (macOS 走 `CVPixelBuffer`/Metal——README 里那两条 macOS 编译警告正是 `CVPixelBufferRef` 的指纹),
  它以普通 widget 身份参与合成、**不往窗口层级插 NSView**;而 `macos_window_utils` 动的是 NSWindow 本身。
  两者不在同一层。官方文档中也没有任何关于无边框/透明窗口/标题栏改造/窗口插件冲突的已知问题。
  (诚实边界:README 的架构节对 macOS 实现写的是 `TODO: documentation`,故这是**从证据推断**、不是白纸黑字。)
- **一族卡零改动地拿到播放**:`AnMediaRefCard` 仍按**附件行的 mime** 分发,故 chat 工具卡、flowrun 节点
  检查器、实体调试台、approval 门、文档编辑器**同时**得到内联视频,没有一处需要知道播放器的存在(不变量④)。

## 备选 / Alternatives

| 方案 | 为何未选 |
|---|---|
| `video_player` 官方插件 | 重心在移动端,桌面支持历来薄弱;而 media_kit 是桌面场景的成熟答案 |
| 继续渲文件卡、外部打开 | 用户明确要求做进来;而「生成了一段视频却要跳出应用才能看」是一次断裂的体验 |
| 播放器随卡片急切构造 | widget test 里没有原生层,会**崩**而非失败;且十段片子起十个 libmpv |
| 把附件字节写进临时文件再播 | 要等整段下完才出第一帧、要管临时文件生命周期、字节落两遍盘;而 loopback HTTP 已经开着且是流式的 |
| 让 libmpv 直接读 blob 路径 | 沙箱拒(实测 `Operation not permitted`);且 `ANSELM_BACKEND_URL` 允许外部后端,共享文件系统路径的假设会碎 |
| 音频继续留在 audioplayers | 「证据只覆盖 macOS」这条不成立——两者的平台证据完全一样;而 libmpv 反正要打进包,留着它等于白背第二套原生音频栈 |
