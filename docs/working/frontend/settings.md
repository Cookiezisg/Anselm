---
id: WRK-062
type: working
status: active
owner: @weilin
created: 2026-07-08
reviewed: 2026-07-09
review-due: 2026-10-06
audience: [human, ai]
---

# Settings 模块 —— 建造规范(资源·偏好双骨架)

> **出身**:20-agent 五段扇出(6 读码 + 4 联网 + 3 设计概念 + 3 评审 + 4 对抗,170 万 token)。冠军=「资源·偏好双骨架」(3 评审 2 票;总分王「系统设置正统全案」的穷尽目录与端点缺口全部嫁接进来),吸收 52 条对抗挑刺(多条读后端源码实证)的全部修法。本文=唯一施工蓝图。
> **状态**:设计已完成;**§8 决策清单待用户拍板(总路线④)后开建(路线⑤)**。

---

## 0. 一句话

Settings = 「一目录、两骨架」的全页海洋:**偏好域**(外观/通知/对话)用 32px 键值行即时生效的表单骨架;**资源域**(模型与密钥/MCP/记忆/沙箱/工作区)用「列表+推入详情+状态徽章+分布式危险区」的管理骨架——同一 AnPage 720 列、同一浮层头面包屑、同一搜索索引缝成一体。存储三层各归其位:**app 级** SharedPreferences(本机)/ **机器级** `<dataDir>/settings.json`(/limits 族)/ **workspace 级** 后端表(workspaces/api_keys/…)。**零新增后端偏好端点**(本地优先纪律:app 偏好绝不上后端)。

## 1. 信息架构

- **进入**:左岛齿轮 + AnWorkspaceButton「设置」(既有两入口,`selectOcean(settings)`);**Cmd+, 标准快捷键**。退出=点海洋药丸/Esc。
- **布局**:左岛中段被 settings 目录接管(同海洋 rail 位置):顶部 seamless 搜索框 + 静态目录三段(AnSection quiet,不折叠,禁 30 项平铺):**偏好**(通用/通知/对话)· **资源**(模型与密钥/MCP 服务器/记忆/沙箱/工作区)· **系统**(存储与日志/高级限额/快捷键/关于)。中心=唯一 AnPage(720 同滚),面包屑「设置 / 面板 / 详情」;资源详情走**中心推入第三级**(`SettingsPushPane`,Esc/面包屑返回,dirty 二次确认)。**无右岛**。
- **两骨架**:偏好页=AnSection 分节 + `AnSettingRow`(label+desc 次行+右控件槽+modified 左缘竖条+hover 单项重置——统一原语,limits 与偏好共用);资源页=页头统计条+主 CTA+AnRow 列表(状态徽章+hover actions)+推入详情(entities 详情范式)+页尾 `AnDangerZone` 红框。统一物只有四样:同 AnPage/同面包屑/同搜索索引/同 toast·confirm 语汇。
- **作用域可视化**:`AnScopeBadge`(本机/工作区/全机,13px chrome)**下沉到 AnSection 级**(每节一枚,禁页头单枚——「对话」页两节分属两域,页头徽章必撒谎);徽章由 catalog 的 storage 列生成,禁手写。
- **搜索(v1 降级裁决)**:v1=面板粒度目录过滤(`SettingsSearchIndex` 静态注册表照建、登记穷尽、**三相等门禁照上**:可搜项 catalog 项数==索引项数==面板锚点数,隐式项守「SettingsPrefs 声明键集==catalog 登记键集」);二级命中(行级锚定+2s 脉冲)+`@modified` 过滤器整体排 v2——穷尽性资产不丢,UI 复杂度后置。
- **保存模型**:一切即时生效、无 Save/Apply;文本 Enter/失焦提交;后端写失败=行内红字+值回滚+danger toast;仅高危加确认,永久丢数据级用 `AnTypeToConfirm`。
- **导航状态**:`settingsPanelProvider`(panelKey 路由友好命名,持久化 'an.settings.panel');海洋 go_router 化时升格 /settings/:panel/:detail。

## 2. 十六条硬裁决(挑刺修法,违反=实现 bug)

