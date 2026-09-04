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

Models & Keys 的受管免费档配额行将已用量、上限和重置时间格式化为当前 locale 的人类可读
紧凑值；不得把原始大整数或 ISO-8601 字符串直接暴露给用户。接口仍保存原始 quota 数值和
时间戳，格式化只发生在显示边界。场景默认的 utility、agent、image、speech、video 在能力
目录确认返回空数组时仍保留清除入口，保证失效默认可自救；dialogue 不提供清除入口，因为
清除会让 Chat 无法启动。模型能力目录本身必须区分 loading、读取失败和成功但为空：只有成功
返回 `data: []` 才能进入「没有可用模型」引导；已有目录时刷新失败继续展示 last-good 目录，
没有旧目录时显示可读错误与单一 Retry，不得把网络/后端故障伪装成没有 key。

当用户为 Agent 场景选择已探测但不支持工具调用的模型时，设置写入必须被服务端拒绝，前端保留
原选择并在顶带显示本地化、可行动的说明；不得把后端的英文 wire message 直接展示给用户。

受管 `Anselm Auto` 选择器的二级文案是短标签：英文为 `Gateway-managed`，中文为「网关托管」。
它必须在默认单行轨道内完整可读，不以省略号隐藏产品模式的身份；路由与推理的详细说明属于帮助/文档
层，不塞进窄的选择行。

左岛支持面板级和静态设置项级搜索。`settingsSearchIndex` 与页面内 `SettingsAnchor` 双向门禁，确保搜索结果一定有可滚到的真实控件。

## 2. 两条持久化轴

- 机器级偏好由 `SettingsPrefs` 写入 `SharedPreferences`：主题、缩放、字体、窗口、快捷键、通知展示偏好等。
- 服务端配置与资源由 `SettingsRepository` 写后端：workspace 偏好、provider key、网络/限额及各资源面；具体作用域由对应后端端点裁决，不按本地存储方式猜测。
- 壳折叠、海洋记忆、Chat rail 偏好等不属于某个面板，但必须登记在 `settingsImplicitKeys`。
- `resetAll` 只清声明过的 Anselm 偏好键，不扫第三方或未知键。

文档不把“机器级/工作区级”靠 UI 徽章猜测；实际归属以 `settings_catalog.dart`、`settings_prefs.dart` 和 repository 写面为准。

## 3. 数据与安全

