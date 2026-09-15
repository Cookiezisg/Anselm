---
id: DOC-070
type: reference
status: active
owner: @weilin
created: 2026-07-31
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# 前端平台层——当前物理事实

> 本篇登记跨 feature 的桌面平台能力。业务 feature 不复制这些机制，只消费 `core/` 与 `app/` 暴露的缝。

## 1. 启动与进程

- `main.dart` 安装 Flutter/Dart 错误入口、窗口与缩放 binding，再挂 `ProviderScope`。
- Flutter framework 错误由 `installErrorHandlers` 以可恢复 ErrorWidget 收口；真实 App console 同时记录压缩异常行和堆栈，供台架定位构建/布局红线。
- `AppStartupGate` 托管 Go sidecar：Dart 选择端口，以 `ANSELM_ADDR` 启动，等待 `/api/v1/health` 后放行；开发时 `ANSELM_BACKEND_URL` 可连接已运行后端，且就绪后仍由连续健康探测监督，外接 backend 失联达到阈值会回到全 App 可重试错误门。
- 正常退出先优雅停止 sidecar；崩溃路径由 `ANSELM_PARENT_WATCH=1` 的 stdin EOF 死人开关收口。
- `WorkspaceGate` 以服务端 workspace 名册为准；无行进入创建旅程，有行激活并进入唯一 `AppShell`。

## 2. 桌面壳

- `AppShell` 是 app/demo 唯一壳；左岛、中心海洋、右岛和顶带通知在此装配。
- chat/entities/library/scheduler 四海洋与 settings 共用同一 shell；路由使用常量 page key 保持壳身份，切页不重挂三岛。
- 左右岛可拖、可收；窄窗下冻结海洋终宽以避免过渡期 relayout。岛内 feature 只能组装既有原语。
- UI、内容、代码字体是三条机器级偏好轴；缩放用 `scaled_app` 做整体重排，不用视觉 Transform 欺骗布局。

## 3. 网络、状态与通知

- `ApiClient` 统一注入 base URL、workspace header、loopback bearer 与错误 envelope；workspace/base URL 变化会重建客户端和三条 SSE。
- `SseGateway` 只维护 `messages` / `entities` / `notifications` 三条 workspace 级连接，并在 plain Dart 层按 scope demux。
- 顶带 `noticeCenterProvider` 是 app 内即时消息唯一出口；左岛通知托盘保存 durable 账本；未聚焦时后台事件可进入 OS 原生通知。
- `core/overlay` 只保留阻断式确认/说明模态；说明类弹窗只有一个中性关闭动作，不能伪装成危险确认；旧右上 toast 展示层已退役。

## 4. 本地持久化与安全

- 机器级偏好进入 `SharedPreferences`；workspace 业务设置进入后端。两条轴不混。
- master key 由系统 keychain 铸造和保存，见 [`ADR 0008`](../../decisions/0008-master-key-keychain.md)。读写有单步超时；授权 UI 或 keychain daemon 挂起时，应用必须在有界等待后降级到 legacy fingerprint，而不是冻结启动。
- launch-at-login 经平台 adapter 注册，设置偏好与 OS 注册表分别承担 UI/系统事实；
  close 后后台运行与 tray 尚未形成产品合同。
- loopback 安全由后端默认 `127.0.0.1`、bearer 与 Host 校验三层完成；前端不复制鉴权规则。
- 文件选择、剪贴板、拖放、目录打开和终端打开经平台适配层；feature 不直接散落平台判断。macOS 的本地路径
  通过 `app/system_path` MethodChannel 进入 AppKit：Finder 定位使用 `NSWorkspace.selectFile`，Storage 的
  数据目录与日志目录都以可观察的选中结果为准，不把沙箱下无法证明的子窗口打开回报成成功。

## 5. 媒体与原生宿主

- 媒体卡、receipt 解析、附件读取、图像查看、音视频控制位于 `core/media/`，供 chat、scheduler、entities、approval 与 library 复用。
- 视频播放按平台选择：Apple 平台用 AVFoundation，Windows 用 Media Foundation，Linux 用 vendored linux-only `media_kit_video`；见 [`ADR 0019`](../../decisions/0019-vendor-media-kit-video-linux-only.md)。
- macOS 宿主使用 Swift Package Manager，不依赖 CocoaPods。Windows/Linux host 仍是 Flutter 的原生壳工程。

## 6. 工具链与门禁

