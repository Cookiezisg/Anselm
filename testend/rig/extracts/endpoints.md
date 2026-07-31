EP | POST /api/v1/functions | function | 创建函数（扁平 payload 反推 ops 走构建管线），201
EP | GET /api/v1/functions | function | 函数分页列表（`?search` name 子串过滤）
EP | GET /api/v1/functions/{id} | function | 单读，附 activeVersion（代码+env 状态一趟拿全）
EP | PATCH /api/v1/functions/{id} | function | 改 meta（name/description/tags，不升版本）
EP | DELETE /api/v1/functions/{id} | function | 软删 + 销毁 env + 清边，204
EP | POST /api/v1/functions/{id}:run | function | 同步执行，body `{args, version?}`，返裸结果
EP | POST /api/v1/functions/{id}:revert | function | active 指针移到指定版本号
EP | POST /api/v1/functions/{id}:edit | function | ops 构建新版本（空 ops = 仅重建 env）
EP | POST /api/v1/functions/{id}:iterate | function | 开 AI 编辑对话，202 返 conversation id
EP | GET /api/v1/functions/{id}/versions | function | 版本分页列表
EP | GET /api/v1/functions/{id}/versions/{version} | function | 单版本（接受版本号或 fnv_ id）
EP | GET /api/v1/functions/{id}/executions | function | 执行日志分页 + aggregates
EP | GET /api/v1/function-executions/{id} | function | 单执行详情（含 logs）
EP | POST /api/v1/handlers | handler | 创建 handler（扁平 → ops），201，不 spawn 实例
EP | GET /api/v1/handlers | handler | handler 分页列表（`?search`）
EP | GET /api/v1/handlers/{id} | handler | 单读（附 activeVersion + configState + runtimeState）
EP | PATCH /api/v1/handlers/{id} | handler | 改 meta
EP | DELETE /api/v1/handlers/{id} | handler | 停实例 + 软删 + 销毁 env + 清边，204
EP | POST /api/v1/handlers/{id}:call | handler | 同步调方法，body `{method, args}`，返裸结果
EP | POST /api/v1/handlers/{id}:restart | handler | 手动重启常驻实例，返新 runtimeState
EP | POST /api/v1/handlers/{id}:revert | handler | 移 active 指针 + 重启实例
EP | POST /api/v1/handlers/{id}:edit | handler | ops 构建新版本 + 重启实例
EP | POST /api/v1/handlers/{id}:iterate | handler | 开 AI 编辑对话
EP | GET /api/v1/handlers/{id}/versions | handler | 版本分页列表
EP | GET /api/v1/handlers/{id}/versions/{version} | handler | 单版本（号或 hdv_ id）
EP | GET /api/v1/handlers/{id}/config | handler | 读 config（sensitive 掩码）
EP | PUT /api/v1/handlers/{id}/config | handler | JSON Merge Patch 更新 + 重启实例重跑 `__init__`
EP | DELETE /api/v1/handlers/{id}/config | handler | 清空 config + 停实例
EP | GET /api/v1/handlers/{id}/calls | handler | 调用日志分页 + aggregates
EP | GET /api/v1/handler-calls/{id} | handler | 单调用详情（含 logs）
EP | POST /api/v1/agents | agent | 创建（identity + 全量 Config 快照 = v1），201
EP | GET /api/v1/agents | agent | agent 分页列表（`?search`）
EP | GET /api/v1/agents/{id} | agent | 单读（附 activeVersion）
EP | PATCH /api/v1/agents/{id} | agent | 改 meta
EP | DELETE /api/v1/agents/{id} | agent | 软删 + 清边，204
EP | POST /api/v1/agents/{id}:invoke | agent | 同步跑 ReAct loop，body `{input, version?}`
EP | POST /api/v1/agents/{id}:revert | agent | 移 active 指针
EP | POST /api/v1/agents/{id}:edit | agent | 全量 Config 替换 → 新版本
EP | POST /api/v1/agents/{id}:iterate | agent | 开 AI 编辑对话
EP | GET /api/v1/agents/{id}/mount-health | agent | 按需预检 active 版本各挂载是否可解析
EP | GET /api/v1/agents/{id}/versions | agent | 版本分页列表
EP | GET /api/v1/agents/{id}/versions/{version} | agent | 单版本（号或 agv_ id）
EP | GET /api/v1/agents/{id}/executions | agent | 执行日志分页 + aggregates
EP | GET /api/v1/agent-executions/{id} | agent | 单执行详情（含完整 transcript）
EP | POST /api/v1/workflows | workflow | 创建工作流，201
EP | GET /api/v1/workflows | workflow | 分页列表（`?search`）
EP | GET /api/v1/workflows/{id} | workflow | 单读（附 activeVersion 图）
EP | PATCH /api/v1/workflows/{id} | workflow | 改 meta（含 concurrency 政策），不升版本
EP | DELETE /api/v1/workflows/{id} | workflow | 软删 + 清边，204
EP | POST /api/v1/workflows/{id}:trigger | workflow | 立即跑一次，body `{payload?}`，202 返 flowrun id
EP | POST /api/v1/workflows/{id}:stage | workflow | 待命恰一次真实触发后自动撤防（已 active → 409）
EP | POST /api/v1/workflows/{id}:activate | workflow | 上线：挂监听 + active，返实体快照
EP | POST /api/v1/workflows/{id}:deactivate | workflow | 优雅下线：摘监听 + inactive/draining
EP | POST /api/v1/workflows/{id}:kill | workflow | 硬停：摘监听 + 取消全部在途 run，返实体快照
EP | POST /api/v1/workflows/{id}:edit | workflow | 图 ops 构建新版本
EP | POST /api/v1/workflows/{id}:revert | workflow | 移 active 指针
EP | POST /api/v1/workflows/{id}:capability-check | workflow | ref 解析体检，返 problems + warnings
EP | POST /api/v1/workflows/{id}:iterate | workflow | 开 AI 编辑对话
EP | GET /api/v1/workflows/{id}/versions | workflow | 版本分页列表
EP | GET /api/v1/workflows/{id}/versions/{version} | workflow | 单版本图
EP | GET /api/v1/flowruns | flowrun | 运行历史分页（keyset 或 offset 两互斥模式 + 全套过滤）
EP | POST /api/v1/flowruns | flowrun | 手动起 run，body `{workflowId, entryNode?, payload?}`
EP | GET /api/v1/flowruns/{id} | flowrun | run 头 + 一页节点行（N4 keyset）
EP | GET /api/v1/flowruns/{id}/activity | flowrun | 按 run 聚合的四表执行活动时长投影（keyset）
EP | POST /api/v1/flowruns/{id}:replay | flowrun | 重放失败 run（仅 failed 可重放）
EP | POST /api/v1/flowruns/{id}:cancel | flowrun | 取消单个 running run，202 返 run + 节点首页
EP | GET /api/v1/flowrun-inbox | flowrun | 审批收件箱（全部 parked 节点行 + workflow 上下文 enrich）
EP | GET /api/v1/flowrun-stats | flowrun | 运营统计批查（`?workflowIds&recentN&since&until`），有界 ≤50
EP | GET /api/v1/flowrun-matrix | flowrun | 节点×run 状态格阵批查（`?flowrunIds`），有界 ≤50
EP | POST /api/v1/flowruns/{id}/approvals/{node}:decide | flowrun | 人工审批决策 `{decision, reason?}`，first-wins
EP | POST /api/v1/triggers | trigger | 创建触发器（cron/webhook/fsnotify/sensor）
EP | GET /api/v1/triggers | trigger | 分页列表（带 paused/refCount/listening/lastFiredAt）
EP | GET /api/v1/triggers/{id} | trigger | 单读（同上派生字段）
EP | PATCH /api/v1/triggers/{id} | trigger | Edit：热更监听中的 listener（暂停者不热更）
EP | DELETE /api/v1/triggers/{id} | trigger | 删除触发器 + 注销监听
EP | POST /api/v1/triggers/{id}:fire | trigger | 手动催一次，202 返 activation id（暂停 → 422）
EP | POST /api/v1/triggers/{id}:pause | trigger | 持久暂停 + 源头注销 listener，返裸 trigger
EP | POST /api/v1/triggers/{id}:resume | trigger | 恢复调度并按当前 config 重注册，返裸 trigger
EP | POST /api/v1/triggers/{id}:iterate | trigger | 开 AI 编辑对话
EP | GET /api/v1/triggers/{id}/activations | trigger | 活动审计分页（触没触发都有记录）
EP | GET /api/v1/trigger-activations/{id} | trigger | 单 activation 详情
EP | GET /api/v1/firings | trigger | workspace 级 firing 收件箱分页（`?triggerId&status&窗`）
EP | GET /api/v1/triggers/{id}/firings | trigger | 逐 trigger firing 分页（同一 handler，路径填 filter）
EP | GET /api/v1/trigger-schedule | trigger | 前瞻 cron 调度时间线（`?within&limit`，带 truncated）
EP | ANY /api/v1/webhooks/{triggerId}/{path...} | trigger | webhook 外部入站 catch-all（方法按 trigger config，默认 POST；免 bearer、自带 HMAC）
EP | POST /api/v1/controls | control | 创建 control（路由分支实体），201
EP | GET /api/v1/controls | control | 分页列表
EP | GET /api/v1/controls/{id} | control | 单读（附 activeVersion）
EP | PATCH /api/v1/controls/{id} | control | 改 meta
EP | DELETE /api/v1/controls/{id} | control | 软删 + 清边，204
EP | POST /api/v1/controls/{id}:edit | control | 构建新版本
EP | POST /api/v1/controls/{id}:revert | control | 移 active 指针
EP | POST /api/v1/controls/{id}:iterate | control | 开 AI 编辑对话
EP | GET /api/v1/controls/{id}/versions | control | 版本分页列表
EP | GET /api/v1/controls/{id}/versions/{version} | control | 单版本
EP | POST /api/v1/approvals | approval | 创建 approval（人在环审批实体），201
EP | GET /api/v1/approvals | approval | 分页列表
EP | GET /api/v1/approvals/{id} | approval | 单读（附 activeVersion）
EP | PATCH /api/v1/approvals/{id} | approval | 改 meta
EP | DELETE /api/v1/approvals/{id} | approval | 软删 + 清边，204
EP | POST /api/v1/approvals/{id}:edit | approval | 构建新版本
EP | POST /api/v1/approvals/{id}:revert | approval | 移 active 指针
EP | POST /api/v1/approvals/{id}:iterate | approval | 开 AI 编辑对话
EP | GET /api/v1/approvals/{id}/versions | approval | 版本分页列表
EP | GET /api/v1/approvals/{id}/versions/{version} | approval | 单版本
EP | GET /api/v1/skills | skill | skill 全列（有界不分页，List 省 dir）
EP | POST /api/v1/skills | skill | 新建 skill（严格冲突 + name 须符规范形态）
EP | GET /api/v1/skills/{name} | skill | 单读（附 provenance 与 dir）
EP | PUT /api/v1/skills/{name} | skill | 结构化覆盖（保真读-改-写，frontmatter 键序不丢）
EP | DELETE /api/v1/skills/{name} | skill | 删整目录含捆绑文件，204
EP | POST /api/v1/skills/{name}:activate | skill | 激活：inline 渲染注入 / fork 派 subagent
EP | POST /api/v1/skills/{name}:update | skill | 按 provenance 来源重拉（本地改动非 force → 409）
EP | POST /api/v1/skills/{name}:approve-tools | skill | 打开 allowed-tools 信任门
EP | POST /api/v1/skills:inspect-source | skill | 预览来源可装 skill 清单，不落盘
EP | POST /api/v1/skills:install | skill | 从来源安装 `{source, names?, force?}`
EP | GET /api/v1/skills/{name}/files | skill | 全文件元数据列表（含 SKILL.md，有界不分页）
EP | GET /api/v1/skills/{name}/files/{path...} | skill | 单文件裸字节读（1MB 护栏）
EP | PUT /api/v1/skills/{name}/files/{path...} | skill | 裸字节写入，204（SKILL.md 为带校验整替）
EP | DELETE /api/v1/skills/{name}/files/{path...} | skill | 删附属文件，204（清单拒删）
EP | GET /api/v1/mcp-servers | mcp | server 实时状态列表
EP | GET /api/v1/mcp-servers/{name} | mcp | 单读（状态 + tools 缓存）
EP | PUT /api/v1/mcp-servers/{name} | mcp | 手动装/同名替换（stdio 或 remote；失败仍落盘）
EP | DELETE /api/v1/mcp-servers/{name} | mcp | 卸载 server，204
EP | POST /api/v1/mcp-servers/{name}:reconnect | mcp | 重连重置按钮，返新状态
EP | GET /api/v1/mcp-servers/{name}/stderr | mcp | stdio stderr ring 尾
EP | GET /api/v1/mcp-servers/{name}/calls | mcp | 调用台账分页 + aggregates
EP | POST /api/v1/mcp-servers/{name}/tools/{tool}:invoke | mcp | 直接试调工具（绕过 chat/LLM），返裸结果
EP | POST /api/v1/mcp-servers:import | mcp | 导入 Claude Desktop mcp.json 片段（`?overwrite=`）
EP | GET /api/v1/mcp-calls/{id} | mcp | 单调用详情（含 logs + 失败 stderr 尾）
EP | GET /api/v1/mcp-registry | mcp | curated 市场全列
EP | POST /api/v1/mcp-registry:plan | mcp | 安装表单数据源（选包结果投影，零副作用）
EP | POST /api/v1/mcp-registry:install | mcp | 从市场安装 `{name, env}`
EP | GET /api/v1/documents | document | 直接子节点列表（`?parentId=`，空=根级）
EP | POST /api/v1/documents | document | 创建文档，201
EP | GET /api/v1/documents/tree | document | 整树 metadata（无正文，每行带 hasContent）
EP | GET /api/v1/documents/{id} | document | 单读（含 content）
EP | PATCH /api/v1/documents/{id} | document | 更新文档 meta/正文
EP | DELETE /api/v1/documents/{id} | document | 删除（含子树），204
EP | POST /api/v1/documents/{id}:move | document | 移动（防环；nil parent=根）
EP | POST /api/v1/documents/{id}:duplicate | document | 深拷整子树，201 返新根裸实体
EP | POST /api/v1/documents/{id}:iterate | document | 开 AI 编辑对话
EP | POST /api/v1/conversations | conversation | 创建对话
EP | GET /api/v1/conversations | conversation | 列表（`?search&archived&sort&workDir&pinned`）
EP | GET /api/v1/conversations/{id} | conversation | 单读（含 isGenerating/awaitingInput/hasUnread）
EP | PATCH /api/v1/conversations/{id} | conversation | 改 meta（ModelOverride 三态 + workDir）
EP | DELETE /api/v1/conversations/{id} | conversation | 软删 + 级联清边与触点台账，204
EP | GET /api/v1/conversations/workdir-groups | conversation | 驻地分组投影（零参数有界，分列 active/archived 计数）
EP | POST /api/v1/conversations:archive-workdir | conversation | 驻地组批量归档 `{workDir}`，返改变条数
EP | POST /api/v1/conversations:delete-workdir | conversation | 驻地组批量删除 `{workDir}`，跨归档态
EP | GET /api/v1/conversations/{id}/workdir | conversation | 驻地投影（现算 path/exists/git/branches/worktrees）
EP | POST /api/v1/conversations/{id}/workdir:switch-branch | conversation | 切本地分支（脏区拒 422），返重探 WorkDirInfo
EP | POST /api/v1/conversations/{id}/workdir:create-branch | conversation | 从 HEAD 建分支（不受脏区门），返 WorkDirInfo
EP | POST /api/v1/conversations/{id}/workdir:add-worktree | conversation | 建 worktree 一条龙 `{name}` 并自动切驻地
EP | POST /api/v1/conversations/{id}/messages | chat | Send：落 user 回合 + 开 assistant 回合，202 返 msg id
EP | GET /api/v1/conversations/{id}/messages | chat | 回合历史三读形态（`?cursor` / `?around` / `?dir=newer`）
EP | POST /api/v1/conversations/{id}:cancel | chat | 取消在途生成，204
EP | POST /api/v1/conversations/{id}:seen | chat | 清 hasUnread（幂等），204
EP | POST /api/v1/conversations/{id}:fork | chat | 分叉线程到新对话，201 返新对话全行
EP | POST /api/v1/conversations/{id}:retry | chat | 末回合换新版本（重生成 / 编辑重发），202 返新 msg id
EP | GET /api/v1/conversations/{id}/system-prompt-preview | chat | system prompt 调试预览
EP | GET /api/v1/conversations/{id}/usage | chat | token 用量
EP | GET /api/v1/conversations/{id}/interactions | chat | 待决人机交互重同步
EP | POST /api/v1/conversations/{id}/interactions/{toolCallId} | chat | 决议交互 `{action, answer?}`，204
EP | GET /api/v1/conversations/{id}/anchors | chat | 场次条导航锚点 keyset 分页
EP | GET /api/v1/conversations/{conversationId}/todos | todo | 对话工作清单（有界不分页）
EP | GET /api/v1/conversations/{conversationId}/touchpoints | touchpoint | 对话触点台账 keyset 分页（`?kind&verb`）
EP | GET /api/v1/sandbox/runtimes | sandbox | 已装运行时列表
EP | GET /api/v1/sandbox/runtimes/available | sandbox | 可装语言运行时 + 默认/钉死版本
EP | POST /api/v1/sandbox/runtimes | sandbox | 安装运行时
EP | DELETE /api/v1/sandbox/runtimes/{id} | sandbox | 卸载运行时
EP | GET /api/v1/sandbox/envs | sandbox | env 列表（有界）
EP | GET /api/v1/sandbox/envs/{id} | sandbox | 单 env 详情
EP | DELETE /api/v1/sandbox/envs/{id} | sandbox | 销毁 env
EP | GET /api/v1/sandbox/disk-usage | sandbox | 沙箱磁盘占用
EP | GET /api/v1/sandbox/bootstrap-status | sandbox | 引导状态
EP | POST /api/v1/sandbox:gc | sandbox | 垃圾回收孤儿 env
EP | POST /api/v1/sandbox:retry-bootstrap | sandbox | 重试引导
EP | GET /api/v1/conversations/{id}/sandbox-envs | sandbox | 对话级 scratch env 列表
EP | POST /api/v1/conversations/{id}/sandbox-envs/{kind}:reset | sandbox | 销毁该对话某 kind 的 scratch env，204
EP | POST /api/v1/conversations/{id}/sandbox-envs:reset-all | sandbox | 销毁该对话全部 scratch env
EP | POST /api/v1/attachments | attachment | 上传附件（返行 + 可选 preparation）
EP | GET /api/v1/attachments/{id} | attachment | 附件 metadata（含 preparation 状态）
EP | GET /api/v1/attachments/{id}/content | attachment | 附件内容字节
EP | POST /api/v1/attachments/{id}/playback-lease | attachment | audio 短期 loopback 播放租约，返 `{url,expiresAt}`
EP | GET /api/v1/attachment-playback/{token} | attachment | bearerless 短租约 fetch（支持 Range/seek）
EP | POST /api/v1/attachments/{id}/preparation/cancel | attachment | 取消进行中的媒体准备（canCancel 时）
EP | POST /api/v1/attachments/{id}/preparation/retry | attachment | 重试失败的媒体准备（canRetry 时）
EP | DELETE /api/v1/attachments/{id} | attachment | 删除附件
EP | GET /api/v1/memories | memory | memory 全列（有界不分页）
EP | GET /api/v1/memories/{name} | memory | 单读（name 即 id）
EP | PUT /api/v1/memories/{name} | memory | Upsert
EP | DELETE /api/v1/memories/{name} | memory | 删除
EP | POST /api/v1/memories/{name}/pin | memory | 置顶
EP | POST /api/v1/memories/{name}/unpin | memory | 取消置顶
EP | GET /api/v1/search | search | 综搜/垂搜同端点（`?q&types&tags&窗&cursor&limit`）
EP | POST /api/v1/search:reindex | search | 就地重建本 workspace 索引，204（并发调 409）
EP | GET /api/v1/search/settings | search | 机器级搜索设置 + 引擎实时状态
EP | PATCH /api/v1/search/settings | search | 修补搜索设置（embedder/ollama 参数）
EP | GET /api/v1/workspaces | workspace | workspace 全列（有界不分页）
EP | POST /api/v1/workspaces | workspace | 创建 workspace（触发异步免费档开通）
EP | GET /api/v1/workspaces/{id} | workspace | 单读
EP | PATCH /api/v1/workspaces/{id} | workspace | 改 meta（含 webFetchMode）
EP | DELETE /api/v1/workspaces/{id} | workspace | 删除（守最后一个）
EP | GET /api/v1/workspaces/{id}/stats | workspace | 删除确认的内容盘点（含 blobBytes，超时 -1）
EP | PUT /api/v1/workspaces/{id}/default-models/{scenario} | workspace | 设某场景默认模型（校 apiKeyId 存在性 + native options）
EP | DELETE /api/v1/workspaces/{id}/default-models/{scenario} | workspace | 清该场景默认模型
EP | PUT /api/v1/workspaces/{id}/default-search | workspace | 设默认搜索 key
EP | DELETE /api/v1/workspaces/{id}/default-search | workspace | 清默认搜索 key
EP | POST /api/v1/workspaces/{id}:activate | workspace | 刷 lastUsedAt
EP | POST /api/v1/api-keys | apikey | 建 key（白名单 provider，dev 才含 mock）
EP | GET /api/v1/api-keys | apikey | key 列表
EP | PATCH /api/v1/api-keys/{id} | apikey | 改 key（受管行 422 `API_KEY_IMMUTABLE`）
EP | DELETE /api/v1/api-keys/{id} | apikey | 删 key（受管行 422；被引用挡 `API_KEY_IN_USE`）
EP | POST /api/v1/api-keys/{id}:test | apikey | probe 探测该 key 可用性
EP | GET /api/v1/providers | apikey | provider 白名单列表（每项带 managed 标记）
EP | GET /api/v1/freetier/quota | freetier | 免费档本月配额代理（无受管行 404）
EP | POST /api/v1/freetier:provision | freetier | 手动重开通/修复（幂等），返 `{provisioned}`
EP | GET /api/v1/speech/asr | speech | 本机 ASR WebSocket sidecar（16k PCM + 控制帧）
EP | GET /api/v1/voices | voice | 音色库存列表（enroll_voice 登记的参考音色;库存上限闸,不是钱的闸）
EP | DELETE /api/v1/voices/{id} | voice | 删除已登记音色（网关侧句柄随之失效）
EP | GET /api/v1/read-aloud/availability | read-aloud | 朗读可用性 `{available}`
EP | POST /api/v1/read-aloud:read | read-aloud | 合成朗读，返附件引用 + `cached`（不经 LLM）
EP | GET /api/v1/model-capabilities | model | 模型能力目录（有界不分页）
EP | GET /api/v1/scenarios | model | 场景枚举（dialogue/utility/agent + image/speech/video）
EP | GET /api/v1/relations | relation | 关系边列表
EP | GET /api/v1/relations/neighborhood | relation | 某实体邻域子图
EP | GET /api/v1/relgraph | relation | 全关系图
EP | GET /api/v1/catalog | catalog | 目录/模板清单
EP | GET /api/v1/tools | tools | 可授权内置工具目录 `{name, summary}`（有界不分页）
EP | GET /api/v1/limits | limits | 机器级活动运行上限
EP | GET /api/v1/limits/schema | limits | 逐字段 default/min/max/unit/desc 元数据
EP | PATCH /api/v1/limits | limits | 部分合并更新并热换（越界 400）
EP | POST /api/v1/limits:reset | limits | 恢复服务端 Default() 并热换
EP | GET /api/v1/health | system | liveness 探针（免 workspace，不免 bearer）
EP | GET /api/v1/version | system | 构建版本 `{version}`（免 workspace）
EP | GET /api/v1/system/data-dir | system | 解析后的数据目录 `{dataDir}`
EP | GET /api/v1/network | system | 出站代理配置读
EP | PATCH /api/v1/network | system | 出站代理配置整体替换并应用 env
EP | GET /api/v1/retention | system | run 保留天数（恒具体值，默认 90）
EP | PATCH /api/v1/retention | system | 部分合并保留策略并踢一趟清理（0=永久）
EP | GET /api/v1/storage-stat | storage | 库 + 附件两存储字节盘点（零参数单对象）
EP | POST /api/v1/storage:compact | storage | 同步全量 VACUUM，200 返 `{reclaimedBytes,migrated}`
EP | GET /api/v1/notifications | notification | 通知 keyset 分页（最新在前）
EP | GET /api/v1/notifications/unread-count | notification | 未读计数（徽标对账源）
EP | POST /api/v1/notifications/{id}:mark-read | notification | 单条标已读
EP | POST /api/v1/notifications:mark-all-read | notification | 批量标已读（可选 `{after?,before?}` 半开窗）
EP | POST /api/v1/notifications:mark-all-unread | notification | 批量标未读（mark-all-read 镜像），204
EP | POST /api/v1/executions/{id}:triage | aispawn | 按 execId 前缀开 AI 诊断对话，202 返 conversation id
EP | GET /api/v1/messages/stream | stream(SSE) | 聊天消息 SSE 流（open→delta*→close）
EP | GET /api/v1/entities/stream | stream(SSE) | 实体面板活动 SSE 流（含 ephemeral Signal）
EP | GET /api/v1/notifications/stream | stream(SSE) | 通知 SSE 流
EP | GET /debug/pprof/ | debug(dev-only) | pprof Index 子树（goroutine/heap/allocs/block…）
EP | GET /debug/pprof/cmdline | debug(dev-only) | 进程命令行
EP | GET /debug/pprof/profile | debug(dev-only) | CPU profile
EP | GET /debug/pprof/symbol | debug(dev-only) | 符号解析
EP | GET /debug/pprof/trace | debug(dev-only) | 执行 trace
EP | GET /debug/stats | debug(dev-only) | 运行时快照 JSON（goroutines/heap/GC…）

