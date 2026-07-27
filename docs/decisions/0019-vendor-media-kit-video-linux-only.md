---
id: DOC-066
type: decision
status: active
owner: @weilin
created: 2026-07-27
reviewed: 2026-07-27
review-due: 2099-12-31
audience: [human, ai]
---

# 0019 — vendor 一份只声明 linux 的 media_kit_video;CocoaPods 这次真的拆了

> **Supersedes [ADR 0018](0018-playback-video-player-per-platform.md)**。0018 的**判据**是对的、**结论**
> 也是对的——错的是它**声称拆除已经完成**,而拆除根本没有发生。本篇纠正那份记录,并写下真正让它成立的
> 那一步。

## 0. 先纠正记录 / The record 0018 got wrong

ADR 0018 §二写道:「`pod deintegrate` → 删 `Podfile` → 移除两条 `Pods-Runner` include」「拆完实测:
`grep -c Pods project.pbxproj` = **0**」。同一句话也进了 CLAUDE.md 与那次的 commit message。

**三处都是假的。** 提交 `148c7379` 里 `macos/` **一个文件都没被拆**:`Podfile` 与 `Podfile.lock` 仍在
git 里、`Podfile` 的 mtime 停在两天前(从未被动过)、`project.pbxproj` 仍有 **43** 处 Pods 引用、两条
xcconfig `#include?` 仍在第一行。那次提交里确实动了 `Podfile.lock`(8 行)与 `project.pbxproj`(118 行)
——但那是 pubspec 变更后 **`pod install` 自己重跑**的痕迹,是 CocoaPods **正在正常工作**的证据,而它被
当成了拆除的证据。

**一个未执行的操作被报告成了已完成,并附了一个没有跑出来过的数字。** 用户在下一次 `flutter run` 的警告
里发现了它。本篇的每一条实测结论都在下面 §3 附了当场输出。

## 1. 背景:0018 漏掉的那一环 / Context

0018 定的判据是对的——**「按平台」必须落在包的平台声明上,不能靠 Dart 过滤**。它选的实现也是对的:
macOS/iOS 走官方 AVFoundation、Windows 走 `video_player_win`、Linux 走 `video_player_media_kit`。

漏的是**没有拿这条判据去检查自己选的包**:

```
video_player_media_kit   (纯 Dart 桥,不声明任何平台 ✓)
  └── media_kit_video 2.0.1
        pubspec platforms: windows / linux / macos / ios / android / web   ← 声明了 macos
        macos/ 下只有 media_kit_video.podspec,没有 Package.swift
```

于是:Flutter 见到「有插件不支持 SPM」,就在**每次 macOS 构建时重新生成 `Podfile` 并跑 `pod install`**
——为的是一个 macOS **一次也不会被调用**的 100KB 纹理桥(`initMediaPlayback()` 只写了
`ensureInitialized(linux: true)`)。**为 Linux 而来的一个纹理桥,把整套 CocoaPods 钉在了 macOS 上。**

这与 fvp 那次是**同一个错误的第二次**:仍然以为「Dart 侧只对 Linux 生效」等于「macOS 不会被牵连」。

**穷尽过替代品,没有现成的**:

| 包 | 平台声明 | 为何不可用 |
|---|---|---|
| `media_kit_video` 2.0.1(最新,2025-12-02) | 含 macos,只有 podspec | 就是本病灶 |
| `flutter_mpv_video` 2.0.4(media_kit 的活跃 fork) | **仍含 macos** | 同病 |
| `flutter_gstreamer_player` | linux/android/ios,**无 macos** | 2022 年起弃养;且是自己的 API、不是 `video_player` 实现 |
| `flutterpi_gstreamer_video_player` | 纯 Dart | 只服务 flutter-pi 嵌入式,不是桌面 GTK 嵌入器 |

**pub.dev 上不存在「不声明 macos 的、video_player 兼容的 Linux 后端」。** 所以自己扛。

## 2. 决策 / Decision

### 一、vendor `media_kit_video`,`platforms:` 只留 `linux`

`third_party/media_kit_video/` = pub 2.0.1 的 `lib/` + `linux/` + `LICENSE` + `pubspec.yaml` **逐字拷贝**,
经 `dependency_overrides` 接入(与 super_editor 同一套 vendor 机制,见 [ADR 0009](0009-vendor-super-editor-presenter.md))。

**与上游的分歧恰好一处**:`platforms:` 删掉 macos/ios/windows/android/web,只留 linux。**只有 Linux 没有
系统解码器,故只有 Linux 需要它**——其余平台各有系统底座,那五行声明纯粹是让它们白背一个用不到的插件。

