---
id: DOC-054
type: reference
status: active
owner: @weilin
created: 2026-07-09
reviewed: 2026-07-20
review-due: 2026-10-18
audience: [human, ai]
---

# Feature:Settings(设置模块:齿轮进的 13 面板 + 机器/工作区两域)—— 当前形态

> 齿轮进的设置海洋:双骨架 IA(偏好 / 资源 / 系统三段 · 13 面板)+ 机器域与工作区域两条持久化轴 + 一批平台地基(热切换 / keychain 铸钥 / 出厂重置 / 更新检查 / 可改绑快捷键)。本篇 = **它现在是什么样**;**怎么一步步建的**(调研 / 16 硬裁决 / 后端工单①–⑩ / S0–S6 阶梯 / 逐片真机 E2E)看建造账 [`WRK-062`](../../../archive/settings/README.md);**DTO** 看 [`contract.md`](../contract.md);keychain 选型看 [`ADR 0008`](../../../decisions/0008-master-key-keychain.md)。

## 一句话

单进程单用户桌面 app 的「控制台」:密钥 / 模型 / MCP / 记忆 / 沙箱 / 存储 / 限额 / 网络 / 快捷键全在一处调,**机器级偏好**(主题 / 缩放 / 窗口 / 快捷键,存本地 `SharedPreferences`)与**工作区级配置**(语言 / 限额 / 代理 / 密钥,存后端 `settings.json` + DB)两条轴分明,每个危险动作都有 type-to-confirm 双闸,改一处即时生效、无需重启(代理例外,需重启 sidecar)。

## 壳与信息架构(S0 地基)

- **入口**:左岛底栏齿轮格 → `selectedOceanProvider = settings`(顶部海洋切换器无选中、齿轮高亮);也可 **⌘,** 直达(全局快捷键)。
- **左岛 = 目录 / 项级搜索** `settings_rail.dart`:搜索框(升到**设置项粒度**,macOS / VS Code 同款)+ **三段** `Preferences / Resources / System`(System 段可折叠),共 **13 面板**。空搜索 = 目录;有搜索 = 按面板分组的**设置项结果**。搜索框已抽出 `AnSidebarList`(新增 `showFilter:false`),同一个框驱动「目录 / 结果」两态。详见「设置项级搜索」节。
- **中心 = 海洋** `settings_ocean.dart`:每面板一页 `AnPage`(H1 + 注册表体 + 浮层头「设置 / 面板」+ 换面板回顶);`settings_panels.dart` 是**穷尽 switch 注册表**(漏接体 = 编译错)。
- **导航持久化** `settings_panel_provider.dart`:选面板存 `an.settings.panel`,重建同步恢复;过期枚举名回落 general(byName 门)。
- **推入第三级** `settings_detail_provider.dart`:资源详情(密钥编辑 / 工作区编辑 / 记忆编辑 / MCP 详情)推入海洋,面包屑第三段 + Esc 返回 + 换面板弹出。
- **三相等门禁**(`settings_catalog_gate_test`):面板 ↔ 目录、声明键 ↔ 归属分区(`ownedKeys`)、rail ↔ 目录 三者恒等,漏一个即红。**搜索索引 ↔ 挂载锚门禁**(`settings_search_test`,与三相等门禁同构):每面板 pump 后其挂载的 `SettingsAnchor` item 集恒等于 `settingsSearchIndex` 对该面板的声明——新增可搜索行忘声明、或删行忘清索引,双向皆红。

## 13 面板

