# 提取①·工具全集(0728 基线,0731 对照新 main 重校)· TOTAL 124
# 0731 重校法:活后端 GET /tools 全集(117,与基线逐字同)+ 代码枚举逐请求 resident
# (search_tools + 生成族 6)。差异恰为生成族 +3:edit_image / animate_image / enroll_voice
# (「改图/图生视频/参考音色」桌面半,生成全部收归受管后仍是 CapabilityTools 缝注入)。

TOOL | Read | filesystem | 读文件,cat -n 格式,默认前 2000 行,offset+limit 分页
TOOL | Write | filesystem | 原子写文件(覆盖需本对话先 Read 过),父目录须存在
TOOL | Edit | filesystem | 文件内精确字面串替换(非正则),须先 Read
TOOL | LS | search | 列目录直接内容(非递归),目录优先
TOOL | Glob | search | glob 模式找文件(支持 ** 递归),按 mtime 倒序
TOOL | Grep | search | ripgrep 正则内容检索,三种输出模式
TOOL | Bash | shell | 执行 shell 命令,支持 run_in_background
TOOL | BashOutput | shell | 拉取后台 Bash 新增输出+状态
TOOL | KillShell | shell | 按 bash_id 终止后台 Bash(幂等)
TOOL | ask_user | ask | 向用户提问并阻塞等待(humanloop broker)
TOOL | todo_write | todo | 整体覆盖写本对话任务清单
TOOL | todo_read | todo | 读回当前任务清单含已完成项
TOOL | search_tools | toolset | 按能力检索并激活 lazy 工具
TOOL | search_function | function | 关键词+语义检索 function 库
TOOL | get_function | function | 取 function 活跃版本全貌
TOOL | create_function | function | ops 构建新 Python function,v1 立即生效;公开为数组,窄兼容有效 JSON 编码数组字符串及 set_inputs/set_outputs 无歧义字段 map/全 required JSON-Schema 并在校验前还原,CSV/歧义/坏字符串拒绝
TOOL | edit_function | function | 活跃版本叠 ops 出新版本;公开为数组,窄兼容有效 JSON 编码数组字符串及 set_inputs/set_outputs 无歧义字段 map/全 required JSON-Schema 并在校验前还原,CSV/歧义/坏字符串拒绝
TOOL | revert_function | function | 活跃指针切到已有版本号
TOOL | delete_function | function | 静态危险下限=dangerous,模型自报 safe 也必须过 HumanLoop 人闸;软删 function 主行并回收 sandbox;不可逆版本历史保留供审计,主实体与动作随后 not-found
TOOL | update_function_meta | function | 仅改 name/description/tags
TOOL | run_function | function | 关键字参数运行,返回 ok/output/logs
TOOL | search_function_executions | function | 分页检索执行历史
TOOL | get_function_execution | function | 取单条执行记录
TOOL | search_handler | handler | 检索 handler 库；调用方法用 call_handler，修改 init 配置用 update_handler_config
TOOL | get_handler | handler | 取活跃版本+配置态+运行态
TOOL | create_handler | handler | 新建有状态常驻 Python 类
TOOL | edit_handler | handler | 叠 ops 新版本并重启实例
TOOL | revert_handler | handler | 切版本并重启实例
TOOL | delete_handler | handler | 静态危险下限=dangerous,模型自报 safe 也必须过 HumanLoop 人闸;停实例并软删主行;回执含 retention(handler/versions/sandbox/actions);版本历史保留供审计,环境尽力回收,关系边清理;主实体与动作随后 not-found
TOOL | call_handler | handler | 只调用已声明的常驻实例方法；顶层 config 不属于此工具，修改 init 配置用 update_handler_config
TOOL | update_handler_config | handler | 唯一的 init-args 配置工具；Merge Patch 后重启；兼容解码后仍为对象的 JSON 字符串，数组/非法字符串/根级 null 拒绝
TOOL | update_handler_meta | handler | 仅改 meta,不重启
TOOL | restart_handler | handler | 优雅关停+新实例
TOOL | search_handler_calls | handler | 列调用历史；支持 cursor/limit 分页，limit 接受 JSON 整数或精确十进制字符串
TOOL | get_handler_call | handler | 取单条调用记录
TOOL | search_agent | agent | 按关键词+语义检索 agent；自然语言可纯语义召回，含下划线/分隔符/数字的 ID/key 形 query 必须有词法证据，空 query 列出全部
TOOL | get_agent | agent | 取 agent 活跃版本完整配置
TOOL | create_agent | agent | 新建配置式 LLM worker
TOOL | edit_agent | agent | 局部编辑,未传字段保持
TOOL | revert_agent | agent | 回退活跃版本
TOOL | delete_agent | agent | 静态危险下限=dangerous,模型自报 safe 也必须过 HumanLoop 人闸;软删,保留执行历史,active configuration 不可恢复
TOOL | update_agent_meta | agent | 仅改行 meta
TOOL | invoke_agent | agent | 跑 agent ReAct 循环,按 outputSchema 成形
TOOL | search_agent_executions | agent | 检索轻量运行历史（分页 cursor 必须原样复制,列表不带 transcript）
TOOL | get_agent_execution | agent | 取单条执行全记录
TOOL | search_control | control | 检索 control
TOOL | get_control | control | 取活跃版本分支集
TOOL | create_control | control | 新建路由分支表实体
TOOL | edit_control | control | 全量替换分支集新版本
TOOL | revert_control | control | 切版本指针
TOOL | delete_control | control | 静态危险下限=dangerous,模型自报 safe 也必须过 HumanLoop 人闸;删全版本,不可逆
TOOL | search_approval | approval | 检索 approval 表单
TOOL | get_approval | approval | 取活跃版本(模板+timeout 等)
TOOL | create_approval | approval | 新建 approval 表单实体
TOOL | edit_approval | approval | 全量替换新版本
TOOL | revert_approval | approval | 切版本指针
TOOL | delete_approval | approval | 静态危险下限=dangerous,模型自报 safe 也必须过 HumanLoop 人闸;软删主行、清关系、版本历史保留,主行不可恢复
TOOL | search_workflow | workflow | 直接关键词优先、无直接命中时补语义;返回 tags/生命周期态/active
TOOL | get_workflow | workflow | 取活跃图+生命周期+并发策略
TOOL | create_workflow | workflow | ops 构图,v1 初始 deactivated;LLM schema 与 ValidateInput 均强制显式 description/tags/changeReason 槽位(无值传空);用户值原样放顶层;窄兼容托管模型数组字符串(含 tags)、add_node/add_edge 顶层 body 变体、nodes+edges 图快照(type/triggerId→kind/ref)与已观察的 add_node nodeId/kind=trigger/triggerId 简写(未知/冲突仍拒绝),逗号分隔文本仍拒绝
TOOL | edit_workflow | workflow | 叠 ops 出新版本
TOOL | revert_workflow | workflow | 切图版本指针;version 公开 integer,执行边界兼容精确整数字符串;workflowId+version 同次调用,失败不重试;新版本保留历史
TOOL | delete_workflow | workflow | 静态危险下限=dangerous,模型自报 safe 也必须过 HumanLoop 人闸且不可被 skill/approve_always 绕过;软删主行并停自动化;canonical 参数 workflowId(兼容 hosted model 的精确 id 别名,冲突拒绝),拒绝 file_path/old_string/new_string 等文件编辑字段;CallIdentity 按目标 workflow 收窄,参数修正不得为同一破坏性意图重开人闸;主行不可恢复且无 restore 操作;版本/flowrun 历史保留供审计;回执含 restorable=false,historyRetained=true;参数先于危险人闸校验
TOOL | capability_check_workflow | workflow | 校验图健全+引用实体可用;回执始终带 problems/warnings 数组(空时为[]),ok 只受结构与阻断问题影响,warning 仅提示
TOOL | trigger_workflow | workflow | 自供 payload 手动跑一次;不改 listener/不走 overlap policy;回 flowrunId+workflowId;payload 必须符合入口 fire-payload shape(webhook 用户数据在 body),执行边界兼容同一 object 的 JSON 字符串编码,数组/数字/畸形字符串拒绝
TOOL | stage_workflow | workflow | 布防:下次真实触发跑一次即解除;成功回执带staged/workflowId/workflowName/lifecycleState/active,保持inactive
TOOL | activate_workflow | workflow | 上线持续监听;成功回执带workflowId/workflowName/lifecycleState=active/active=true
TOOL | deactivate_workflow | workflow | 优雅下线,在飞跑完;回执带workflowId/workflowName/lifecycleState(active/inactive/draining)/active
TOOL | kill_workflow | workflow | 硬停+取消在飞;回执带workflowId/workflowName/lifecycleState=inactive/active=false/killed
TOOL | get_flowrun | workflow | 严格使用flowrunId字段(不是file_path/id/workflowId);取运行头+节点记录+可解析时workflowName(身份仍是flowrun.workflowId);≤80行全量,大/循环run保留全部非completed与最新尾部至80并带真实总数nodeSummary;全量经GET /api/v1/flowruns/{id}分页
TOOL | search_flowruns | workflow | 列运行,可限定 workflow;limit接受原生整数或精确十进制整数字符串,浮点/布尔/数组/任意字符串拒绝
TOOL | replay_flowrun | workflow | 断点重跑失败运行
TOOL | list_approval_inbox | workflow | 列全工作区待决审批
TOOL | decide_approval | workflow | 先用list_approval_inbox发现parked行,逐字复制flowrunId+nodeId后批/拒;yes/no+可选reason;first-wins,后续决定/超时no-op;回更新run+nodes
TOOL | search_triggers | trigger | 按 query（兼容 hosted model 的 pattern 别名）检索 trigger，直接 name/description/kind 命中优先于语义邻居，含 listener 在线态；未知/畸形搜索键不得静默退化为全量列出
TOOL | get_trigger | trigger | 取 kind/配置/运行态
TOOL | create_trigger | trigger | 新建信号源;config 兼容原生对象或精确 JSON 字符串,数组/标量/坏字符串拒绝;sensor output map 稳定归一化为 CEL
TOOL | edit_trigger | trigger | 改 name/description/config(kind 不可变);config 同样兼容原生对象或精确 JSON 字符串;sensor output map 与 create 同源归一化,省略/null 不改配置
TOOL | delete_trigger | trigger | 静态危险下限=dangerous,模型自报 safe 也必须过 HumanLoop 人闸;门禁本体说明 stop listener/主行不可恢复/history 保留/relation edges purge;软删主行,停 listener,清关系,activation/firing 历史保留,主行不可恢复
TOOL | fire_trigger | trigger | 手动触发一次演练扇出;只合成 {manual:true},真实走 firing inbox/overlap 策略并回 activationId;暂停返回 TRIGGER_PAUSED,不可用 edit_trigger 清除 paused,必须经 Resume 控件或 :resume 后再 fire
TOOL | search_activations | trigger | 查动作日志(触没触发都记);每行 firingCount=该次 activation 扇出的 workflow 数,不是历史累计次数;payload.manual=true 表示手动 fire 绕过 sensor condition,不是条件通过证据;支持 firedOnly/cursor/limit;托管模型发出的精确字符串布尔/十进制 limit 窄兼容,浮点/任意字符串/数组拒绝
TOOL | get_activation | trigger | 精确读取单条 activation 审计记录;必须逐字复制 opaque activationId(不是 triggerId,不省略参数);返回 id/triggerId/kind/fired/returnValue/payload/error/detail/firingCount/createdAt 原值,正文占位时指向相邻 activation 卡片
TOOL | search_firings | trigger | 查扇出收件箱逐 workflow 处置(status=started/pending/skipped/superseded/shed);必须逐字复制 opaque triggerId,不是 name/pattern/placeholder,不知道 id 先 search_triggers;支持 cursor/limit,limit 接受原生整数或精确十进制字符串,浮点/任意字符串/数组拒绝
TOOL | search_documents | document | 文档库关键词检索（query；非文件系统 path/pattern）；托管 provider 若误发显式 path/pattern 形状则非空 pattern/path 只作为文档 query、两者皆空返回一页有界文档列表，绝不读文件系统；返回正文/标题 snippet 与 durable path/description/tags、total/nextCursor（仅截断时出现）；无 nextCursor 即完整，匹配到 ID 后直接使用；用同一 query 原样携 cursor 续页
TOOL | list_documents | document | 枚举已知父节点的 Notion 式直接子节点;按 sibling position 做 cursor 分页(默认50,最大200);返回本页 count/同父 total/complete/hasMore,有更多时返 nextCursor;必须逐字携 cursor,不能从 count 或全局上限猜完整性;同回合相同 parentId/cursor/limit 已返回后不得重复;用 search_documents 做关键词检索
TOOL | read_document | document | 载入完整 markdown 正文
TOOL | create_document | document | 建文档,可嵌套; name/description/content/tags 每次调用(包括首次)必填,未提供后三者传空字符串/空数组;用户值同一调用原样带上;禁止name-only placeholder/先create再edit或同父同名重复mutation
TOOL | edit_document | document | 一次请求一个 canonical call,更新字段,content/tags 全量替换,tags 必须是 JSON 字符串数组（仅兼容多包一层的合法 JSON 数组字符串）
TOOL | move_document | document | 重挂父节点+兄弟序,跨父压缩旧/新 sibling 且路径级联;position 接受原生非负整数或托管调用者的严格十进制整数字符串,拒绝浮点/布尔/数组/任意字符串;自身/后代循环为该精确文档/父节点组合的终局拒绝,本回合不重复调用
TOOL | delete_document | document | 静态危险下限=cautious;软删整棵子树,墓碑可恢复;缺失ID为completed软失败,界面不得显示成功删除
TOOL | list_attachments | attachment | 按新到旧列 workspace 上传文件 metadata(id/filename/mime/kind/sizeBytes/createdAt),createdAt 是精确 ISO-8601 上传时点;不读 blob;文本/文档下一步 read_attachment,媒体下一步 inspect_media
TOOL | read_attachment | attachment | 按 canonical `id` 读取文本/文档类附件正文（受管模型误发 `attachmentId` 时兼容归一化；大文本支持 index/offset/limitChars/query，媒体返回描述符并指向 inspect_media）
TOOL | inspect_media | attachment | 用 user 回合 `<uploaded_attachments_for_tools>` 中的精确 attachmentId 取有界媒体证据;禁止复制 schema 示例值;图走有界视觉/crop 或 tiles,文本/文档走本地 query/page/offset,音视频只回 metadata+时间范围,不伪造 transcript/OCR/scene
TOOL | read_memory | memory | 按名载入记忆正文
TOOL | write_memory | memory | 存跨对话持久事实(重名原地更新)
TOOL | forget_memory | memory | 不可逆删除记忆;始终 dangerous 并需用户 approval;删除 Markdown 后无 restore 操作,重复调用诚实返回 already gone
TOOL | get_model_config | model | 报工作区模型配置
TOOL | list_mcp_marketplace | mcp | 浏览 MCP 市场
TOOL | install_mcp_server | mcp | 安装 MCP server+env
TOOL | uninstall_mcp_server | mcp | 卸载:停进程删配置
TOOL | reconnect_mcp | mcp | 重启已装 server 连接
TOOL | search_mcp_calls | mcp | 列工具调用历史
TOOL | get_mcp_call | mcp | 取单条调用记录
TOOL | activate_skill | skill | 激活:载入指令+占位符替换
TOOL | get_skill | skill | 读完整内容不激活
TOOL | create_skill | skill | 撰写新 skill
TOOL | edit_skill | skill | 全量覆写 SKILL.md
TOOL | delete_skill | skill | 静态危险下限=dangerous,模型自报 safe 也必须过 HumanLoop 人闸;永久删除目录,不可恢复
TOOL | run_skill_script | skill | 沙箱跑 skill 自带脚本
TOOL | Subagent | subagent | 派发隔离子 agent(Explore/Plan/general-purpose)
TOOL | get_subagent_trace | subagent | 读回 subagent 隐藏 trace
TOOL | search_conversations | conversation | 混合检索历史对话
TOOL | list_conversations | conversation | 枚举对话按活跃排序
TOOL | manage_conversation | conversation | 归档/置顶/重命名当前对话
TOOL | search_blocks | blocks | 检索可接线 workflow 积木
TOOL | get_relations | relation | 查实体关系邻域(uses/used-by)
TOOL | WebFetch | web | 抓 URL 并 LLM 摘要
TOOL | WebSearch | web | 联网搜索
TOOL | generate_image | generate | 文生图,落附件返回 receipt
TOOL | generate_speech | generate | 文合成语音,落音频附件
TOOL | generate_video | generate | 文生视频(同步,最贵)
TOOL | edit_image | generate | 改既有图:attachmentId+指令("改成夜晚"),生成模型原生改图,落新附件返回 receipt
TOOL | animate_image | generate | 图生视频:attachmentId+运动 prompt("缓推近"),受管两次请求形(签名句柄),落视频附件
TOOL | enroll_voice | generate | 参考音色登记:干净音频附件(≤30s 单说话人)+名字→音色库存,后续 generate_speech 可指名

## 分区事实(验收路径决定项)
- Resident 12(filesystem3+search3+shell3+ask_user+todo2);其余 109 Lazy 须 search_tools/自动激活。
- 动态族:mcp__<server>__<tool> 逐请求注入 / agent mount 族(仅 invoke_agent 内部面,随实体改名) / sys: 挂载使 generate 三件在 agent 面二次出现。
- 条件注入:generate 三件按路由可用性诚实缺席;run_skill_script 需沙箱;inspect_media 需 resolver。
- subagent 裁剪:Subagent/get_subagent_trace 恒剔除;Explore={Read,LS,Glob,Grep};Plan=+{WebFetch,WebSearch};general-purpose=全集-2。
- skill allowed-tools 用户数据驱动,不可枚举;skill 不进 search_tools 投影。
