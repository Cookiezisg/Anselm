EDGE | 上下文水位 80% 触发 tool_result 换 marker | loop | 单对话灌入大量长 tool_result 直到预测 prompt 达 80% input budget | 保留最新 3 组完整 tool_result 与全部 reasoning/tool_call，更旧的换成可重取 prompt-only marker，durable block 不改写
EDGE | continuation checkpoint 语义压缩 | loop | 清旧 tool_result 后仍超 80%，逼引擎把旧前缀折成结构化 checkpoint | 目标降到 55%，checkpoint 协议完整（不留悬空 tool_call）
EDGE | 语义压缩失败落确定性有损 checkpoint | loop | 让 utility 与主模型两条压缩路径都失败（mock 返错） | 回落到明确标注「有损、需 re-fetch」的确定性 checkpoint，回合不炸
EDGE | 权威 context_length 透明恢复 | loop | 让 provider 在尚未产出任何 block 时返结构化 `UPSTREAM_REJECTED.reason=context_length` | 清旧结果、压缩、重试同一逻辑 step ≤2 次，成功则用户完全看不到失败
EDGE | CONTEXT_INPUT_TOO_LARGE 终态 | loop | 自动恢复后最新一条不可再分的输入（超大附件）仍被 provider 拒 | 回合终态 error + `CONTEXT_INPUT_TOO_LARGE`，提示拆分最新附件/内容
EDGE | DeepSeek active tool chain 切割 | loop | 在 deepseek 路由上压缩一条含 reasoning_content + tool_calls 的长链 | 按完整 assistant / tool group 边界切，绝不产生孤儿 tool 协议
EDGE | 工具错误风暴熔断 | loop | 脚本让模型连续 3 轮每个 tool_result 都带 error | `TOOL_ERROR_STORM` 终止回合，UI 可解释、不无限钻牛角尖
EDGE | MaxSteps 耗尽 | loop | 把 `limits.Agent.MaxSteps` 调到 2 并让模型持续要动工具 | stop_reason=max_steps + error_code `MAX_STEPS_REACHED`，非成功终态、UI 给「继续」
EDGE | 回合总墙钟兜底 | chat | 把 `ChatTurnSec` 调到几秒 + 用一个卡住的工具（不响应的 MCP） | 回合被墙钟切断落终态，isGenerating 复位、不阻塞 graceful shutdown
EDGE | tool_result 256KiB 硬封顶 | loop | 跑一个不带 head_limit 的巨量 Grep 或话痨 MCP 工具 | 保头部 + 附收窄提示，落库/SSE/prompt 三处都不被打爆
EDGE | 执行组并行下标写入 | loop | 让模型一轮内发多个同 `execution_group` 的工具调用 | goroutine 并发跑、按调用序拍平 block，无乱序无竞态
EDGE | danger 非枚举值 fail-open | loop | 让模型把 `danger` 填成 `"none"` 或省略 | 回落 `safe` 不设闸（fail-open），与 fspath fail-closed 相反
EDGE | ObjectMap 字符串化对象参数 | loop | 让模型把 `run_function.args` 送成 `"{\"points\":6}"` 字符串 | 接受并解出对象；解出数组/数字/非 JSON 仍报错
EDGE | MediaExpander 当轮回喂 | loop | 让 `generate_image` 或 MCP 工具在一步内产出 MediaRef | 以一条追加 user 消息把原生 content part 喂给后续请求，持久历史不写这条
EDGE | MCP 非纯 JSON 结果里的 receipt | loop | 让 MCP 返 `[image: …]\n{…receipt…}` 这种「一段话 + receipt」 | 逐 `{` 试解嵌入对象，媒体仍到达模型（只认整串 JSON 会一个像素都到不了）
EDGE | 生成族产地过滤 | loop | 让 `generate_image` 的 tool_result 被 MediaExpander 收集 | 只回 receipt 不回字节（ADR 0017），且只在 loop 的 tool_result 这一侧否决
EDGE | deepseek 全文本 parts 坍缩 | llm | 在 deepseek 路由上发一条附件被降级成文本占位的 user 回合 | Parts 以 `\n\n` join 坍缩回字符串 content，避免该对话每回合永久 400
EDGE | sanitizer 孤儿 tool_call 补 stub | llm | 取消一个正在派发工具的回合后再续聊 | 发送前给孤儿 tool_call 合成 stub 回复，严格 provider 不 400
EDGE | 危险工具人闸阻塞 | loop | 让模型自报 `danger=dangerous`（含花真钱的生成调用） | dispatchWithGate 阻塞等人批，interaction 信号推流、broker pending 表是真相
EDGE | approve_always 会话白名单 | chat | 对同一 (对话, 工具) 先 approve_always，再触发第二次同工具危险调用 | 第二次直接放行不再问
EDGE | 白名单随对话删除清除 | chat | approve_always 后删除该对话 | `ForgetConversation` 钩子整批清掉，授权不越过删除泄漏在内存
EDGE | 驻地越界写人闸 | loop | 挂驻地的对话里让模型 `Write` 一个驻地子树外的绝对路径 | 无视自报等级强制设闸，载荷多一个 `outsideWorkDir:true`；`approve_always`/skill allowed-tools 均不可豁免
EDGE | 越界判定路径解不开 | loop | 让 `Write` 的 args 畸形或无路径字段 | 落回普通 danger 闸（而非静默放行），Execute 自己再拒
EDGE | 驻地只闸写不闸读 | loop | 挂驻地后让模型 Read/Grep 驻地外绝对路径 | 直接放行、绝不设闸（zoom 非牢）
EDGE | skill 信任门未批时预授权为空 | skill | 装一个 installed skill 但不 `:approve-tools`，再激活它 | 正文注入、active skill 记名，但 allowed-tools 预授权集为空、危险调用照走逐次确认
EDGE | allowed-tools 变更重置信任门 | skill | 对已授权的 installed skill 跑 `:update` 且新版改了 allowed-tools | 信任门重置回未授权；未变则授权延续
EDGE | ask_user 无交互用户 | loop | 在 agent invoke / workflow 节点（无 broker）路径上触发 `ask_user` | 503 `ASK_NO_INTERACTIVE_USER`，提示继续而不阻塞
EDGE | interaction 枚举外 action | chat | POST resolve-interaction 传 `"aprove"` 拼错 | 先于 broker 查找 422 `INTERACTION_INVALID_ACTION` + `details.validActions`，绝不静默当 deny
EDGE | 重复 resolve interaction | chat | 同一 toolCallId 连发两次决议 | 第二次 404 `NO_PENDING_INTERACTION`，幂等安全
EDGE | 生成中再 Send | chat | 回合流式期间再 POST 一条消息 | 409 `STREAM_IN_PROGRESS`，不排队
EDGE | 回合收尾期单槽缓冲 | chat | 在压缩检查（可达秒级 LLM 调用）窗口内 Send | 落进单槽缓冲紧随其后被服务；槽已满仍 409
EDGE | convQueue 5 分钟自毁后重建 | chat | 让对话空闲 >5min 再发消息 | 队列拆卸后按需重建，task 不滞留死 channel
EDGE | 关页不留 streaming 孤儿 | chat | 回合流式中直接关闭客户端/取消请求 | WriteFinalize 在 Detached ctx 落 blocks + message_stop
EDGE | 硬崩溃孤儿回合清扫 | chat | kill -9 后端于流式回合中途，再启动 | boot `SweepOrphans` 逐 workspace 把 pending/streaming 行扫成 cancelled
EDGE | 自动标题双预算 | chat | 让标题生成占满 10s `autoTitleTimeout` 后再落盘 | 落盘另取从 detached 新 derive 的 5s 预算，慢步不饿死写入
EDGE | 只发生过一轮的对话标题丢失 | chat | 让首轮 autoTitle 生成成功但落盘失败，且不再发第二轮 | 线程永远叫「New chat」（已知诚实边界，下一轮才补）
EDGE | 归档对话发消息自动解档 | chat | 给 archived 线程 POST 消息 | 隐式 unarchive 后照常接收，软失败不挡消息
EDGE | :retry 重生成分支 | chat | 对末回合 POST `:retry` 空 body | supersede 末 assistant、不写新 user 回合、入既有队列重跑
EDGE | :retry 编辑重发分支 | chat | POST `:retry` 带 `content` | supersede 末 user + 其 assistant 两条，新 user 回合保留原附件 id、刻意不带 @ 提及快照
EDGE | superseded 指针只挡 LLM 视图 | messages | retry 后用三种 REST 读形态与 `?around=` 读旧版本行 | 旧行照常返回可寻址；只有 `LoadThreadForLLM` 按 `superseded_by=''` 过滤
EDGE | retryOf 在 close 快照里 | chat | 用第二个客户端在 open 帧之后才连上（或 410 后 replay） | 仅凭 message_stop 的 close 快照即可重建版本链，绝不渲成多出来的一轮
EDGE | retry 尾巴是无回答的 user 行 | chat | 崩溃清扫后线程尾巴是一条没有 assistant 的 user 行，再 `:retry` | 「重生成」自然降级为「把缺的那个回答产出来」
EDGE | retry 写序中断留重复问句 | chat | 在「落新行」与「supersede 旧行」之间杀掉进程 | 屏幕上出现看得见的重复问句（自我修正），绝不从模型视图删掉一次交流
EDGE | retry 非终态尾巴 | chat | 硬崩溃留下 pending/streaming 尾行后立刻 `:retry` | 409 `STREAM_IN_PROGRESS`（耐久状态与内存队列两处门都读）
EDGE | retry 的 modelOverride 逐回合 | chat | `:retry` 带 modelOverride 后再看对话头 | 只作用于本回合、绝不回写 `conversations.model_override`，行的 provider/model_id 记真实产出者
EDGE | fork summary 水位重定基 | chat | 对一条已压缩过的线程在水位**之后**的消息处 `:fork` | 带走 summary 且水位重定基为被折叠 block 中最大的新 seq
EDGE | fork 切在水位之前不带 summary | chat | 在 `summary_covers_up_to_seq` 之前的消息处 fork | summary 与水位都不带（否则摘要描述分叉根本没有的历史）
EDGE | fork 版本指针 remap | chat | 对一条重试过的线程 fork | `superseded_by` 与 `attrs.retryOf` 双双 remap；被窗切掉的取代者留零值（该行即现行版）、悬空 retryOf 丢弃
EDGE | fork parent_block_id 跨消息 remap | chat | fork 一条含 subagent 子树的线程 | 预铸全部新 block id 后再灌行，subagent block 仍挂在其父 tool_call 下
EDGE | fork 血缘源被删 | conversation | fork 后删除源对话 | 两列 id 悬空、UI 只是不显血缘行，无级联无外键
EDGE | 压缩水位幂等键 | contextmgr | 在写 summary 与翻 archived 标记之间杀进程再启动 | 水位是幂等键，重跑不重复计数、不二次折叠
EDGE | 压缩读过滤被取代回合 | contextmgr | 让一个被 retry 掉的回答落进压缩窗口 | 压缩读丢掉被取代版本，否则它会经 summary 回流进此后每次 prompt
EDGE | demote 只动 tool_result | contextmgr | 单个 assistant 回合内堆很长的工具链后回合收尾 | 全线程 tool_result 按新旧降 hot→warm→cold，用户原话与大粘贴不截断
EDGE | 附件跨压缩水位 | contextmgr | 让含附件的旧回合被折进 summary | 持久附件 id 写入摘要，后续只能经 `read_attachment` 重读、不编造媒体细节
EDGE | 最近 2 条 message 的 durable 底线 | contextmgr | 构造一条只有两条消息但都极长的线程 | durable summarize 不越过最近 2 条，loop 仍可在 prompt 投影内做 checkpoint
EDGE | SSE 410 SEQ_TOO_OLD 重放 | stream | 断开某条流足够久（或灌满 replay 环）后带旧 `Last-Event-ID` 重连 | 410 Gone + `SEQ_TOO_OLD`，客户端全量重拉再续
EDGE | 续传游标三来源 | stream | 分别用 `Last-Event-ID` 头、`?fromSeq`、以及缺/坏值重连 | 头优先 > 查询参 > 缺/坏一律 0（仅实时、不重放）
EDGE | durable buffer 满断开卡死订阅者 | stream | 造一个只连不读的 SSE 订阅者并灌 durable 帧到 `bufSize+256` | 发布方关它的 done、幂等断开，不让一个卡死客户端堵死整工作区扇出
EDGE | ephemeral delta 丢弃不背压 | stream | 让 token 级 delta 打满慢订阅者 | seq=0 帧不入环、订阅者满即丢，绝不卡生产者
EDGE | lifecycleResync 六处配对 | frontend | 制造 notifications 流 410 缺口 | chat rail / 对话头 / 实体列表 / 实体详情 / library 树 / skill 列表六处各自订阅自己那条流的 resync 并重取
EDGE | transcriptResync 不可与 lifecycleResync 互顶 | frontend | 制造 messages 流缺口而 notifications 流完好 | 只有 transcriptResync 能救活态点，两条流的 resync 不互相替代
EDGE | overlap serial 推迟 | scheduler | 让 workflow(serial) 有一个在途 run，再打第二次真触发 | 新 firing 留 pending，下个 5s tick 再试，绝不并发
EDGE | overlap skip 丢弃 | scheduler | 同上但策略设 skip | firing 标 `skipped`（中性「未执行」桶、不染红），不建 run
EDGE | overlap buffer_one 收敛 | scheduler | 在途 run 期间连打三次触发（策略 buffer_one） | 更早的 pending 全标 `superseded`，只留最新一条
EDGE | overlap replace 抢占 | scheduler | 在途 run 期间再触发（策略 replace） | 先 race-safe 取消在途 run（标 cancelled + 打断 advance）再跑新 firing；被顶替 run 的连败计数不受影响
EDGE | overlap allow_all 并发 | scheduler | 高频触发 allow_all workflow | 多 run 并发跑，池 N=4 封顶子进程扇出
EDGE | 手动 :trigger 绕过 overlap | scheduler | 策略设 replace/buffer_one，连点两次 `:trigger` 或 `trigger_workflow` | 两个手动 run 同时在途（人明确点一次、无去重）
EDGE | 两阶段 drain 背靠背触发 | scheduler | 让同一 workflow 的两条 firing 落在同一 tick 的同一批 | phase-1 顺序 claim+seed 全批、phase-2 才 advance，故 skip/replace/buffer_one 对背靠背触发真生效
EDGE | ClaimFiring 事务崩溃回滚 | scheduler | 在 claim+建 run 头+seed 的单事务中途杀进程 | firing 仍 pending，绝无 claimed-但-无-run 的半成品残留
EDGE | approval 人工 vs 超时 first-wins | approval | 让 approval timeout 恰好在人点批准的同一瞬到期 | `ResolveParkedNode` 条件更新首写赢，人工输家 422 `FLOWRUN_APPROVAL_NOT_PARKED`
EDGE | approval 三种超时行为 | approval | 分别配 timeoutBehavior=reject/approve/fail 并等到期 | 各自走 no 分支 / yes 分支 / 让 run 失败
EDGE | approval 显式零时长 | approval | create 时填 `timeout:"0s"` | 422 `APPROVAL_INVALID_TIMEOUT`（会永 park 却不触发；用 `""` 表永不）
EDGE | approval 版本 resolve 失败 | approval | 让收件箱行的钉死 approval 版本解析不出来 | 仅该行缺 `deadline` 键，行本身保持可见可决策
EDGE | run 取消竞态输家 | scheduler | 对一个正在自然落定的 run 打 `:cancel` | 头守卫裁决，输家 422 `FLOWRUN_NOT_CANCELLABLE`、不发第二帧 `run_terminal`
EDGE | 取消赢家收割 parked 审批 | scheduler | 取消一个持 parked 审批节点的 running run | 仅赢家 `CancelParkedNodes` 把 parked 写成 `cancelled`（不是 failed），收件箱不留死项
EDGE | 收割闸破了会造永久停滞子图 | scheduler | 人为让 first-wins 输家也收割（回归验证） | 「有行、却未 completed」挡住重排与全部下游边，`:replay` 也清不掉——必须只在 won 上收割
EDGE | 被打断的在飞节点不落行 | scheduler | 在一个卡在 LLM 流式/长工具的节点上取消 run | `nodeInterrupted` 伪状态、不写任何行、不发 tick、不误写 failed
EDGE | 崩溃恢复 Recover | scheduler | 让 running run 处于半途时 kill -9，再启动 | boot 对每个 running run 入队（非内联）再调一遍 Advance，completed 行被抄不重跑
EDGE | 恢复后排队戳是新起点 | scheduler | 崩溃恢复一个曾排队的节点 | `ready_at` = 恢复驱动的 walk 时刻，绝不回填伪装无缝
EDGE | :replay 只收 failed | scheduler | 对一个 cancelled run 打 `:replay` | 422 `FLOWRUN_NOT_REPLAYABLE`（cancelled 是终局终态）
EDGE | 并发 :replay 守卫 | scheduler | 同一 failed run 同时打两次 `:replay` | `WHERE status='failed'` 守卫使输家匹配 0 行 → 422，赢家的 replay_count 恰好正确
EDGE | replay 与保留清理竞速 | scheduler | 让保留清理正要删某终态 run 时打 `:replay` | 删头时重申终态守卫，`:replay` 赢、清理输
EDGE | MaxIterations 栅栏 | scheduler | 写一个 CEL guard 永真的回边循环 | 至多 1001 条循环体行（iteration 0 是前向入口 + 1000 条回边轮）后停
EDGE | 菱形 join 未守 has() | workflow | 造一个读 `X.field` 而 X 在 control 另一分支的汇合节点，跑不选 X 的分支 | 运行时 `no such key` 炸（capability_check 只查结构 ancestor、刻意不阻断）——作者责任
EDGE | pin 闭包冻结在途 run | scheduler | run 跑到一半时编辑被引用的 function/agent/control | 在途 run 仍跑 pin 住的版本；handler/mcp 活态绑定不受 pin 约束
EDGE | advClosing 关停不跑缓冲 run | scheduler | 队列里堆着 run 时发 SIGTERM | 先置 advClosing、缓冲 run 跳过不执行、保持 Running 待下次 boot Recover
EDGE | sendJob 撞已关队列 | scheduler | 让 feeder 在 `StopPool` 的 `close(queue)` 之后 mid-send | recover 兜住 panic、丢弃该入队、清去重槽，绝不崩进程
EDGE | per-run 单飞 + redrive | scheduler | 对同一 run 并发触发多次 advance | 至多一个 goroutine 在跑，其余置 redrive 标志；ctx 取消后停止再走
EDGE | draining 最后一个 run 结算 | workflow | 有在途 run 时 `:deactivate`，等最后一个 run 落定（或对它 `:cancel`） | draining→inactive 收口，取消也算结算
EDGE | run 历史保留清理 | scheduler | 把 `runRetentionDays` 调到 1 天并造一批老终态 run | 删头 + 节点行 + 该 run 的四张审计表行；running/parked 永不删；firing/通知/触点留存成悬挂引用
EDGE | 保留清理后的孤儿深链 | frontend | 点一条 firing/通知里指向已被清理 run 的 flowrunId | 深链 404、呈现端渲孤儿墓碑（诚实后果）
EDGE | 磁盘回收闸 | infra/db | 保留清理真删了行后观察文件大小 | 死空间 ≥25% 或 ≥128MiB 才 `incremental_vacuum`，日常 churn 不折腾文件
EDGE | 手动 VACUUM 压缩失败 | storage | 在磁盘接近满时点「压缩数据库」 | 500 `STORAGE_COMPACT_FAILED`，库不动、可重试
EDGE | mode=0 老库升级 | infra/db | 用 auto_vacuum 顺序修复之前建的 dogfood 库跑 `:compact` | 顺带升级到 INCREMENTAL、零丢行、`migrated=true`
EDGE | flowrun-stats 倒挂窗 | scheduler | 传 `until` ≤ `since` | 静默给出空窗结果，不是错误
EDGE | flowrun-matrix 未知 id | scheduler | 传入异 workspace / 不存在的 flowrunIds | 静默缺席（cols 自带键可发现），全未知返三个空列表
EDGE | matrix 多迭代最坏处置 | scheduler | 造一个第 3 轮 failed、第 5 轮 completed 的 loop 节点 | 格取最坏 `failed`（不是最后一轮）；cancelled run 上也能诚实渲一个红格
EDGE | activity 排队段负值 | scheduler | 对一个 `:replay` 过的 run 读 `/activity` | 旧审计尝试行可早于新真相行 readyAt，呈现端把排队段钳制 ≥0
EDGE | flowruns 两种分页互斥 | scheduler | 同时给 `?cursor` 与 `?offset` | 422 `FLOWRUN_LIST_CURSOR_OFFSET_CONFLICT`，绝不静默择一
EDGE | LLM 工具 flowrun 节点封顶 | workflow | 让 `get_flowrun` 打在一个数千行的长 loop run 上 | 封顶 80 节点（保全部非 completed + 最近尾巴）+ `nodeSummary` 指向 REST 取全量
EDGE | misfire 记账不补跑 | trigger | 后端停机跨过若干 cron 刻度后启动 | 每个错过刻度落一条 `missed` firing（created_at 回拨到刻度本身），绝不补跑
EDGE | 睡眠期 misfire（进程仍活） | trigger | 让笔记本睡一小时再醒（进程未重启） | 1min ticker 的 SweepMisfires 发现并记账，无重启也不漏
EDGE | 窗口上界留容差尾带 | trigger | 让一个刻度恰落在 now 前 2min 的 `MisfireTolerance` 尾带内 | 本趟不记 missed（否则占掉 dedup 键让真 fire 无 firing 可跑），下趟 sweep 再记
EDGE | hotSince 下界 | trigger | 重启后立刻打开面板问「我错过什么了」 | 重启自己错过的刻度立刻入账（hotSince 及之前的刻度已死），不等两分钟
EDGE | AttachReplay 零值纪元 | trigger | boot 重放挂载 vs 运行中 0→1 实时挂载 | 前者盖零值纪元故为其记停机缺口；后者盖 now、绝不记挂载前的账
EDGE | 暂停期间的错过不算 misfire | trigger | 暂停一个 cron trigger 数小时后 `:resume` | 窗被闭合但不产生任何 missed 行（暂停是用户意志、非事故）
EDGE | catchup_one 补一个 | trigger | 配 `misfirePolicy:catchup_one` 后停机跨多个刻度再启动 | 只对本趟真落账的最近一个刻度补跑（`RequeueMissedFiring` 翻回 pending），更早的仍是 missed
EDGE | catchup_one 崩溃窗不重跑 | trigger | 在扇出已提交、水位未推进之间杀进程再启 | 已入账刻度（dedup 命中）不许再补，绝不把同一刻度跑第二遍
EDGE | misfire 台账双封顶 | trigger | 用 `* * * * *` 的 trigger 跨一周关机后启动 | 每 trigger 单趟至多 200 条（留最近的）+ 遍历封 30d，水位仍跳到窗口上界不重走
EDGE | 睡醒伪 fire 吸附/丢弃 | trigger | 让 robfig 在睡醒时补送一次过期回调 | `snapTick` 吸附到 2min 内最近刻度；无此刻度即判墙钟跳变丢弃（绝不隐式补跑）
EDGE | AppendFiring 撞键返已存在行 | trigger | 让同一刻度在 missed 已记后又真 fire | 按返回行 status 分流：missed 经 Requeue 救回 pending 并计数，终态行不许 firingCount +1
EDGE | shed 孤儿 firing | trigger | 在 firing pending 期间删掉监听它的 workflow | claim 时见 `WORKFLOW_NOT_FOUND` 即终态 shed，不留 pending 让每 tick 重试
EDGE | sensor 电平触发风暴 | trigger | 让 sensor 条件持续为真跨多个 poll 周期 | 每 poll 都 fire 一条新 firing（非边沿），alert-storm 由 workflow 并发策略兜
EDGE | trigger 暂停在源头注销 | trigger | `:pause` 一个 cron/webhook/fsnotify/sensor trigger | cron 摘 entry / webhook 路径 404 / fs watch 停 / 探测停；在飞报告被 onReport 丢弃
EDGE | 暂停时 :fire 大声拒 | trigger | 对已暂停 trigger 打 `:fire` 或 `fire_trigger` | 422 `TRIGGER_PAUSED`，agent 与 UI 都绕不过用户的暂停
EDGE | resume 的 Register 失败回滚 | trigger | 让 source 在 `:resume` 时拒绝起来（端口占用/路径不存在） | 持久开关翻回 paused=true、错误上抛，可再按一次重试（绝不留 paused=false + 冷 listener）
EDGE | Edit 与 :pause 并发 | trigger | agent 在改 trigger 的同时用户按 ⏸ | Edit 走定点 UPDATE 只写 name/desc/config/outputs，绝不整行 upsert 弹回 paused 与 misfire 水位
EDGE | 暂停期间的 Edit 何时生效 | trigger | 暂停 → Edit 改 cron 表达式 → `:resume` | 暂停期不热更，resume 用当前 config 重注册
EDGE | webhook 路径改后旧路径 | trigger | Edit 改 `config.path` 后打旧 URL | catch-all registry miss → 404（mux 永不增长、无 per-trigger 注册）
EDGE | webhook HMAC 不匹配 | trigger | 配 `signatureAlgo:hmac-sha256-hex` 后发错签名 | 401 纯文本响应（不走标准 envelope）
EDGE | webhook 分钟桶去重 | trigger | 一秒内重放同一 body 三次，下一分钟再发一次 | 秒级网络重试折叠成一条；下一分钟同 payload 照常触发
EDGE | fsnotify 秒桶去重 | trigger | 用编辑器保存一次（产生事件突发） | path+op+秒桶折叠成一条 firing，eventKind 归一为配置词汇小写
EDGE | 暂停时 nextFireAt 缺席 | trigger | 读一个已暂停 cron trigger 的行 | `listening=false` 且 `nextFireAt` 键缺席（给时间戳即撒谎）
EDGE | envfix 自愈循环 | function | 声明一个装不上的依赖（拼错包名）并 create function | LLM 改依赖重试 ≤3 次，尝试/修复行 tee 到 entities 流 build 终端
EDGE | envfix 拒绝丢包修复 | function | 让 LLM 的「修复」把声明依赖列表缩到原始数量以下 | 拒绝该建议、env 保持 failed + 真实装错，绝不产出缺包的绿 env
EDGE | 未配 utility 模型时的 envfix | function | 清空 utility 场景默认后触发一次装不上 | `OK=false` 结束、stderr 留在 History 上呈给建构 LLM，绝不返 Go error
EDGE | env failed 仍创建成功 | function | 用装不上的依赖建 function 后立刻 `:run` | 实体创建成功且状态可见；run 时才 422 `FUNCTION_ENV_NOT_READY`
EDGE | 空 ops edit 重建 env | function | 对 env failed 的 function 打 `:edit` 空 ops | 只重建 active env、发 `function.env_rebuilt`，不铸新版本
EDGE | env 被 GC 后重试一次 | function | 跑 `sandbox:gc` 回收掉某 function 的 venv 再执行它 | `ErrEnvNotFound` → 重建 env + 重试一次，用户无感
EDGE | 版本 cap 50 trim 回收 venv | function | 对同一 function 连续 edit 51 次 | 硬删最老版本（放过 active）并经 `DestroyEnv` 回收其孤儿 venv
EDGE | revert 到很老版本后再 trim | function | revert 到 v1 后再连续 edit 到越过 cap | trim 放过 active（哪怕它是最老的那个）
EDGE | function 超时清洗 | function | 把 `FunctionRunSec` 调到 1s 跑一个死循环 function | 返 504 `FUNCTION_RUN_TIMEOUT`（不是裸 sandbox "spawn process timeout"），进程组 SIGKILL
EDGE | function 媒体产物声明 | function | 让 function 写 `chart.png` 并返 `{"chart": {"$media": "chart.png"}}` | 就地替换成 MediaRef receipt（`source:function_artifact`），产物留在它本该在的键上
EDGE | 产物路径逃逸 | function | 声明 `{"$media": "../../.ssh/id_rsa"}` | `fspath.Inside` fail-closed 在打开任何东西之前拒
EDGE | 产物四道闸逐件失败 | function | 声明一个 40MiB 的图 + 一个伪装成 .png 的 shell 脚本 | 逐件拒绝写进 logs、声明原样留下，绝不弄废一次算对了的运行
EDGE | 无 uploader 时的产物声明 | function | 在只跑 REST 的装配/测试下声明产物 | 声明原样通过、不建目录，绝不新增失败模式
EDGE | handler spawn 单飞 | handler | 让 chat 一轮并行发多个 `call_handler` 打在冷 handler 上 | 共享一次 in-flight spawn，不重复付 env+进程+`__init__` 开销
EDGE | handler 孤儿 config key | handler | 先配一个 init arg，再 edit 掉该 arg 的 schema，然后调用 | spawn 咽喉按 active schema 过滤掉孤儿 key，避免 Python TypeError 永久 spawn 失败
EDGE | handler config 不完整 | handler | 建 handler 后不配必填 init arg 就调用 | `HANDLER_CONFIG_INCOMPLETE`、不 spawn，且仍记一条 failed Call 行
EDGE | handler ctx 取消 = 管道脏 | handler | 在一次 RPC 等待中取消回合 | 客户端标 crashed、废弃实例（下次 Get 自动重生），这是协议正确性不是 bug
EDGE | handler generator 终值两写法 | handler | 分别用 `yield 终值` 和 `return 终值` 写 method | 两种都生效（driver 捕 `StopIteration.value`），裸 return 不被吞
EDGE | handler traceback 不被剥 | handler | 让 method 内抛 Python 异常 | traceback 进错误 Details（非 fmt 包裹），agent/flowrun 路径读到的不是不透明 "call failed"
EDGE | handler 注入 secret 掩码三面 | handler | 让 method 把 sensitive init-arg 值 print 出来并抛进 traceback | 实时错误面 / logs / 审计副本三处都掩成 `********`（含 inst==nil 的 spawn 失败路径）
EDGE | handler 空 ops edit 抹内存态 | handler | 对有状态 handler 打 `:edit` 空 ops | 重建 env + 重启（内存态丢失），结果带 `restarted:true` + restartNote 使其可见
EDGE | handler 纯 meta edit 不重启 | handler | 用 ops 全为 `set_meta` 的 edit 改名 | 只更行、不铸版本、不重启（内存态保住）
EDGE | handler 产物目录 chdir 恢复 | handler | 让一次带 `out` 的调用中途 continue/异常退出 | driver 在 try/finally 里恢复 cwd，下一次调用不从已删目录起步
EDGE | handler 同实例并发调用串扰 | handler | 让两次调用同时在同一实例上跑并各自 print | stderr 扇出按窗口归属，明示可能串扰；收尾留 30ms 宽限接住迟到的 print
EDGE | 沙箱运行时首用直装 | sandbox | 清空 runtimes 目录后首次跑 python function | 从上游拉钉死版本 tarball、sha256/512 校验、staging 原子 rename
EDGE | sandbox bootstrap 失败 degraded | sandbox | 让数据目录不可写导致 bootstrap 失败 | 进 degraded 模式、不挂 boot，`:retry-bootstrap` 可救
EDGE | boot 回收残留 running_pid | sandbox | kill -9 后端时留下活的 sandbox 子进程 | `RestoreOrCleanupOnBoot` 对记录 pid 的整个进程组 SIGKILL 再清零
EDGE | boot 回收 run_in_background 孤儿 | shell | kill -9 时留下 `run_in_background` 的 bash | `ReapStaleOnBoot` 按 `<dataDir>/shellpids/<bsh_id>.pid` 负 pgid 整组杀；pid 被无辜进程复用时 Getpgid 确证后放过
EDGE | uvx/npx 孙进程整组杀 | sandbox | 用 uvx 起一个 MCP server 再删它 | 负 pgid SIGKILL 连 python/node 孙进程一同收割
EDGE | env 在用时删除 | sandbox | 对正在被实例占用的 env 打 DELETE | 409 `SANDBOX_ENV_IN_USE`，诚实拒绝
EDGE | agent 挂载撞名 | agent | 挂两个合成后同名的工具（如同名 function 与 handler 方法） | 撞名检测使 invoke 失败；`mount-health` 对称地把第二个标 unhealthy
EDGE | agent 挂载目标被删 | agent | create 后删掉被挂的 function/知识文档 | invoke fail-fast 冒具体码；`mount-health` 逐条报 unhealthy（不 fail-fast）
EDGE | 离线 MCP 挂载归因 | agent | 让被挂 MCP server 处于 failed/connecting 再 invoke | 报 `MCP_SERVER_DOWN` 而非 `MCP_TOOL_NOT_FOUND`（排错指向重连 server）
EDGE | agent 声明输出回解析 | agent | 声明 2+ outputs 但让终答是自由文本 | 422 `AGENT_OUTPUT_NOT_STRUCTURED` 大声失败（恰 1 声明则裹进该名）
EDGE | agent 非 OK 终态置空输出 | agent | 让声明了 outputs 的 agent 撞 max_steps 或工具风暴 | `Output` 置 nil，绝不留裸叙述冒充声明形状；裸文本仍在 transcript
EDGE | sys: 能力工具无路由 | agent | 挂 `sys:generate_image` 但不配任何能出图的 key | ref 不可解析、invoke 大声失败；mount-health 显 Healthy=false 带「配 key 或开免费档」
EDGE | agent 墙钟压过自报终态 | agent | 把 `AgentInvokeSec` 调到几秒跑一个慢 agent | ctx DeadlineExceeded 映射 `timeout`（durable、可 `:replay`），压过 loop 自报的 cancelled
EDGE | subagent 墙钟 | subagent | 从一个无父回合 deadline 的路径 spawn subagent | `Spawn` 自套 `ChatTurnSec`，超时收尾 cancelled 并 annotateTerminal 浮出截断
EDGE | subagent 深度守卫 | subagent | 让 subagent 试图再派 subagent | `Subagent` 工具总从子集剔除（深度 1）
EDGE | get_subagent_trace 隔离 | subagent | 在 subagent 内试图读 subagent trace | 该工具总被 strip，防泄漏父对话的其它 subagent trace
EDGE | 被取消的 subagent 落终态 | subagent | 取消父回合时 subagent 正在跑 | 混血 host 在 Detached 上落 message_stop 终态，防孤儿
EDGE | MCP OAuth 全流程 | mcp | 装一个支持 DCR 的 remote server（如 notion/sentry） | 探测 401 → RFC 9728/8414 发现 → DCR 注册公共客户端 → PKCE+state → 拉浏览器 → loopback 回调换 token
EDGE | OAuth refresh 失效 | mcp | 在网关侧吊销 refresh token 后调用该 server | 401 `MCP_OAUTH_REAUTH_REQUIRED`，指路重新授权
EDGE | 自带客户端固定端口被占 | mcp | 装 Box/Entra 类 server 时先占住 47100 | 退随机端口（固定端口只是让用户能注册确定 redirect URI）
EDGE | 每租户模板 URL | mcp | 装 Glean 类 `Remote.URLEnv` 条目 | `Plan` 暴露成必填 env，安装时 `expandPlaceholders` 解出真实 URL 再走流程
EDGE | MCP degraded 态 | mcp | 让某 server 连续 3 次调用失败 | 转 degraded（仍 `IsCallable`、软警告），entities 流发 status 信号变色
EDGE | MCP 连接失败仍落盘 | mcp | PUT 一个连不上的 stdio/remote server | 落盘 `status=failed` + `lastError`，`:reconnect` 可救
EDGE | MCP 媒体逐件 best-effort | mcp | 让 MCP 返多件 image/audio，其中一件落库失败 | 失败件保留占位叙事、其余成为一等附件，绝不失败整个调用
EDGE | 无 uploader 时的 MCP 媒体 | mcp | 在未装配 uploader 的环境跑返图 MCP 工具 | 整体退回占位符（诚实降级）
EDGE | MCP name-or-id 双键 purge | mcp | 用 `mcp:<名>/tool` 挂载后再 `RemoveServer` | 按 `srv.ID` 与 `srv.Name` 两键 purge equip 边，不留悬挂孤儿污染依赖图
EDGE | MCP 进度关联 | mcp | 并发跑两个会发 progress 的 MCP 工具 | per-call token 把 session 级 progress 关联回各自的 sink，不串台
EDGE | MCP 失败附 stderr 尾 | mcp | 让一个 stdio server 在调用时崩 | `logs` 附 8KiB server stderr 尾并标注「可能早于本次调用」
EDGE | MCP 市场缺必填 env | mcp | 从市场装一个需要 token 的条目但留空 env | 422 `MCP_ENV_MISSING`（`Plan`→`missingEnv` 结构性堵死静默零认证连接）
EDGE | 无可跑 package | mcp | 装一个只有不支持 runtime 包的 registry 条目 | 422 `MCP_NO_RUNNABLE_PACKAGE`
EDGE | 搜索 embedder 缺席降级 | search | 把 `embedder` 设为 `off`（或让 builtin 下载失败） | 恒混合管线自动降级成纯词法 BM25 结果，检索模式无配置、无报错
EDGE | 首用下载途中关停 | search | 在 builtin embedder 首次拉 ~600MB 模型时发 SIGTERM | `Close(ctx)` 由关停 ctx 限界、中止安装 ctx 释放锁，绝不把 db.Close 阻塞在下载上
EDGE | embedder 孤儿回收 | search | kill -9 后端留下 ~2GB llama-server 再启动 | 按 `runtimes/llamasrv/embedder.pid` best-effort 回收残留
EDGE | 整批 embed upsert 全失败 | search | 让向量表写入全失败（盘满/表损） | 中止本轮等下次 kick，绝不进无限重嵌热循环
EDGE | cosineFloor 噪声闸 | search | 用一段乱码 query 搜一个有 8 个实体的 workspace | 余弦 <0.55 全被挡，绝不按噪声灌全 workspace
EDGE | 换 embedder 重嵌 | search | 从 builtin 切到 ollama | 旧模型行对新模型即「缺向量」自动重嵌，绝不混用；向量缓存整体 invalidate
EDGE | 短词 LIKE 回退 | search | 用 2 个字符的 query 搜 | trigram 零命中 → 短词 LIKE 回退；长短混合时长 token 走 MATCH、短 token 叠 LIKE
EDGE | 异查询游标 | search | 拿 A 查询的 cursor 去翻 B 查询 | 400 `SEARCH_CURSOR_INVALID`，绝不切错窗口
EDGE | :reindex 并发与就地重建 | search | 同 workspace 连打两次 `:reindex`，期间并发 Search | 第二次 409 `SEARCH_REINDEX_RUNNING`；重建期间 Search 仍返完整结果（force-reconcile 不 purge）
EDGE | fts_schema_version 不匹配 | search | 改 schema 版本后启动 | boot 清空全量重建（索引从不原地迁移）
EDGE | 密文红线 | search | 建带 secret 的 api key / mcp config / trigger config 后全文搜其值 | 零命中——经 Encryptor 落盘的字段永不进投影
EDGE | Changed 队满丢事件 | search | 短时间批量写实体打满非阻塞投递队列 | 溢出丢弃，boot 对账（stamps 比对 + 孤儿清理）兜底自愈
EDGE | sifter 缺席回退 | search | 清掉 utility 模型后跑 `search_blocks` | 回退纯索引排序（三段精度链第③段），对调用方透明
EDGE | 附件 sandbox 提取路径 | attachment | 上传一个 .docx/.odt 并 @ 进对话 | 走共享 python env 的一次性抽取脚本、400K char 截断内联（NativeDocs 只对 PDF 生效）
EDGE | 不认的 mime 抽取 | attachment | 上传一个抽取器不认的二进制文档 | 415 `ATTACHMENT_EXTRACTION_UNSUPPORTED` → 降级成明确文字占位，回合不失败
EDGE | 模型能力缺失诚实降级 | attachment | 把默认对话模型换成无 vision 的模型再发图 | 按原顺序降成明确文字占位（不丢附件、不假装看得见）
EDGE | 单回合媒体额度耗尽 | attachment | 一条消息附超过 `MaxMediaParts`/`MaxMediaBytes` 的图 | 超额部分降级成文字占位，其余仍原生递交
EDGE | 不可交付格式（HEIC/AVIF） | attachment | 在受管 Anselm 路由下发一张 HEIC | 上传**之前**判定为不可交付、降级成点名文件与格式的注记，不中断整回合
EDGE | 受管 remote media lease | attachment | 在受管路由下发一张图并观察线缆 | 经 device-proof resumable upload 取短期 lease，传**相对** fetch 路径（带 scheme/host 一律拒），聊天 wire 不含 base64
EDGE | lease 临期刷新 | attachment | 让同一附件在一次长 ReAct 里跨过 lease 过期前 30s | 自动重传刷新，同一可用字节不重复上传；重启不保留 bearer
EDGE | staging 失败大声失败 | attachment | 让受管 staging 端点返错 | 本回合大声失败，绝不静默丢媒体（与「不可交付格式降级」语义刻意不同）
EDGE | 代理图未 ready | attachment | 上传大图后立刻发送 | 本回合最多短暂等待本地 worker 产出 `model-default` v2 代理，超时退回原件、后台继续追上
EDGE | blob GC 只在 boot 跑 | attachment | 上传大量附件后删除，再重启 | boot 逐 workspace 按活跃 sha 保留集回收；删除时不扫描（会与在飞上传的 Put 竞态）
EDGE | 缺失/不可读 blob | attachment | 手工删掉某个 blob 文件后重放该回合 | 告警跳过、绝不让回合失败
EDGE | audio playback token 过期 | attachment | 签发 playback-lease 后等它过期再 fetch | 404；token 仅内存保存、绑 workspace/attachment，支持 Range/seek
EDGE | 非 audio 签发 playback | attachment | 对一张图打 `:playback-lease` | 415 `ATTACHMENT_PLAYBACK_UNSUPPORTED`
EDGE | 朗读缓存命中 | readaloud | 对同一段文本+音色连按两次朗读 | 第二次 `cached=true`、命中在合成之前判定，`SpeechInputs()` 不多一条（零上游花费）
EDGE | 朗读缓存 LRU 淘汰 | readaloud | 朗读到超过 per-workspace 50MB 预算 | 按 `last_used_at` 物理删缓存行（D1 第三个例外），其附件软删、blob 由 GC 回收
EDGE | 朗读长度上限 | readaloud | 提交 >4000 rune 的文本 | 400 `READALOUD_TEXT_TOO_LONG`
EDGE | 朗读可用性诚实缺席 | readaloud | 清掉所有能说话的 key | `/read-aloud/availability` 返 false → 前端根本不给按钮（探测失败也自吞成 false，不上退避循环）
EDGE | origin_tool_call_id 收窄展开 | attachment | 让模型在 tool_result 里回显一个**不是**本次调用铸出的 att_ id | `ToolResultContentParts` 只展开本次调用自己铸的，其余当文本
EDGE | 附件无保留线 | attachment | 让附件积累数月 | 永不自动删除（裁定：删除不可逆、不删可逆），容量治理走带预览的手动清理
EDGE | 免费档配额耗尽 | freetier | 把受管档用到网关返 402 / 流内 `BUDGET_EXHAUSTED` | `LLM_QUOTA_EXHAUSTED`（429，Code 与 RATE_LIMITED 区分故不可重试），绝不改动受管 install 身份
EDGE | 网关 install 自愈 | freetier | 在网关侧清库/吊销 install 后点设置页「修复」 | 探测见 `INVALID_INSTALL` → 重新登记设备 + `RotateManagedCredential` 就地换 install id（行 id 不变、scenario 默认无需重接）
EDGE | 瞬时失败绝不轮换 | freetier | 断网/让网关限流后点「修复」 | 不轮换凭证（离线/限流/网关重启绝不毁掉好 install），失败留日志、行保持原样
EDGE | 未开通读配额 | freetier | 在 in-memory/测试模式或 provision 仍 pending 时读 `/freetier/quota` | 404 `FREETIER_NOT_PROVISIONED`，设置页据此隐藏免费档仪表
EDGE | 开通降级不挂 boot | freetier | 无机器指纹 / install 失败 / 持久化冲突 | 每个失败路径 log 并返 nil，免费档缺席绝不挂 boot 或 onboarding
EDGE | 受管 key 不可变 | apikey | 对受管 `anselm` 行打 PATCH 或 DELETE | 均 422 `API_KEY_IMMUTABLE`（删除会割裂安装身份与配额历史，零引用也不放行）
EDGE | 被引用的 key 拒删 | apikey | 删一个被 scenario 默认 / 搜索默认 / agent override 引用的 key | 422 `API_KEY_IN_USE` + `details.references[{kind,id,name}]` 指明去哪解引用
EDGE | 旋转 key 重探失败 | apikey | PATCH 换新 key 值但让重探针失败 | PATCH 仍成功（旋转已完成），只是 testStatus 反映失败，不脑裂
EDGE | 播种只填未设 | freetier | 用户先手动设了 dialogue 默认，再触发受管播种 | `SeedDefaultsIfUnset` 只填仍未设的 scenario，绝不覆盖显式选择
EDGE | native knob 校验 | model | 给 modelRef 的 `options` 填一个该模型没有的旋钮 / 非法值 | 422 `MODEL_OPTION_UNSUPPORTED` / 400 `MODEL_OPTION_VALUE_INVALID`，绝不静默丢弃
EDGE | 未探测/custom 模型 | model | 用一个 custom provider 的未探测 modelId 且 options 为空 | 不做硬目录校验，保留 invoke 时 fail-loud
EDGE | 写时校 apiKeyId 存在性 | model | 把 conversation/agent override 或 workspace 默认指向不存在的 key | 立刻 `API_KEY_NOT_FOUND`，不是等到 invoke 才失败
EDGE | 生成 origin 从凭证派生 | llm | 用新加坡区 DashScope key 触发视频/图片生成 | 从凭证聊天 base 剥 `/compatible-mode/v1` 得生成 origin，绝不硬编码北京域（否则 401 读作「你的 key 不对」）
EDGE | 视频轮询超时诚实话 | llm | 让视频任务超过轮询上限 | 503 `VIDEO_GEN_FAILED`，消息含「上游任务可能仍会完成」的诚实话，无假进度百分比
EDGE | 不可能的生成组合钳制 | llm | 向 Veo 要 15 秒视频 | 客户端钳到该路由做得到的长度，receipt 报**真正做出来**的那个
EDGE | 能力工具诚实缺席 | chat | 清掉所有能出图的 key 后看工具集 | `generate_image` 不注入（逐请求重估，与 generate_speech 各自判定）；硬调则 422 `IMAGE_NO_ROUTE`
EDGE | 受管档视频路由 | freetier | 只有受管 key 时调 `generate_video` | 受管播种含 video(WRK-082 H1 翻案):经网关签名句柄提交→轮询→取回,真生成成功;额度 10 条/天/install
EDGE | 语音配额与限流分流 | speech | 让网关分别返 QUOTA/BUDGET/INSTALL_CAP、RATE_LIMITED/UPSTREAM_BUSY、ACCOUNT_BANNED | 分别映射 `SPEECH_QUOTA_EXHAUSTED`(429 不可重试) / `SPEECH_RATE_LIMITED`(429 可重试) / `SPEECH_ACCOUNT_BANNED`(403)
EDGE | ASR sidecar 无受管凭证 | speech | 清掉受管行后开语音输入 | 503 `SPEECH_UNAVAILABLE`（语音只走默认 Anselm Auto，不拿 BYOK 做适配）
EDGE | 多块 TTS PCM 拼接 | llm | 朗读一段超过单请求上限（qwen ~500 字符 / 智谱 1024）的长文本 | 在 PCM 层重接（非按字节追加 WAV），格式不一致大声拒绝而非静默变调
EDGE | ParseWAV 遍历 chunk 表 | llm | 用一个夹带 LIST/fact chunk 的 WAV | 遍历 chunk 表而非假定 44 字节头，元数据不被当成样本
EDGE | 断网启动 | bootstrap | 拔网线后冷启动 | 免费档 provision 失败留 nil、modelcatalog 刷新失败静默留 vendored/缓存、更新检查沉默，app 正常可用
EDGE | 模型目录运行时刷新失败 | llm | 让 boot 后 30s 的 models.dev 刷新失败 | 静默留旧（缓存优先于 vendored），能力描述不塌
EDGE | boot 顺序 SweepMisfires | bootstrap | 让 SweepMisfires 早于 ReattachActive 跑（回归验证） | 监听表为空则静默什么都不记——顺序必须严格在 ReattachActive 之后
EDGE | 三步优雅关停 | bootstrap | 有 3 条常驻 SSE 连接时发 SIGTERM | 先 cancel base 请求 ctx（否则 http.Shutdown 干等满 grace 窗）→ 排空 → 停后台 → WAL checkpoint → 关 DB
EDGE | 关停预算格 | bootstrap | 让某子系统在关停时卡住 | shutdownGrace 6s + drainShutdownGrace 2s + 2×WaitDelay 2s 必须嵌进 app 侧 8s SIGTERM 宽限，超过则 SIGKILL = 有序关停全作废
EDGE | 父进程死人开关 | bootstrap | 用 `ANSELM_PARENT_WATCH=1` 起后端后 kill -9 父进程 | stdin EOF 汇入同一 `signal.NotifyContext`，走同一条有序关停链
EDGE | 坏 settings.json | bootstrap | 手工写坏 `<dataDir>/settings.json` 再启动 | boot 失败（缺文件则纯默认）
EDGE | settings 三段整体写 | bootstrap | 只 PATCH limits 后检查 network/retention 段 | `persist(limits, network, retention)` 三段整体写，修补任一段绝不丢其余两段
EDGE | CHECK 加词整表重建 | infra/db | 用一个旧 schema 的库启动（trigger_firings/flowrun_nodes/message_blocks 三处） | `MigrateRebuild` 结果幂等：仅当标记词缺席才建新表→逐列拷贝→删旧→改名→重建索引（含 UNIQUE `idx_frn_once` / `idx_blocks_conv_seq`）
EDGE | ADD COLUMN 结果幂等 | infra/db | 对已加过列的库重复启动 | `duplicate column name` 视作已应用跳过；其他语句的真重复列错仍令整个迁移失败
EDGE | 换 master key 种子 | bootstrap | 改 `ANSELM_MASTER_KEY` 后启动一个已有密文的库 | 既有密文（api key / handler config / mcp config）全部解不开，key 须重录（故 keychain 只对全新安装铸钥）
EDGE | keychain 铸钥只对全新安装 | frontend | 在盘上已有 db 的旧装机上启动 | 绝不硬注新钥；keychain 异常一律退化机器指纹旧径，启动绝不变砖
EDGE | 出厂重置 | frontend | 在设置页输「Anselm」触发出厂重置 | 停 sidecar → 删数据目录 → resetAll → `open -n` 重启 + exit(0)
EDGE | bearer token 缺失 | transport | 让前端拿错/丢失 `ANSELM_AUTH_TOKEN` | 401 `UNAUTH_BAD_TOKEN` → 前端显示「重启后端」横幅、**不清 workspace**
EDGE | workspace 头缺失 | transport | 对隔离路由不带 `X-Anselm-Workspace-ID` | 401 `UNAUTH_NO_WORKSPACE` → 前端清 workspace 重选（与上一条刻意分流）
EDGE | DNS rebinding 防护 | transport | 用非 loopback Host 头打后端 | 403 `FORBIDDEN_BAD_HOST`（常开，仅放行 127.0.0.1/::1/localhost）
EDGE | ServeMux 纯文本 404/405 改写 | transport | 打一个 `/api/v1/` 下不存在的路径 / 用错方法 | 改写成 N1 envelope 的 `ROUTE_NOT_FOUND` / `METHOD_NOT_ALLOWED`（保留 Allow 头）
EDGE | 客户端断连与请求超时 | transport | 中途断开一个长请求 / 让请求超 deadline | `CLIENT_CLOSED`(499) / `REQUEST_TIMEOUT`(504)，从 stdlib context 错误直发
EDGE | 后台裸 ctx 播种缺失 | bootstrap | 给某个后台入口传裸 `context.Background()`（回归验证） | ws-scoped 查询 500 `MISSING_WORKSPACE_ID`——自动化链路全死却像轻微降级，故守护测试 `background_ctx_test.go` 锁死
EDGE | workspace 删除级联 | workspace | 删一个有活 workflow / 常驻 handler / MCP / 索引 / 文件树的 workspace | Reaper 杀自动化 → 停实例 → 断 MCP → 清索引 → 删文件树 → 删行，全程 Detached(目标 ws)、best-effort
EDGE | 删最后一个 workspace | workspace | 只剩一个 workspace 时删它 | 422 `CANNOT_DELETE_LAST_WORKSPACE`
EDGE | stats blobBytes 超时 | workspace | 造一棵极大的 blobs 树再读 `{id}/stats` | 500ms 预算内 walk，超时/未接线返 **-1**（诚实未知，绝不假 0）
EDGE | 单连接 panic 事务砖化 | orm | 让事务内 panic 且上层在不可取消 ctx 上 recover | `Transaction` 的 defer 回滚保证唯一连接不被永久占住（否则整库砖化）
EDGE | keyset 排序切换丢游标 | conversation | 在 `?sort=activity` 翻到第二页后切到 `?sort=name` 继续用旧 cursor | 必须丢弃游标重头翻（游标列随排序列走，跨 sort 无意义）；`?search` 同理
EDGE | PageAsc collation 不一致 | orm | 让 `.Order()` 或覆盖索引漏掉 `COLLATE NOCASE` | 跨页漏/重行（keyset 不变量对 collation 敏感）
EDGE | 驻地目录被移走 | conversation | 挂驻地后在终端里把该目录删掉/改名 | `GET /{id}/workdir` 答 `path` 非空而 `exists=false`（警示态，非错误）；Bash 予以拒绝、不静默回落后端目录
EDGE | 脏区切分支被拒 | conversation | 在有未提交改动的驻地里 `:switch-branch` | 422 `CONVERSATION_WORK_DIR_DIRTY`（脏态服务端此刻现读，不信客户端投影）
EDGE | 新建分支不受脏区门 | conversation | 同样脏状态下 `:create-branch` | 放行（`checkout -b` 从当前 HEAD 起、工作树零变化），这处不对称是刻意的
EDGE | 切分支名拼错 | conversation | `:switch-branch` 传一个只在远端存在的分支名 | 404 `CONVERSATION_BRANCH_NOT_FOUND`——同时封掉 `git checkout` 的 DWIM，拼错永不悄悄建跟踪分支
EDGE | 前导 `-` 的合法 ref | conversation | 传分支名 `-foo` | 422 `CONVERSATION_INVALID_BRANCH`（对 git 合法但会被下条命令读成选项）
EDGE | worktree 目录已存在 | conversation | 对一个已有 `../Anselm-x` 的名字打 `:add-worktree` | 409 `CONVERSATION_WORKTREE_EXISTS` + `details.path` 点名挡路目录，绝不静默接管别人的活
EDGE | worktree 分支已存在 | conversation | 用 `make worktree-rm` 保留的分支名重开一份 worktree | 复用该分支（与 Makefile 一致）；若已在别处 checkout → 422 `CONVERSATION_GIT_FAILED` 带 git 逐字 stderr 点出占用目录
EDGE | worktree 建成后切驻地失败 | conversation | 让 `:add-worktree` 的最后一步（Service.Update）失败 | 留下完好的 worktree + 仍在原处的线程——可停的诚实半状态，什么都没被毁
EDGE | 「这里没有 git」四情形 | conversation | 分别用未挂 / 已消失 / 普通目录 / 无 git 二进制打三个写动作 | 统一 422 `CONVERSATION_WORK_DIR_NOT_GIT_REPO`；读侧同样这些情形只答 `isGitRepo=false`（读不该失败）
EDGE | 切驻地落 marker 块 | conversation | 对已有消息的线程中途 PATCH 换 `workDir` | 落一个 `{kind:'workdir',from,to}` marker 块（content 恒空、客户端本地化），**不发 SSE 帧**、靠 `conversation.work_dir` 回声重读
EDGE | 空线程/重复 PATCH 不落 marker | conversation | 首发之前挂驻地；或对同一路径重复 PATCH | 均不落标记（没有「之前」；重复是 no-op）
EDGE | 切分支不落 marker | conversation | 在同一驻地里切分支 | 驻地没变故不落标记（分支变化活在投影里）
EDGE | 驻地分组批量归档重跑 | conversation | 对同一驻地连打两次 `:archive-workdir` | 第二次答 `archived: 0` 且不发回声（只动 `archived=0` 的行）
EDGE | 驻地分组批量删除范围 | conversation | 对一个含置顶 + 已归档线程的驻地打 `:delete-workdir` | 跨归档态删、**置顶存活**、消息行分毫不动、文件系统分毫不动（UI 用词绝不是「删除目录」）
EDGE | 空 workDir 批量动作 | conversation | 给 `:archive-workdir` 传 `workDir:""` | 400 `INVALID_REQUEST`（`''` 是正当过滤但不是一个组，否则会扫掉每条从未选过目录的线程）
EDGE | 分组事务交叉核对 | conversation | 让批量语句影响行数与 Pluck 出的 id 数不一致 | 变成一次**回滚的错误**，绝不留下半个归档了的目录
EDGE | 分组计数跨翻页不漂移 | conversation | rail 无限翻页时反复滚动并对比组头计数 | 服务端一次 GROUP BY 算出，workspace 没变则数就不变
EDGE | `?workDir=` 三态 presence | conversation | 分别用缺席 / `?workDir=`（空值）/ `?workDir=<path>` 列表 | 不过滤 / 仅未挂 / 仅该驻地——必须读键 presence，否则「最近」段会静默列出整个 workspace
EDGE | 立碑线程读消息 | conversation | 删一条对话后 `GET /{id}/messages` | 404 `CONVERSATION_NOT_FOUND`（线缆分不清「行被立碑」与「消息被抹」，D1 证明做在后端单测里）
EDGE | 文档超 1MB | document | PUT 一篇 >1MB 的正文 | 413 `DOCUMENT_CONTENT_TOO_LARGE`，硬拒、绝不自动拆分
EDGE | 并发同父建文档 | document | 同时对同一 parent 建多个文档 | `InsertAtNextPosition` 单事务 `max(兄弟)+1`，position 不撞车（无 position 唯一索引）
EDGE | 文档改名子树级联 | document | 对一棵三层深的子树根改名 | 批量重写全部后裔的物化 `path`
EDGE | 文档 Move 防环 | document | 把一个节点挂到自己的后裔下 | 422 `DOCUMENT_INVALID_PARENT`
EDGE | 对话挂载的文档被删 | document | PATCH 挂载文档后删掉它，再发消息 | 渲成 `<document id=… missing="true">` 警告行（模型知道 grounding 丢了），不让整个回合失败
EDGE | agent 知识文档被删 | agent | 同样场景但走 agent knowledge 挂载 | 大声失败 `AGENT_KNOWLEDGE_NOT_FOUND` + `details.missing`（与上一条刻意不对称）
EDGE | skill 安装炸弹护栏 | skill | 用一个 300MB 解压 / 5000 条目 / 含 symlink 的 tarball 装 skill | 压缩 100MB、解压 200MB、4096 条目、单文件 1MB 四道闸；tar symlink 条目直接丢弃
EDGE | skill 本地改动漂移 | skill | 手工改一个 installed skill 的文件后 `:update` | 409 `SKILL_LOCALLY_MODIFIED` + details 列漂移文件，`force=true` 才覆盖
EDGE | skill 路径穿越 | skill | files 面 PUT 到 `../../etc/x` 或用反斜杠/绝对路径 | 三重守卫（`filepath.IsLocal` 词法 → Clean 复核 → `os.Root` 句柄）内核级阻断 symlink 逃逸与 TOCTOU
EDGE | skill 清单拒删 | skill | DELETE `skills/{name}/files/SKILL.md` | 400 `SKILL_FILE_PATH_INVALID`，指向 `DELETE /skills/{name}`
EDGE | 大小写不敏感 FS 上的 skill.md | skill | 在 macOS 上先有小写 `skill.md` 再走平台写入 | 写大写、清退独立小写残件，经 `SameFile` 判别防自删
EDGE | skill 目录前导兜底 | skill | 激活一个带捆绑文件但正文没写占位符的 skill | 渲染结果前置一行 `This skill's directory …: <abs>`；单文件 skill 不加
EDGE | run_skill_script 扩展名不支持 | skill | 用 `.rb` 脚本调 `run_skill_script` | 400 `SKILL_SCRIPT_UNSUPPORTED`，指向 bash 工具
EDGE | fork skill 无 runner | skill | 在未接 subagent runner 的装配下激活 fork skill | 503 `SKILL_SUBAGENT_UNAVAILABLE`；`context=fork` 缺 agent 则 422 `SKILL_FORK_REQUIRES_AGENT`
EDGE | @ 一个 fork skill | skill | 在输入框 @ 一个 fork 模式 skill | fork skill 不进 @ 候选；即便注入也只给指令、不给预授权
EDGE | skill 未知 frontmatter 键保真 | skill | 用右岛表单编辑一个带 `license`/厂商扩展键的 skill | typed 视图之外的键与键序在编辑循环中不丢
EDGE | memory 更新保留策展 | memory | 让 LLM 的 `write_memory`（永远 source=ai、从不设 pinned）编辑一条用户置顶的记忆 | 保留现有 `pinned` 与 `source`，绝不把逐字注入规则静默降级成懒加载目录行
EDGE | todo 全完成后被问清单 | todo | 让 agent 把清单全标 completed 后再问「列一下清单」 | reminder 在 0-open 时抑制，靠常驻 `todo_read` 读回含已完成项，绝不凭记忆编造
EDGE | 删被依赖实体 | relation | 删一个被 3 个 agent 挂载的 function（HTTP 或 LLM 工具任一路径） | purge 抹边**前**快照入向 equip/link，purge 后发 ONE 聚合 `relation.dependency_broken` 点名这些悬空挂载者
EDGE | 触点不记幽灵删除 | touchpoint | 让用户 deny 一次 `delete_agent` 危险调用 | 门 = `ok && executed`，被拒的调用工具层没发生 → 绝不产生 `deleted` 幽灵行
EDGE | 触点记真执行的失败 | touchpoint | 跑一个会抛异常的 function / 一个 status=failed 的 agent | 仍记 `executed`（台账是足迹事实，成败属执行审计）
EDGE | 触点 deleted 行借名 | touchpoint | 删一个对话从未碰过的实体，再看台账 | 兄弟借名取不到 → 诚实空名（hydrate 只查活体）
EDGE | 触点目录穷尽性 | touchpoint | 加一个新工具但不在提取目录或 no-touch 清单表态 | bootstrap 的 `TestTouchpointCatalog_CoversEveryTool` 门禁红
EDGE | 未读徽标绝不据帧 +1 | frontend | 让 Emit 与 Broadcast 两档同 type 事件同时到达 | 徽标只靠权威 `unread-count` refetch（两档帧形相同、payload 判不出是否落行）
EDGE | 顶带 5000 条积压 | frontend | 短时间灌 5000 条通知 | 队列 O(1)、UI 只投影 current + 最多两 cue + 计数，widget 数不随积压增长、不设 cap 不丢消息
EDGE | 顶带公平调度 | frontend | 同时灌大量 priority（审批/操作反馈）与 normal 事件 | 每播 3 条 priority 必须让 1 条 normal 接班，普通事件不被饿死
EDGE | 顶带清场水位 | frontend | 在批清动画进行中再来新消息 | `clearVisibleSnapshot` 交换两条队列，新消息进新队列保留、不被旧清场误伤
EDGE | OS 通知被静默拒 | frontend | 在 unsigned dev bundle 上让 app 失焦后触发后台事件 | UserNotifications 可能静默拒（已知边界，真投递以签名 build 为准）
EDGE | 侧幕 activity 门控 | frontend | 打开一条从没跑过任何工具的空对话 | 右岛按钮不存在（无内容→无门），首条 activity 到达时 toggle 横向滑入
EDGE | 侧幕跟随三档 | frontend | 分别设 always / 每会话首次 / 从不，再让首个活动登台 | 前两档自动开岛，`从不` 档只亮按钮与 activityBit
EDGE | 侧幕尊重手动关 | frontend | 在面板可见时手动关一次，再让新活动登台 | 本会话记入手动关、不再自动弹（切海洋翻桶不误记）
EDGE | 导演器清 Live 幽灵 | frontend | 制造流缺口吞掉一个 tool_result 终态帧，再让 subagentEpoch 变化 | 按 transcript 全部 live 根重新接地，清掉「Live 幽灵」（停拍/poll 驻留/失败红行豁免）
EDGE | poll 型 202 不谢幕 | frontend | 用 `trigger_workflow`（202 只是回执）后等 run 跑很久 | 关帧后不离场，驻留到 durable `run_terminal` 按 flowrunId 匹配才谢幕/红纱
EDGE | 侧幕失败行清除 | frontend | 让一个工具失败后驻留在侧幕 | hover 亮行级清除按钮（失败驻留的唯一出口），否则旧失败活动永久滞留
EDGE | 侧幕分档时钟 | frontend | 让一行静置跨过「刚刚」窗（10min）而无任何重建 | 每分钟安静重分桶，不让静置行冻在「刚刚」再突跳
EDGE | 深跳 ?around= 整窗替换 | frontend | 从场次条跳到一条很老的消息 | 整扇替换（目标即 center sliver 首行）+ 双向续翻 + 「回到现场」pill；跳转即解钉、流式帧绝不夺视口
EDGE | 归队重钉贴底 | frontend | 从深跳窗点「回到现场」且重拉很快（不换 State） | 转变显式重钉贴底，否则读者被晾在历史里（真机抓获的真 bug）
EDGE | 版本组走 retryOf | frontend | 加载一份在自己被 supersede **之前**就取到的旧版副本 | 按向后指针 `attrs.retryOf` 组版本（`supersededBy` 在本进程里已过期）；成环终止、前驱未加载自成单成员组
EDGE | 编辑器 undo 全量重建 | frontend | 在增量 presenter 下按 ⌘Z | `DocumentWasResetChange` 哨兵令归账 fail-safe 走全量重建（事件不描述 undo 前后差）
EDGE | 编辑器唯一光标铁律 | frontend | 点进嵌入代码块字段或表格格 | 后代持焦（hasFocus && !hasPrimaryFocus）时清文档选区，避免两根光标同屏共闪
EDGE | 空 task 尾空格腐化 | frontend | 建一个空的 `- [ ] ` 待办后存盘再打开，往返两轮 | 剪尾空白豁免空 task 行；旧腐化档由 `_healTaskShapes` 自愈（字面 `[ ]` bullet 复原、剥前导换行）
EDGE | 行内代码 CJK 断盒 | frontend | 在行内代码里写中文注释并观察灰底 | 逐视觉行并盒（`getBoxesForSelection` 在 script run 边界会断），灰块连续不断裂
EDGE | 选区跨块缝隙 | frontend | 跨多个块划选 | 逐视觉行并盒（同行判据是竖向中心重合、非重叠）+ 块间 padding 由 overlay gap layer 填
EDGE | 原子块双/三击 | frontend | 双击代码块/表格/分隔线后拖动 | tap guard 在上游状态机之前整块选中并 halt，不形成 NPE 毒态（「点着点着鼠标失灵」）
EDGE | 大纲下标不变式 | frontend | 用围栏内 `#`、引用内 `#`、h4–h6 的刁钻文档 | 大纲正则与编辑器 `headingNodeIds` 对「谁是标题」完全一致（h1–h6 六档全算），漏一档全体错位
EDGE | skill 双写者竞态 | frontend | 在中心 body 与右岛 config 表单的 600ms 防抖窗口内同时编辑 | 已知竞态窗（注释已声明），属记档取舍
EDGE | 草稿文档首次编辑 | frontend | 在 library 无选区态打字 | 判空（标题/正文/简介/标签全未动）才不建；首次编辑 POST 后认领新 id、编辑器不重挂（光标/内容不丢）
EDGE | 应内缩放到顶 | frontend | 在小屏上连按 ⌘+ | `maxFactor` = 屏可容/设计 min，到顶即停、绝不撑破布局；持久化档恢复时也按当前屏收敛
EDGE | 进全屏白带 | frontend | 从小窗进原生全屏 | 在原生 `willEnterFullScreen`（动画**前**）撤 toolbar，过渡无白带（window_manager 的 did 回调太晚）
EDGE | 窗角半径 swizzle 失效 | frontend | 让 `NSThemeFrame` 私有半径 getter 改名（未来 OS 版本） | 判空守卫静默回落系统半径、不崩
EDGE | 空工作区名册 | frontend | 全新安装（或出厂重置）后启动 | 停在单页 onboarding，创建成功直接落空白 Chat；不另存 first-run flag，故恢复数据库不漂移
EDGE | 首启创建过渡 | frontend | 在 onboarding 提交名字 | 旧面与真 Shell 短暂共存、按两端实测 Composer 矩形做 560ms paint-only 飞行；reduced motion 直接落位
EDGE | workspace 热切换三拍 | frontend | 在一条对话深链上切换 workspace | ①同瞬 `go('/')` 并清右岛线程记忆 ②post-frame 才设 id（先离开是先一**帧**）③级联重取，否则旧 id 在新 ws 下 404
EDGE | 快捷键冷启动 | frontend | 冷启动后不点任何地方直接按 ⌘B | `GlobalShortcuts` 挂在 autofocus **之上**才不被饿死（放焦点之下要先点一下才活）
EDGE | 快捷键录制后吞键 | frontend | 在设置里录一个新绑定后继续按组合键 | 录完 `unfocus()` 交还键盘，否则本行吞掉后续每次组合键
EDGE | 设置项搜索索引漂移 | frontend | 新增一个可搜索行但忘了声明索引（或反之） | `settings_search_test` 双向门禁红
EDGE | 限额面板载入失败 | frontend | 让 `GET /limits/schema` 失败 | 整面 `AnState` 人话句 + wire 码收 tooltip + 重试钮，不灰屏
EDGE | MCP 面板帧不可信 | frontend | 让 entities 流的 mcp 帧密集到达 | 任何帧 → 300ms coalesce 一次重取；410 强制重取
EDGE | 保留面板无客户端默认 | frontend | 全新安装打开存储面板的「Run 历史保留」 | GET 恒返服务端自持的具体值（90），客户端永不硬编默认、无 modified/onReset
EDGE | testend Kill9 崩溃半场 | testend | 用 `Kill9`（真 SIGKILL）模拟崩溃恢复场景 | 绝不软化成 SIGTERM，否则优雅链会先删掉要断言的残骸（非终态行/未收尸子进程/未 checkpoint 的 WAL）
EDGE | testend 进程组泄漏自检 | testend | 让某个场景漏出常驻 llama-server | 轮询进程组至空，超 10s 仍有成员即 `t.Errorf` 并列幸存者命令行（测试绿不是收容的证据）
EDGE | testend 超时/被杀由下一轮收 | testend | 让整轮撞 `-timeout` 或对测试二进制 SIGKILL | 下一轮按 `$TMPDIR/anselm-testend/<pid>/` 的 pid 存活性挑死轮次，**先杀残留进程再删目录**
EDGE | testend 缓存剥 pid | testend | 让运行时缓存搭上 `embedder.pid` | `saveRuntimeCache` 回存前剥 `*.pid`，否则回收器指向 OS 此后分给别人的号码
EDGE | testend 网关指向关闭端口 | testend | 跑一轮完整 testend 并观察真网关侧 | `ANSELM_GATEWAY_URL` 指向关闭的回环端口使开通快速失败，绝不登记 ~50 个真 install、绝不真花配额

