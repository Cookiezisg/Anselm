---
id: DOC-053
type: decision
status: active
owner: @weilin
created: 2026-07-09
reviewed: 2026-07-09
review-due: 2099-12-31
audience: [human, ai]
---

# 0008 — 落盘主密钥升级 OS keychain（fresh-install-only 铸钥）

## 背景

后端把 api-key / MCP secret 用 AES-GCM 落盘，密钥种子（`Config.Fingerprint`）此前只有一条路：`MachineFingerprint()`（机器硬件指纹），失败退化 `"anselm-local:"+dataDir`。两者都**不是秘密**——同一台机器上的任何进程都能推导出种子并解开数据库里的密文。WRK-062 拍板 #14 裁定 v1 就升级 OS keychain。

约束（读码实证）：种子参与 `DeriveKey` → 直接决定密文能否解开。**换种子 = 既有密文全部作废**（api-key 必须重录）。因此升级绝不能碰既有安装的种子。

## 决策

1. **后端**：`ANSELM_MASTER_KEY` env → `Config.Fingerprint`（空 = 走原机器指纹路径，行为零变化）。后端不感知 keychain——秘密的存取归拥有 OS 会话的前端。
2. **前端**（`core/process/master_key.dart`，DIP 注入 `BackendController.masterKey`，每次 spawn 重解析）：
   - keychain 有条目（`anselm.master-key`）→ 直接注入；
   - 无条目 **且盘上无 `$HOME/.anselm/anselm.db`**（全新安装）→ 铸 256-bit 随机钥，写 keychain，**读回验证**后注入（读不回 = 静默写失败，如缺 entitlement——弃用，走旧径）；
   - 无条目但库已存在（keychain 化之前的旧装机）→ **返回 null 走机器指纹旧径**——硬注新钥会孤儿化全部既有密文；
   - keychain 任何异常（未签名 dev 构建、Linux 无 libsecret…）→ null 旧径，**启动绝不变砖**。
3. **存取实现**：`flutter_secure_storage`（macOS Keychain / Windows DPAPI / Linux libsecret）。macOS 取 **login keychain**（`MacOsOptions(usesDataProtectionKeychain: false)`）——data-protection keychain 需开发证书签名 + `keychain-access-groups` entitlement，本地 ad-hoc 构建直接编译失败（实测）；login keychain 无此要求且同为 Keychain 加密存储。WRK-043 落 Developer ID 签名后切 data-protection keychain + entitlement。

## 否决的备选

- **迁移旧装机到 keychain**（读出旧种子存 keychain）：机器指纹本身推导自硬件、"迁移"只是换存放处不换种子，安全增益为零；真正换钥需要解密-重加密全部密文的搬迁工序，收益不匹配 v1 复杂度。旧装机保持旧径，新安装即享 keychain。
- **后端直读 keychain**（Go 侧 keychain 库）：跨三平台的 keychain 桥在 Go 侧重复一份前端已有的成熟能力，且 sidecar 无 GUI 会话语境（Linux keyring 解锁提示无处弹）。env 注入保持了「秘密拥有者=前端、消费者=后端」的单向缝。

## 后果

- 全新安装的落盘加密种子首次成为真秘密（OS keychain 保护、随用户会话解锁）。
- dev 挂接（`ANSELM_BACKEND_URL`）不 spawn、不注入——dev 后端继续机器指纹，互不干扰。
- 出厂重置（拍板 #12）删数据目录后，下次启动即走 fresh 路径换新钥（keychain 旧条目被覆写）。
