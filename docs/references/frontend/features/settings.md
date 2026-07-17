---
id: DOC-054
type: reference
status: active
owner: @weilin
created: 2026-07-09
reviewed: 2026-07-09
review-due: 2026-10-07
audience: [human, ai]
---

# Feature:Settings(设置模块:齿轮进的 13 面板 + 机器/工作区两域)—— 当前形态

> 齿轮进的设置海洋:双骨架 IA(偏好 / 资源 / 系统三段 · 13 面板)+ 机器域与工作区域两条持久化轴 + 一批平台地基(热切换 / keychain 铸钥 / 出厂重置 / 更新检查 / 可改绑快捷键)。本篇 = **它现在是什么样**;**怎么一步步建的**(调研 / 16 硬裁决 / 后端工单①–⑩ / S0–S6 阶梯 / 逐片真机 E2E)看建造账 [`WRK-062`](../../../archive/settings/README.md);**DTO** 看 [`contract.md`](../contract.md);keychain 选型看 [`ADR 0008`](../../../decisions/0008-master-key-keychain.md)。

## 一句话

单进程单用户桌面 app 的「控制台」:密钥 / 模型 / MCP / 记忆 / 沙箱 / 存储 / 限额 / 网络 / 快捷键全在一处调,**机器级偏好**(主题 / 缩放 / 窗口 / 快捷键,存本地 `SharedPreferences`)与**工作区级配置**(语言 / 限额 / 代理 / 密钥,存后端 `settings.json` + DB)两条轴分明,每个危险动作都有 type-to-confirm 双闸,改一处即时生效、无需重启(代理例外,需重启 sidecar)。

## 壳与信息架构(S0 地基)

- **入口**:左岛底栏齿轮格 → `selectedOceanProvider = settings`(顶部海洋切换器无选中、齿轮高亮);也可 **⌘,** 直达(全局快捷键)。
- **左岛 = 目录** `settings_rail.dart`:搜索框 + **三段** `Preferences / Resources / System`(System 段可折叠),共 **13 面板**;内建面板粒度过滤(v1 搜索裁决)。
- **中心 = 海洋** `settings_ocean.dart`:每面板一页 `AnPage`(H1 + 注册表体 + 浮层头「设置 / 面板」+ 换面板回顶);`settings_panels.dart` 是**穷尽 switch 注册表**(漏接体 = 编译错)。
- **导航持久化** `settings_panel_provider.dart`:选面板存 `an.settings.panel`,重建同步恢复;过期枚举名回落 general(byName 门)。
- **推入第三级** `settings_detail_provider.dart`:资源详情(密钥编辑 / 工作区编辑 / 记忆编辑 / MCP 详情)推入海洋,面包屑第三段 + Esc 返回 + 换面板弹出。
- **三相等门禁**(`settings_catalog_gate_test`):面板 ↔ 目录、声明键 ↔ 归属分区(`ownedKeys`)、rail ↔ 目录 三者恒等,漏一个即红。

## 13 面板