| 段 | 面板 | 文件 | 是什么 |
|---|---|---|---|
| 偏好 | **通用** General | `panels/general_panel.dart` | 主题三档(含 dark)+ 缩放六档(镜像 `WindowZoom`)+ **字体三轴**(机器级偏好,`AnDropdown` 三行:①UI 内置/系统 · ②内容 无衬线/衬线/系统 · ③代码 JetBrains Mono/Fira Code/Cascadia Code/系统 mono;内容轴**即时切换**、UI+代码轴 desc 标「**重启后生效**」;机制见 [`design-system.md`](../design-system.md) `an_fonts.dart` 节)+ 语言**单项双写**(UI locale 即时 + `workspace.language` PATCH,失败回滚)+ 记住窗口 + 开机自启 + 自动检查更新。 |
| 偏好 | **通知** Notifications | `panels/notifications_panel.dart` | 三档级别（全部 / 仅需处理 / 静音，「需你处理永远送达」并入级别行 desc）+ OS / 应用内两开关 + 失败与崩溃 / 待审批 / 需要关注三类登记；切静音的一次性确认反馈也送共享顶带舞台。持久化键保持兼容，当前由 `NoticeDispatcher` 执行 level、类别、4 秒去重与前台顶带 / 后台 OS 路由，详见 [`notifications`](notifications.md)。 |
| 偏好 | **对话** Chat | `panels/chat_panel.dart` | 右岛自动登台三档(与 chat 的 `followModeProvider` **同一份状态**)+ 发送键两档 + webFetchMode(workspace PATCH)+「默认对话模型 → 模型与密钥」**标准可点行**(AnRow + hover 箭头,单源链不重复渲);首组徽章头、混域逐节域徽。 |
| 资源 | **模型与密钥** Models&keys | `panels/models_keys_panel.dart` | 旗舰面板,**四区**(0719 重构):①受管免费档卡(未开通 CTA / 配额 meter / 预算横幅)②提供商区——**品牌 logo 密钥行**(受管锁顶 + 探测点尾端常驻 + Test/Edit/Delete hover,**行点击 = 编辑**),添加流程从**厂家 logo 网格**起步(ollama/custom baseUrl 硬必填才解锁保存),保存即 `:test`(飞行中转圈)③场景默认三行——收起一句话摘要,点开进**可复用三段面板 `ModelPickerPanel`**(凭证→模型[上下文窗+视觉/文档徽]→原生 knobs 通用渲染[enum 下拉/bool 开关/int 数字,default 预填],应用 `{apiKeyId,modelId,options}`;零可用引导跳密钥区)④搜索区(search 类 key 一层默认选择)。`KeyForm` 仍是 **S-3 状态机**(首次 POST 绑 id、此后一律 PATCH;secret 提交即清)。未配默认对话模型 = 人话句 + `MODEL_NOT_CONFIGURED` 收 tooltip。 |
| 资源 | **MCP 服务器** MCP | `panels/mcp_panel.dart` + `mcp_forms.dart` | **空态承接市场**(0720:一台 MCP 都没有时,面板主体**直接就是市场**——一句安静引导 `marketEmptyLead` + 全列可搜市场顶到面板头下,「已安装」区含组头整个不渲[零计数律]、`浏览市场` 钮退役;装了第一个后已装区自然长出、市场退居 `浏览市场` 之后)+ **已装 = 双列品牌卡**(0719:brand icon + 名 + 状态点 + 统计句[零计数不显] + 失败卡诚实错误句 + ⋯ 菜单[重连/删除],点卡进详情)+ 详情(状态卡 + lastError 红字 + 工具 / 调用历史 / stderr 三 tab)+ 手动添加 + 导入 + **市场默认全列**(整个 curated 注册表双列卡 `_MarketCard`:brand icon + 描述 + 前置徽,搜索即过滤、绝不「空输入=空列表」;**卡 hover / 键盘 focus 揭示 App Store 式「安装」主 CTA**[常驻布局不重排 + 即时 opacity + 隐时惰化,keyboard-reachable]→ 点即**就地空 env 安装**[转圈 `AnSpinner` → 名册重取落行渲「已安装」 / 抛错卡上红句诚实];**整卡点击仍进 `:plan` 驱动安装表单**[isSecret 掩码 / required 星标 / OAuth]收集 env——需密钥的条目一键装落后端 failed 诚实态,再进表单填)。统计条零计数律:`N 台 · 就绪 n · 失败 n` 各段 n>0 才显。**帧不可信**:`kindStream(entities,'mcp')` 任何帧 → 300ms coalesce 一次重取 + 410 强制重取。 |
| 资源 | **记忆** Memory | `panels/memory_panel.dart` | 名册(全部 / 已固定投影 + 搜索 + 行内金 pin toggle + source·mtime)+ **手动添加入口**(面板头 `新建记忆` 钮,顶右常驻)+ 推入编辑(名字 slug 建时活校验、编辑锁名 + 描述 + 内容多行 + **建时可选 `已固定` 开关**[`AnField` + `AnSwitch`,仅创建时渲:一步把新记忆置顶;既有行的 pin 由名册行内 toggle 掌管,编辑时不显——后端更新忽略 body pinned] + Cmd+S)+ 确认物理删除。**空态穿目标形态**(0720:零记忆时不渲 `还没有记忆` 墓碑,而是一句安静引导 `emptyLead` + 顶右 `新建记忆` 即添加入口顺承;过滤/搜索退役[零计数律],照 MCP 空态先例);名册非空但过滤/搜索无命中→`noMatches` 诚实句、不留空白。PUT **恒送 `source:'user'` + `pinned`**(F147:创建时二者生效[用户手动添加=`source:'user'`]、**更新时后端忽略二者**——编辑 AI 记忆保 `source:'ai'` 与既有 pin 不变,故 AI 记忆可编辑内容而作者归属不翻转)。 |
| 资源 | **沙箱** Sandbox | `panels/sandbox_panel.dart` | 引导健康门(ok=false 红卡 + 重试)+ 磁盘占用(**诚实数字非进度轨**——绝对字节数无分母,未解析不渲)+ 运行时(装 / 删 [409 `SANDBOX_ENV_IN_USE` 诚实],AnTabs 五 owner 环境 tab)+ GC(N 天 + 立即全回收两步)。 |
| 系统 | **工作区** Workspaces | `panels/workspaces_panel.dart` | 名册(色点 + 当前高亮,**点行 = 热切换**)+ 新建(六预设色盘)+ 推入编辑(改名同步底栏 / 改色 / **页尾危险区** `AnTypeToConfirm` 输名解锁,stats 真数字入散文;**当前 ws 与最后一个绝不给删**)。 |
| 系统 | **存储与日志** Storage | `panels/storage_panel.dart` | 无头首节(面板大题不复述)全走设置行文法:数据目录行(路径入 desc,**访达 / 日志钮钉行尾**)+ 磁盘占用行(诚实数字非进度轨)+ 诊断行(复制钮钉行尾)+ **Run 历史保留**(机器级四档下拉)+ **数据库**(T4/WRK-070 机器级节:`storageStatProvider` 诚实显示「库 X MB,其中 Y MB 可回收」+「压缩数据库」按钮=`POST /storage:compact` 同步 VACUUM,忙态「压缩中…」+转圈锁库几秒、完成顶带反馈「已回收 Y」+ 失效重取;**非危险动作**[VACUUM 不删行]故无输名双闸)+ 重置本地偏好(`SettingsPrefs.resetAll` 声明集)+ **出厂重置**(前端编排,`AnTypeToConfirm` 输「Anselm」双闸)。 |
| 系统 | **高级限额** Limits | `panels/limits_panel.dart` | **schema 驱动**(`GET /limits/schema` → group AnSection + 每字段 AnSettingRow:点路径 `_valueAt` / 提交构部分嵌套 PATCH / modified 竖条 + 单项重置);越界回滚到服务端真相;零复刻 Go 常量。整面载入失败 = AnState 人话句(ApiException.message),wire 码 / 原始错收 tooltip,重试 sm outline 钮。 |
| 系统 | **网络** Network | `panels/network_panel.dart` | 三 proxy 字段(http/https/no_proxy)水化 + 整体替换 PATCH(**有真实改动才可保存**——dirty 比对已载配置)+ 重启注记归 `AnCallout`(warn,不裸奔)+ 全机域徽。 |
| 系统 | **快捷键** Shortcuts | `panels/shortcuts_panel.dart` | 6 全局命令逐行(**静息 = 逐键小帽** `[⌘][B]`,20 高 mono 12、行回 32 节律;点帽录下一组合键 [须带修饰键 / 冲突则拒并说明 / Esc 取消] + modified 竖条 + 单项重置 + 全部重置);**宽板形态归录制/冲突态专属**(录制蓝框 accent / 冲突 danger)。见下「全局快捷键」。 |
| 系统 | **关于** About | `panels/about_panel.dart` | 版本区(app 版本行 + **检查更新钮钉行尾** + 引擎版本行)+ **v1 更新检查**(独立裸 Dio 查 GitHub Releases、semver 比较、三面)+ 诊断行(复制钮钉行尾)+ **字体致谢行**(`fontsCredit`——履行 MiSans「软件中注明」许可义务:列随包 Inter/MiSans/JetBrains Mono/思源宋 SC/Fira Code/Cascadia Code/Newsreader,MiSans © 小米依自有许可、余皆 OFL;协议全文随 `assets/fonts/*-OFL.txt`+`MiSans-License.txt`)。 |