| 命令 | 作用 |
|---|---|
| `make -C frontend quick` | diff 驱动的提交内环 |
| `make -C frontend verify` | codegen、analyze、分组测试的 pre-push 门禁 |
| `make -C frontend gallery` | 原语与状态目录 |
| `make -C frontend demo` | 真壳 + fixtures |
| `make -C frontend app` | 真壳 + sidecar |
| `make -C frontend package` | 本机发行包：sidecar 装进 release app，归档到 `frontend/dist/` |
| `make doctor` | 原生桌面工具链诊断 |

## 7. 发行

`.github/workflows/release.yml` 由 `v<version>` tag 触发，版本必须等于 `frontend/pubspec.yaml`
的 `version`；同一个数字盖进 Go sidecar（`-X main.version`）与产物名。三平台各自构建
Flutter release app，把 sidecar 放到可执行文件旁（`BackendController` 从那里解析），经
`frontend/tool/package.sh` 归档：macOS 为通用二进制 `Anselm-<v>-macos.dmg`；Linux 为
`Anselm-<v>-linux-x86_64.AppImage`、`anselm_<v>_amd64.deb`（装到 `/opt/anselm`，`linux/packaging/`
提供桌面项与图标）和便携 `Anselm-<v>-linux-x64.tar.gz`；Windows 为 Inno Setup 按用户安装器
`Anselm-<v>-windows-x64-setup.exe`（`windows/installer/anselm.iss`，装到 `%LocalAppData%\Programs`）
和便携 `Anselm-<v>-windows-x64.zip`；连同 `SHA256SUMS.txt` 发布到 GitHub Release；任一平台失败则不发布。

macOS 签名分两档：仓库 secrets 里有 `MACOS_CERT_P12`/`MACOS_CERT_PASSWORD`（Developer ID
Application 证书）时，嵌套框架、sidecar（`Sidecar.entitlements`：app-sandbox + inherit）和 bundle
（`Release.entitlements`）依次以 hardened runtime + 时间戳签名，DMG 再签名；再有
`NOTARY_KEY_P8`/`NOTARY_KEY_ID`/`NOTARY_ISSUER_ID`（App Store Connect API key）时经 notarytool 公证并
staple。没有这些 secrets 则退回 ad-hoc 签名，用户首次打开需手动放行。证书只进 job 内的一次性钥匙串。DMG 由 appdmg 出图：背景 `macos/dmg/background.png`
由 `tool/dmg_background.py` 渲染（800×500 窗口、176 图标，app 与 Applications 的坐标两处必须一致）；
三平台图标由 `tool/app_icon.py` 从品牌几何生成，改图标只改脚本再重跑。Windows 与 Linux 产物尚未签名；官网下载页读取 Releases 的最新资产。Windows 签名与 clean-machine 验收记录仍是
[`working/platform-foundation/`](../../working/platform-foundation/) 的未完成合同。

应用内更新按平台分三档。macOS 走 Sparkle 2（本地插件 `packages/anselm_updater`，Swift Package 固定
2.10.0）：插件注册时创建 `SPUStandardUpdaterController`，后台按 `Info.plist` 的
`SUScheduledCheckInterval`（一天）静默检查 `SUFeedURL`（最新 Release 附带的 `appcast.xml`），
用 `SUPublicEDKey` 校验附件的 EdDSA 签名，经 `SUEnableInstallerLauncherService` 在沙箱外安装并重启；
两个 entitlements 文件为此放行 `website.anselm.app-spks`/`-spki` 两个 mach 服务名。`package.sh` 在
`SPARKLE_PRIVATE_KEY_PATH` 与 `SPARKLE_BIN` 齐备时用 `generate_appcast` 产出 appcast，CI 从
`SPARKLE_PRIVATE_KEY` secret 注入。Dart 侧 `AnselmUpdater` 只做三件事：About 面板的手动检查、把
Settings 的“自动检查更新”开关镜像到 Sparkle、读 feed URL；Sparkle 的标准对话框负责其余交互。
Windows 仍由 `update_check_provider` 查询 Releases，About 面板的“安装更新”把 `-setup.exe` 下载到临时目录、
按 `SHA256SUMS.txt` 校验后以 `/SILENT /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS` 启动安装器并退出
当前进程；Linux 只提示并打开 Release 页。本地验证 Sparkle 链路时可用
`defaults write website.anselm.app SUFeedURL <本地 appcast>` 临时改 feed，验完 `defaults delete`。

当前 macOS 关闭最后一个窗口后会退出，Windows close 同样退出；历史研究中的“关闭后驻留后台”
尚未落地，也仍需按当前三平台约束复核。