- **S-1 受管 key 不可删(后端 P0 前置)**:`apikey.Delete` 现无 managed 守卫(读码实证 apikey.go:276)——三场景默认换 BYOK 后受管行引用归零即可被物理删除、gwk_ token 行被毁。后端 Delete 前置 `Managed` 检查返 422 `API_KEY_IMMUTABLE`(与 PATCH 对称)+error-codes/domains 文档同步+testend;前端不渲入口双保险。
- **S-2 MCP 配置编辑 v1 不做**:ServerStatus DTO 不含 command/args/env/url/timeoutSec(config_enc 加密永不下发)——「复用表单编辑」无从预填,盲填全量 PUT 会静默清 env。v1 详情页明示「修改配置请删除后重装」;编辑能力=v2 后端工单(GET /config secret 掩码 + PATCH「留空=不动」语义)。
- **S-3 添加 key 状态机**:首次提交=POST;201 后表单**绑定该 id**,任何重试(改 key/baseUrl)一律走 PATCH(旋转自动重探),绝不二次 POST(409 僵尸行);取消时提示 error 行已存在可在列表删。
- **S-4 旋转=危险写**:PATCH 非空 key 立即毁旧密文不可回滚——编辑表单 key 字段旁常驻「替换即生效,原 key 不可恢复」;旋转后 error 保持表单展开+内联 reason,绝不静默收起。
- **S-5 provider 下拉排除 managed+mock** 并加 widget test 守集合;正统解=后端 ListProviders 非 dev 剔除 mock(T6 测试设施不该上产品 wire),同步 api.md。
- **S-6 场景默认「清除」防自伤**:dialogue 场景不渲清除项(或清除即渲红警示「未设置——Auto 对话将不可用」+确认文案言明);「指向已删 key」警示是死代码(RefScanner 挡删)不做——真警示只做 testStatus=error 与 capabilities 查无此对。**conversation.model_override 是 RefScanner 盲区**(删 key 可致会话级 LLM_RESOLVE_ERROR)→ **拍板 #16(0709):覆写神圣不清**——后端不动,chat 侧对死 override 渲「模型已失效,点击重选」CTA(打开模型菜单),LLM_RESOLVE_ERROR 终态横幅接同一引导。
- **S-7 免费档三态+provision**:quota 404 且 workspace `createdAt<60s`=渲「正在开通…」+5s 自动 refetch(OnCreated 钩子已存在,读码实证 build_services.go:419——boot+create 双钩子,缺的只是手动重试端点);否则渲「启用免费档」按钮=POST `/freetier:provision`(**幂等短路**:先查受管行存在即 200 返现有 quota;按钮 in-flight 单飞;旁注「将向 Anselm 网关注册本机匿名指纹以分配额度」——隐私显式化)。
- **S-8 通知档语义**:默认 **important(仅需你处理)**(对齐 N4/N5 already-landed 裁决);「全部」档分母=**落收件箱行的 Emit 事件**(后端 Emit 帧加 `inbox:true` 标记位,一行 payload+events.md 同步)——Broadcast 对账回声永不进 toast 候选,否则 N0 后 18 个高频回声=toast 风暴。通知声音项 v1 砍(记留位,若做=「系统通知声音」从属行+平台注记)。
- **S-9 主题(拍板 #1 改判 0709):v1 就带 dark**——AnTheme.dark 全量定义但从未渲过一帧,故 dark 点亮=独立切片 **S1b**(gallery 全 specimen dark 截图→真壳四海洋走查;webview 对齐已随编辑器原生化消失);settings 建三档控件(跟随系统/浅/深),S1b 落地前 dark 档渲 disabled「即将推出」、落地即启用。
- **S-10 workspace 切换(拍板 #17 改判 0709):先建热切换基建**——全库零 provider watch activeWorkspace、SSE 无强制重连缝(读码实证),故新增前置切片 **S3-pre**(workspace 敏感 provider 审计→watch activeWorkspace + SSE 三流强制重连缝 + keepAlive 缓存失效清单),S3 的切换建在其上;Phoenix 方案作废。**禁删当前活跃 workspace** 守卫保留(按钮 disabled+tooltip);删除编排收进独立 Notifier(不依赖 widget 生命周期)。
- **S-11 删 workspace 确认带真数字+动态警示**:`GET /workspaces/{id}/stats`(§6)返静态计数+**runningFlowruns/generatingConversations**——>0 时确认框首行红字「有 N 个执行进行中,删除将终止它们」;AnTypeToConfirm 正文粗体引用真实数字(「将永久删除 N 对话、M 实体、X MB 附件」);DELETE 失败=留在新 workspace+danger toast+refetch,绝不自动切回。
- **S-12 「重启后端」按 managed 分叉**:BackendController 暴露 `managed:bool`——dev-attach(ANSELM_BACKEND_URL)下按钮**隐藏**、渲「外接后端(开发模式)· url」;「安全状态」行由事实派生(sidecar 铸过 token=绿「loopback+Bearer」;attach=灰「加固状态未验证」),禁硬编码绿点。重启前审计:dio/SSE 必须每请求从 BackendState 取 token,禁构造期快照(配 widget test 模拟 token 轮换)。
- **S-13 SettingsPrefs 键集表驱动**:中央服务收编全部键('an.*' 命名+兼容读 fy.ocean/fy.side.* 旧键+迁移与 clear 域同一常量表);**隐式偏好登记进 catalog**(fy.ocean→an.ocean/fy.side.*→an.side.*/右岛折叠 'an.right.collapsed.<ocean>' **per-ocean 桶**——与 WRK-061 §9 拍板同形);「重置本地偏好」=遍历声明键集(禁前缀通配)+逐 provider 即时回落(zoom.restore/setLocale/themeMode),无「重启生效」。
- **S-14 网络代理(拍板 #19 扩围 0709)**:env 透传照做(sidecar spawn 透传宿主 http_proxy/HTTPS_PROXY/no_proxy,一行 P0,面板未配时的兜底)+ **v1 直建 network 面板**(proxyMode system|manual|none 进机器级 settings.json `network` 段,工单⑩;改动生效=提示重启 sidecar,不做热生效链)。
- **S-15 model-capabilities provider 搬迁 core 先行**:现物理长在 features/chat/state(features 互不依赖铁律下 settings 无法 import)——S2 切片第一步把 fetch+provider 上移 core/shared,chat 改消费点,补「settings 改 key→chat 选择器刷新」集成测;key 增/删/旋转/test 转 ok 每处 invalidate 该 provider。
- **S-16 demo fixture=每片 DoD**:app 与 demo 共壳铁律——9 个资源面板必须配 fixture repository override(覆盖 error/pending/managed/五态等边缘),fixture 下截图入交付;「打开目录/日志」「重启后端」demo 下隐藏。

## 3. 设置目录(13 面板逐项;格式=项|控件|存|默认|生效)

> 完整逐项目录以下表为准(合并两案 64 项+挑刺修正)。**穷尽性由 SettingsSearchIndex 三相等门禁守住**。

**① 通用**(外观/语言/启动三节)
- 主题|AnSegmented 三档(浅色/深色/跟随系统)|app `an.theme`|**light**(S-9;dark 档后置)|即时(MaterialApp 补接 darkTheme+themeMode;webview 随 brightness 重渲)
- 界面缩放|AnSegmented 6 档+重置|app `an.window.zoom`(沿用既有键)|1.0|即时(WindowZoom 双向同步 Cmd+=/−/0;小屏超 maxFactor 档禁用+tooltip)
- 界面语言|AnDropdown(跟随系统/EN/简中)|app `an.locale`|system|即时(LocaleSettings.setLocale;**MaterialApp 补接 locale/supportedLocales——现缺**;索引同步换语言;zh 是 deferred import 注意首切延迟)
- AI 输出语言|AnDropdown+说明「影响 AI 回复与自动命名」|**workspace** PATCH /workspaces/{id} {language}|建 ws 时的 locale|热应用(下一回合)
- 记住窗口大小与位置|AnSwitch|app `an.window.remember`+`an.window.bounds`|on|下次启动(**restore 纪律**:bounds 与任一显示器可见区交集≥标题栏可点面积否则回落 1280×791 居中;序=clamp 尺寸→定位→应用 zoom,zoom 超 maxFactor 降档并改写键)
- 〔留位不渲〕开机自启 `an.startup.atStartup`/托盘 `an.tray.*`/免打扰时段/reduce-motion 三档 `an.a11y.reduceMotion`(v1 先零成本接 OS 级 MediaQuery.disableAnimations 到全部动效原语)

**② 通知**
- 通知级别|AnSegmented(全部收件箱事件/仅需你处理/静音)+只读行「需你处理的事永远送达,不可关闭」|app `an.notify.level`|**important**(S-8)|即时(ToastDispatcher 读 provider;「全部」分母=Emit inbox:true)
- 系统通知(未聚焦)|AnSwitch|app `an.notify.os`|on|即时(appFocusedProvider 路由处加闸)
- 应用内 toast|AnSwitch|app `an.notify.toast`|on|即时(danger 级错误 toast 不受闸,保诚实)
- 静音时确认 toast 微文案「已静音,重要事项仍在铃里」(一次性 neutral)

**③ 对话**
- 右岛自动登台|AnSegmented 三档(从不/每对话首次/每次)|app `an.chat.autoStage`(**只存全局意愿;导演器持 per-conversation 覆盖、切换复位**——WRK-061 契约)|always|即时(**V8 W1 落地后才渲此行**,未建前渲=死开关)
- 发送键|AnSegmented(Enter 发送·Shift+Enter 换行 / Cmd+Enter 发送)|app `an.chat.sendKey`|enter|即时(composer 读;**IME 组合态永不发送=代码守卫非设置项,随手修**)
- 网页抓取模式|AnSegmented(本地抓取/Jina 代理)+取舍说明|**workspace** PATCH {webFetchMode}|local|热应用(下次 WebFetch)
- 节尾 ghost 链接「默认对话模型 → 模型与密钥」(单一事实源不重复渲)

**④ 模型与密钥**(资源旗舰)
- 免费档托管卡|只读卡:Anselm Free·deepseek-v4-flash+AnMeter 配额(>85% warn)+resetAt+available=false 琥珀横幅|GET /freetier/quota|boot/create 双钩子自动开通|打开面板取+手动刷新(绝不轮询);404 按 S-7 三态
- API Key 列表|AnRow:provider 图标+displayName+keyMasked mono+testStatus 徽章(error 带 tooltip)+lastTestedAt+hover(测试/编辑/删除);**受管行锁图标置顶、无编辑删除入口**;分页|GET /api-keys|—|即时
- 添加 Key(BYOK)|推入表单:provider 分组下拉(**排除 managed+mock**,S-5;旁附「去控制台取 key」外链)→displayName→`AnSecretField`(**粘贴 trim 隐形空白**)→条件 baseUrl/apiFormat;保存=POST+自动 :test(**状态机按 S-3**)|POST /api-keys|—|即时;409/422 逐字段行内
- 测试/编辑/旋转/删除|行内动作;旋转按 S-4;删除 422 IN_USE→引用清单对话框(kind 译人话+「前往解除」深链)|:test/PATCH/DELETE|—|即时;每次变动 invalidate capabilities(S-15)
- 场景默认模型 ×3|AnSettingRow+分组下拉(capabilities 按 provider 分组,项 meta 渲 ctx/vision/docs 徽章;**dialogue 无清除项**,S-6)|**workspace** PUT/DELETE default-models/{scenario}|免费档播种 deepseek-v4-flash(只填未设)|热应用;未配置 warn「执行将报 MODEL_NOT_CONFIGURED」
- 默认搜索 Key|AnSettingRow+下拉(category=search 且 ok)|**workspace** PUT default-search|空|热应用
- 刷新模型列表|section 头 ghost|invalidate capabilitiesProvider|—|即时
- 〔v2 留位〕knobs 高级参数:每场景行下渐进披露,按 capabilities.knobs 元数据动态渲(enum→下拉/int→数字/bool→开关),换模型清空重渲

**⑤ MCP 服务器**
- 页头统计条「N 台·ready X·failed Y」+CTA(浏览市场 primary/⋯手动添加·导入 mcp.json)
- 列表|AnRow:五色状态灯+name mono+tools 数+调用统计+source 徽章+hover(重连/详情/删除)|GET /mcp-servers|空态三 CTA 引导|entities 流 mcp signal→**300ms coalesce 去抖 refetch**(不信帧内容);SSE 重连后强制 refetch(状态不落盘,后端重启全回 disconnected)
- 市场安装|推入页:registry 搜索→条目详情→env 表单(**数据源=POST :plan 端点**,§6;isSecret 掩码/required 星标);OAuth 条目「连接并授权」等待态(timeout 放宽 120s+可放弃+refetch 兜底)|GET /mcp-registry+POST :install|—|即时
- 手动添加|推入表单:name→transport 分段(stdio/sse/streamable-http)→条件字段(runtime/command/args/env kv | url/headers kv)→timeoutSec|PUT /mcp-servers/{name}|—|即时;连接失败仍落盘 failed 诚实进列表
- 导入 mcp.json|对话框:mono 粘贴框+overwrite 开关→「导入 N·跳过 M」toast|POST :import|overwrite=false|即时
- 详情|推入页:状态卡(reconnect/lastError/consecutiveFailures)+AnTabs〔工具(schema 折叠;**直调排 v2**,S-2 同族安全裁决——若提前必须 danger confirm+开发者折叠)|调用历史(分页+aggregates+过滤)|stderr(256KB 尾 AnTermViewport)〕+页尾删除(普通两步);**无配置编辑 tab**(S-2)
- 删除|红框+确认|DELETE(软删)|—|即时

**⑥ 记忆**
- 列表|AnRow:pin 图标(实心金,点击 toggle 幂等)+name mono+description+source 徽章+updatedAt;顶部过滤(全部/已固定)+搜索+「新建」|GET /memories[?pinned]|空态引导|即时
- 新建/编辑|推入页:name(新建就地 slug 校验;编辑态只读锁+tooltip「名称即文件名」)+description+content 多行 mono(失焦/Cmd+S 提交;dirty 返回二次确认)|PUT /memories/{name}(**不送 pinned/source**,后端保留)|source=user|即时
- pin/unpin|行内 toggle+tooltip「固定的记忆常驻每次对话上下文」|POST pin/unpin|unpinned|即时
- 删除|确认对话框(物理删文件+粗体 name+「无法撤销」)|DELETE|—|即时

**⑦ 沙箱**
- 页头:bootstrap 健康条(error 红卡+重试)+磁盘 AnMeter|GET bootstrap-status/:retry+disk-usage|—|打开取
- 运行时(节徽「全机」)|AnRow kind+version+size+installedAt+删除(409→先清 envs);安装=对话框(available 渲 kind/version,default 预选)→installing 行内态|GET/POST/DELETE runtimes|空态引导(directInstaller 按需下)|异步转终态
- 环境|AnTabs 五 ownerKind:AnRow ownerName+runtime+deps+size+status 徽章+lastUsedAt+runningPid 绿脉冲;删除(副文案「下次执行自动重建」;409 IN_USE 行内)|GET/DELETE envs?ownerKind=|各 tab 空态|即时
- GC|页尾:AnStepper N 天(默认 30)+回收→toast{removed};红框「立即回收全部空闲」=0 天中危两步|POST :gc|30|即时

**⑧ 工作区**
- 列表|AnRow:AnColorSwatch 圆点+name+lastUsedAt+「使用中」徽章;点非当前=确认后**整树重启式切换**(S-10;与左岛按钮同一 action);hover(改名 AnInlineEdit/换色/删除——**当前行删除 disabled**)|GET /workspaces|bootstrap 建默认|即时
- 新建|对话框 name+色板+language→建后询问切换(**免费档 provision 竞态按 S-7**:新 ws 模型页渲「正在开通…」)|POST|language=当前 locale|即时;409 行内
- 删除(非当前)|页尾红框:AnTypeToConfirm 输入名+**stats 真数字**+running 红字警示(S-11);仅剩一个 disabled 前置|DELETE(级联销毁)|—|即时
- 改名/换色|就地|PATCH|—|即时;左岛同步刷新

**⑨ 存储与日志**
- 数据目录|只读 mono+「在 Finder 显示」|GET /system/data-dir(前端绝不猜)|~/.anselm|只读
- 磁盘占用|分段条(v1 仅 sandbox 段+「明细即将提供」;/system/storage 落地补全——**口径=全机聚合+perWorkspace 细分数组**,与 stats.blobBytes 同源出数)|—|打开取
- 打开日志文件夹|行+按钮(zap 10MB×3 gzip 说明)|dataDir 派生|—|即时
- 复制诊断信息|按钮→版本×2/OS/dataDir/端口·health/ws 数/缩放语言→剪贴板+toast|内存聚合|—|即时
- 重置本地偏好|红框中危两步:遍历 SettingsPrefs 声明键集清除+逐 provider 即时回落(S-13);文案言明「只清本机界面偏好,不碰任何工作区数据」|SettingsPrefs.resetAll|—|即时
- 〔显式不做〕日志尾读端点(跨 workspace 泄露面,理由入规范防捡起)

**⑩ 高级限额**(页头 AnScopeBadge「全机」+常驻说明)
- Limits 全字段(~16 项)|**schema-driven 零硬编码**:GET /limits/schema 按 group 渲 AnSection;int→AnStepper(min/max/unit/desc);triggerRatio→AnInput 开区间校验;modified 左缘竖条+单项重置(AnSettingRow 承载);stepper 250ms 去抖合并 PATCH|机器级 settings.json,GET/PATCH /limits|schema default|即时热换;400 违规行内+回滚
- 全部恢复默认|红框+确认|POST :reset|—|即时全量重渲

**⑪ 快捷键**
- cheatsheet|v1 只读:搜索+分组 AnSection+每行命令名+AnKbd 键帽(⌘/Ctrl 平台分流);**建造含绑定收编重构**:app.dart/app_shell 散落绑定改为遍历 core/shortcuts.dart ShortcutCatalog 表驱动生成(门禁「catalog 条数==实际绑定」物理成立;Cmd+, 顺手入表)|代码常量注册表|—|只读;可改绑=future(hotkey_manager)
- 页尾 quiet「自定义快捷键将在后续版本提供」

**⑫ 关于**
- 版本|AnKv:应用(package_info_plus)+后端(GET /version,§6;**鉴权同 /health:免 workspace 过 bearer**;401/网络错/门控前统一渲「不可用」,仅 Gate 通过后拉)+点击复制|编译期|0.1.0+1|只读
- 检查更新|v1「前往 GitHub Releases」外链;WRK-043 auto_updater 落地后原地换原生|—|—|外链
- 后端状态|卡:health 绿点+127.0.0.1:port mono+**事实派生安全徽章**(S-12)+运行时长+「重启后端」(中危两步;仅 managed 渲;重启期 AppStartupGate 横幅自然接管)|/health+BackendController|—|即时
- 开源许可/文档/GitHub/反馈|LicenseRegistry An 化页+三外链行|编译期|—|只读

## 4. 组件清单

**新原语 15**(gallery-first):`AnSwitch`(库硬缺口,bool 唯一正统)· `AnSegmented`(2–4 段,**按正常 gallery 流程建 2-3 天**——AnOceanSwitcher 是竖排专用,只借动效基因非「直接抽」)· `AnStepper` · `AnSecretField`(粘贴 trim/可见性切换/**可兑现三条**:掩码不回显·值不落 prefs 日志异常·提交后 controller.clear——禁写「清内存」伪承诺)· `AnMeter` · `AnColorSwatch` · `AnKbd` · `AnDangerZone` · `AnTypeToConfirm`(粗体资源名+输入精确匹配解锁;确认词统一「输入目标名称」,i18n 登记)· `AnScopeBadge` · `AnSettingRow` · `SettingsPrefs`(中央键表服务,S-13)· `SettingsSearchIndex`(+三相等门禁)· `SettingsPushPane`(推入导航壳+dirty 守卫)· `workspaceDeletionController`(独立 Notifier 编排,S-10/11)。

**复用**:AnPage/AnSection/AnField/AnKv/AnFormField/AnInput/AnDropdown(meta 位渲模型徽章)/AnRow(资源行+目录行,dot 复用 rail 信号点)/AnInlineEdit/AnTags(health)/AnTabs(flow)/overlayProvider.confirm+showToast/AnMenuItem(danger)/AnButton/AnState/AnTermViewport/OceanBreadcrumb/entities 详情页范式/WindowZoom/LocaleSettings/OsNotifier·ToastDispatcher·appFocusedProvider(加读闸)/BackendController(+managed:bool)/AppStartupGate/workspaceBootstrap+AnWorkspaceButton 同一 action。

## 5. 后端工单(守 N/D/E/S/T+文档 1:1)

**P0(随 settings 建造;⑧⑧'⑩ 按 2026-07-09 拍板改)**:①受管 key DELETE 守卫(S-1,一行+文档+testend)②`GET /api/v1/version`{version,builtAt}(免 workspace 过 bearer;-X main.version 盖章,WRK-043 已规划)③`POST /api/v1/freetier:provision`(幂等短路,S-7)④`GET /api/v1/workspaces/{id}/stats`(免 RequireWorkspace+path id 铸 ctx;静态计数+runningFlowruns/generatingConversations;blobBytes walk 设 500ms 预算超时返 -1)⑤Emit 帧加 `inbox:true` 标记(S-8,一行 payload+events.md)⑥mock 非 dev 剔除(S-5)⑦sidecar spawn 透传 http_proxy env(S-14,一行)⑧~~删 key 清空 conversations.model_override~~**撤销**(拍板 #16:覆写神圣,改 chat 侧 LLM_RESOLVE_ERROR 横幅「重选模型」CTA,前端件)⑧'**主密钥从 env 读**(拍板 #14 keychain:后端确认/新增 `ANSELM_MASTER_KEY` env 优先于文件,+迁移路径文档)。

**P1**:⑨`POST /api/v1/mcp-registry:plan`{name}→{chosenPackage,requiredEnv[],oauth}(安装表单数据源,防前端复刻择包漂移)⑩机器级 settings.json 加 `network` 段(proxy 地址,schema-driven 同 /limits 族;生效=sidecar 重启时 env 注入,拍板 #19)。

**v2/显式不做**:`GET /system/storage`(全机聚合+perWorkspace 细分,walk 抽共享 util+30s 缓存)· MCP config GET/PATCH(S-2)· `POST /api-keys:probe` 存前验证 · 日志尾读端点=**显式不做**(跨 workspace 泄露面)· factory-reset **后端端点不做**(拍板 #12:一键重置走**前端编排**——停 sidecar→删数据目录→重启,前端本就有进程+目录权柄)· 自动更新**后端件不做**(拍板 #7:客户端直查 GitHub Releases API)。**铁律:api-keys/workspace 偏好变更不上 entities 流**(E1 三条流不加设置帧,settings 操作后前端自 invalidate)。

## 6. 建造切片 S0–S6(每片 DoD 含 demo fixture+真机 E2E)

| 片 | 内容 |
|---|---|
| **S0 地基** | SettingsPrefs(键表+fy.* 迁移)+AnSwitch/AnSegmented/AnSettingRow/AnScopeBadge+壳(目录三段+AnPage+面包屑+SettingsPushPane)+SettingsSearchIndex(面板过滤+三相等门禁)+OS reduce-motion 全局接线 |
| **S1 偏好域** | 通用(主题三态[跟随/浅/深]+**语言单项双写**[app locale+workspace.language,文案明示双效]+**窗口几何记忆**[多显示器 clamp]+**开机自启**[launch_at_startup]+自动检查更新开关)+通知(三档;含 Emit inbox 标记后端件)+对话(sendKey+webFetchMode+autoStage[app 级]) |
| **S1b dark 主题** ⚡ | dark 全量点亮(拍板 #1):AnColors 暗色板定稿→49+ 原语 gallery 逐件验色→demo/app 全面真机走查;跟随系统=platformBrightness 监听。**独立片,S1 后紧跟**(其余片在 light 下继续并行) |
| **S2 模型与密钥** | capabilities provider 搬迁 core 先行(S-15)→受管 DELETE 守卫+provision+version 后端件→免费档卡+key CRUD(S-3/4 状态机)+场景默认+AnSecretField/AnMeter;**keychain 升级**(拍板 #14:flutter_secure_storage 主密钥+一次性迁移+env 注入+ADR)+**chat 侧删 key 引导**(拍板 #16:LLM_RESOLVE_ERROR 横幅「重选模型」CTA) |
| **S3-pre 热切换基建** ⚡ | (拍板 #17)全库 workspace 敏感 provider 审计→watch activeWorkspace;SSE 三流强制重连缝;keepAlive 缓存失效清单;验收=切 ws 不重启、无陈旧数据残影 |
| **S3 工作区+关于** | stats 端点→列表/新建/改名色/TypeToConfirm 删除(禁删当前)+**热切换**(S3-pre 之上);关于页(version/后端状态 S-12/许可/诊断复制+**自动更新检查**[GitHub Releases API 直查,提醒+外链]) |
| **S4 记忆+MCP** | 记忆 CRUD+pin;MCP 列表/市场(:plan 端点)/手动/导入/详情三 tab(无编辑无直调) |
| **S5 沙箱+限额+存储+网络** | 沙箱全面;limits schema-driven;存储与日志(重置本地偏好+**一键出厂重置**[拍板 #12:TypeToConfirm 双闸→停 sidecar→删数据目录→重启,前端编排]);**network 面板**(拍板 #19:settings.json network 段+重启生效提示) |
| **S6 快捷键+收尾** | 绑定收编表驱动+**可改绑**(拍板 #4:冲突检测+持久化+热重注册)+cheatsheet;i18n 专项审查(~300 key×2 locale);搜索二级命中/@modified/knobs 评估进 v2 |

## 6b. 建造进展(路线⑤,逐片落账)

- **S0 地基 ✅(2026-07-09)**:`SettingsPrefs` 中央键表服务(`core/settings/`,20 声明键+`an.right.collapsed.` 族+fy.*→an.* 一次性迁移+声明集 resetAll[外键存活]);四原语进 gallery(`AnSwitch` 30×18 药丸/`AnSegmented` 等宽段白卡滑动/`AnSettingRow` modified 竖条+hover 单项重置/`AnScopeBadge` 三域);settings 壳(`SettingsRail` 目录三段 13 面板[内建面板粒度过滤=v1 搜索裁决]+`SettingsOcean` 每面板一页 AnPage[H1+注册表体+浮层头「设置 / 面板」+换面板回顶]+`settingsPanelProvider` 持久化导航+穷尽 switch 注册表[漏接体=编译错]);**Cmd+, 快捷键**;三消费者改接同步读(shell_chrome/oceans/followMode——异步 restore 竞态整个消失);main/demo 双入口装载。**三相等门禁落地**(`settings_catalog_gate_test`:面板↔目录/声明键↔归属分区/rail↔目录)。测 +40(2688 全绿),真机验收(齿轮进入/13 面板三段/切面板/占位诚实)。**S0 内偏移**:`SettingsPushPane` 推迟到 S2(首个资源详情才有真消费者,零消费者建=测不真);OS reduce-motion 接线经查**已存在**(AnMotionPref=MediaQuery.disableAnimations,无事可做)。

- **S1 偏好域 ✅(2026-07-09)**:**三面板点亮**——①通用(主题三档[dark 段 disabled 待 S1b]+缩放六档[镜像 WindowZoom.factor、超屏 cap 段 disabled、⌘ 快捷键同步]+**语言单项双写**[拍板 #2:UI locale 即时 + workspace.language PATCH,失败回滚+danger toast]+记住窗口+开机自启+自动检查更新开关);②通知(三档级别+只读「需你处理永远送达」行+OS/应用内两开关+切静音一次性确认 toast);③对话(右岛自动登台三档=**读 chat 的 followModeProvider 同一份状态**+发送键两档+webFetchMode[workspace PATCH]+「默认对话模型→模型与密钥」ghost 单源链)。**横切工程**:MaterialApp 补接 darkTheme/themeMode+locale/supportedLocales(此前全缺);`ThemePreference`/`LocalePreference`/bool·string 偏好 provider 族(core/settings/app_prefs_providers);**窗口几何记忆**(拍板 #13:`WindowBounds` 纯 clamp[标题栏带抓取测试+尺寸收屏+退化拒绝,6 纯测]+moved/resized 去抖捕获+开窗前恢复,screen_retriever);**开机自启**(拍板 #15:launch_at_startup 缝);数据缝 `SettingsRepository`(Live/Fixture)+`workspacePrefsProvider`(乐观 PATCH+回滚);**消费接线**=ToastDispatcher 三闸(级别/OS/toast,danger 穿透)+composer sendKey(cmdEnter 模式)+AnSegmented 段级 disabled。**修自伤 bug**:LocalePreference build 对 system 也 useDeviceLocaleSync→踩宿主 locale(改只应用具体 tag);workspacePrefs 首取未完成时 _patch 静默弃写(改 await future)。测 2688→2702,真机三面板逐帧验收。

- **S1b dark 全量点亮 ✅(2026-07-09,拍板 #1;产品史上第一帧暗色)**:MaterialApp darkTheme/themeMode 接线随 S1 已备(app+demo 双壳),本片=**点亮与验证**——①gallery 矩阵新增 **dark 轴**(每 specimen 在 AnTheme.dark 下 build+布局无抛错无溢出,529 specimen×新轴=+529 测,门禁常驻:硬编亮色/缺暗色扩展在 CI 炸,色彩审美归真机);②真机四海洋走查全过:settings(域徽/白卡段/开关/修改条)/chat(工具卡/运行台账红绿节点/HANDLER_RPC_TIMEOUT 红 mono/inline chips)/documents(原生编辑器/@ 药丸/引用条/大纲)/entities(状态点/代码块**语法高亮暗色板**/run 终端)——零破色零补丁,AnTheme.dark 三 ThemeExtension 对定义一次成活;③dark 段解禁(general 面板可选)+themeDesc 文案重述(「跟随系统随 macOS 外观」)。**顺手修**:demo 壳(_DemoRoot)漏接 darkTheme/themeMode(只接了 app 壳——真机首验即抓)。测 2702→3231 全绿。

- **后端 P0 批 ✅(2026-07-09,S2 前置 6 件)**:①受管键删除守卫(Delete 补 Update 同款 `GetProviderMeta().Managed` 检查→422 `API_KEY_IMMUTABLE`;testend 契约测同步改判)+ mock provider 目录过滤(`ListProviders(dev)` 非 dev 隐藏;创建白名单不动,testend 依赖它);②版本注入(`-ldflags -X main.version` 经根 Makefile `git describe`)+ `GET /api/v1/version` 免鉴权白名单(About 面板用);③免费档显式开通 `POST /freetier:provision` → `ProvisionNow` 诚实布尔(开通后行存在=true/降级=false,状态非故障);④通知帧 `inbox:true` 线上标记(Emit 推帧于**拷贝** payload 上加标、落库行不带;Broadcast 不加)——前端铃徽标据此分层;⑤chat handler 既有 S20 违例清理(裸 `responsehttpapi.Error` → `errorspkg.ErrInvalidRequest.WithDetails`);⑥`ANSELM_MASTER_KEY` env → `Config.Fingerprint`(keychain 工单⑧' 后端路径;换种子=既有密文作废,故 keychain 只对全新安装启用)。文档 1:1(api/error-codes/events/support-services);verify+docs+testend 黑盒全绿。

- **S2 模型与密钥 ✅(2026-07-09,资源旗舰面板)**:**契约与缝**——`core/contract/api_key.dart`(ApiKey/ProviderMeta/FreetierQuota freezed)+ **S-15 能力目录上移 core**(`core/models/model_capabilities.dart`,chat 选择器与 settings 双消费、features 互不依赖;chat repo 的 listModelCapabilities 面收编,demo 装配直喂 `demoModelCapabilities`);SettingsRepository 补 keys 全面(providers/keys CRUD/:test/quota[404→null]/provision/场景默认 PUT·DELETE)+`settings_demo_fixture`。**状态**——`apiKeysProvider`(每变更重拉+invalidate capabilities;**test 在 finally 重拉**——失败探测同样落了行态)+`freetierQuotaProvider`(手动刷新,绝不轮询)+`settingsDetailProvider`(中心推入第三级:面包屑第三段+Esc 返回+换面板弹出)。**UI**——`ModelsKeysPanel` 三区:受管免费档卡(未开通 CTA+指纹隐私提示/配额 meter+重置期/预算横幅三面)、密钥列表(受管锁顶+受管标常驻 meta;**行点击=编辑**[承重:AnInteractive 仅可激活行跟踪 hover,无 onSelect 则真鼠标永远够不到动作——真机抓出]、hover 现 Failed 徽章+Test/Edit/Delete)、场景默认三下拉(`apiKeyId::modelId` 值对,对话默认不可清)+搜索默认键;`KeyForm` **S-3 状态机**(首次提交 POST 绑 id、此后一律 PATCH 绝不二次 POST;secret 提交即清;保存自动探测,失败就地红字;编辑态非空 secret=轮换 S-4 就地警示);新原语进 gallery:`AnSecretField`(遮罩+眼睛+粘贴修剪)/`AnMeter`(accent→warn 0.85→danger 0.97,null=空槽)。i18n ~45 键双语。**测**:s2 电池(免费档三面/受管锁顶/S-3 状态机/S-15 失效)+chat_head 补 core 能力 override(S-15 搬家余波:旧 override 不再覆盖→riverpod 重试 timer 悬挂);fe-verify 3258 全绿。**真机 E2E 全链**(release build+真 sidecar):免费档真网关配额(0/5000)→provider 目录(mock 已滤)→DeepSeek 预填 baseUrl→假 key 提交(POST+真探测 401 失败红字+表单留驻)→列表红点 Failed→删除确认→只剩受管行;**真机修出 2 bug**(探测失败列表行态 stale;hover 动作不可达)。**S2 全清:**keychain 铸钥与 #16 CTA 见下两条。

- **S2 尾·keychain 铸钥 ✅(2026-07-09,拍板 #14,ADR 0008)**:`core/process/master_key.dart` DIP 解析器(read/write/hasDb 三缝注入,单测 5 分支)——keychain 有条目直用/全新安装(盘上无 anselm.db)铸 256-bit 随机钥入 OS keychain+**读回验证**(静默写失败弃用)/旧装机(库在、无条目)**绝不铸**走机器指纹旧径(硬注新钥=密文全孤儿)/任何 keychain 异常退化旧径**启动绝不变砖**;`BackendController.masterKey` 缝每次 spawn 重解析→`ANSELM_MASTER_KEY` env(后端批⑥已备)。macOS 取 **login keychain**(`usesDataProtectionKeychain:false`)——data-protection keychain 需真证书签名+entitlement,本地 ad-hoc 构建**编译直接失败**(实测,entitlements 已回滚),WRK-043 落 Developer ID 后切。真机双启验证:fresh wipe→首启 login keychain 现 `anselm.master-key` 条目+库新建;二启复用同钥解开首启密文(托管行 ok+配额正常=round-trip 成立)。flutter_secure_storage ^10.3.1。**已知现实**:ad-hoc 签名每次 rebuild 变 → login keychain 条目 ACL 绑旧签名,新 build 首访弹系统授权(正式 Developer ID 签名后消失);Deny 分支真机亲验=退化旧径 app 完好启动(绝不变砖 ✅)。

- **S2 尾·LLM_RESOLVE_ERROR 重选 CTA ✅(2026-07-09,拍板 #16)**:头部模型菜单提为共享 `chatModelMenu(anchorBuilder 换锚脸)`;`_stopBanner` 对 `errorCode==LLM_RESOLVE_ERROR` 长出「重选模型」sm 钮(其余错误码不长)——删 key 后会话覆写神圣不动,修复入口就长在失败处;选中经 `conversationHeaderProvider.setModel` PATCH 线程覆写。i18n `chat.repickModel` 双语;widget 测 2 条(CTA 现身+选中 PATCH 同 id/普通错误不长)。**真机全链亲验**(fresh 安装+真后端):Auto 发「hi」真模型回复+自动命名 → API 布置真悬空(override 指向 cta-key 后 DELETE 204;后端正确拒绝 PATCH 指向不存在 key=悬空只能由删除产生) → 再发触发红字 `LLM_RESOLVE_ERROR · api key not found`+CTA 现身 → 点开菜单选托管模型 → 浮层头即变 deepseek-v4-flash(覆写落库)。

- **S3-pre 热切换基建 ✅(2026-07-09,拍板 #17 方案 B)**:①**脉搏**——`apiClientProvider`/`sseGatewayProvider` 加 watch `activeWorkspaceProvider`(id 仍每请求懒读;watch 只为依赖边):切 workspace→唯一 HTTP 边界与 SSE 网关重建→**全部 Live repo(都 watch 这两个)→全部 server-state provider(都 watch repo)零逐处接线级联重取**,三流按新 workspace 重连(后端按连接时 header 定域);②**生产者出环**——`workspace_bootstrap` watch→read(bootstrap 是 activeWorkspace 的生产者,watch 会闭环:每次切换重跑 bootstrap 把选区拽回首个 workspace);③**粘性自愈**——不经级联的 feature keepAlive 态各自 watch id:chat `landingModelProvider`(键对属旧 ws key 集→回 null)+`titleRevealsProvider`(清队);审计确认选区全部 URL 派生(conversation/entity/document 三 shim)无需清;④**切换动作** `core/workspace/workspace_switch.dart`(`workspaceSwitchProvider`):同 id 短路;先 `go('/')` 离旧深链(否则未卸载详情页在新 ws 下查旧 id 404 闪)再设 id+name——S3 workspaces 面板直接调。电池 `test/core/workspace/hot_switch_test.dart` 5 测(ApiClient/网关重建 identity/出环不被拽回[mock dio adapter 数 list 调用]/粘性清空/动作离深链+同 id 不动路由);architecture.md 运行时段重述(顺手修 fy.* 旧键名残留)。fe-verify 3270 绿。

- **后端工单④ stats ✅(2026-07-09,S3 前置)**:`GET /api/v1/workspaces/{id}/stats`——domain `Stats` 形状+Repository.Stats;store 一批相关标量子查询(六表滤软删+flowruns partial 索引数 running+generating IN 交集);app 层 `SetStatsPorts`(blobfs TotalBytes 500ms 预算 walk[超时/未接线=-1 诚实未知]+chatapp `GeneratingIDs()` 在飞快照,后注入同 Reaper 模式);handler 免 workspace 头、path id 铸 ctx。测:store 影子表交集测+app 端口拼装/预算退化/404 测+chat GeneratingIDs。api.md+support-services.md 1:1。verify 全绿。

- **S3 工作区+关于 ✅(2026-07-09)**:**⑧工作区面板**——名册(色点+当前行高亮+Current 常驻 meta;**点行=热切换**,S3-pre 级联的第一个真消费者,真机亲验:底栏名/名册/全数据即时换 ws,切换后留在 settings[海洋走 provider、go('/') 只清深链选区——比回 chat 更顺]);新建(名+六预设色盘);推入编辑页(改名[当前 ws 同步底栏名]/改色/**页尾分布式危险区**=新原语 `AnTypeToConfirm`[红框卡+动态警示红字置顶+真数字散文+输名解锁+busy]进 gallery 3 specimen;stats 真数字入散文[对话/实体合计/文档/附件体积,-1=体积未知];runningFlowruns/generating >0 红字警示;**当前 ws 与最后一个绝不给删**[Current/lastOne 提示替代];删除失败留守+danger toast 绝不自动切)。**⑬关于面板**——版本区(app 版本[package_info]+引擎版本[GET /version 真机=dev])+**v1 更新检查**(拍板 #7:`update_check_provider` 独立裸 Dio 查 GitHub Releases[绝不带 loopback 凭据出网]+semver 比较[怪格式绝不称新]+三面[最新/可更 available+外链/诚实 unknown];`StartupUpdateCheck` 启动自动查[开关控,available 才 toast,失败沉默]真机亲验 unknown 面)+诊断复制(版本+OS→剪贴板+toast)。**修 3 缺陷**:①**dio 层脉搏(重大)**——S3-pre 把切换 watch 放在 apiClientProvider,共享 Dio 上旧 client 拦截器(闭包捏已废 Ref)每请求必炸,S3 首次真机即全局白数据;脉搏下沉 dioProvider(每切换新 Dio+onDispose close,旧拦截器随旧实例退役),回归钉入 hot_switch(sabotage 亲验会红);②rail 重点当前面板=回面板根(pop detail);③settings repo 面+fixture 扩(workspaces CRUD/stats/version,failNextWorkspaceDelete 脚本钩)。s3 电池 6 测(名册切换/新建/危险区真数字+解锁+删除/当前绝不给删+失败留守/关于/semver);fe-verify 3285 绿。真机全链:建 Play→热切换→切回→危险区→输名删除→About。

- **S4a 记忆面板 ✅(2026-07-09)**:`core/contract/memory.dart`(slug 名即身份无 id)+repo 面(list[?pinned]/put/pin/unpin/delete)+`memoriesProvider`(pin 用权威响应就地补单行,一比特翻转不整表重拉)+`MemoryPanel`——名册(全部/已固定 AnSegmented 投影+搜索+行内金 pin toggle[tooltip「常驻每次对话上下文」]+source·mtime meta+行点击=编辑)/推入编辑(建时活校验 slug `^[a-z][a-z0-9_-]{0,63}$`;编辑**锁名**[名称即文件名]+dirty 返回先问;Cmd+S)/确认删除(物理删文件)。**真机修出契约缺口**:PUT 创建**必须带 source**(scout 契约在此列明但首版漏送→后端 400 `MEMORY_INVALID_SOURCE` 真机即抓);修=恒送 `source:'user'`(更新时后端按 F147 忽略、创建时正确,AI 记忆被编辑时 source 保留 ai)。s4 电池 4 测(名册/过滤/pin 就地/slug 拒绝+落册/锁名+F147 pin 存活/删行);真机全链(建 team-style→落册→pin 上金)。i18n mem.* 双语。

- **S4b MCP 面板 ✅(2026-07-09,含后端工单⑨)**:**后端⑨** `POST /mcp-registry:plan`(app `PlanFromRegistry` 投影 domain `Plan()` 选包结果成 `RegistryPlan{transport,runtime,oauth,envVars,prerequisite}`——选包逻辑单源服务端;零副作用,envVars 恒 [];单测+api.md/mcp.md 1:1)。**前端**:`core/contract/mcp.dart` 五 DTO(ServerStatus 纯运行态/RegistryEntry 列表投影/RegistryPlan/EnvVar/Call)+repo 面 11 方法(含 `getPageWithAggregate` 调用日志聚合)+`mcpServersProvider`(**kindStream(entities,'mcp') 任何帧→300ms coalesce 一次重取,绝不信帧内容**+resync(410) 强制重取[后端重启全回 disconnected])+registry/plan/stderr/calls providers;`McpPanel`——名册(五态点映射[disconnected=无点]+统计条+三 CTA+行点击=详情)/详情(状态卡+lastError 红字置顶+**工具/调用历史/stderr 三 tab**[AnTabs 文档流内定高;无配置 tab,S-2 配置加密只写])/手动添加(transport 分段条件字段+KEY=VALUE 行解析+「失败也落盘」诚实提示)/导入(粘贴框+overwrite 开关+导入 N·跳过 M toast)/市场(本地搜索[端点无参]+短名比对已装标+**:plan 驱动安装表单**[isSecret 掩码/required 星标/OAuth 变「连接并授权」])。s4_mcp 电池 5 测。**真机全链**:市场 96 条真拉(GitHub 首拉慢=loading 诚实)→context7 :plan 表单(stdio+node 徽章+掩码 env)→真安装 npx→**failed 诚实态落名册**→详情真 lastError 红字(`fork/exec .../node/22/bin/npx: operation not permitted`——**App Sandbox 禁 spawn directInstaller 下载的二进制,release 沙盒 app 的平台级已知现实**,归 WRK-042/043 sidecar+sandbox 范畴、非本面缺陷;dev 非沙盒后端不受影响)→删除确认→空态。**真机修**:plan 错误面(dead :plan 曾永远 loading→hasError 诚实红字);重申**改后端必须重 build sidecar 进 bundle**(旧二进制 404 :plan 复踩)。

- **S5 存储/限额/网络 ✅(2026-07-09,含后端工单⑩)**:**后端⑩** settings.json 加 `network` 段(`fileShape{limits,network}`,`persist(limits,network)` 整体写——PATCH 任一段绝不丢另一段)+`GET/PATCH /network`(整体替换 `{httpProxy?,httpsProxy?,noProxy?}`)+`applyProxy` boot 与 PATCH 时 `os.Setenv HTTP_PROXY/HTTPS_PROXY/NO_PROXY`(Go `http.ProxyFromEnvironment` 读之,重启 sidecar 完整生效);工单⑦(shell env 透传)由 `Process.start includeParentEnvironment:true 默认满足`,无需额外配置。单测 TestPatchNetwork(往返+env 应用+limits patch 不丢网络段);api.md/platform-pkgs.md 1:1。**前端 3 面板**:⑨存储(`LimitField` DTO 无关;数据目录只读[后端解析绝不猜]+访达/日志文件夹[macOS `open`]+沙箱磁盘 AnMeter+诊断复制+重置本地偏好[SettingsPrefs.resetAll 声明集]+**出厂重置**[拍板 #12:`core/platform/factory_reset.dart` 前端编排=停 sidecar→删数据目录→`resetAll`→`open -n bundle` 重启;AnTypeToConfirm 输「Anselm」双闸]);⑩高级限额(**schema 驱动**:`GET /limits/schema`→group AnSection+每字段 AnSettingRow[点路径 `_valueAt`/提交构部分嵌套体 PATCH/modified 竖条+单项重置];越界回滚到服务端真相;全机域徽+全部重置;零复刻 Go 常量);⑪网络(`NetworkConfig` DTO;三 proxy 字段水化+整体 PATCH+重启生效橙字+全机域徽)。s5 电池 4 测(存储数据根+出厂闸锁死/限额 schema 分组+嵌套 PATCH+全部重置/网络水化+PATCH);**真机全链**:存储(真容器路径+真沙箱 520.6MB+出厂红区锁死)→限额(真后端 schema 三组全渲+maxSteps 25→40 **API 确认落库**+复位)→网络(三字段+橙字+proxy PATCH **API 确认持久化**+清理)。i18n storage/limits/network 三块双语。

## 7. 测试与验收

五电池(每原语)+集成:settings 改 key→chat 选择器刷新 · token 轮换后无 401 风暴 · workspace 删除全序(Notifier 编排+无脏 id)· fy.* 迁移无残留 · 重置=声明键集全清且即时回落 · 「全部」档无 Broadcast toast · demo fixture 9 面板截图 · 三相等穷尽门禁入 fe-verify。真机 E2E:每片 build→开 app→逐面板交互→截图核对(用户明令)。

## 8. 决策清单——已拍板(2026-07-09,用户逐条裁决;⚡=推翻原推荐、范围扩大)

1. **主题** ⚡:**v1 就带 dark**——dark 主题工程(49+ 原语全量验色)并入建造,立独立切片 S1b(S-9 的「后置」作废)。
2. **语言**:**单项双写**——一个语言设置同时写 app 级 UI locale + workspace.language(AI 输出);面板文案须明示「同时影响界面与 AI 回复」。
3. **通知**:三档单选(全部收件箱/仅需处理/静音,默认仅需处理);矩阵存储缝保留待 v2。
4. **快捷键** ⚡:**v1 直上可改绑**——绑定收编表驱动之上加改绑(冲突检测+持久化+热重注册),S6 范围扩大。
5. **危险区**:分布式(各资源页尾,就地语境+双重确认)。
6. **MCP 安装表单**:后端 `:plan` 端点(P1 工单⑨)。
7. **版本与更新** ⚡:**v1 带自动更新检查**——客户端直查 GitHub Releases API(最新 tag vs 本地版本,提醒+外链下载;不做自动下载安装),通用面板加「自动检查更新」开关;auto_updater 全自动化仍随 WRK-043。
8. **settings 导航**:provider 先行(用户委托按推荐定;海洋统一路由化时一并迁 go_router)。
9. **右岛 autoStage**:app 级(SharedPreferences,与侧幕三档跟随同存法)。
10. **免费档**:托管卡与 BYOK 分区。
11. **数据目录**:v1 只读展示+「在访达中打开」;可改+搬迁向导独立立项。
12. **恢复出厂** ⚡:**做一键重置(双重确认)**——实现走**前端编排**(TypeToConfirm 双闸→停 sidecar→删数据目录→重启拉起),不做后端毁灭端点(单用户本地 app,前端本就有进程+目录权柄)。
13. **窗口几何记忆**:做(含多显示器 clamp 纪律:恢复前验证落点在可见屏内,否则居中)。
14. **BYOK 主密钥** ⚡:**v1 就升级 OS keychain**——flutter_secure_storage 铸/存主密钥→env 注入 sidecar;须配迁移(既有文件主密钥→keychain,一次性)+ ADR 记录;后端确认/新增「主密钥从 env 读」路径(工单⑧')。
15. **开机自启** ⚡:**v1 就做**(launch_at_startup 成熟包,macOS SMAppService);**托盘/关窗驻留不做**(关窗=退出语义不变),通用面板出「开机自启」开关。
16. **删 key 对会话覆写** ⚡:**保留覆写,chat 侧引导重选**——原 S-6「后端顺手清空」作废(P0⑧撤销);改为 chat 在 LLM_RESOLVE_ERROR 终态横幅上出「重选模型」CTA(打开模型菜单),会话覆写神圣不动。
17. **workspace 切换** ⚡:**先建热切换基建**(独立前置工程,新切片 S3-pre):全库 workspace 敏感 provider 改 watch activeWorkspace + SSE 三流强制重连缝 + 各 keepAlive 缓存失效审计;S-10 的 Phoenix 方案作废,禁删当前活跃 ws 的守卫保留。
18. **MCP 工具直调**:v2(S18 安全模型,v1 只列工具)。
19. **网络代理** ⚡:**直建 network 面板**——机器级 settings.json 加 `network` 段(proxy 地址,schema-driven 同 /limits 族,后端工单⑩)+ sidecar spawn env 注入生效(重启 sidecar 提示);env 透传(工单⑦)仍做(面板未配时尊重 shell env)。
20. **切片顺序**:确认 S0→S6 主干;新增插片见 §6(S1b dark / S3-pre 热切换)。