- `SettingsRepository` 是唯一数据缝，Live/Fixture 同形；动态资源面不直接调用 `ApiClient`。
- Sandbox 的 bootstrap 健康面同时保留 loading、transport error 和 degraded data 三态：加载中用延迟骨架，读取失败显示本地化错误与 Retry，`ok:false` 显示可行动的人话与 Retry；绝不把后端的文件路径或包装错误拼进用户文案，Retry 期间锁住重复提交并在后续 GET 落定后收敛。machine runtime roster 同时保留 loading、error 和 settled-empty 三态：加载中用骨架，读取失败显示明确错误与 Retry，只有服务端确认 `data: []` 才显示「暂无运行时」。安装按钮在真实下载期间显示 `Installing…` 并锁住重复提交；切换 runtime kind 会用该 kind 的后端 default 重建版本输入，不能遗留上一个 kind 的版本。`disk-usage` 是全机 manifest 的 `sizeBytes` 投影，`0 B` 是合法空值；Sandbox 与 Storage 共用同一数值，加载显示骨架，读取失败显示明确错误和 Retry，绝不以空白或 `0 B` 代替错误。因为设置海洋由懒 `IndexedStack` 常驻，进入 Settings 以及切换到 Sandbox/Storage 都必须失效重取。最终 runtime kind/version/size 与 disk usage 必须和 REST、机器级 SQLite 真相一致，安装或删除成功、GC 成功后都必须同时重取 runtime roster、所有 owner env tab 和机器级磁盘总量；缺 workspace 不能降级为空列表。GC 的任意删除动作都要先说明本机环境文件会永久移除，确认后显示进行中并锁住重复提交；天数输入只接受 0 或更大的整数，空值/负数不得静默变成默认值；失败显示安全、可重试文案。
- Sandbox owner env roster 同样必须区分 loading、error 和 settled-empty：每个 `ownerKind` tab 在查询未落定时显示骨架，查询失败显示可重试错误，只有 `GET /sandbox/envs?ownerKind=...` 确认返回空数组时才显示「暂无环境」；不能用 `.value ?? []` 把断线或后端错误伪装成空 tab。列表按后端 `lastUsedAt DESC` 投影可读 owner 名、依赖数、大小、状态和运行 PID；Function/Handler 的历史 env 行也必须由后端读时 hydrate 当前实体名，不能让用户面对复合 owner id；wire `deps` 始终是数组，空值为 `[]`；failed 行还要显示后端 `errorMsg`，installing 行要显示构建中提示，不能只给一个用户无法解释的颜色点。删除确认必须说明本机文件会被永久移除、所属实体仍保留且下次执行会自动重建；运行中的 env 必须先停所属实体，不能静默删掉活进程的目录；删除成功后同时刷新当前 owner tab 和机器级 disk usage。
- Storage & logs 的数据目录必须来自 `GET /api/v1/system/data-dir` 的运行中 sidecar 解析结果，不得由前端拼接或猜测。`Reveal in Finder` 与 `Reveal logs folder` 都是用户可观察的 Finder 定位动作：macOS 通过 AppKit `selectFile` 选中目标；若系统请求失败则显示可重试的人话提示。日志按钮不声称打开一个不可证明的 Finder 子窗口，数据目录与日志目录的路径必须与 backend journal 和 REST 真相一致。
- Sandbox 安装失败按 wire code 呈现可行动错误：`SANDBOX_RUNTIME_VERSION_UNSUPPORTED` 使用后端 `details.kind/version/hint` 告诉用户改用什么发行版，`SANDBOX_RUNTIME_INSTALL_FAILED` 点名失败的 runtime/version 并提示检查版本和网络；错误留在安装表单内，不把用户弹回一个看似空成功的名册。同步安装飞行期间锁住 `Cancel`，因为当前契约没有取消下载动作，不能让用户以为后端已停止。删除 runtime 的确认框必须明确说明本机文件会被永久移除、仍被环境引用时会拒绝，并告知之后可重新安装；取消不改变名册，确认后才以 REST 真相收敛到 settled-empty。
- provider credential 按目录声明的类型收集；Vertex 使用服务账号 JSON，不伪装成 API key 文本框。
- key 保存后走真实测试；鉴权失败、未验证 provider 与可疑自填 base URL 分开解释。
- BYOK key 行在窄 rail 中以状态胶囊加 probe/edit/delete 纯字形动作呈现；每个动作保留本地化 tooltip 与读屏语义标签，不能用带文案按钮把行撑出溢出条，也不能为收窄而裁掉操作。
- 删除仍被场景默认、搜索默认或 Agent 覆盖引用的 key 时，后端拒绝删除；前端用单按钮中性说明框列出人话引用位置，不暴露 `scenario_default` 等 wire kind，也不渲染重复的危险/取消动作。普通 BYOK key 的确认框必须点名当前对象并说明不可恢复，取消不产生 mutation，确认后以服务端重读收敛且只移除目标行；受管 key 即使没有引用也保持不可删除。
- MCP 名册的 loading、error、empty 是三个不同的产品状态：请求未落定时显示内容骨架，读取失败显示可重试错误，只有后端确实返回空数组时才显示无服务器市场入口；不能用空列表兜底掩盖断线。名册同时监听 entities 上的实时状态和 notifications 上的 `mcp.*` 生命周期事件，两者都只触发对 REST 真相的重取。已打开的 server 详情也以落定名册对账：对象从名册消失时下一帧自动回到名册并给出“已删除/列表已刷新”反馈，loading/error 不触发误驱逐。
- Memory 名册同样使用 `AnLastGood` 保留最近一次有效数据，但必须把 loading skeleton、读取错误与已确认的空数组分开呈现：只有 `GET /memories` 成功返回 `data: []` 才显示空态引导；错误态显示本地化原因和 Retry，不能用 `.value ?? []` 把断线伪装成“暂无记忆”。`activeWorkspaceProvider` 作为 reset key，切换 workspace 时先清除旧名册的可见快照，避免旧 workspace 的 memory 行短暂泄漏到新 workspace。每一行的 pin/unpin 是独立的可聚焦 toggle：动作进行时只锁住该行的 pin 入口、显示带读屏标签的 busy 指示并禁止该行导航；失败捕获为 pin 专用通知，权威旧状态保留，用户可再次尝试，不能冒成 Flutter 未处理异常或发出重复 mutation。
- Memory 名册还必须订阅 notifications 流上的 durable `memory.created/updated/deleted`，用 REST 重读名册作为真相；同一条流的 410 resync 也必须重读。对已经落定的名册要就地替换 `AsyncData`，不先让整个 provider 重新构建出加载间隙；连续信号按代数丢弃旧响应。这样 Agent 或另一客户端改动记忆时，已打开的设置页不会静默保留旧描述；pin 回声的歧义由整表重读安全吸收。已打开的 Memory 详情也必须以落定名册确认存在：对象从名册消失时下一帧回到名册并给出“已删除/名册已刷新”反馈，loading/error 不得误驱逐或把旧表单当成事实。
- MCP `mcp.json` 导入面使用完整的设置阅读列，JSON 粘贴区固定为 `AnSize.jsonViewport` 并在自身内部滚动；合法的长配置不能把表单变成窄高长条，也不能把 Import/Cancel 推出视口。导入需要物化运行时或建立连接时，提交按钮显示 spinner 与“导入中”并锁住重复提交；完成后以服务端返回的 imported/skipped 计数反馈，解析错误或 `MCP_IMPORT_INVALID` 留在当前表单且不改名册，提示必须以完整可见的短句告诉用户补上非空的 `mcpServers` 对象；`MCP_IMPORT_TOO_LARGE` 同样显示完整的尺寸修复提示。
- MCP 详情的 Call history 读取 `data.calls` 与同一 `data` 下的 `aggregates` sidecar；聚合与当前过滤集的真实 ok/failed 数一致，列表行只显示工具、触发来源和耗时，完整 logs 通过单条调用详情读取，不能把缺失的聚合默认为成功或空记录。历史行在固定高的详情 pane 内通过滚动视口承载，不能因调用数量增长产生 Flutter overflow。ServerStatus 的 `lastError` 保留为历史诊断，但只有当前 `failed`/`degraded` 才投影为红色错误条；恢复到 `ready` 后撤掉旧错误，避免「已恢复」与「仍报错」同屏。
- MCP server roster 的数量短语必须遵守英文单复数：`1 call`，`N calls`；中文保持自然的“次调用”。数量为 0 时不渲染该统计段，避免产生无意义或语法错误的状态摘要。状态、工具数、调用数是独立可定位的文本段，视觉上仍以中点分隔；这样卡片既保持紧凑，也让读屏/自动化验证能准确定位每一项。
- Cloned voices 是受管档的持久库存：列表与剩余槽位必须来自同一次 `GET /voices` 权威重读；读取失败显示错误态与重试，不得伪装成「暂无音色」。即使库存为空，也要展示 `remaining/capacity` 算术，不能让 settled-empty 遮住库存上限。Settings 海洋跨 workspace 常驻，故 `activeWorkspaceProvider` 是库存 provider 的代际边界：切换后旧 workspace 的音色行必须立即消失，新的 `GET /voices` 未落定期间显示 loading，不能把旧列表穿透到新 workspace；同一边界也必须清掉旧 workspace 的确认意图，但不能把真实在途删除伪装成已结束：操作保持单飞直到原请求结算，旧异步完成不得回写新 workspace 或在切回时复活破坏性确认。删除与其后的权威 `GET /voices` 都固定使用发起删除时的 workspace header，避免热切换竞态串域。Chat 中的登记会改变这份持久库存；由于 Settings 海洋可能仍挂在壳的常驻 `IndexedStack` 中，进入 Models & keys 或离开后重新进入 Settings 必须失效 `voicesProvider` 并重读权威库存，不能把登记前的 `AsyncData` 继续显示。删除是上游持久登记的破坏性动作：行级危险区必须先要求精确输入音色名，明确费用不会退回、只恢复一个库存位；取消不发请求，确认后服务端先删上游再删本地行，失败时保留行并给出可重试反馈。若 DELETE 已成功但紧随其后的库存重读失败，旧行不得继续显示或再次提供删除入口，界面必须明确“删除已提交、库存待刷新”并只提供 Retry；Retry 成功后才恢复服务端确认的行与库存算术。
- Advanced limits 是机器级单一配置：页面由 `GET /limits/schema` 的字段元数据驱动、由 `GET /limits` 水化具体值；每一行都展示 schema 提供的边界语义（含开区间、无上界）与默认值，输入框会先在本地拒绝非数字/越界值，再使用 dotted key 对应的部分嵌套 PATCH。输入框按回车只提交一次并以权威 GET 收敛，点按移出也提交一次；Reset all 必须先确认并明确告知“全部当前修改会被服务端默认值覆盖”，成功后重新读取全部服务端默认值，不能由前端猜默认或留下重复写入；请求失败时先重读服务端真相并给出可重试的人话反馈。**整面 schema/limits 载入失败也必须始终使用本地化产品文案，稳定 wire code 只进入 tooltip，后端 message/网关诊断文本不得上脸。**后端仍是最终校验者，服务端拒绝时行回滚并展示人话错误。
- master key 由系统 secure storage 管理；旧安装不能在缺 key 时静默铸新钥覆盖既有密文，详见 [`ADR 0008`](../../../decisions/0008-master-key-keychain.md)。钥匙串读写每步有界，若原生授权弹窗或 daemon 无响应，启动在超时后沿用 legacy fingerprint 路径，不能永久卡在启动页。
  既有安装探测必须先检查显式配置的 `ANSELM_DATA_DIR`，只有未配置时才回退到 `$HOME/.anselm`；否则 App
  可能在实际数据根已有数据库时误铸新钥，令密文与运行中的 sidecar 脱节。