| 段 | 面板 | 文件 | 是什么 |
|---|---|---|---|
| 偏好 | **通用** General | `panels/general_panel.dart` | 主题三档(含 dark)+ 缩放六档(镜像 `WindowZoom`)+ 语言**单项双写**(UI locale 即时 + `workspace.language` PATCH,失败回滚)+ 记住窗口 + 开机自启 + 自动检查更新。 |
| 偏好 | **通知** Notifications | `panels/notifications_panel.dart` | 三档级别(全部 / 仅需处理 / 静音)+ 只读「需你处理永远送达」+ OS / 应用内两开关 + 切静音一次性确认。喂 `ToastDispatcher` 三闸,详见 [`notifications`](notifications.md)。 |
| 偏好 | **对话** Chat | `panels/chat_panel.dart` | 右岛自动登台三档(与 chat 的 `followModeProvider` **同一份状态**)+ 发送键两档 + webFetchMode(workspace PATCH)+「默认对话模型 → 模型与密钥」ghost 单源链。 |
| 资源 | **模型与密钥** Models&keys | `panels/models_keys_panel.dart` | 旗舰面板:受管免费档卡(未开通 CTA / 配额 meter / 预算横幅)+ 密钥列表(受管锁顶 + Failed 徽 + Test/Edit/Delete,**行点击 = 编辑**)+ 场景默认三下拉 + 搜索默认键。`KeyForm` 是 **S-3 状态机**(首次 POST 绑 id、此后一律 PATCH;secret 提交即清)。新原语 `AnSecretField`/`AnMeter`。 |
| 资源 | **MCP 服务器** MCP | `panels/mcp_panel.dart` + `mcp_forms.dart` | 名册(五态点 + 统计条 + 三 CTA)+ 详情(状态卡 + lastError 红字 + 工具 / 调用历史 / stderr 三 tab)+ 手动添加 + 导入 + 市场(本地搜索 + `:plan` 驱动安装表单)。**帧不可信**:`kindStream(entities,'mcp')` 任何帧 → 300ms coalesce 一次重取 + 410 强制重取。 |
| 资源 | **记忆** Memory | `panels/memory_panel.dart` | 名册(全部 / 已固定投影 + 搜索 + 行内金 pin toggle + source·mtime)+ 推入编辑(建时活校验 slug、编辑锁名 + Cmd+S)+ 确认物理删除。PUT **恒送 `source:'user'`**(F147:更新时后端忽略、创建时必需)。 |
| 资源 | **沙箱** Sandbox | `panels/sandbox_panel.dart` | 引导健康门(ok=false 红卡 + 重试)+ 磁盘 meter + 运行时(装 / 删 [409 `SANDBOX_ENV_IN_USE` 诚实])+ **五 owner 环境 tab**(function/handler/mcp/skill/conversation,状态点 + runningPid)+ GC(N 天 + 立即全回收两步)。 |
| 系统 | **工作区** Workspaces | `panels/workspaces_panel.dart` | 名册(色点 + 当前高亮,**点行 = 热切换**)+ 新建(六预设色盘)+ 推入编辑(改名同步底栏 / 改色 / **页尾危险区** `AnTypeToConfirm` 输名解锁,stats 真数字入散文;**当前 ws 与最后一个绝不给删**)。 |
| 系统 | **存储与日志** Storage | `panels/storage_panel.dart` | 数据目录只读(后端解析,绝不猜)+ 访达 / 日志文件夹 + 沙箱磁盘 meter + 诊断复制 + **Run 历史保留**(机器级四档下拉)+ **数据库**(T4/WRK-070 机器级节:`storageStatProvider` 诚实显示「库 X MB,其中 Y MB 可回收」+「压缩数据库」按钮=`POST /storage:compact` 同步 VACUUM,忙态「压缩中…」+转圈锁库几秒、完成 toast「已回收 Y」+ 失效重取;**非危险动作**[VACUUM 不删行]故无输名双闸)+ 重置本地偏好(`SettingsPrefs.resetAll` 声明集)+ **出厂重置**(前端编排,`AnTypeToConfirm` 输「Anselm」双闸)。 |
| 系统 | **高级限额** Limits | `panels/limits_panel.dart` | **schema 驱动**(`GET /limits/schema` → group AnSection + 每字段 AnSettingRow:点路径 `_valueAt` / 提交构部分嵌套 PATCH / modified 竖条 + 单项重置);越界回滚到服务端真相;零复刻 Go 常量。 |
| 系统 | **网络** Network | `panels/network_panel.dart` | 三 proxy 字段(http/https/no_proxy)水化 + 整体替换 PATCH + **重启生效**橙字 + 全机域徽。 |
| 系统 | **快捷键** Shortcuts | `panels/shortcuts_panel.dart` | 6 全局命令逐行(当前键帽 + 点键帽录下一组合键 [须带修饰键 / 冲突则拒并说明 / Esc 取消] + modified 竖条 + 单项重置 + 全部重置);录制态蓝框「Press a new chord…」。见下「全局快捷键」。 |
| 系统 | **关于** About | `panels/about_panel.dart` | 版本区(app 版本 `package_info` + 引擎版本 `GET /version`)+ **v1 更新检查**(独立裸 Dio 查 GitHub Releases、semver 比较、三面)+ 诊断复制。 |

> 原语 gallery-first:`AnSwitch` / `AnSegmented` / `AnSettingRow`(modified 竖条 + hover 单项重置)/ `AnScopeBadge`(三域徽)/ `AnTypeToConfirm`(红框危险卡,输精确名解锁)/ `AnSecretField` / `AnMeter` / `AnKvRow` 均先进 gallery 再被面板组装。

## 两条持久化轴 · 域徽