# ---- 0731 对照新 main 增补(BYOK 全目录 / 生成收归受管 / 音色 / 语音双工 / 多模态 durable 加固) ----
EDGE | BYOK base URL 模板未填占位 | apikey | 选 Azure/Vertex 等模板型供应商,base URL 留占位原样提交 | 表单以 `baseUrlTemplateHint` 指名要替换的占位;模板不是值,不得静默照发
EDGE | Vertex service-account 文件校验 | apikey | 贴一段缺 `type`/`project_id`/`private_key` 的 JSON | `serviceAccountBad` 当场拒绝;合法文件则 URL 按 project 拼出,不问 API key
EDGE | 未验证供应商诚实徽标 | apikey | 从 173 家目录选一家从未真测过的 | `unverified` 徽标 + hint(「来自 models.dev 目录,没人试过」);诊断句引导先疑 base URL(`baseUrlSuspect`)
EDGE | chat-only 模型的工具面 | catalog | 选一个 `tool_call=false` 的模型开对话 | picker 带 `chatOnlyBadge`,目录不再替用户扔掉能聊天的模型;对话内工具循环诚实缺席
EDGE | 工具参数双线缆形 | llm | 让 provider 分别以 object 与 string 两形返回 tool arguments | 两形都被认得(toolargs 归一),不再只认其中一种
EDGE | 直连生成整体退场 | generate | 只配 BYOK key、无受管 install,让模型试 generate_image | 生成三工具**诚实缺席**(CapabilityTools 无路由即不存在);`videoNoRoute` 类文案不留死钮
EDGE | 音色登记→指名说话全链 | voice | enroll_voice 登记参考音色→generate_speech 指名它 | 句柄被翻译成上游 id(63f402f 之前从来没能说过话);音色出现在设置音色库存卡
EDGE | 音色库存 2 槽上限 | voice | 登记第三个音色 | 库存闸拒绝(`voicesFull` 文案「删一个腾位」);库存不是钱的闸,与配额无关
EDGE | 删音色上游失败保行 | voice | 让网关删句柄失败再删本地音色 | `voicesDeleteFailed`:行保留可重试,绝不本地删了上游还挂着
EDGE | 语音双工握手拒绝闭集 | speech | 让网关握手返 401/配额类拒绝 | 拒绝只携带闭集 code(`handshakeRefusal`),上游散文**没有能力**泄进用户面错误
EDGE | 语音流中上游断线 | speech | 会话中途杀上游连接 | 客户端收 `SPEECH_UPSTREAM_CLOSED` 事件帧,双向心跳 deadline 收尾,不悬挂
EDGE | 语音帧越界 | speech | 发超过帧上限的音频帧 / 非法控制帧 | `SPEECH_AUDIO_FRAME_INVALID` / `SPEECH_CONTROL_INVALID`,会话终止而非静默丢帧
EDGE | 429 不动钱 | freetier | 受管生成撞限流(非配额耗尽) | 网关侧 429 **不扣用户配额**(aabd07d:恢复 GW-INV-23 合规);配额卡数字不动
EDGE | 分叉携带附件与 subagent 树 | fork | fork 一条带附件、@ 快照与 subagent 嵌套的对话 | attrs 逐字带走**除** retryOf/parentBlockId 被 remap 到分叉自己的 id;附件 id 与冻结快照正当共享
EDGE | workflow 停用排空双类 | workflow | :deactivate 时既有在飞 run 又有已接受 pending firing | draining 直到**两类**都排空才 inactive;只看 run 会把 pending firing 丢在地上

TOTAL: 353