> 原语 gallery-first:`AnSwitch` / `AnSegmented` / `AnSettingRow`(modified 竖条 + hover 单项重置)/ `AnScopeBadge`(三域徽)/ `AnTypeToConfirm`(红框危险卡,输精确名解锁)/ `AnSecretField` / `AnMeter` / `AnKvRow` / `AnKeycap`(逐键帽紧凑档)/ `AnBrandIcon.brand` + 品牌注册表(`brand_registry.dart`)均先进 gallery 再被面板组装。
>
> **设置表单行文法(0719 总纲)**:①行 = `AnSettingRow`(标签 + desc + 行尾控件)——动作钮**归位进所属行尾**、漂浮孤行退役;②工具类动作钮统一 **sm + outline**(示能律:静息也像按钮;primary 留给表单 CTA,danger 标独立危险动作亦加 outline);③组头有信息才立——与面板大题同名的组头删(徽章头/无头节),同域徽只在首组标一次、**混域页逐节标**(S-16);④纵向表单字段 = `AnFormField`(标签 13 灰,两级配比:值 13 墨在控件内);⑤空态零人话(一行安静句,入口按钮即引导)、零计数不显、载入失败 = AnState 人话句 + 技术细节收 tooltip。

## 设置项级搜索(用户 0719,macOS / VS Code 同款)