- **机器域**(`AnScopeBadge.machine`「This machine」):主题 / 缩放 / 窗口几何 / 快捷键 / 限额 / 代理——存本地。
  - **中央键表** `core/settings/settings_prefs.dart`:`SettingsPrefs` 服务 + `SettingsKey<T>` 声明(约 21 键,含 `an.right.collapsed.` 族与 `an.shortcuts`),`resetAll` 只清声明集(外键存活),`fy.*→an.*` 一次性迁移。
  - **偏好 provider 族** `app_prefs_providers.dart`:`ThemePreference` / `LocalePreference` / bool·string 偏好(异步 restore 竞态已消除,消费者同步读)。
- **工作区域**(`AnScopeBadge.workspace`):语言 / webFetchMode / 默认模型 / 密钥——存后端。
  - `workspace_prefs_provider.dart`:乐观 PATCH + 回滚;首取未完成时 `await future`(不静默弃写)。

## 平台地基(跨切,settings 触发但归 core)

- **热切换**(拍板 #17 方案 B,`core/workspace/`):切 workspace → `dioProvider`/`sseGateway` 重建(**脉搏在 dio 层**,每切换新 Dio + `onDispose(close)`——放 client 层会在共享 Dio 上叠旧拦截器捏已废 Ref 必炸,回归钉入 `hot_switch_test`)→ 全 Live repo → 全 server-state provider 零逐处接线级联重取;生产者 `workspace_bootstrap` 用 `ref.read` 出反应环;粘性态(landingModel/titleReveals)各自 watch id 自愈;选区全 URL 派生故 `go('/')` 即清。`workspace_switch.dart`:同 id 短路 + 先离旧深链再设 id。
- **Master key 铸钥**(拍板 #14 / [ADR 0008],`core/process/master_key.dart`):keychain 有条目直用 / **全新安装**(盘上无 db)铸 256-bit 随机钥 + 读回验证 / 旧装机绝不铸(硬注新钥 = 密文全孤儿)/ 任何异常退化机器指纹旧径**启动绝不变砖**。macOS 用 login keychain(`usesDataProtectionKeychain:false`——data-protection 需真证书签名,ad-hoc 编译失败);`BackendController.masterKey` 每 spawn 解析 → `ANSELM_MASTER_KEY` env。
- **出厂重置**(拍板 #12,`core/platform/factory_reset.dart`):前端编排 = 停 sidecar → 删数据目录 → `resetAll` → `open -n <bundle>` 重启 + `exit(0)`。
- **更新检查**(拍板 #7,`state/update_check_provider.dart` + `ui/startup_update_check.dart`):独立裸 Dio(**绝不带 loopback 凭据出网**)查 GitHub Releases + semver(怪格式绝不称新);启动自动查(开关控,available 才 toast,失败沉默)。
- **窗口几何**(拍板 #13,`core/platform/window_bounds.dart`):纯 clamp(尺寸收屏 + 退化拒绝)+ moved/resized 去抖捕获 + 开窗前恢复。
- **开机自启**(拍板 #15,`core/platform/launch_at_login.dart`):`launch_at_startup` 缝。

## 全局快捷键(S6,可改绑目录)

- **目录三件** `core/shortcuts/`:
  - `shortcut_catalog.dart`:`ShortcutCommand` 枚举 6 命令(切左 / 右岛 · 开设置 · 缩放 in/out/reset)+ `ShortcutChord`(平台归一:`cmd` = mac ⌘ / 其余 Ctrl,`toActivator()` 映 meta·control)+ 稳定序列化(用 `keyId` 数字、绝不用 label)+ 人读 `display`(⌘⇧B)+ `kShortcutDefaults` **唯一声明处**。
  - `shortcut_bindings.dart`:`ShortcutBindings` Notifier —— 默认表叠加用户覆写(单 JSON 存 `an.shortcuts`,**只存非默认覆写** → resetAll 干净回落)+ `conflictFor`(排除自身)+ rebind/reset/resetAll。
  - `global_shortcuts.dart`:`GlobalShortcuts` ConsumerWidget,watch `shortcutBindingsProvider` **从目录生成 CallbackShortcuts**;handler 全为纯 provider/静态调用故无需壳 context。
- **挂载位置铁律**:`GlobalShortcuts` 由 `app.dart` 挂在 **app 根、autofocus `Focus` 之上**(`AppStartupGate → GlobalShortcuts → autofocus → WorkspaceGate → child`)。CallbackShortcuts 只对「从持焦点子孙冒泡上来的按键」触发,故持焦点节点须在其**之下**;放壳内(autofocus 之下)会饿死冷启动全局键、要先点一下才活——回归测 `global_shortcuts_test` 钉「autofocus 无点击即触发」。壳 `app_shell.dart` 只把同一批动作接到屏上按钮(收起钮)。
- **面板改绑生效链**:面板录入 → `rebind` → 存 `an.shortcuts` → `shortcutBindingsProvider` 变 → `GlobalShortcuts` 重建 CallbackShortcuts,**热生效无重启**。`ShortcutsPanel._ShortcutRow._onKey` 仅录制态拦截(`_recording` 守卫)、录完 `unfocus()` 交还键盘(否则本行吞掉后续每次组合键)。

## 后端契约(工单①–⑩,前端消费面)

- **受管键守卫**:Delete 补 `Managed` 检查 → 422 `API_KEY_IMMUTABLE`;mock provider 目录非 dev 隐藏。
- **版本**:`GET /version`(免鉴权)= 引擎版本;`-ldflags -X main.version` 经 `git describe`。
- **免费档**:`POST /freetier:provision` 诚实布尔(开通行存在 / 降级)。
- **工作区 stats**:`GET /workspaces/{id}/stats`(六表滤软删标量子查询 + flowruns running + generating 交集 + blob 500ms 预算 walk,超时 = -1 诚实未知)。
- **MCP 安装计划**:`POST /mcp-registry:plan`(投影 domain `Plan()` 成 `RegistryPlan`,选包逻辑单源服务端,零副作用)。
- **网络**:`GET/PATCH /network`(`settings.json` `network` 段整体替换 `{httpProxy?,httpsProxy?,noProxy?}`;`applyProxy` boot 与 PATCH 时 `os.Setenv HTTP_PROXY/…`,Go `http.ProxyFromEnvironment` 读之,重启 sidecar 完整生效)。
- **master key env**:`ANSELM_MASTER_KEY` → `Config.Fingerprint`(换种子 = 既有密文作废,故 keychain 只对全新安装启用)。

## 数据缝 + state

- **唯一缝** `SettingsRepository`(`features/settings/data/`):`LiveSettingsRepository`(`ApiClient`)/ `FixtureSettingsRepository`(内存 + 脚本钩:`nextMcpStatus`/`failNextWorkspaceDelete`/`failNextRuntimeDelete`/`fixtureLimits`/`fixtureNetwork`/`envsByOwner`/`gcRemoved`…)/ `settingsRepositoryProvider` 单点 override。面约 40 方法覆盖 keys/workspaces/stats/version/memory/mcp/sandbox/limits/network/reset。
- **能力目录上移 core**(S-15,`core/models/model_capabilities.dart`):chat 选择器与 settings 双消费,features 互不依赖;demo 装配直喂 `demoModelCapabilities`。
- **state**(`features/settings/state/`):`api_keys_provider`(每变更重拉 + invalidate capabilities,test 在 `finally` 重拉)· `workspaces_provider` · `memories_provider`(pin 就地补单行)· `mcp_providers`(300ms coalesce)· `sandbox_providers` · `update_check_provider`(裸 Dio)· `settings_panel_provider` / `settings_detail_provider`。
- **DTO** `core/contract/`:`api_key` · `memory` · `mcp`(5 型)· `limits`(`LimitField` `@JsonKey(name:'default')`)· `network` · `sandbox`(4 型)· `workspace`(+`WorkspaceStats`)。

## 状态

✅ **全落**(S0 地基 → S1 偏好三面 → S1b dark 点亮 → 后端 P0 批 → S2 模型与密钥 [+keychain] → S3-pre 热切换 → S3 工作区 + 关于 → S4a 记忆 → S4b MCP → S5 存储 / 限额 / 网络 / 沙箱 → S6 快捷键收官)。13 面板全建,机器 / 工作区两域分明,平台地基(热切换 / keychain / 出厂重置 / 更新检查 / 可改绑快捷键)成活。`make verify`(后端,含工单①–⑩ 单测 + testend 黑盒)+ `make fe-verify`(前端 3312 测)+ `make docs` 全绿。**每片真机 E2E**(release build + 真 sidecar,逐面板交互 + 逐帧截图核对);真机验收累计修出多处 widget 测漏抓的真 bug(hover 不可达 / dio 层脉搏 disposed-Ref / Memory PUT 缺 source / 快捷键录后吞键 / 快捷键冷启动焦点序)。
