---
id: DOC-037
type: how-to
status: active
owner: @weilin
created: 2026-06-12
reviewed: 2026-07-31
review-due: 2027-01-27
audience: [human, ai]
---

# 数据目录与跨机迁移

## 数据都在哪

一切在 `$ANSELM_DATA_DIR`（默认 `~/.anselm`）：

| 路径 | 内容 |
|---|---|
| `anselm.db` | SQLite 全库（实体/版本/执行日志/消息/索引） |
| `device-proof.key` | 网关设备证明的 Ed25519 seed；由主密钥 AES-GCM 加密，文件权限 `0600` |
| `workspaces/<ws>/` | 文件式存储：memories / blobs（SHA256 CAS）/ skills |
| `sandbox/` | 运行时 `runtimes/<kind>/<version>/`（python/node/uv/dotnet/llamasrv/embedmodel）+ env `envs/<kind>/<id>/`——**纯派生缓存，可不迁** |
| `logs/anselm.log` | 轮转日志（10MB×3，保留 28 天，gzip）——报障就发这个文件 |

## 备份

直接拷贝整个数据目录（建议先停 app，让 SQLite WAL checkpoint 干净落盘）。同一台机器上的恢复 = 拷回去，完整无损。

## 跨机迁移：密文配置需要重填

全新桌面安装会在 OS keychain 铸随机主密钥，并通过 `ANSELM_MASTER_KEY` 注入
sidecar；既有安装没有 keychain 条目或 keychain 不可用时，后端退回机器指纹
（macOS `IOPlatformSerialNumber` / Windows `MachineGuid` / Linux
`/etc/machine-id`）派生 AES-256-GCM 密钥。两条路径都刻意不让“只拷数据目录”
携带解密能力。

因此，直接把数据目录复制到另一台机器后，以下密文需要重新建立：

1. **API keys**（模型密钥）——重新录入 + `:test`
2. **Handler init-config**（init 参数，含密钥类）——重新 `PUT /handlers/{id}/config`
3. **MCP server 的 env/headers/OAuth token**——重新配置、重新授权或重 import
4. **受管 API 的 device proof seed**——由新安装重新 provision，不复制旧身份

**其余一切数据完整可用**：实体与版本、对话与消息、执行日志、workflow/flowrun、
文档、记忆、技能、blob 附件。`sandbox/` 不必迁移，新机首用按需重装
（directInstaller）。

不要手工复制 keychain 条目或设置旧机器的 `ANSELM_MASTER_KEY` 来绕过重填；当前没有
受支持的密钥导出协议，错误处理会让旧密文或 device identity 处于不可诊断状态。

> 完整 export/import（用户口令重加密密文）在 roadmap，未排期。
