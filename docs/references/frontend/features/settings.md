---
id: DOC-054
type: reference
status: active
owner: @weilin
created: 2026-07-09
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Feature：Settings（设置海洋）——当前形态

> `settingsCatalog` 是 13 个面板的唯一目录源；rail、搜索、页面注册表与门禁都从它对账。平台实现见 [`platform.md`](../platform.md)，通知行为见 [`notifications.md`](notifications.md)。

## 1. 信息架构

| 分区 | 面板 | 主要职责 |
|---|---|---|
| Preferences | General | 主题、语言、缩放、字体、窗口恢复、开机启动、更新检查 |
| Preferences | Notifications | 通知级别、OS/应用内出口、失败/审批/attention 类别 |
| Preferences | Chat | 发送键、右岛自动登台、web fetch 与默认对话模型跳转 |
| Resources | Models & Keys | 受管免费档、provider key、模型能力/默认场景、BYOK 支出 |
| Resources | MCP | 已安装服务器、市场、安装计划、环境变量、状态/工具/日志 |
| Resources | Memory | 搜索、固定、新建、编辑、删除 |
| Resources | Sandbox | 健康、磁盘、runtime、owner 环境与 GC |
| Resources | Workspaces | 创建、热切换、重命名、颜色、统计与删除 |
| System | Storage | 数据目录、日志、诊断、保留期、数据库压缩与出厂重置 |
| System | Limits | 服务端 schema 驱动的限额编辑与单项重置 |
| System | Network | HTTP/HTTPS/no-proxy 配置与重启提示 |
| System | Shortcuts | 六个全局命令的改绑、冲突检测与重置 |
| System | About | app/engine 版本、更新检查、诊断与字体许可 |

左岛支持面板级和静态设置项级搜索。`settingsSearchIndex` 与页面内 `SettingsAnchor` 双向门禁，确保搜索结果一定有可滚到的真实控件。

## 2. 两条持久化轴

- 机器级偏好由 `SettingsPrefs` 写入 `SharedPreferences`：主题、缩放、字体、窗口、快捷键、通知展示偏好等。
- 服务端配置与资源由 `SettingsRepository` 写后端：workspace 偏好、provider key、网络/限额及各资源面；具体作用域由对应后端端点裁决，不按本地存储方式猜测。
- 壳折叠、海洋记忆、Chat rail 偏好等不属于某个面板，但必须登记在 `settingsImplicitKeys`。
- `resetAll` 只清声明过的 Anselm 偏好键，不扫第三方或未知键。

文档不把“机器级/工作区级”靠 UI 徽章猜测；实际归属以 `settings_catalog.dart`、`settings_prefs.dart` 和 repository 写面为准。

## 3. 数据与安全

- `SettingsRepository` 是唯一数据缝，Live/Fixture 同形；动态资源面不直接调用 `ApiClient`。
- provider credential 按目录声明的类型收集；Vertex 使用服务账号 JSON，不伪装成 API key 文本框。
- key 保存后走真实测试；鉴权失败、未验证 provider 与可疑自填 base URL 分开解释。
- MCP 名册的 loading、error、empty 是三个不同的产品状态：请求未落定时显示内容骨架，读取失败显示可重试错误，只有后端确实返回空数组时才显示无服务器市场入口；不能用空列表兜底掩盖断线。名册同时监听 entities 上的实时状态和 notifications 上的 `mcp.*` 生命周期事件，两者都只触发对 REST 真相的重取。已打开的 server 详情也以落定名册对账：对象从名册消失时下一帧自动回到名册并给出“已删除/列表已刷新”反馈，loading/error 不触发误驱逐。
- MCP `mcp.json` 导入面使用完整的设置阅读列，JSON 粘贴区固定为 `AnSize.jsonViewport` 并在自身内部滚动；合法的长配置不能把表单变成窄高长条，也不能把 Import/Cancel 推出视口。导入需要物化运行时或建立连接时，提交按钮显示 spinner 与“导入中”并锁住重复提交；完成后以服务端返回的 imported/skipped 计数反馈，解析错误或 `MCP_IMPORT_INVALID` 留在当前表单且不改名册，提示必须以完整可见的短句告诉用户补上非空的 `mcpServers` 对象；`MCP_IMPORT_TOO_LARGE` 同样显示完整的尺寸修复提示。
- MCP 详情的 Call history 读取 `data.calls` 与同一 `data` 下的 `aggregates` sidecar；聚合与当前过滤集的真实 ok/failed 数一致，列表行只显示工具、触发来源和耗时，完整 logs 通过单条调用详情读取，不能把缺失的聚合默认为成功或空记录。历史行在固定高的详情 pane 内通过滚动视口承载，不能因调用数量增长产生 Flutter overflow。ServerStatus 的 `lastError` 保留为历史诊断，但只有当前 `failed`/`degraded` 才投影为红色错误条；恢复到 `ready` 后撤掉旧错误，避免「已恢复」与「仍报错」同屏。
- Cloned voices 是受管档的持久库存：列表与剩余槽位必须来自同一次 `GET /voices` 权威重读；读取失败显示错误态与重试，不得伪装成「暂无音色」。
- master key 由系统 secure storage 管理；旧安装不能在缺 key 时静默铸新钥覆盖既有密文，详见 [`ADR 0008`](../../../decisions/0008-master-key-keychain.md)。
- 危险删除与出厂重置使用精确 type-to-confirm；数据库 `VACUUM` 不删业务行，不伪装成危险删除。
- 更新检查使用独立外网 client，不携带 loopback bearer 或 workspace header。

## 4. 热切换与全局能力

- workspace 切换先导航离开旧深链并清壳内绑定，再在下一帧切 active workspace；HTTP、SSE 与所有 Live repository 随轴重建。
- 全局快捷键目录是默认键位唯一源；用户覆盖只存非默认差异，修改后热生效。
- 快捷键宿主位于 app 根 autofocus 之上，冷启动无需先点击页面。
- 网络代理写入后明确提示需要重启 sidecar 才能完整生效。
- 工厂重置由前端编排停止 sidecar、删除数据目录、清本地声明偏好并重启 app。

## 5. 关键不变量

1. 13 面板、rail、注册表和归属键集合必须恒等。
2. 静态搜索索引与页面锚集合必须恒等。
3. 动态 provider/MCP/memory/workspace 内容不伪装成静态搜索项。
4. provider secret 不进入文档、日志、诊断复制或普通 state。
5. workspace 热切换不得让旧资源 id 在新 workspace 下重取。
6. demo 的 13 面板必须使用与真 demo 入口相同的 fixture override 清单。

## 6. 验证入口

- feature：`frontend/test/features/settings/`
- 热切换：`frontend/test/core/workspace/`
- 快捷键与偏好：`frontend/test/core/shortcuts/`、`frontend/test/core/settings/`
- 全面板 fixture 电池：`settings_demo_fixture_test.dart`
- 人眼验收：`make -C frontend demo` 与 `make -C frontend app`
