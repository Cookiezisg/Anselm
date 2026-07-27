---
id: DOC-065
type: decision
status: superseded
owner: @weilin
created: 2026-07-27
reviewed: 2026-07-27
review-due: 2099-12-31
audience: [human, ai]
---

# 0018 — 播放底座:一套官方 API、按平台选实现;CocoaPods 就此拆除

> **⚠️ 已被 [ADR 0019](0019-vendor-media-kit-video-linux-only.md) 取代(2026-07-27,同日)。**
> 本篇的**判据**(「按平台」必须落在包的平台声明上)与**实现选择**(macOS/iOS AVFoundation、Windows
> Media Foundation、Linux libmpv)都仍然成立。被取代的原因有两条,且第二条是硬伤:
> ①本篇**没有拿自己那条判据去检查自己选的包**——`media_kit_video` 的 pubspec 里就声明着 macos,于是
> CocoaPods 在每次 macOS 构建时被自动接回来;②**本篇 §二「CocoaPods 就此拆除」所报告的操作从未发生**
> (`Podfile` 从未被删、43 处 pbxproj 引用一处未动、`grep -c Pods = 0` 这个数从未被跑出来过)。
> 保留本篇原文与那份错误记录,不抹掉;订正与真正的拆除见 0019。
>
> **Supersedes [ADR 0016](0016-inline-video-media-kit.md)**(media_kit / libmpv)。0016 的**目标**不变
> ——内联播放、惰性构造、loopback HTTP 取流——变的是**底座**与选它的那条判据。

## 背景 / Context

0016 选 media_kit,理由是「Flutter **桌面**视频的成熟答案」。那个筛选**漏了一个条件**:项目 macOS 侧
**早已全面走 Swift Package Manager**——12 个插件(`window_manager` / `macos_window_utils` /
`file_selector` / `record` / `pasteboard` …)全是 Swift Package,而 `Podfile.lock` 里只剩
`FlutterMacOS` 一个空壳。用户先于我发现了这具残骸。

media_kit 的两个 macOS 插件**不支持 SPM**,故它们把那具残骸**重新变成了承重结构**。代价随即兑现:

- `media_kit_libs_macos_video` 把 Mpv framework **vendored 进 `macos/Flutter/ephemeral/.symlinks/`**;
- 我为绕开一个没看懂的 `make quick` 报错,`rm -rf` 了那个目录两次——对 12 个 SPM 插件它确实是纯生成物,
  **唯独对 CocoaPods vendored 的 framework 不是**;
- 结果:`ld: framework 'Mpv' not found`,而 `make verify` **四个门禁全绿**。

**「删生成目录是安全的」这句话,在两套集成系统并存时不再成立。** 这是双系统的真实代价,它第一次咬人就
咬掉了整个 macOS 构建。

## 决策 / Decision

### 一、上层认**一套 API**,实现**按平台选**——而「按平台」必须落在**包的平台声明**上,不是 Dart 过滤

只对官方 `video_player` 说话:

| 平台 | 实现 | 原生代价 |
|---|---|---|
| macOS / iOS | 官方 **AVFoundation** | **零**——系统解码器 |
| Windows | **`video_player_win`**(只声明 windows) | 系统 Media Foundation,~130KB DLL |
| Linux | **`video_player_media_kit`**(纯 Dart 桥)+ **`media_kit_libs_linux`**(只声明 linux) | libmpv,仅 Linux |

**这一条我做错过一次,而错法很有教育意义。** 第一版用了 `fvp` 一个「全平台」包,在 Dart 里
`registerWith(options: {'platforms': ['windows','linux']})` 过滤。那个过滤**是真的**——但它只决定 Dart
**注册**哪个实现,**拦不住 Flutter 去链那个插件的 framework**:`fvp` 的 pubspec 声明了 macos,于是
`fvp.framework` + **26MB 的 `mdk.framework`** 照样进了 macOS 包。

更糟的不是体积:mdk 用 **weak 链接**声明了多套可选 ffmpeg(`libavdevice` 等),dyld 沿 `@rpath` 找不到包内
副本时**会一路找到 `/opt/homebrew/.../ffmpeg`**——两份 libffmpeg 同时在进程内、`AVFFrameReceiver` 撞名、
ObjC 运行时警告「may cause mysterious crashes」。**一个「加载了哪些库取决于它跑在谁机器上」的 app**。

正确做法是让「按平台」落在**包的平台声明**上:带原生代码的两个包各自只声明自己的平台,桥接是纯 Dart。
实测 macOS 包内只剩 `media_kit_video.framework` **100KB**,`otool -L` 确认**不链 Mpv、不链 ffmpeg**;
`objc` 警告与 mdk 横幅一并消失。

**为什么不是一套底座打天下**:Windows/Linux **没有可用的系统解码器**,那两个平台**无论选谁都必须自带
一个**——这是平台现实,不是哪个包的错。而 macOS **有** AVFoundation。让不需要带库的平台陪着带,还搭上
一套将死的集成系统,这笔账算不过来。

