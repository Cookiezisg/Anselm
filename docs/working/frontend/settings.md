---
id: WRK-062
type: working
status: active
owner: @weilin
created: 2026-07-08
reviewed: 2026-07-08
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
- **S-6 场景默认「清除」防自伤**:dialogue 场景不渲清除项(或清除即渲红警示「未设置——Auto 对话将不可用」+确认文案言明);「指向已删 key」警示是死代码(RefScanner 挡删)不做——真警示只做 testStatus=error 与 capabilities 查无此对。**conversation.model_override 是 RefScanner 盲区**(删 key 可致会话级 LLM_RESOLVE_ERROR)→ 后端裁决:删 key 顺手清空指向它的会话覆写(回落默认,推荐)——列 §6 后端工单;chat 侧对死 override 渲「模型已失效,点击重选」。
- **S-7 免费档三态+provision**:quota 404 且 workspace `createdAt<60s`=渲「正在开通…」+5s 自动 refetch(OnCreated 钩子已存在,读码实证 build_services.go:419——boot+create 双钩子,缺的只是手动重试端点);否则渲「启用免费档」按钮=POST `/freetier:provision`(**幂等短路**:先查受管行存在即 200 返现有 quota;按钮 in-flight 单飞;旁注「将向 Anselm 网关注册本机匿名指纹以分配额度」——隐私显式化)。
- **S-8 通知档语义**:默认 **important(仅需你处理)**(对齐 N4/N5 already-landed 裁决);「全部」档分母=**落收件箱行的 Emit 事件**(后端 Emit 帧加 `inbox:true` 标记位,一行 payload+events.md 同步)——Broadcast 对账回声永不进 toast 候选,否则 N0 后 18 个高频回声=toast 风暴。通知声音项 v1 砍(记留位,若做=「系统通知声音」从属行+平台注记)。
- **S-9 主题 v1 默认 light 且 dark 档后置**:AnTheme.dark 全量定义但 app 从未渲过一帧,113 工具卡/终端 ANSI/webview theme.css 全是第二套走查——dark=独立 WRK(gallery 全 specimen dark 截图→真壳四海洋走查→webview 对齐),settings 只建三档控件接线、v1 藏 dark 档或渲 disabled「即将推出」。
- **S-10 workspace 切换=v1 整树重启**:全库零 provider watch activeWorkspace、SSE 无强制重连缝(读码实证)——热切换=横切重构独立前置工程。v1 切换走 Phoenix 式(activate → runApp 重跑 ProviderScope+WorkspaceBootstrap,零级联债);**v1 禁删当前活跃 workspace**(按钮 disabled+tooltip「先切换到其他工作区」——把时序问题变 UI 约束);删除编排收进独立 Notifier(不依赖 widget 生命周期)。
- **S-11 删 workspace 确认带真数字+动态警示**:`GET /workspaces/{id}/stats`(§6)返静态计数+**runningFlowruns/generatingConversations**——>0 时确认框首行红字「有 N 个执行进行中,删除将终止它们」;AnTypeToConfirm 正文粗体引用真实数字(「将永久删除 N 对话、M 实体、X MB 附件」);DELETE 失败=留在新 workspace+danger toast+refetch,绝不自动切回。
- **S-12 「重启后端」按 managed 分叉**:BackendController 暴露 `managed:bool`——dev-attach(ANSELM_BACKEND_URL)下按钮**隐藏**、渲「外接后端(开发模式)· url」;「安全状态」行由事实派生(sidecar 铸过 token=绿「loopback+Bearer」;attach=灰「加固状态未验证」),禁硬编码绿点。重启前审计:dio/SSE 必须每请求从 BackendState 取 token,禁构造期快照(配 widget test 模拟 token 轮换)。
- **S-13 SettingsPrefs 键集表驱动**:中央服务收编全部键('an.*' 命名+兼容读 fy.ocean/fy.side.* 旧键+迁移与 clear 域同一常量表);**隐式偏好登记进 catalog**(fy.ocean→an.ocean/fy.side.*→an.side.*/右岛折叠 'an.right.collapsed.<ocean>' **per-ocean 桶**——与 WRK-061 §9 拍板同形);「重置本地偏好」=遍历声明键集(禁前缀通配)+逐 provider 即时回落(zoom.restore/setLocale/themeMode),无「重启生效」。
- **S-14 网络代理最小解(P0 一行)**:macOS GUI 子进程拿不到 shell 的 http_proxy——sidecar spawn 时**透传宿主 http_proxy/HTTPS_PROXY/no_proxy env**(一行改动,中文用户 BYOK 国际 provider 的唯一自救);完整「网络」面板(proxyMode system|manual|none 进 settings.json)=v2,目录「登台待留」段登记。
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

**P0(随 settings 建造)**:①受管 key DELETE 守卫(S-1,一行+文档+testend)②`GET /api/v1/version`{version,builtAt}(免 workspace 过 bearer;-X main.version 盖章,WRK-043 已规划)③`POST /api/v1/freetier:provision`(幂等短路,S-7)④`GET /api/v1/workspaces/{id}/stats`(免 RequireWorkspace+path id 铸 ctx;静态计数+runningFlowruns/generatingConversations;blobBytes walk 设 500ms 预算超时返 -1)⑤Emit 帧加 `inbox:true` 标记(S-8,一行 payload+events.md)⑥mock 非 dev 剔除(S-5)⑦sidecar spawn 透传 http_proxy env(S-14,一行)⑧删 key 清空 conversations.model_override(S-6 裁决①)。

