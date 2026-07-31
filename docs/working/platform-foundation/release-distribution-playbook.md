---
id: WRK-043
type: working
status: active
owner: @weilin
created: 2026-06-26
reviewed: 2026-07-31
review-due: 2026-08-14
audience: [human, ai]
landed-into:
---

# Release and distribution draft

> 本页是待执行合同，不是已验证操作手册。平台政策、证书、费用、CI action 与打包工具
> 都具有时效性；每次真正发行前必须重新读取所选平台和工具的官方文档，并把查询日期、
> 决定与证据写入本页或新的 ADR。

## 当前基线

- 产品版本当前由 `frontend/pubspec.yaml` 表达，但尚未证明覆盖 GUI、Go sidecar 和所有
  artifact metadata。
- macOS/Linux application ID 已使用 `website.anselm.app`；Windows metadata 仍需发行级复核。
- 当前仓库没有可声明为已验证的三平台签名、公证、installer、发布 CI 或安装型自动更新链。
- 开发/测试命令与 current host 能力见
  [`references/frontend/platform.md`](../../references/frontend/platform.md)。

## Release 0 的完成合同

### 1. 版本与来源

- 一个 release version 驱动 Flutter、macOS bundle、Windows resource、Linux package、
  Go sidecar 和 artifact 名称；
- clean tag/commit 可重建；
- release notes、license/NOTICE 与 SBOM 绑定同一 commit；
- build 不读取开发机未声明状态。

### 2. Artifact 内容

每个平台的安装包必须包含并验证：

- Flutter GUI；
- 匹配架构的 Go sidecar；
- 必需的 native plugins/codecs；
- brand assets、locales、licenses；
- 正确 executable permissions 与 runtime lookup；
- 首次启动所需目录由应用创建，而不是预置用户数据。

### 3. 平台信任链

发行前分别从当前官方文档确认：

- macOS：Developer ID、hardened runtime、entitlements、notarization/stapling；
- Windows：选择的签名服务/证书、timestamp、installer 与 reputation 预期；
- Linux：目标格式、desktop entry、MIME/scheme、依赖与仓库策略。

任何凭证只进入受保护的 CI secret store；日志、artifact 和 fork PR 不得获得 secret。

### 4. CI 与发布

```text
tag/approved manual trigger
→ per-platform clean build
→ tests and artifact inspection
→ sign/notarize where applicable
→ clean-machine smoke
→ generate checksums/manifest/SBOM
→ publish immutable artifacts
→ verify download and install
```

不允许未签 artifact 与签名 artifact 共用模糊名称，也不允许失败 job 发布部分 release。

### 5. Clean-machine acceptance

三平台分别记录：

- 下载、安装、首次启动与 workspace onboarding；
- GUI 找到并监管 sidecar；
- loopback health/bearer；
- Function/Handler/MCP runtime 最小路径；
- notification、媒体播放与 credential store；
- 真 Quit 后无 sidecar/child orphan；
- upgrade、rollback 与 uninstall 的数据保留结果。

### 6. 更新

首个发行可以只提供“检查新版本并打开下载页”。自动安装只有在 artifact trust chain
稳定后才进入范围，且必须验证：

- manifest authenticity；
- artifact checksum/signature；
- GUI + sidecar 版本一致；
- 下载中断与安装失败可恢复；
- 用户数据不参与 binary rollback；
- 当前版本仍可启动才允许报告更新成功。

## 重新验证清单

真正执行前逐项写入日期与官方链接：

- Flutter 当前桌面 release/build 指南；
- Apple signing/notarization 与 entitlement 要求；
- Microsoft 当前 code-signing/installer 指南；
- 选定 Linux packaging target 的规范；
- GitHub Actions/Release 与所选 action 的固定 commit；
- updater、installer、codec 和 vendored dependency 的当前 license/security 状态。

旧的详细研究仅作线索，见
[`archive/platform-foundation-research/`](../../archive/platform-foundation-research/)；
不得从其中复制价格、政策或命令而不重新验证。