- 危险删除与出厂重置使用精确 type-to-confirm；确认输入框填满危险区可用宽度，长对象名不能被输入控件最小宽截断；数据库 `VACUUM` 不删业务行，不伪装成危险删除。
- 更新检查使用独立外网 client，不携带 loopback bearer 或 workspace header。

## 4. 热切换与全局能力

- workspace 切换先导航离开旧深链并清壳内绑定，再在下一帧经唯一的 `setActiveWorkspace` 入口切 active workspace；该入口同时 settle HTTP 运行时并非阻塞地 POST `/workspaces/{id}:activate` 刷服务端 `lastUsedAt`。HTTP、SSE 与所有 Live repository 随轴重建；记账失败必须进入 Flutter console，不能变成未处理 future 或静默丢失。
- 全局快捷键目录是默认键位唯一源；用户覆盖只存非默认差异，修改后热生效。
- 快捷键宿主位于 app 根 autofocus 之上，冷启动无需先点击页面。
- 网络代理写入后明确提示需要重启 sidecar 才能完整生效。
- 工厂重置由前端编排停止 sidecar、删除数据目录、清本地声明偏好并重启 app。删除失败必须回到可再次
  操作的危险区，并明确提示仍有外部后端占用数据根；不能把失败留成永久 busy，也不能显示成功后的 onboarding。
  macOS 直接启动当前
  bundle executable 而不是走 LaunchServices 的 `open -n`，以保留开发台架的 `ANSELM_BACKEND_URL`
  等 attach 环境；验收台架可显式设置 `ANSELM_RELAUNCH_LOG` 接住 replacement App 的 console，正式打包不改变用户可见的重启语义。

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
