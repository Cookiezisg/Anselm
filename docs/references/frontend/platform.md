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
| `make doctor` | 原生桌面工具链诊断 |

Settings 可查询 GitHub Releases 并提示新版本，但不会下载或安装。发行签名、公证、
安装器、sidecar bundling 与安装型自动更新尚未形成已验证流水线；未完成合同见
[`working/platform-foundation/`](../../working/platform-foundation/)，冻结研究见
[`archive/platform-foundation-research/`](../../archive/platform-foundation-research/)，两者都不是
当前可照抄的发行操作手册。

当前 macOS 关闭最后一个窗口后会退出，Windows close 同样退出；历史研究中的“关闭后驻留后台”
尚未落地，也仍需按当前三平台约束复核。