**P1**:⑨`POST /api/v1/mcp-registry:plan`{name}→{chosenPackage,requiredEnv[],oauth}(安装表单数据源,防前端复刻择包漂移)。

**v2/显式不做**:`GET /system/storage`(全机聚合+perWorkspace 细分,walk 抽共享 util+30s 缓存)· MCP config GET/PATCH(S-2)· `POST /api-keys:probe` 存前验证 · 网络面板 settings.json network 段 · 日志尾读端点=**显式不做**(跨 workspace 泄露面)· factory-reset=**显式不做**(文案指引删 ~/.anselm)。**铁律:api-keys/workspace 偏好变更不上 entities 流**(E1 三条流不加设置帧,settings 操作后前端自 invalidate)。

## 6. 建造切片 S0–S6(每片 DoD 含 demo fixture+真机 E2E)

| 片 | 内容 |
|---|---|
| **S0 地基** | SettingsPrefs(键表+fy.* 迁移)+AnSwitch/AnSegmented/AnSettingRow/AnScopeBadge+壳(目录三段+AnPage+面包屑+SettingsPushPane)+SettingsSearchIndex(面板过滤+三相等门禁)+OS reduce-motion 全局接线 |
| **S1 偏好域** | 通用(无 dark 档)+通知(含 Emit inbox 标记后端件)+对话(sendKey+webFetchMode;autoStage 行等 V8 W1) |
| **S2 模型与密钥** | capabilities provider 搬迁 core 先行(S-15)→受管 DELETE 守卫+provision+version 后端件→免费档卡+key CRUD(S-3/4 状态机)+场景默认(S-6)+AnSecretField/AnMeter |
| **S3 工作区+关于** | stats 端点→列表/新建/改名色/TypeToConfirm 删除(禁删当前)+Phoenix 切换;关于页(version/后端状态 S-12/许可/诊断复制) |
| **S4 记忆+MCP** | 记忆 CRUD+pin;MCP 列表/市场(:plan 端点)/手动/导入/详情三 tab(无编辑无直调) |
| **S5 沙箱+限额+存储** | 沙箱全面;limits schema-driven;存储与日志(重置本地偏好) |
| **S6 快捷键+收尾** | 绑定收编重构+cheatsheet;i18n 专项审查(~300 key×2 locale);搜索二级命中/@modified/knobs 评估进 v2 |

## 7. 测试与验收

五电池(每原语)+集成:settings 改 key→chat 选择器刷新 · token 轮换后无 401 风暴 · workspace 删除全序(Notifier 编排+无脏 id)· fy.* 迁移无残留 · 重置=声明键集全清且即时回落 · 「全部」档无 Broadcast toast · demo fixture 9 面板截图 · 三相等穷尽门禁入 fe-verify。真机 E2E:每片 build→开 app→逐面板交互→截图核对(用户明令)。

## 8. 决策清单(待用户拍板——总路线④时逐条问)

1. **主题默认与 dark 时机**:v1 light+dark 档后置(推荐,S-9);dark 独立 WRK 何时排。
2. **界面语言 vs AI 输出语言分离**:两项分离(推荐:受众不同,app 级 vs workspace 级)vs 单项双写。
3. **通知档位**:三档(全部收件箱/仅需处理/静音,默认仅需处理)推荐;是否要 Linear 式类别×渠道矩阵(存储已留缝)。
4. **快捷键 v1 只读 cheatsheet**(推荐)vs 直上可改绑。
5. **危险区分布式**(各资源页尾,推荐)vs 集中页。
6. **MCP 安装表单数据源**:后端 :plan 端点(推荐)vs 前端复刻择包。
7. **版本与更新 v1**:仅版本+Releases 外链(推荐);auto_updater 随 WRK-043 整体推进。
8. **settings 导航**:provider 先行(推荐)vs 立刻 go_router 子路由。
9. **右岛 autoStage 存放**:app 级(推荐,纯 UI 偏好)——WRK-061 消费方确认。
10. **免费档呈现**:托管卡与 BYOK 分区(推荐)vs 混列。
11. **数据目录**:v1 只读+打开(推荐);可改+搬迁向导单独立项。
12. **恢复出厂**:不做端点、文案指引(推荐)。
13. **窗口几何记忆**:做(推荐,含多显示器 clamp 纪律)。
14. **BYOK 主密钥去向**:现 AES-GCM 落 SQLite;是否升级 OS keychain(flutter_secure_storage 铸 key→env 注入)——立 ADR 后续做(推荐,不阻塞 v1)。
15. **开机自启/托盘**:随 WRK-042 节奏,目录留位不渲(推荐)。
16. **删 key 对会话覆写**:后端顺手清空回落默认(推荐)vs 只 chat 侧引导重选(S-6)。
17. **workspace 切换 v1 Phoenix 整树重启**(推荐,S-10)vs 先建热切换基建(独立前置工程)。
18. **MCP 工具直调**:v2(推荐,S18 安全模型)vs v1 带 danger confirm。
19. **网络代理**:v1 只做 env 透传(推荐)vs 直建 network 面板。
20. **建造切片 S0–S6 顺序**确认(§6)。