TOTAL: 257

（0731 对照新 main 重校:transport 层路由真 diff **恰 +2**——`GET /voices` 与 `DELETE /voices/{id}`,零删除;
workflow `:deactivate` 语义澄清为「run 与已接受 pending firing 双双排空才 inactive」,端点形状不变。)

DRIFT(0728 抓到四处;0731 对照重排后的新 api.md:三处已被另一团队独立修掉——preparation 两端点已列
〔api.md:257-258〕、三条 SSE 流已有登记行、「免费档永不供视频」死句已由 91b8eeea 订正;**webhook catch-all
仍缺登记**,0731 已再次 `[doc-fix]` 补进 api.md trigger 节:`ANY /webhooks/{triggerId}/{path...}`。)

补充（非 drift，供清册使用）：`{idAction}` 类模式在代码里是单条 mux 注册 + switch 派发，上表已按实际接受的动词逐条展开；派发器与动词对照 —— function `run|revert|edit|iterate`、handler `call|restart|revert|edit|iterate`、agent `invoke|revert|edit|iterate`、workflow `edit|revert|trigger|stage|activate|deactivate|kill|capability-check|iterate`、control/approval `edit|revert|iterate`、document `iterate|move|duplicate`、trigger `fire|pause|resume|iterate`、chat `cancel|seen|fork|retry`、flowrun `replay|cancel` + approvals `decide`、skill `activate|update|approve-tools`、mcp server `reconnect` / tool `invoke`、workspace `activate`、apikey `test`、notification `mark-read`、executions `triage`、sandbox conv-env `reset`。未列于此的动词一律 404。