**三平台都有明确落点**,没有任何平台被推给「以后」。**验证时差诚实写明**:macOS 今天真机验;Windows/Linux
的播放行为等真跑那两个目标时验——**与 media_kit 当时的时差完全相同**,不是本决策新增的。

### 二、CocoaPods 就此**拆除**

换掉 media_kit 后 CocoaPods 缩回只管 `FlutterMacOS`。官方文档**没有**「移除 CocoaPods」的流程(迁移是
单向的),但 **Flutter 自己在警告文本里给了完整步骤**:`pod deintegrate` → 删 `Podfile` → 从
`Flutter-Debug.xcconfig` / `Flutter-Release.xcconfig` 移除两条 `Pods-Runner` include。

用 `pod deintegrate` 而**不是**手改 pbxproj:那 43 处引用由工具改,**不手搓原生工程文件**(原则 #8;
本项目在窗口 chrome 上手搓过、栽过)。

拆完实测:`grep -c Pods project.pbxproj` = **0**,`flutter clean` 后完整重建通过。

### 三、附件内容端点改用 `http.ServeContent`(后端)

**这是换底座逼出来的真 bug。** AVFoundation 打开每个媒体 URL 时先发 `Range: bytes=0-1`,答不上来就拒绝
(`CoreMediaErrorDomain -12939`,真机实测)。**拖进度条是同一套机制**:没有 range,播放器永远只能从第 0
字节顺流。

原 handler 手写整段 `Write`,**只是因为 libmpv 恰好线性下载才能用**——正是「换底座就活不过来」的那类假设。
改用标准库 `http.ServeContent`:range/206/Content-Range、条件请求、正确的 416,全部免费,没有一行归我们
维护。

## 影响 / Consequences

- **macOS 侧不再链任何解码库**:AVFoundation 是系统框架;包内与播放相关的只剩 `media_kit_video.framework`
  **100KB**(纹理桥,`otool -L` 实测不链 Mpv/ffmpeg)。`ephemeral` 目录恢复成「删了也没事」的纯生成物
  ——**当初那个事故已实测无法复现**(删掉它、重建、通过)。
- **一套播放栈同时供视频与音频**,`AttachmentAudioDriver` 是这层缝的**第三个**实现
  (audioplayers → media_kit → video_player),而 UI **三次都没改过**——那正是这层缝存在的全部理由。
- **音频延迟重测**(上一套的数**不能顺延**):朗读规格(24kHz/16bit/mono,2 秒)实测 open→playing
  **cold ~126ms / warm 61–124ms**,在感知阈内,音频可与视频共栈。
- **探针整篇重写**并改名 `probe_playback.dart`:换底座后**每一条假设都重验**,尤其
  loopback + `Authorization` 头那条——它是**只会在真后端面前失败**的那种假设。三段全绿。
- **一族卡的第三条渲染路径顺手删掉**:`tool_card_generate.dart` 里图像与视频各自手搓了渲染,而它自己的
  注释却写着「一族卡、不变量④的第一个工具卡消费者」。**它不是**——代价直到 H5.5 给视频加了内联播放、
  而播放**没能到达用户真正会看的地方**才暴露。现在三个体都是 `AnMediaRefCard` 的薄包装。
- **代价按平台分摊,不再互相牵连**:Windows 走系统 Media Foundation(~130KB 垫片);**只有 Linux** 带
  libmpv——那是它没有系统解码器的必然结果。三者都藏在官方 `video_player` 接口之后,故上层代码对此一无所知,
  而**任何一个平台换实现,其余两个一行都不用动**。
- **Windows/Linux 的播放行为尚未真机验证**,与换底座前完全相同的时差,不是本决策新增的;那一轮验证时,
  这两个包各自的成熟度也该一并重估。

## 备选 / Alternatives

| 方案 | 为何未选 |
|---|---|
| 留在 media_kit | macOS 无 SPM 支持(issue #1399 无人认领、无 PR),而 CocoaPods registry **2026-12-02 永久只读**;且它逼出 vendored framework 与「删不得的生成目录」 |
| fvp(全平台包)+ Dart 侧过滤平台 | **试过,不成立**:Dart 过滤只管注册、不管链接,macOS 仍被塞 26MB mdk,且其 weak-link 可选 ffmpeg 会捡走机器上的 Homebrew 副本 |
| fvp 全平台(macOS 也用) | 同上,且会把 libmdk 拖回**唯一不需要它**的平台 |
| flutter_vlc_player | **无 macOS 支持** |
| 只加视频、音频留 audioplayers | 第二套原生音频栈是白背重量;而实测共栈延迟在感知阈内 |
| 手改 pbxproj 拆 CocoaPods | 43 处原生工程文件手搓——本项目在这类事上栽过;`pod deintegrate` 是工具自己的活 |
| 保留 CocoaPods 空壳不拆 | 它是「两套集成系统并存」这一类事故的**根**,而拆除步骤 Flutter 自己给了 |
