SURF | shell/startup-gate | screen | 后端 phase 门控面:连接中 / 崩溃可重试 / 就绪显壳,整 app 单点。
SURF | shell/workspace-gate | screen | 冷启动工作区名册解析中的「准备工作区」面,扣住 Router。
SURF | shell/workspace-onboarding | screen | 零工作区单页创建面:左 Rijksmuseum 画作 + 右恒宽 460 决策列 + 真 AnComposer。
SURF | shell/ocean-switcher | rail | 左岛顶部四海洋图标钮 + matched-geometry 滑动药丸,settings 时无选中。
SURF | shell/sidebar-footer | rail | 左岛底栏:workspace 快捷菜单 + 设置格 + 通知格(红点)。
SURF | shell/ocean-breadcrumb-head | screen | 海洋浮层头 44px 透明带:reopen 钮 + OceanBreadcrumb 标题 + panel-right 钮。
SURF | shell/notice-band | screen | 顶带消息舞台:AnNoticeCapsule / AnApprovalCapsule 居中 + 右缘队列尾巴。
SURF | shell/notification-tray | rail | 铃接管左岛中段:搜索 + ⚙ + 今天/昨天/更早三时段可折叠组。
SURF | shell/flowrun-inbox | rail | 铃托盘顶部「待你处理」审批带:parked 卡 + Approve/Reject。
SURF | chat/landing | screen | 无选区新对话面:静态问候 h2 + 居中浮起 composer,首发建线程并导航。
SURF | chat/transcript | screen | `/chat/:id` 对话正文流 + 停靠 composer,按会话 key 换台。
SURF | chat/composer | screen | 停靠输入器:附件/@ mention/工作目录钮/git 动作/发送键两档。
SURF | chat/toc | screen | 场次条:全量 keyset 分页锚点列,任意深度不静默截断。
SURF | chat/log-drawer | screen | 共享日志抽屉:计行标签 + 双端截断 + 全量复制 + MCP stderr 分段。
SURF | chat/run-dossier | screen | 一次执行的完整审计卷宗:状态徽 + 溯源 + I/O 机器窗 + 日志抽屉。
SURF | chat/nested-run-pane | screen | Subagent/invoke_agent 卡下的 live E3 嵌套轨迹窗。
SURF | chat/tool-cards | screen | 对话流内联工具卡族(exec/search/todo/trigger/workflow/subagent 等 20+ 皮肤)。
SURF | chat/rail-pinned | rail | 置顶段:跨 residency 的全部 pinned 线程,pin 优先。
SURF | chat/rail-residency | rail | 每个 workDir 一段:目录名即段名,折叠段零取数。
SURF | chat/rail-recents | rail | 不属任何目录的线程,按活动/创建/名称排序。
SURF | chat/rail-states | rail | rail 四态:骨架 / 错误+重试 / 空 / 列表。
SURF | chat/sidestage | inspector | 右岛侧幕 StagePanel:todo 顶行 + 活动委派层 + 落定 Cast 时间三档 + 载更多。
SURF | entities/overview | screen | `/entities` 默认总览:五计数牌 + 关系图预览 + 最近更新 5 行。
SURF | entities/graph | screen | `/entities/graph` 全屏无边框关系图探索态:满幅涟漪焦点星图 + kind 图例过滤。
SURF | entities/detail | screen | `/entities/:kind/:id` 单一 AnPage 文档:OceanHeader + AnTabs(flow) + 720 阅读列同滚。
SURF | entities/tab-overview | screen | 概览 tab:各 kind 量身(function 代码收合 / workflow 图 hero / trigger 四源模板)。
SURF | entities/tab-versions | screen | 版本 tab:全宽粘性手风琴,行内 diff 卡 + 结构化摘要 + 设为活跃版本。
SURF | entities/tab-logs | screen | 日志 tab:ok/failed 聚合 + AnRowDetail 行展开 + loadMore。
SURF | entities/tab-runs | screen | workflow 运行驾驶舱:AnRunBoard + 节点甘特 + run 态图 + 内联节点调试。
SURF | entities/tab-activity | screen | trigger 活动 tab:activations 触发面,firedOnly 过滤。
SURF | entities/tab-dispatch | screen | trigger 派发 tab:firings 运行面,status 过滤 pending/started/skipped/superseded/shed。
SURF | entities/workflow-editor | screen | `/entities/workflow/:id/editor` 全屏无边框图编辑器:满铺画布 + 浮层药丸 chrome。
SURF | entities/rail-overview-row | rail | rail 顶部固定「总览」无头行,无选中即高亮。
SURF | entities/rail-function | rail | Function 折叠段(可执行 Quadrinity)。
SURF | entities/rail-handler | rail | Handler 折叠段,行状态点=运行态。
SURF | entities/rail-agent | rail | Agent 折叠段。
SURF | entities/rail-workflow | rail | Workflow 折叠段,状态点=生命周期/attention。
SURF | entities/rail-control | rail | Control 支撑段(无调试台)。
SURF | entities/rail-approval | rail | Approval 支撑段(运行时第二张脸在铃托盘)。
SURF | entities/rail-trigger | rail | Trigger 支撑段,listener 热→蓝点,头部持 Fire CTA。
SURF | entities/run-terminal | inspector | 右岛实体调试台 v3 JSON-first:身份头 + 速览带 + 编辑器卡 + 工具条 + 最近执行条 + 落定条。
SURF | entities/workflow-editor-inspector | inspector | 图编辑器可收右岛:节点 kind/ref 分层选择器/input 映射/retry/边 port,未选=空态。
SURF | entities/graph-entity-card | inspector | 探索态右岛实体卡:kind 字形 + vN + 描述 + 关系分组 + 打开详情。
SURF | library/draft | screen | 无选区被动着陆草稿编辑器:四空态灰引导,首次编辑才 POST 并认领 id 不重挂。
SURF | library/document | screen | `/documents/:id` AnDocumentEditor 同滚页:头 sliver(面包屑/H1/描述/tags) + AnEditor sliver。
SURF | library/skill-manifest | screen | `/documents/skill/:name` 清单页:标题不可改名、PUT 全覆盖、⋯ 切源码模式。
SURF | library/skill-file-preview | screen | `?file=<rel>` 文件预览族:md 富文本 / 代码 / 图片 / SVG / CSV / 字体 / 信息卡 + 逃生口。
SURF | library/rail-documents | rail | Documents 递归页面树段:全 CRUD + hover [+][⋯] + 拖拽重排 + 空/已写 icon。
SURF | library/rail-skills | rail | Skills 扁平 slug 列段,行 id 加 `skill:` 前缀防撞。
SURF | library/inspector-doc | inspector | 文档右岛:身份头 + 速览带 + 三折叠组(大纲 / 属性 / 反链)。
SURF | library/inspector-skill | inspector | skill 右岛:文件树组(含绑定) → 属性组(表单/allowed-tools 选择器) → 来源组 → 大纲组。
SURF | scheduler/overview | screen | `/scheduler` 全局看板:KPI 牌 → 调度时间轴 → 等你处理 → 正在跑 → 失败聚合,零数据整页教育卡。
SURF | scheduler/workflow-home | screen | `/scheduler/w/:id` 运营主页四段:健康头 → 矩阵区 → run 大表(行内速览卡) → triggers 陈列。
SURF | scheduler/run-flagship | screen | `/scheduler/w/:id/runs/:frId` 单 run 旗舰:卷宗头 + 钉版图 + 甘特 + 台账,一个 URL 选区。
SURF | scheduler/run-relay | screen | `/scheduler/runs/:frId` 仅 id 中转位:解析宿主 workflow 后交棒旗舰。
SURF | scheduler/rail-overview-row | rail | 固定首行 Overview,右缘等人计数徽=rail 唯一数字。
SURF | scheduler/rail-main | rail | 无头主段:曾运行过的 workflow,活动排序 + 单值 meta(运行中/下次点火/上次)。
SURF | scheduler/rail-never-ran | rail | 沉底初始折叠段「未运行 (n)」。
SURF | scheduler/rail-inactive | rail | 再沉一段「停用 (n)」,灰不占状态点位。
SURF | scheduler/run-inspector-dossier | inspector | 右岛无选中脸=运行卷宗:钉结论 + replay 史 + 入口 payload + 全文错误 + :triage。
SURF | scheduler/run-inspector-node | inspector | 右岛选中节点脸=检查器:迭代切换 + 错误 + I/O 树 + 日志深链 + 就地人闸/重放。
SURF | settings/rail-prefs | rail | 目录段「偏好」:通用 / 通知 / 对话。
SURF | settings/rail-resources | rail | 目录段「资源」:模型与密钥 / MCP 服务器 / 记忆 / 沙箱。
SURF | settings/rail-system | rail | 目录段「系统」:工作区 / 存储与日志 / 高级限额 / 网络 / 快捷键 / 关于。
SURF | settings/rail-search | rail | 同一输入框双视图:空查询=三段目录,有查询=设置项级命中列表。
SURF | settings/panel-general | panel | 通用:主题三档 + 缩放六档 + 字体三轴 + 语言双写 + 记住窗口 + 开机自启 + 自动检查更新。
SURF | settings/panel-notifications | panel | 通知:三档级别 + OS/应用内两开关 + 失败崩溃/待审批/需关注三类登记。
SURF | settings/panel-chat | panel | 对话:右岛自动登台三档 + 发送键两档 + webFetchMode + 默认对话模型跳转行。
SURF | settings/panel-models-keys | panel | 模型与密钥(0731 重形):受管免费档卡 + **音色库存卡**(克隆音色 2 槽:列表/删除/「库存不是配额」文案,仅受管档) + 品牌 logo 密钥行 + 场景默认三行(ModelPickerPanel) + **供应商选择器照 MCP 市场文法**(173 家一次铺开、searchProviders 收窄、unverified/chat-only 徽标、模型计数、Vertex service-account JSON 字段、base URL 模板占位提示、诊断三句〔baseUrlSuspect 等〕)。
SURF | core/media-viewer | overlay | 媒体放大察看器(0731 新增,WRK-082 B1 人眼验收逼出):图/视频同一 RawDialogRoute chrome(scrim/关闭/Esc/障幕点击/文件名题注),视频带完整走带(播放/暂停/进度/重播);卡族渲染处(chat/flowrun 检查器/实体台/文档编辑器)点击即达,一处文法四处同义。
SURF | settings/panel-mcp | panel | MCP 服务器:空态即市场 + 已装双列品牌卡 + 详情三 tab(工具/调用/stderr) + 手动添加/导入/市场。
SURF | settings/panel-memory | panel | 记忆:名册 + 搜索 + 行内金 pin toggle + 新建记忆推入编辑 + 确认物理删除。
SURF | settings/panel-sandbox | panel | 沙箱:健康门 + 磁盘占用诚实字节 + 运行时装删(五 owner tab) + GC 两步。
SURF | settings/panel-workspaces | panel | 工作区:色点名册(点行热切换) + 新建 AnComposer + 推入编辑(改名/六色/危险区输名删)。
SURF | settings/panel-storage | panel | 存储与日志:数据目录 + 磁盘占用 + 诊断 + Run 历史保留 + 数据库压缩 + 重置偏好 + 出厂重置。
SURF | settings/panel-limits | panel | 高级限额:`GET /limits/schema` 驱动的 group + 字段行,部分嵌套 PATCH + 越界回滚。
SURF | settings/panel-network | panel | 网络:http/https/no_proxy 三字段 + 整体替换 PATCH + 重启注记 AnCallout。
SURF | settings/panel-shortcuts | panel | 快捷键:6 全局命令逐行小帽,点帽录键 + 冲突拒绝 + 单项/全部重置。
SURF | settings/panel-about | panel | 关于:版本区 + 检查更新(GitHub Releases 三面) + 引擎版本 + 诊断 + 字体致谢。
SURF | settings/detail-push | screen | 推入第三级(13 kind):addKey/editKey/sandboxInstall/mcpServer/mcpAdd/mcpImport/mcpMarket/mcpInstall/addMemory/memory/addWorkspace/workspace。
SURF | i18n/chat | i18n-group | 683 键:对话海洋全部文案(rail/composer/侧幕/工具卡/turn 动作)。
SURF | i18n/settings | i18n-group | 399 键:13 面板 + 三段目录 + 搜索 + 三域徽全部文案。
SURF | i18n/entities | i18n-group | 302 键:实体海洋 rail/详情/tab/调试台/关系图文案。
SURF | i18n/scheduler | i18n-group | 246 键:调度海洋 rail/Overview/运营主页/run 旗舰文案。
SURF | i18n/library | i18n-group | 125 键:文库海洋 rail/编辑器/skill 表单/右岛三组文案。
SURF | i18n/notifications | i18n-group | 45 键:通知托盘标题/时段组/批量标记/搜索/显示选项。
SURF | i18n/run | i18n-group | 41 键:运行结果、重放、审批等待、flowrun 节点计数文案。
SURF | i18n/feedback | i18n-group | 36 键:信息/成功/警告/错误/确认删除/加载/步骤/标签增删。
SURF | i18n/a11y | i18n-group | 26 键:屏幕阅读器标签(旗标/编辑字段/更多动作/图缩放)。
SURF | i18n/attach | i18n-group | 21 键:附件不可用/重试/上传中/媒体准备失败/取消准备。
SURF | i18n/shell | i18n-group | 14 键:侧栏收展/切面板/海洋/即将推出/设置/通知/工作区回退。
SURF | i18n/ref | i18n-group | 11 键:11 种 ref 药丸类型名(function/handler/workflow/agent/document/conversation/skill/mcp/trigger/control/approval)。
SURF | i18n/coldStart | i18n-group | 11 键:onboarding 预览/连接中/创建工作区/名称冲突/画作致谢。
SURF | i18n/action | i18n-group | 8 键:编辑/取消/保存/复制/展开/收起/换行/删除通用动词。
SURF | i18n/diff | i18n-group | 7 键:新增/删除/折叠/显示全部/只显变更。
SURF | i18n/startup | i18n-group | 6 键:启动门控连接中/崩溃/重试/错误面文案。
SURF | i18n/graph | i18n-group | 6 键:图节点 kind 词。
SURF | i18n/status | i18n-group | 5 键:idle/run/wait/err/done 五状态词。
SURF | i18n/tree | i18n-group | 3 键:JSON 树非法/循环/更多项。
SURF | i18n/appName | i18n-group | 1 键:产品名 wordmark。
SURF | i18n/markdown | i18n-group | 1 键:图片加载失败提示。
SURF | stage/function | stage | 地层 → OpTicker 三态点 → 活代码窗 → 落定真 diff 徽(before=冻结基线)。
SURF | stage/document | stage | 书脊 + 前缀快进 + R-9 元数据卡 + `[[id]]` 内联药丸解真名。
SURF | stage/workflow | stage | 真画布图生长 + 判别式抽屉;edit ops 在旧图重放,落定对账新鲜真相。
SURF | stage/control | stage | 丝线决策梯 + 透传幽灵 + 否则徽。
SURF | stage/approval | stage | 信笺 + 琥珀插值 + timeout 人话;失败面红标「创建失败·残稿如下」。
SURF | stage/trigger | stage | 四脸(cron/webhook/fsnotify/sensor) + R-16 落定只信 GET + nextFireAt 分钟活钟。
SURF | stage/subagent | stage | 一席一卡:任务名=args.prompt 首行 + ReAct 尾 + 结算双源 + 内联终端活窗 ≤10 行。
SURF | stage/handler | stage | 方法架:set_init_args_schema 键=args,update_method RFC-7396 合并上架,timeout 渲钟词。
SURF | stage/agent | stage | prompt/tools/knowledge/model 四槽全铺,未触槽回全墨,落定 prompt 有界视口内滚。
SURF | stage/skill | stage | 装订台 + allowedTools 琥珀仅在信任门已批时 + $ 占位槽。
SURF | stage/memory | stage | 记忆笺,图钉 REST-only。
SURF | stage/mcp | stage | 接线现场 + 工具货架(仅 install/reconnect/create 的类型化 tools 列表)。
SURF | stage/generic | stage | 第 13 座通用舞台兜底(诚实丝带 + kind 量身体 + poll 型活运行卷);conversation 无舞台、attachment 走展品座。
TOTAL: 114

(0731 对照新 main 重校:frontend/lib 真 diff——新增 core/media-viewer 一面;models-keys 面重形(供应商选择器 MCP 市场文法 + 音色库存卡 + Vertex service-account)已就地重述;chat_head/chat_transcript 为执行反馈保留的小改不成新面。i18n 侧发现孤儿键组 spend.*(支出卡已随直连支出台账拆除,键未清)——非本战役辖区,已交独立工单。)