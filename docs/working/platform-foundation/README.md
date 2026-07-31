---
id: WRK-042
type: working
status: active
owner: @weilin
created: 2026-06-25
reviewed: 2026-07-31
review-due: 2026-08-14
audience: [human, ai]
landed-into:
---

# Desktop platform foundation

本工作面只追踪尚未落地或尚未跨平台验证的桌面地基。已经存在的能力以
[`references/frontend/platform.md`](../../references/frontend/platform.md) 为准；
2026-06 的详细调研快照已移入
[`archive/platform-foundation-research/`](../../archive/platform-foundation-research/)。

## 当前已落事实

代码已具备：

- Flutter 监管 Go sidecar、health gate、loopback bearer、stdin parent watch 与有界关停；
- macOS 窗口 chrome、几何恢复、全屏适配和整体 UI zoom；
- SharedPreferences 机器偏好、系统 keychain master key；
- launch-at-login adapter；
- 文件选择、拖放、剪贴板、系统打开；
- macOS/Linux/Windows 的 OS notification adapter；
- GitHub Releases 的检查更新提示，但不自动下载或安装；
- 三平台原生 host 与平台化音视频播放实现。

这些是 current reference，不在本工作面重新复制实现细节。

## 未完成面

### PF-01 · Single-instance 与数据目录互斥（P0）

同一 data dir 启动两个 GUI 会产生两个 sidecar 和两个 Scheduler，是正确性风险。
当前 Windows host 直接创建窗口，Linux 明确使用 `G_APPLICATION_NON_UNIQUE`，macOS 也没有
per-data-dir guard。

完成条件：

- guard 在 sidecar spawn 前取得；
- scope 由 canonical data dir 派生，不误伤不同 data dir；
- 崩溃自动释放；
- 第二实例把 argv/deep-link 意图交给第一实例并唤醒窗口；
- 三平台有真实宿主验收。

### PF-02 · Close、background 与 tray 决策复核及落地（P1）

当前 macOS `applicationShouldTerminateAfterLastWindowClosed = true`，Windows close 退出，
没有 tray/menu-bar-extra。Launch-at-login 已有。历史研究曾选择“关闭窗口后驻留后台”，
但该选择没有进入当前实现，也没有按现在的产品形态与三平台约束重新确认。

需要复核并明确：

- macOS 红按钮与 Windows/Linux X 的默认语义；
- pending approval / failed run 是否要求 tray badge；
- 真 Quit 时 active run 的提示与关停策略；
- Linux 无可靠 tray 环境时的退化体验。

完成条件是：历史选择经复核后进入当前参考文档，完成实现，并通过三平台真实宿主验证。
在此之前不引入 tray dependency，也不把 Scheduler 后台运行写成已支持。

### PF-03 · 外部启动意图（P1）

GoRouter 支持应用内 URL，但 OS 层尚未登记 `anselm://`、文件关联或第二实例转发。

完成条件：

- 定义公开 scheme/file types 和稳定 route allowlist；
- 三平台 native registration；
- 冷启动、热启动、非法目标、workspace 不存在与第二实例路径；
- 不允许外部 URL 绕过 workspace/bearer 或直接执行危险动作。

### PF-04 · Release artifact 与 sidecar bundling（P0）

开发态 `make app` 不等于可分发 artifact。仍需证明每个平台的 GUI、Go sidecar、
vendored runtime/media 依赖、licenses、icon/identity、data dir 与首次启动在干净机器可用。

执行合同见 [`release-distribution-playbook.md`](release-distribution-playbook.md)。

### PF-05 · 自动更新安装链（P1）

当前只查询 GitHub Releases 并提示新版本，不下载、不验签、不替换。安装更新必须晚于
签名/发布物、版本单源和回滚策略，不能先接一个 updater UI 假装完成。

完成条件：

- manifest 与 artifact 使用同一版本；
- 下载与签名/哈希验证；
- sidecar 与 GUI 原子升级或可恢复；
- 用户主动确认、失败保留当前可启动版本；
- 三平台安装态真实验收。

### PF-06 · 三平台宿主验收（P0）

现有门禁以 Dart/widget 为主，不能证明签名权限、通知、媒体 decoder、launch-at-login、
窗口恢复和关停在真实 OS 上成立。

每个平台至少需要：

- 干净安装与首次启动；
- sidecar 启停/崩溃恢复/无孤儿；
- 窗口与缩放；
- keychain/credential store；
- OS notification；
- 媒体播放；
- 卸载后用户数据策略。

## 执行顺序

```text
PF-01 single-instance
→ PF-02 close/background decision
→ PF-04 reproducible artifacts
→ PF-06 clean-machine acceptance
→ PF-03 external intents
→ PF-05 signed update installation
```

每项落地时必须同提交更新 frontend platform reference；涉及不可逆平台取舍时新增 ADR。