rail 搜索框从**面板粒度**升到**设置项粒度**——输入「代理」→ rail 列表变为匹配项结果(`网络` 组下「HTTP 代理」「HTTPS 代理」「绕过代理」行);点结果 = 跳该面板 + 滚动到该项 + 洗亮(`AnWashHighlight`,scheduler 深跳同款配方)。

- **声明式索引** `model/settings_search.dart`:`settingsSearchIndex` = 每个可搜索**设置项**的 `{panel, anchor, labelOf, hintOf}` 声明。索引按**当前 locale** 的 label + hint 建(中文界面搜中文、英文搜英文)。**`ownedKeys` 不是可用种子**——13 面板仅 4 个声明机器键、网络例子一个都没有,故搜索走本索引、不搭机器键表。内容是动态数据的面板(模型与密钥 / MCP / 记忆 / 工作区 / schema 驱动的限额 / 带健康门的沙箱)不声明项——它们经目录**仍按面板名可搜**(向下兼容);此索引只收静态配置行(通用[含字体三轴] / 通知 / 对话 / 网络 / 存储 / 快捷键 / 关于[含字体致谢]共约 35 项)。
- **分组规则** `buildSettingsSearchGroups`(纯函数):按面板目录序;面板名命中**或**任一项命中即收入;面板名命中时其**全部**项都出(搜类别见全部——「搜网络既出面板头行也出其下项」),否则只出 label/hint 命中的项。头行恒为面板本身(跳面板命中 → 旧的面板粒度搜索向下兼容,连不声明项的面板亦然)。空 query → 显目录;无匹配 → 一句安静句 `searchNoMatch`。
- **定位锚 + 跳转** `ui/settings_anchor.dart` + `state/settings_jump_provider.dart`:每个可搜索行在其面板里被 `SettingsAnchor(item:…)` 包住(静息=纯透传、零布局变化)。结果点击 → 先 `select(panel)`、再 `settingsJumpProvider.request(anchor)`;目标面板挂载后其匹配锚 `Scrollable.ensureVisible`(坐浮层头之下)+ 一次性 `AnWashHighlight`(换 key 重跑)后放开目标(重搜同项可再触发)。目标外置(锚不持有)——点击处与锚互不相识,同 chat 的 `transcriptJumpProvider`。
- **搜索框抽出** `ui/settings_rail.dart`:rail 自持 `AnRailFilterField` + query 态,`AnSidebarList` 新增 `showFilter:false` 让同一个框驱动「目录 / 结果」两态(有 query → 结果 `ListView`:面板头行 `AnRow` 跳面板 + 项行 `AnRow`(depth 1 leadless)跳转洗亮)。
- **门禁**:见「壳与信息架构」的**搜索索引 ↔ 挂载锚门禁**(`settings_search_test`,与三相等门禁同构)。

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
- **更新检查**(拍板 #7,`state/update_check_provider.dart` + `ui/startup_update_check.dart`):独立裸 Dio(**绝不带 loopback 凭据出网**)查 GitHub Releases + semver(怪格式绝不称新);启动自动查(开关控,available 才进入顶带消息舞台,失败沉默)。
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
- **能力目录上移 core**(S-15,`core/models/model_capabilities.dart`):chat 选择器与 settings 双消费,features 互不依赖;demo 装配直喂 `demoModelCapabilities`。`ModelCapability` 全镜像后端 `CapabilityView`(0719):`contextWindow`/`maxOutput`/`vision`/`nativeDocs` + `knobs[]`(`ModelKnob` 渲染描述符 `{key,label,type,values,default}`,原生词表不归一);`putDefaultModel` 带可选 `options`(map<string,string>,`ModelRef.options` 往返)。
- **13 面板数据电池**(0719 P0 防线,`settings_demo_fixture_test.dart`):每面板在**真 demo override 清单**(`demoOverrides`,与 `make demo` / capture 同源)下 pump,断言种子数据渲出、无错误/空态脸——capture 手抄 override 子集漂移(六面板假「坏」的 0719 根因)从此过不了门禁;capture_demo 已改吃 `demoOverrides` 单源。
- **state**(`features/settings/state/`):`api_keys_provider`(每变更重拉 + invalidate capabilities,test 在 `finally` 重拉)· `workspaces_provider` · `memories_provider`(pin 就地补单行)· `mcp_providers`(300ms coalesce)· `sandbox_providers` · `update_check_provider`(裸 Dio)· `settings_panel_provider` / `settings_detail_provider` / `settings_jump_provider`(设置项搜索的待跳锚,一次性)。
- **搜索**(`model/settings_search.dart` + `ui/settings_anchor.dart`):声明式项索引 + 分组纯函数 + 行级定位锚(见「设置项级搜索」节)。
- **DTO** `core/contract/`:`api_key` · `memory` · `mcp`(5 型)· `limits`(`LimitField` `@JsonKey(name:'default')`)· `model_capability`(`ModelCapability` + `ModelKnob`,`@JsonKey(name:'default')` 同法)· `network` · `sandbox`(4 型)· `workspace`(+`WorkspaceStats`;`ModelRef.options`)。

## 状态

✅ **全落**(S0 地基 → S1 偏好三面 → S1b dark 点亮 → 后端 P0 批 → S2 模型与密钥 [+keychain] → S3-pre 热切换 → S3 工作区 + 关于 → S4a 记忆 → S4b MCP → S5 存储 / 限额 / 网络 / 沙箱 → S6 快捷键收官 → **0719 生产级战役**[P0 断线根因修复 + 13 面板数据电池 / P1 一致性扫荡(标题重复×4·徽去连环·零计数·空态零人话·游离句归位·跳转行·表单标签 13 档·错误人话·缩放置灰系有意[屏容量 cap]) / P2 按钮示能 sm outline + 归位 + 键帽紧凑档 / P3 模型与密钥四区重构 + MCP 双列卡与市场默认全列 + 品牌资产 52 枚(lobe-icons MIT + simple-icons CC0,首字母兜底)])。13 面板全建,机器 / 工作区两域分明,平台地基(热切换 / keychain / 出厂重置 / 更新检查 / 可改绑快捷键)成活。`make verify`(后端,含工单①–⑩ 单测 + testend 黑盒)+ `make fe-verify`(前端 3312 测)+ `make docs` 全绿。**每片真机 E2E**(release build + 真 sidecar,逐面板交互 + 逐帧截图核对);真机验收累计修出多处 widget 测漏抓的真 bug(hover 不可达 / dio 层脉搏 disposed-Ref / Memory PUT 缺 source / 快捷键录后吞键 / 快捷键冷启动焦点序)。