随之丢弃 4MB 原生源:`common/darwin`(3.3M)、`macos/`(228K)、`ios/`(88K)、`windows/`(88K)、
`android/`(40K)。它们在不被声明之后就是纯死重;linux 的 `CMakeLists.txt` 一处也不引用它们(查过)。
vendor 体积 **416K**。

**代价说清楚**:我们从此自己跟这个包的上游。它是 2025-12-02 的最新版(CocoaPods registry 转只读那天),
而 media_kit 主线已停更;换言之上游本来也不会替我们修这件事。将来若上游加了 SPM 支持,**该做的仍不是
回到上游版**——SPM 只会让 macOS 用**另一种方式**去链一个它不需要的插件。回到上游的条件只有一个:上游
把平台声明拆开。

### 二、CocoaPods 从 macOS 侧移除(这次真的做了)

`media_kit_video` 是 16 个 macOS 插件里**最后一个**不支持 SPM 的;其余 15 个已全在 Swift Package 上
(逐个查过 `Package.swift`,见 §3)。删掉那行声明,CocoaPods 就再没有存在的理由。

执行:`pod deintegrate`(**工具改工程文件,不手搓 pbxproj**——原则 #8)→ 删 `Podfile`/`Podfile.lock` →
`.gitignore` 摘掉 `**/Pods/`(S22:忽略规则同步到当前物理事实)。

## 3. 实测 / Evidence

**这一节的每一行都是当场命令的输出。**

- **macOS 插件 SPM 审计**(遍历 `.flutter-plugins-dependencies` 的 macos 列表,逐个找 `Package.swift`):
  15 个 SPM ✓ · `media_kit_video` 唯一 POD ✗ ·`path_provider_foundation` 是 `dartPluginClass`(纯 Dart
  FFI、不参与原生构建,**不需要任何集成系统**)。
- **vendor 生效**:`flutter pub get` 后,macos 插件 15 个、**`media_kit_video` 不在其中**;linux 16 个、
  `media_kit_video` 在其中且路径指向 `third_party/media_kit_video/`;windows 走 `video_player_win`。
- **拆除**:`pod deintegrate` 报 `No traces of CocoaPods left in project`;
  `grep -c Pods project.pbxproj` 从 **43 → 0**;两条 xcconfig include 由 deintegrate 一并摘除;
  `Runner.xcworkspace` 只剩 `group:Runner.xcodeproj` 一个 FileRef。
- **决定性一步——`flutter clean` 后完整重建**:构建通过,而 **`Podfile` / `Podfile.lock` / `Pods/`
  没有回来**(这正是上一次没做、因而没能发现问题的检查)。
- **包内**:`Contents/Frameworks/` 只剩 `App.framework` / `FlutterMacOS.framework` /
  `objective_c.framework`——**`media_kit_video.framework` 已从 macOS 包里消失**(其余 15 个 SPM 插件静态
  链进 Runner,本就不出现在 Frameworks/)。
- **注册面**:`GeneratedPluginRegistrant.swift` 里视频只有 `video_player_avfoundation`。

## 4. 影响 / Consequences

- **macOS 侧只剩一套集成系统(SPM)**。0018 §一那句「删生成目录是安全的,在两套集成系统并存时不再成立」
  从此不再适用于本仓——但它作为教训仍然成立,并且正是它促成了本篇。
- **三平台各自的底座不再互相牵连**:任一平台换实现,其余两个的构建面一行都不用动。
- **Windows / Linux 的播放行为仍未真机验证**——与 0018 相同的时差,不是本篇新增的。**Linux 侧现在多一
  条要验的**:vendor 后的 `linux/CMakeLists.txt` 是否照常构建。这必须在真跑 Linux 那一轮**头一件**验。
- **多一个 vendor 要跟**。`third_party/` 现有两个(super_editor、media_kit_video),两个都在 pubspec 里
  写明了「与上游的分歧恰好是什么」。

## 5. 备选 / Alternatives

| 方案 | 为何未选 |
|---|---|
| 换一个不声明 macos 的 Linux 后端 | **查穷尽了,不存在**(见 §1 表) |
| 留着 CocoaPods 只管这一个插件 | 就是「两套集成系统并存」本身,而它已经打断过一次整个 macOS 构建;且 CocoaPods registry 已于 2025-12-02 永久只读 |
| Linux 暂不做内联播放 | 三端完整可用是产品要求,不是可选项(用户 0727 明确) |
| 自己写一个 linux-only 的 `video_player` 实现(GStreamer/GTK) | 就是在重写 `media_kit_video` 的 linux 半边;vendor 它拿到完全相同的结果,代价小两个数量级 |
| 编辑 ADR 0018 就地改掉那段假话 | ADR 不可变(收尾清单第 6 条),只能 supersede——故有本篇 |
