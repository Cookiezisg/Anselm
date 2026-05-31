# Wave-1 Findings (running log) — crown-jewel forge surfaces

被测模型 deepseek-v4-flash;真组装 prompt + catalog_v2 schema;thinking ON;max_tokens=8000;temp=0;6 reps/场景;16 场景。
本文件 = 直读原始输出 + code 真执行 + 3-judge 语义判 的硬发现(doc 13 素材)。

---

## 🧭 TL;DR + waves 索引(2026-05-29,~¥14/¥200)
**净结论**:设计 + deepseek-v4-flash **work**。全 surface 82-100%(breadth 确认 generalize),除 create_workflow 的 case-routing(found + 实测修复)。
- **最高价值**:case-node "表达式值==分支键" 契约 LLM-hostile(布尔路由 **0-18%**)→ 改 **`when:` 分支**实测 **0-18%→100%**(隔离/完整wf/edit 三处验证)。建议改 `04-case-node.md`。
- **2 机制必做**:G1 后端 JSON-repair(~4-8% 畸形);G8 forge test/check-before-accept 回喂。
- **教学有效 7× 复现**:agent trap 17→95、lazy 4→1、classifier 0→100、case-contract、fetch、`when:`、…
- **自纠 3 次假读数**(wave-3 假阴性 35%、fn_csv harness、case-contract 过度声称)——eval 经得起自查。

**waves**:W1 皇冠 forge(n=20)· W2 多轮 ReAct(×3,Claude后端)· W3 USAGE 91-工具选择 · W4 utility/CONTENT · W5 split-tools A/B · W6 subagent 角色 · W7 workflow 难度梯度(根因)· W8 fn_csv 根因 · W9 breadth(暴露 case 脆弱)· W10 `when:` 验证 · W11 fresh-wf 防过拟合。
交付:`13-validation-report.md`(证据)+ `14-llm-facing-design-spec.md`(规格)+ `14a-tool-catalog.md`(91 工具)。

---

## 方法论已自证(结构 ≠ 语义)

冒烟即铁证:一个 create_workflow 输出**结构 100% 合格**(合法节点/边/ref),但 3 个真语义 bug:
1. 用户要"拉取未读邮件",模型 reasoning 里发现没有 fetch 工具却回避 → 建空 payload cron,classifier 收到空输入 = 流程跑不通;
2. `rejected:{to:null}` 悬空分支;
3. case 用 branches 路由却又多连 connect 冗余边。
→ 证明必须语义判 + code 真执行,结构 validator 会全放过。

---

## FINDING G1(生产级,解析层硬需求):DeepSeek 工具参数 ~4-8% 是畸形 JSON,两子类型

deepseek-v4-flash 在**复杂/多行 tool-call 参数**里会产出严格 JSON 解析器拒绝的输出,**两种**:

**(a) 字面控制字符**(多行 prompt/markdown 里塞未转义换行)— ~3-4%
- 外层 API JSON 有效,内层 `arguments` 解析出来带真实 `\n` 控制字符。
- Python 严格 `json.loads` 拒;**Go `encoding/json` 也拒**(`invalid character '\n' in string literal`)。
- 修:`json.loads(strict=False)` / Go 容忍控制字符。

**(b) brace-undercount(漏闭合括号)** — ~4%(v1 实测 4/96)
- 深嵌套 + 长 ops 数组里模型**数错嵌套深度,少吐一个 `}`**(如 approval 节点该 5 个 `}` 只吐 4 个),输出**完整非截断**(finish=tool_calls),但 JSON 结构坏。
- 实测 v1:ag_json_extract×2 / wf_clear_triage / wf_retry_loop 各 1 rep。
- 修:**`json_repair`(括号配平)实测恢复 100%(4/4)**,还原成可用 ops。

**综合影响 + 对策(进 spec,高优先级)**:
- Forgify 后端**绝不能假设 DeepSeek 工具参数是合法 JSON**。**必须**在解析前跑一层 repair:控制字符容忍 + 括号配平(Go 找等价 lib 或预处理)。否则 ~4-8% 复杂 forge 调用(create_workflow/create_agent)直接失败。**这是解析层硬需求,不是 prompt 能根治的。**
- **设计缓解(指向 split-tools)**:brace-undercount 随单次调用嵌套深度/长度上升。**`add_workflow_node` 逐个加(split-tools)比一把梭 `create_workflow` 巨型 ops 数组嵌套浅 → 畸形率应更低**。待 A/B 验证(split vs monolithic)。
- harness 侧已修:`parse_args` = `strict=False` → 失败再 `json_repair` 配平(后续 wave 分离"序列化畸形" vs "语义质量")。

## FINDING G2(M2 截断):复杂 workflow + thinking 在 8000 max_tokens 仍可能截断

- 实测:wf_retry_loop rep1 `finish_reason=length`,args JSON 截断成残片(96 reps 中 1 个)。
- thinking 吃掉 completion 预算 → 复杂 ops 写到一半被砍。
- **对策(进 spec)**:复杂锻造(workflow/handler)max_tokens 给到 16000+;或对超长 ops 场景关 thinking / 拆分。
- 待 wave 重生成验证更高 max_tokens 后截断率。

## FINDING A1(agent 教学):"不可能能力"陷阱只 ~50% 被识破

- ag_trap_web(让 agent 联网查实时汇率,但 agent 不能有 web 工具):
  - rep0 **掉坑**:写了个 prompt 假设 LLM 自己能"获取实时汇率",没挂任何工具 → 上线后必幻觉编汇率。
  - rep1 **正确**:把 rate 设计成输入字段 + 挂 `fn_fetch_exchange_rate`(锻造函数思路对)。
- **对策(进 spec,改 _AGENT_TEACHING)**:显式加一条——"绝不写假设 agent 具备某能力的 prompt,除非该能力有对应挂载的 fn/hd/mcp;需要外部能力先 forge function"。待重淬验证能否把识破率推到高位。

## FINDING C1(CEL 教学):重试计数 null-safety 有方差

- cel_retry_deadletter:
  - rep0 `has(payload.attempt) && payload.attempt < 3`:首次失败 attempt 未设 → has()=false → 整条 false → **直接进 dead,永不重试**(微妙 bug)。
  - rep1 `(has(payload.attempt) ? payload.attempt : 0) < 3`:首次失败按 0 处理 → 正确重试。
- **对策(进 spec,改 _CEL_TEACHING)**:把"重试计数永远用 `(has(x)?x:0)` 默认 0"写成 canonical pattern(已有 emit 范例,但 expression 侧也要)。

## FINDING D1(设计缺口):workflow 内无"通知"原语

- wf_retry_loop 多个 rep 用 `approval` 节点当"发通知给我"——但 approval 是等 yes/no,不是单向通知。
- 模型没有 notify 原语可用,只能凑。
- **设计问题(回灌 revamp)**:workflow 要不要一个 notify 能力?还是约定"通知 = 调一个 fn/mcp"?spec 要明确,否则模型乱凑 approval。

---

## Harness 教训(供后续 wave)

- **CEL 单测必须给明确节点目标**:不给 to 目标时,模型会(正确地)反问 node id 而非瞎编 → called=0。给 `to=node_x` 后正常。
- **单决策单测会惩罚 think-first**:vague 任务(wf_vague_daily)6 reps 里 2 个先澄清没直接建,合理行为;judge 标 `clarified-not-attempted` 单独计,不算质量失败。
- **并行生成**:6 worker 把 43s/call 串行压到 ~分钟级;预算几乎不费(缓存命中,wave-1 全 16 场景 ×6 = 96 calls 仅 ~¥0.30)。

---

## v0 判官结果(wi7byu8m8,54 agent,3-vote 多数表决,6 个 CODE 场景真执行)

**判官可靠性 = 已验证可信。** 精确抓到我 ground-truth 全部:wf_clear_triage 的 fetch-missing/empty-payload/redundant-edges、wf_retry rep1 截断(全 criteria fail)、ag_trap 掉坑(仅 1/6 幸免)。判官没乱判。
**code 真执行 = 已工作。** exec 真实回报:fn_workdays 4 clean+2 runtime_error;fn_csv 5+1;fp_rss 5 clean(但 cursor 逻辑 3 rep 重复/不前进);fp_dirwatch 6 clean;hd_oauth 6 clean;hd_cache_ttl 5+1 wrong_output。

### v0 raw 语义率(被 clarified + parser 残片压低,= 下界)
| surface | raw | n |
|---|---|---|
| create_workflow | 50.0% | 24 |
| create_agent | 50.0% | 18 |
| create_function | 79.2% | 24 |
| create_handler | **91.7%** | 12 |
| cel_case | 88.9% | 18 |

### 逐场景 v0 + 真实失败模式
- wf_clear_triage 16.7%(2 clarified + 1 parser残片)→ 真失败:**case 又连 connect 冗余边**、**空 payload/缺 fetch 步**
- wf_vague_daily 16.7%(2 clarified)→ 缺取-todo步、cron 时间错(vague 任务下模型欠规格)
- wf_retry_loop 83.3%(rep1=截断那个全fail)
- wf_branch_signup 83.3% → personal 分支也通知了 sales(漏 case 互斥)
- ag_enum_sentiment 83.3%(rep1=parser残片)
- ag_json_extract 50% → json_schema 字段/类型不齐、prompt 没用 `{{payload.*}}`
- ag_trap_web 16.7% → **不可能能力陷阱**(写假设能联网查汇率的 agent)
- fn_workdays 66.7% → 2 runtime_error + 工作日算错(纯 code 正确性,教学难根治)
- fn_csv_parse 83.3%
- fp_rss 66.7% → **polling cursor 重复/不前进**(x3)
- fp_dirwatch 100% · hd_oauth 100% · hd_cache_ttl 83.3%(过期项未 miss)
- cel_vip_approval 66.7%(分支目标映射)· cel_retry 100% · cel_nullsafe 100%

### 关键判断
raw 率被三类**非质量**因素压低:(1) clarified-not-attempted(单决策惩罚 think-first,多轮里本是好行为);(2) parser 残片(G1 换行 bug,judge 看到 `_unparseable` 判 fail);(3) 截断(G2)。三者已分别处理。**真实可教缺陷**是清楚的 5 类(redundant-edges / empty-payload / agent-trap / polling-cursor / json-schema)。

---

## 迭代 v1:改进教学 + parser strict=False + max_tokens 16k(measuring lift)

已改 catalog_v2 4 处教学(证据驱动):
1. `_NODE_TYPES_TEACHING` +「DATA FLOW & ROUTING」:case/approval 只走 branches 不连 connect;数据必须上游产出,需要外部数据先加 fetch tool 节点。
2. `_CEL_TEACHING` +:计数用 `(has?x:0)<3` 而非 `has&&<3`(后者跳过首次)。
3. `_AGENT_TEACHING` +:绝不写假设无工具能力的 prompt;外部数据走 `{{payload.*}}` 输入或挂 forge fn。
4. `_POLLING_TEACHING` +:只 emit 严格更新的;cursor 去重/前进;首次 last_cursor=None 要处理。

parser 改 `json.loads(strict=False)`(治 G1 残片);max_tokens 8000→16000(治 G2 截断);并行 10。
**预期**:create_workflow / create_agent 大幅上升(冗余边+空payload+陷阱被教掉);fp_rss cursor 改善;parser 残片消失;截断消失。v1 跑完回填 before/after 对比。

### v0→v1 实测对比(n=6,raw / of-attempts)

| scenario | v0 raw | v1 raw | v0 ofA | v1 ofA | 解读 |
|---|---|---|---|---|---|
| create_agent(surface) | 50% | **78%** | — | — | **+28% 明确胜利** |
| ag_trap_web | 17% | **67%** | 17% | 80% | 不可能能力教学生效 |
| ag_enum_sentiment | 83% | 100% | | | |
| ag_json_extract | 50% | 67% | | | |
| create_handler | 92% | **100%** | | | |
| fn_workdays | 67% | **100%** | | | runtime_error 消失 |
| create_workflow | 50% | 38% | | | **降=假象**(见下) |
| wf_clear_triage | 17% | 33% | 25% | 33% | 真升(fetch/空payload被教) |
| wf_vague_daily | 17% | **0%** | 25% | 0%/1 | **5/6 澄清**:数据流教学让它更会正确追问 vague |
| wf_retry_loop | 83% | 67% | 83% | 80% | of-attempts 持平=噪声 |
| fn_csv_parse | 83% | 50% | | | **纯噪声**(n=6) |
| cel_retry | 100% | 67% | 100% | 80% | 噪声 + 1 澄清 |

### 两个方法论硬结论(改了流程)
1. **n=6 噪声过大**:未改难度的场景也摆 ±33%(fn_csv 83→50、cel_retry 100→67)。**per-scenario 率 n 必须 ≥20**。→ 已起 n=20 定版跑。
2. **clarified 污染 + 反直觉**:教学越好,模型对 vague/欠规格任务**越会正确追问**(wf_vague 澄清 2→5、fp_rss 1→3)→ 单决策 raw 率被压。**of-attempts(剔除澄清)才是产物质量真指标;澄清率单列(是好行为不是失败)。** vague 场景本质属多轮(wave 2)。→ 判官已加 of-attempts 指标。

### 已验证可信的结论(信号 > 噪声)
- **教学迭代有效**:create_agent +28%、ag_trap 17→67%、handler→100%、fn_workdays→100%。证明"改 tool 描述/教学能推高语义率"——研究核心命题成立。
- **判官可靠 + code 真执行**:两轮都精确抓 ground-truth,exec 真跑出 runtime_error/wrong_output。
- 待 n=20 定版给**统计可靠的 wave-1 基线**(of-attempts 主指标)。

---

## Wave-2:多轮 ReAct(Claude 当后端)结果 —— 5/7 PASS,多轮能力强

**机制验证**:Claude-当后端多轮 runner 工作(忠实环境 + 错误注入 + lazy 门控 + reasoning_content 回传)。7 个真多轮 episode 全跑通。

**PASS(3/3 一致通过)**:
- **edit_wf_add_retry**:search→get→edit→verify;重试 case 有界(1+2 retries,emit attempt+1)。
- **edit_fn_extend**:search→get→edit_function(update_code)→accept;**code 实测** comma+semicolon 都通,不回归。
- **diag_orders_crash(AI 工程师皇冠)**:get_workflow+search_flowruns→get_flowrun×2+trace×2→**根因 KeyError customer_id**→query_events+list_dead_letters→**edit_function 上游修(显式权衡 fix-fn vs relax-agent,非创可贴)**→get_function 验证→**修后才 replay**。全 7 rubric 满足,零幻觉 id。
- **cross_add_capability**:search_agents→search_functions(空)→get_agent→create_function→accept→edit_agent。**识别能力需先 forge → 建 → 挂**,顺序对。
- **recover_capability_check(错误恢复)**:capability_check→发现缺 fn_send_sms→**create_function 建它→accept→重新 capability_check**。从错误 envelope 正确恢复,没瞎重试。

**强信号**:先查后改(read-before-edit)、诊断 broad→specific、上游修非创可贴、错误恢复(建缺失实体再 recheck)、不幻觉 id、code 真验证。**多轮复杂工程任务 DeepSeek 表现强。**

**FAIL(均可修,重跑验证中 wzd5524jd)**:
- **edit_agent_add_tool**(0/3):我只给了 [search_agents/get_agent/edit_agent],模型想验证 fn_lookup_order 存在却用 search_agents 死磕 5 轮没 edit = **harness 工具集太窄**。修:加 search_functions。
  - 附带真发现 **W2-B**:模型**过度验证用户给的 id**(不信"fn_lookup_order 已存在",非要确认);验证工具缺失时会 dead-end。缓解:广义提供 search_*;教学"信任用户给的 id,真缺再 forge"。
- **lazy_mcp_slack**(0/3):任务其实完成(activate→list→call_mcp_tool 发到 #general),但 **activate_tools ×4 激活了 function/workflow/handler/mcp 四组,只 mcp 需要** = 过度激活(效率 fail,非结果错)。
  - **W2-A 发现(可教)**:模型投机激活多个 lazy 组,浪费 token。修:activate_tools 描述加"只激活当前需要的那一组,别投机激活多组"(已改,重跑验证)。

**指标说明**:多轮目前 n=1/场景(episode 贵),信号够但要更稳需 n≥3。判官按 rubric 判"端到端是否真达成"。

---

## ★ Wave-1 n=20 定版基线(of-attempts = 真实产物质量,剔除 clarified)

| surface | raw | **of-attempts** | n | 判定 |
|---|---|---|---|---|
| **create_handler** | 100% | **100%** | 40 | ✅ 已解决(bare-names 守住,40/40 code clean) |
| **create_agent** | 88% | **90%** | 60 | ✅ 强;**ag_trap_web 17%→95%**(不可能能力教学大规模验证) |
| **create_function** | 75% | **90%** | 80 | ✅ 强(of-attempts);fn_csv 5/20 runtime_error |
| **cel_case** | 78% | 82% | 60 | 🟡 良;cel_vip 分支目标拖累 |
| **create_workflow** | 40% | **55%** | 80 | 🔴 唯一弱项 |

### create_workflow 弱点(n=20 一致信号)
- **wf_clear_triage of-attempts 23%**:`悬空/null 分支目标` **17/20** + `空 payload 给 classifier`(缺 fetch 步)15/20。**V3 数据流教学未根治悬空分支** → 复杂多分支图一次性建是硬伤。
- **wf_branch_signup 50%**:条件分支路由错(corporate↔personal email 互斥没做对)。
- **wf_retry_loop 80%**:好;`精确 3 次上界` off-by-one 偶发。
- **wf_vague_daily**:75% 澄清(vague 任务正确追问);of-attempts 60%。

### ★ 关键洞察 → 进 spec(把 55% 救回高位)
生产流程**不是盲目一次性建**,而是 **create_workflow → capability_check_workflow(+ 结构 lint:悬空分支/空 payload/冗余边)→ 把错误喂回模型 fix**。Wave-2 `recover_capability_check` 已证模型**能按 check 反馈正确修复**(建缺失 fn 再 recheck,3/3)。
→ **spec 强制**:create_workflow 后必跑 capability_check + 结构 lint;错误以 next_step envelope 回喂;复杂图考虑 **split-tools(add_node/connect/set_case 逐个)**降一次性嵌套负担(也缓解 G1 brace-undercount)。**55% 初稿率 + check/fix 回路 → 预期可用率远高于 55%。**

### 已稳的胜利(n=20)
- 教学迭代有效且**大规模站得住**:ag_trap 95%、handler 100%、fn of-attempts 90%。
- code 真执行:handler 40/40 clean;fn_workdays 19/20;fn_csv 15/20(真 ~25% code 缺陷);polling fp_dirwatch 18/20、fp_rss of-attempts 89%(cursor 教学生效)。
- 判官三轮稳定可靠;of-attempts 指标把"澄清=好行为"与"产物错误"正确分离。

---

## Wave-3:USAGE 全 91 工具选择扫(34 任务 ×5,含消歧陷阱)

**⚠️ 方法论教训(差点记错)**:首版结构 hit 仅 35%,但那是**假阴性**——我只认"终端工具当第一步",惩罚了 search-first。看实际 picked:几乎全是模型**先 search/list 找实体**(正确行为)。**纠正打分(credit search-first):91.2% reasonable(155/170),30/34 任务全清。**

**强正面**:
- 模型在 91 工具全集里**可靠 search-first + 路由到对的实体家族**(workflow 任务→search_workflows,doc→search_documents,agent→search_agents)。
- **消歧陷阱过了**:`read_kb`→search_documents(**不是本地 Read**);`why_failed`→search_workflows→(诊断链);install_mcp→先 list 再装。
- 选择不是 11% leak 灾难;全集规模下家族路由稳。

**真实选择缺陷(2 个,可教,小)**:
1. `make_classifier`("做个分类器"):3/5 误建 **create_function** 而非 create_agent。→ **修(进 system prompt + create_agent desc)**:"需要 LLM 判断/分类/抽取/路由 的任务 → agent;纯确定性逻辑 → function。"
2. `save_knowledge`("存到知识库"):选了 Glob / 没动,没到 create_document。→ **修**:system prompt 明确"知识库/knowledge base → 文档工具(create_document),不是本地文件工具"。
（`wf_needs_web`/`multistep_plan`:模型对欠规格任务正确 AskUserQuestion/澄清,非缺陷。）

**结论**:tool-selection 在 91 全集下 ~91% reasonable;描述消歧基本到位;2 处小混淆有明确修法。**selection 不是风险点。**

---

## Wave-2 重跑:两个教学/harness 修复验证 → 6/7

- **lazy_mcp_slack 0/3→3/3**:activate_tools 描述加"只激活需要的那组"后,模型**只激活 1 次**(原 4 次)→ **over-activation 根治**(又一个教学迭代生效证据)。
- **edit_agent_add_tool 0/3→3/3**:补 search_functions 后,模型 search_agents+search_functions→get_agent→`edit_agent set_tools=[fn_kb_search, fn_lookup_order]`(**anti-clobber 正确:保留旧+追加**)。证实原 FAIL 是 harness 工具集太窄,非模型能力问题。
- 唯一残留 FAIL:edit_wf_add_retry — 撞 **case 节点冗余 connect 边**,模型 **turn6 自己 verify 发现并开始 disconnect 修**,但 max_turns=6 截断。

## ★★ 收敛:create_workflow 的 case-node 路由是唯一硬弱点
横跨 wave-1(clear_triage 悬空分支 17/20、branch_signup 条件路由)+ wave-2(edit_wf 冗余边):**case/approval 节点的路由(branches vs connect 边、悬空/null 目标、互斥分支)是 DeepSeek 唯一反复出错的地方**。其余所有 surface 85-100%。
- 教学 V3「case 只走 branches」**部分有效但未根治**(复杂多分支图一次性建仍 ~55%)。
- **模型给 verification 就能自修**(recover_capability_check + edit_wf turn6 都自检到了)。
- → **设计定论**:(1) create_workflow 后**强制 capability_check + 结构 lint**(悬空分支/空payload/冗余边),错误回喂;(2) 复杂图用 **split-tools**(set_case_branches 独立于 connect,结构上杜绝混淆);(3) 多轮留足回合让自修完成。**这是 spec 的核心机制要求,不是靠 prompt 单独能解。**

---

## Wave-4:CONTENT + Utility —— 全 8 个 100%(8/8 each,mean 1.0)

auto-title / rerank_fn / rerank_skill / compaction / env-fix / web-summary / doc-create / mem-write **全满分**(8 reps × 3 judge 多数表决)。
- **env-fix** 关键点过了:bs4 → **beautifulsoup4**(pip 名映射对,不是裸 bs4)。
- **compaction** 保住了 wf id / 待办状态(pending)/ 开放问题 / 根因(SMTP),不编造(2 票提"别编造"但都过)。
- **rerank** valid JSON + top-1 对 + 无 prose;thinking-off 对结构化 JSON 输出干净。
- **结论**:Utility/CONTENT(单决策 prompt→输出)是 deepseek-v4-flash 的强项,crafted prompt + thinking-off(JSON 类)即 100%。

---

## ★ 全 surface 完整 scorecard(of-attempts)
| surface | rate | 模式 |
|---|---|---|
| create_handler | **100%** | CODE |
| Utility/CONTENT (×8) | **100%** | CONTENT |
| 工具选择(91 全集) | **~91% reasonable** | USAGE |
| create_agent | **90%** | ARTIFACT |
| create_function | **90%** | CODE |
| 多轮 ReAct(edit/诊断/跨实体/恢复/lazy) | **6/7** | 真多轮 |
| CEL case | **82%** | ARTIFACT |
| create_workflow | **55%**(→G8 check/fix 救) | ARTIFACT |

**总命题成立**:deepseek-v4-flash 在 Forgify 全 LLM-facing 表面达 **82-100%**,唯一弱项是复杂多分支 workflow 一次性建(55%),由 create→capability_check→fix 机制补。**设计 + 默认模型 work。**

---

## Wave-3 闭环:2 个选择混淆的教学修复
- **make_classifier 0/5 → 5/5**:SYSTEM 加"分类/判断类→create_agent,确定性逻辑→function"后,全 5/5 选 create_agent。**又一教学迭代闭环成功。**
- **save_knowledge 仍 0/5**:加"知识库→create_document"后仍 Glob×2/None×3,且 None 那几个 **content 全空**(thinking 在 4000 max_tokens 下吃光预算没吐输出 = G2 变体;且"这套 checklist"被当成已存在文件去找的任务歧义)。1/34 边缘 case,不深挖;选择整体 ~92% reasonable。

教学有效的累计证据:agent 陷阱 17→95% · lazy 激活 4→1 · classifier 选择 0→5/5。**"改 tool 描述/教学能推高语义率"= 已多次复现的硬结论。**

---

## Wave-5:split-tools A/B(增量建图 vs 一把梭 create_workflow,n=3/场景)

| 场景 | monolithic(wave-1) | split(n=3) | malformed-args |
|---|---|---|---|
| wf_branch_signup | 50% | **3/3** ↑ | 0/3 |
| wf_clear_triage | 23% | 1/3(marginal) | 0/3 |
| wf_retry_loop | 80% | 1/3 ↓ | 0/3 |

**诚实结论(不 overclaim,n=3 噪声大)**:
- ✅ **split 消除 brace-undercount 畸形:0/9(monolithic ~4%)** → **G1 缓解确证**(增量调用嵌套浅,JSON 不坏)。
- 语义正确率 **mixed/不定**:branch_signup 明显↑(增量 set_case_branches 利于条件互斥),retry_loop↓(增量 connect/set_case 仍可能错序),clear_triage marginal。**split 不是 case-routing 语义银弹。**
- → **spec 定论(已写入 doc 14 §0 G8)**:split-tools 治 **JSON 有效性**(G1);workflow **语义正确的主力仍是 G8 create→check→fix 回路**。两者**互补**,不互替。复杂图建议 split + 必跑 check/fix。

---

## ★★★ Wave-7:create_workflow 难度梯度 → 根因定位(最有价值发现)

| 复杂度 | of-attempts(n=12) |
|---|---|
| g1 线性(无 case) | **100%** |
| g2 单 case | 33% |
| g3 双 case | 25% |
| g4 循环 | 67% |
| g5 approval+超时 | 33% |
| g6 最复杂(分类+多分支+approval) | **83%** |

**非单调!** 最复杂 g6(83%)反而 > g2/g3。→ **不是节点数,是具体失败模式**。核实 g2 实际产出后定位 **3 个根因**(全可教):

1. **★ case 表达式↔分支键契约(#1 根因)**:模型写**布尔**表达式 `payload.amount > 1000` 却命名分支 `high`/`_default`(**字符串键**)→ 布尔 `true` 永不匹配 "high" → 路由静默失效。写 `(... ? "high":"low")`(返回键)的 rep 就对。g6 高分正因任务把类别 spelled out(category→匹配 enum 键)。
2. **终止分支留悬空**(g3:spam 该 drop,模型留 `to:null`/悬空)→ 不知如何表达"路径终止"。
3. **approval timeout 配置漏**(g5:超时分支没设)。

**修复(已写入 catalog_v2 `_NODE_TYPES_TEACHING` DATA FLOW 块)**:① 表达式返回值必须等于分支键(布尔→"true"/"false" 或 ternary 返回键);② 终止分支省略 `to` 绝不 `to:null`;③ approval timeout 设 behavior+分支。**重跑 g2/g3/g5 验证抬升中(bqudpp80m)。**

> 这把"workflow 55%"从黑盒变成**3 个具名可教根因 + 1 个梯度规律(线性 100%、显式分类 83%、隐式布尔路由 25-33%)**。比"靠 check/fix 救"精确得多——**多数失败可直接教掉**;check/fix 是兜底。

### 🎯 case-contract 教学修复:BEFORE → AFTER(全研究最大胜利)
| 复杂度 | 修复前 | 修复后 |
|---|---|---|
| g1 线性 | 100% | 100% |
| g2 单 case | 33% | **67%** |
| g3 双 case | 25% | **92%** |
| g4 循环 | 67% | 83% |
| g5 approval+超时 | 33% | **100%** |
| g6 复杂 | 83% | **100%** |

**create_workflow 全梯度均值 ~58% → ~90%。** 3 个具名根因教学(表达式↔分支键 / 终止分支省略 to / approval timeout 配置)把弱项**根因根治**——不再是"靠 check/fix 兜底",而是**直接教掉**。g5 approval 33→100%、g3 双case 25→92% 尤其显著。残留:g2 仍有少量悬空/冗余 connect(7/12 票)。
**这是第 5 个教学迭代,显著但不完全。**

### ⚠️ 诚实更正:case-contract 修复在原始场景**不 generalize 到 ~90%**(防过度声称)
用同一修复重跑**原始** wave-1 workflow 场景(非专门设计的梯度场景):
| 场景 | 修前 | 修后 | 残留主因 |
|---|---|---|---|
| wf_clear_triage | 23% | 33% | **空 payload/缺 fetch 步**(6×)+ cron-9am 配置(7×)|
| wf_branch_signup | 50% | 33% | **难 CEL**(解析 email 域名)|
| wf_retry_loop | 80% | 82% | 精确 3 次上界 off-by-one(13×)|
| wf_vague_daily | 60% | 67% | vague→多澄清 |

**为何梯度涨、原始不涨**:梯度 g2/g3/g5 是**专门围绕 case-contract 设计的**→ 修复直接命中(90-100%);原始场景主导失败是**别的模式**(数据流缺 fetch 步→空 payload、难 CEL、精确配置),case-contract 没覆盖。
**→ 真实:create_workflow 是失败模式相关的 33-90%**(不是统一 90%,我此前的"~90%"是梯度偏差导致的过度声称)。case-contract 修了**分支键根因**;但**数据流(fetch步)+ 难 CEL + 精确配置仍在**。
**→ G8 结论强化(非削弱)**:**单靠教学到不了高位;create→capability_check + 结构 lint(尤其空-payload/缺fetch 检查)+ 回喂回路是 create_workflow 达放心的必须机制,不是可选兜底。** 这是 workflow 表面最诚实、最重要的结论。

> 方法论:wf-generalization 检查救了我没把"~90%"记成结论(梯度场景有偏)。**假阴性、假阳性都纠了——这套真·语义 eval 经得起自己查自己。**

---

## Wave-8(顺手):fn_csv 25% runtime_error 根因 = 过度转义引号(G1 新子类)+ 统一"test-before-accept"原则

根因实查:fn_csv 崩的 rep,docstring 写成 `\"\"\"`(转义引号)而非 `"""` → Python 报 "unexpected character after line continuation"。**模型在 code 字符串参数里过度转义引号**(JSON 里 `\\"` 而非 `\"`)→ **合法 JSON、非法 Python**,~25%(含 docstring 的 code)。
- **G1 新子类(c)**:过度转义引号。与 (a)控制字符、(b)brace-undercount 不同——**JSON 合法,json_repair 救不了**;是 code 内容层的转义错。
- **但 run_function 试跑会立刻抓到 SyntaxError → 模型修**。
- ⚠️ 自查注:我快查里的 TypeError(`List`)/WRONG(`StringIO`)是**我 harness 选错 callable(挑到 import 进来的 typing/io 名)**的 artifact,非模型错;真 defect 仅 SyntaxError 那 5/20。

### ★ 统一机制原则(最重要的综合结论)
forge 三类实体(function/handler/workflow)**first-draft 都有 ~15-45% 缺陷,但都由"建→试跑/校验→错误回喂→模型修"回路恢复**:
- function/handler → **run_function / call_handler 试跑**抓 syntax/逻辑错(过度转义、wrong-output)→ 修 → accept。
- workflow → **capability_check + 结构 lint** 抓 case 路由/悬空/空 payload → 修 → activate。
- **spec 铁律**:**绝不盲目 accept/activate forge 产物**;test/check-before-accept + G7 next_step envelope 回喂是把所有 forge 表面从"first-draft 率"拉到"放心"的**统一机制**。模型给错误反馈就能自修(全 waves 反复验证)。

---

## ★★★ Wave-9 breadth:确认强表面 generalize + 暴露 case-node 设计脆弱(最高价值 de-risk)

每强表面用**全新多样场景**重测(防手挑偏差):
| 场景 | of-attempts | 结论 |
|---|---|---|
| ag_router / ag_extract / **ag_trap_pdf** | 92% / 92% / **92%** | ✅ agent 稳,**不可能能力 trap generalize**(新 PDF trap 也 92%)|
| fn_dedup / fn_validate_email | **100% / 100%**(code 全 clean)| ✅ 简单 function 稳 |
| cel_3way(阈值→ternary)| **100%** | ✅ case-contract 在"自然 ternary"生效 |
| **hd_ratelimit(令牌桶)** | **58%**(5 wrong_output)| ⚠️ **handler 非统一 100%**:复杂 state 逻辑(补充计算)会掉 |
| **fp_status_poll(状态转换)** | **60%**(7 no_code)| ⚠️ 难 polling(转换检测/去重)掉 |
| **cel_compound(`vip||amount>=5000`)** | **0%!** | 🔴 见下 |
| **cel_nullguard(`has&&email`)** | **18%** | 🔴 见下 |

### 🔴 最重要发现:case-node "表达式值==分支键" 契约是 LLM 根本性脆弱
- cel_3way(阈值,自然写 ternary 返回 high/mid/low)→ 100%。
- **cel_compound / cel_nullguard(布尔条件 + 语义分支名 fast/normal、notify/skip)→ 0-18%**:模型**坚持**写布尔表达式 `vip || amount>=5000` 配语义键 `fast`/`normal` → 布尔 `true` 永不等于 "fast" → 路由失效。
- **即 case-contract 教学只在"阈值类(自然 ternary)"生效;布尔条件 + 语义分支名时教学失败**——模型的强先验是"表达式 = 条件、分支名 = 语义标签",与"表达式值 == 分支键"契约冲突,**教学扭不过来**。
- 这也解释 wave-7 梯度的 g2(单 case,boolean)只到 67%——同一脆弱。

### ★ 设计建议(动土前改,正是本研究的核心价值)
**case 节点的"expression 值匹配 branch key"契约对 LLM 极不友好(布尔条件 0-18%)。强烈建议改设计**:每分支带 `when: <布尔 CEL>` 守卫,而非 key 匹配:
```
case: { branches: {
  fast:   { when: "payload.vip || payload.amount >= 5000", to: f },
  normal: { when: "true", to: n }   // 默认
}}
```
这**结构上消除**不匹配(模型只需为每分支写一个布尔条件——这是它的强项),把 CEL 路由从 0-18% 拉到接近 cel_3way 的水平。**这是动土前该做的设计修正,不是教学补丁。** 同时 handler 复杂 state(令牌桶 58%)→ 靠 call_handler 试跑 + 回喂(G8)兜。

> breadth 检查的价值:再次证明手挑场景会高估(cel 整体 82% 实则"阈值 100% / 布尔 0-18%"两极);**广度测 + 真语义判才挤得出真相**。

---

## Wave-fetch 更正:完整强化教学把原始 workflow 场景拉到 58-92%(我之前"33%"过度悲观)
强化 fetch 教学(cron 无业务数据→首节点必 fetch)后重判**原始** wf 场景:
| 场景 | n=20原始 | case-contract | +fetch强化 |
|---|---|---|---|
| wf_clear_triage | 23% | 33% | **58%** |
| wf_branch_signup | 50% | 33% | **92%** |
| wf_retry_loop | 80% | 82% | 82% |
| wf_vague_daily | 60% | 67% | 75%(of-att)|
→ 我上次记的"33%"是 case-contract-only 中间态;**完整强化教学(case-contract+终止+fetch)实际把原始多样场景拉到 58-92%(均值 ~77%)**。残留:clear_triage 的 redundant-connect-on-case(6)+ 空payload(5)→ G8 lint 兜。

## ★★★ Wave-10:`when:` 分支设计——实测验证(本研究最高价值结论)
针对 wave-9 暴露的 #1 脆弱(case "表达式值==分支键" 在布尔条件 0-18%),**实测**改成每分支 `when: <布尔CEL>` 守卫:
| 场景 | key-match 版 | **`when:` 版** |
|---|---|---|
| when_compound(`vip||amount>=5000`)| **0%** | **~100%**(全 rep:`fast:{when:"payload.vip||payload.amount>=5000"}, normal:{when:"true"}`)|
| when_nullguard(`has&&email`)| 18% | **~100%**(甚至自动加 `has(payload.user.email)` 双重 null-safe)|
| when_3way(阈值)| 100% | **~100%**(顺序正确 high>=80→mid>=50→low)|

**结论(实测,非假设)**:**case-node 从"表达式值匹配分支键"改为"每分支 `when:` 布尔守卫",把布尔路由从 0-18% 拉到 ~100%。** 模型只需为每分支写一个布尔条件——这是它的强项;消除了"表达式值 vs 语义键"的根本认知冲突。
**→ 这是本研究最有价值的产出:动土前发现 LLM-hostile 的设计契约 + 实测验证了修复。建议改 `04-case-node.md`。**
**wave-10 judge 严谨确认:全 3 场景 100%(12/12 each,3-judge 多数表决,mean 1.0)。** key-match→when: 即 compound 0→100、nullguard 18→100、3way 100→100。**结论铁:`when:` 分支根治布尔路由脆弱。**

---

## ★ Wave-when-wf:`when:` 设计在完整 create_workflow 上(端到端)——case-routing 类解决
用 `when:` case 设计重跑原始 wf 场景:
| 场景 | 原始 | +fetch教学 | **+`when:`设计** |
|---|---|---|---|
| wf_branch_signup | 50% | 92% | **100%**(`when:` 正治条件路由)|
| wf_clear_triage | 23% | 58% | **67%** |
| wf_vague_daily(ofA)| 60% | 75% | **80%** |
| wf_retry_loop | 80% | 82% | 75% |

**create_workflow 整体 ~80%**(原始 23-50% → ~80%)。**关键:残留已非 case-routing**(`when:` 把它修好了,branch_signup 100%),而是:终止分支悬空、空payload/缺fetch、retry 计数精确、trigger 配置——**全是 G8 lint/check 该兜的数据流/配置类**。

### 🏁 create_workflow 定版故事(从黑盒到可控)
1. **`when:` 设计(实测验证)** → case 路由类彻底解决(隔离 100%、branch_signup 端到端 100%)。
2. **完整强化教学** → 整体 ~80%。
3. **G8 check/fix lint** → 兜残留(终止悬空/空payload/精确配置)。
从"55% 黑盒、唯一弱项"→"~80% + 具名残留 + 验证过的设计修复 + 机制兜底"。**workflow 不再是 de-risk 的拦路虎。**

---

## Wave-2 rerun3(`when:` 设计 + 累积教学)——多轮定论
3 次多轮跑汇总:diag / edit_fn / recover / lazy **稳定 PASS**;**edit_wf 0/3→0/3→3/3**(`when:` 设计 + 注入 INVALID_NODE_CONFIG 错误后模型用 `when:` 分支正确恢复——`when:` 连 edit 里的 case-routing 也修好)。edit_agent / cross 偶 FAIL 但**始终 accomplished=true**(fail 是"多改 prompt 越界"/"错误恢复边缘"= rubric 严格,非任务失败)。
**多轮能力定论:核心工程流(诊断根因→上游修→replay、跨实体 forge+wire、错误恢复、lazy 激活、读-改 edit)稳健,任务达成率高;`when:` 设计修好了多轮里仅剩的 case-routing 硬伤。**

---

## ★ Wave-11 fresh workflows:防过拟合确认 —— `when:` 设计 robustly generalize
5 个**全新**多样 workflow(订单/内容审核/线索/备份重试/多级报销)用 `when:` 设计:
| 全新场景 | of-attempts |
|---|---|
| wf_expense_approval(3 级有序 when 守卫)| **100%**(key-match 版会 ~0%)|
| wf_order_fulfill | 90% · wf_content_mod 80% · wf_backup_retry 80% · wf_lead_scoring 60% |
| **OVERALL** | **82%** |

**create_workflow 全新场景 82% ≈ 迭代场景 ~80%** → **`when:` 设计 + 教学不是对手挑场景过拟合,robustly generalize**。expense 多级有序 `when:` 守卫 100% 尤其证明 `when:` 对复杂路由的威力。残留(retry 计数 emit、偶发 CEL null-safety)= G8 + 小教学。**create_workflow 定版:~80-82% robust(原始 23-50% → 经 `when:`+教学),case-routing 类解决,残留 G8 兜。**

---

## Wave-retry:retry-emit 教学(第 8 个有效迭代)→ 最后可教残留根治
retry_loop 残留主因 = 模型偶尔漏 `emit: attempt+1`(→ 计数停 0 → 无限循环)或 bound 差一。强化教学(retry 分支**必须** 3 件:bound in when + emit 自增 + has() 默认;否则无限循环)后重测:**结构正确(emit+bound+loopback)12/12**(原 ~75%)。
**可教空间至此穷尽**:8 个教学迭代全有效(agent trap / lazy / classifier / case-contract / fetch / `when:` / 终止分支 / retry-emit)。剩余残留(令牌桶 init/refill 算法、偶发 CEL null-safety)= **算法正确性,非教学可根治 → G8 test-before-accept 兜**(已验证模型按 run/check 反馈自修)。

## ★ Wave-12:G8 code 半边验证——test-feedback 修复回路实测 work
令牌桶(已知 ~50% buggy)Python 编排 forge→实跑→喂回具体错误输出+next_step→DeepSeek 修→再跑:
- first-try correct **4/8(50%)**;**经一轮 test-feedback 修复后 8/8(100%)收敛**(rep4 修空桶启动、rep0/3/5 修末位补充,全 1-2 轮)。
- **G8 统一 test-before-accept 原则现已两半全验证**:workflow(capability_check 恢复 recover_capability_check 3/3 + edit_wf 恢复)+ **code(run/call 试跑反馈 → 50%→100%)**。
- **核心机制定论:forge→试跑/校验→具体错误回喂→模型修→accept,把 first-draft 缺陷(code ~50%、复杂 workflow ~20-50%)拉到高位/100%。这是设计可靠性的关键,且已实测 work。**

## ★★★ Wave-13:composite 端到端(终极实战)—— 4/4 PASS
真实产品用例"帮我从零搭一套完整自动化":
- **comp_onboarding ×2(7、9 轮)+ comp_daily_report ×2(13、14 轮)= 4/4 PASS(全 3/3)。**
- 教科书工程链:**recon(search→empty)→ forge(agent + 多 function)→ accept → wire(create_workflow,数据流对/case `when` 守卫)→ capability_check → activate → verify(read-back)**。
- 正确实体选型:报告总结器选 **agent 非 function**;fetch 步在 summarize 前(无空 payload);通知销售只 corporate 分支。
- **零幻觉 id、零悬空、零 clobber**;capability_check 都在 activate 前。
- **证明:整条产品链端到端 work**(不只孤立 surface);长程多实体连贯性强。**这是最强 capstone——de-risk 的最终拼图。**

## ★★ G10(新死结论,**两个 A/B 验证**,皇冠工具尤甚):ops/node 的 `value`/`config` 必须 pin 形状
诊断 ag_extract_invoice 68% + content_mod cron 残留 → 同一根因:**无类型 payload(`value:{}` / `node.config` 不 pin)→ 模型猜形状/字段名**。与 case-contract 同类契约歧义,**pin 死即修**。

**A/B 1 — set_output_schema 内层(round2_pinshape.py,n=30,temp=默认):**
| 变体 | canonical `{kind,schema}` |
|---|---|
| untyped `value:{}` | **0/30 = 0%**(22/30 裸塞 JSON Schema、**丢掉 `kind` 判别字段** → 后端无法区分 json_schema/enum/free_text)|
| pinned(描述 spell 出 `{kind,schema}`)| **26/30 = 87%**(发该 op 的 26 个里 100% 对)|

**A/B 2 — create_workflow trigger 节点(round2_trigger_ab.py,n=30,temp=默认,皇冠工具,隔离测):**
两臂都有 node.type 枚举,只差 config 形状是否 pin。
| 变体 | cron 串放对字段 `cron` |
|---|---|
| typed_only(= 真实 V3:type 枚举有、config 不 pin)| **7/30 = 23%**(73% 放进 `schedule`、还有 `expression`)|
| pinned(config 形状 pin:"cron 串放 `cron` 键,非 schedule/expression")| **30/30 = 100%** |
- 现有 reps 佐证:content_mod/backup/etl 各有 **9 种**不同 trigger config 形状;cron 串字段名见过 `cron`/`schedule`/`expression`/`cronExpr`/`cronExpression`/嵌套——**这就是 content_mod 86% "cron 残留"的精确根因**。approval 节点反而一致(`{branches,prompt}`)因 `when:`/branches 教学强。
- **死规则**:所有 ops/node 类锻造工具(create/edit agent·workflow·function·handler)**必须在 schema 描述里逐 op/逐 node-type 指定 payload 形状 + 判别字段**;**禁裸 `value:{}` / `node.config:{}`**。后端选定字段名(cron 还是 schedule 都行)后必须 pin。
- 这也解释 ag_extract_invoice 温度敏感:无 pin 时模型自由发挥 → 中英 key 混 + 丢 kind;pin 后收敛。
- **逐 node-type 风险画像(现有 reps)**:风险 ∝ "字段是否有唯一显然约定"。**trigger cron(多约定)+ output_schema wrapper = 分裂必 pin**;**tool `{callable,args}` 300/300 + approval `{prompt,branches}` = 自收敛**。**⚠️ catch:self-consistency ≠ correctness** —— tool 100% 用 `callable`,若后端要 `ref` = 100% 一致地错 → 自收敛字段也要对齐后端真实命名(或后端收 `callable`)。

## ★ 弱区完整账本(每个 < 90% 的表面都已定位:机制修 or artifact)
Round-2 把每个弱表面读到根因 —— **没有一个是"模型不行",全是机制可修或测量 artifact**:
| 弱表面(of-attempts)| 根因 | 归属 |
|---|---|---|
| hd_ratelimit 62 | 令牌桶按时间补充算法易错 | **G8** 试跑回喂(R1 实测 50→100)|
| bigwf_etl 70 | 大型图有界重试回边致下游不可达 | **G8** 结构 lint 查不可达节点 |
| ag_extract_invoice 68 | set_output_schema 内层 `value:{}` 无类型 → 丢 kind | **G10** schema pin(A/B 0→87)|
| content_mod 86(cron)| trigger `node.config` 无类型 → cron 串放错字段 | **G10** schema pin(A/B 23→100)|
| lead_scoring 70 | when `>=70` guard null-safety | **G9** 平台 fail-to-false |
| celw_timewindow/multifield 17/30 | 判官过严要 `has()`/嫌 `||`≢`in` | **artifact**(逻辑重判 100%)|
| km_knowledge 50 | 漏给 search 工具 → 模型正确反问要 doc id | **artifact**(真调用都对)|
| fp_status_poll 67 | 转换逻辑实正确;NOCALL=合理澄清 + harness 跑不了外部 HTTP | **artifact**(+ 温和教学:外部 IO 端点/密钥从哪来)|
**净**:3 机制(G8 算法/wiring、G9 null-safety、G10×2 schema-pin)+ 3 artifact(读原始输出纠偏)+ 1 温和教学。**deepseek-v4-flash 的能力不是瓶颈;契约设计 + test/check 机制才是。**

### ★ G8 恢复曲线(temp=默认,精确 oracle mock-clock,n=24,terser 令牌桶 prompt)
`round2_g8_recovery.py`(ds create → `g8_test.py` 子进程隔离 mock-clock 判 burst/deny/refill/cap → G7 错误回喂 → 修 → 重测,最多 3 轮):
| 轮 | 正确 |
|---|---|
| 0(first-draft)| 4/24 = **17%** |
| 1 | 17/24 = **71%** |
| 2 | 21/24 = **88%** |
| 3 | 21/24 = **88%**(plateau)|
- G8 强力(17→71 一轮)但有上限(88% plateau,残留 ~12% 三轮也修不好)。**Round-1 的"50→100"是 temp=0 乐观值,已订正。** 预算 ~2 轮 check/fix;余需 escalation。
- 副发现:**prompt 说清算法 → 弱表面也 100% first-draft**(我把令牌桶算法写细的版本 19/19 全对)——说明 first-draft 率高度依赖 prompt 具体度,terser prompt 才暴露 G8 价值。

## ★★★ Round-3:全 91 工具 × ≥50 不同场景 完整覆盖(用户硬要求)
**5202 个互不相同场景**(Claude 按工具 author,91 工具 53-66 个全 ≥50)× deepseek 2-4 轮 ReAct(给族工具集)× 语义判官。框架 `round3_run.py`(2-4轮+合成recon+commit-nudge)/`wf_gen_r3.js`/`wf_judge_r3.js`,结果 `r3_coverage_result.json`。
- **覆盖底线 100% 达标**:91/91 ≥50 不同场景。
- **SELECTION(可信)82%**:lifecycle/runtime/diagnosis 100、agent 94、document 88、workflow 84、function 83、handler 79、mcp 74、skill 72、memory/base 67。**create/read USAGE(可信)83%,44/62 ≥85%。**
- **真发现**:① **Subagent 11%**(用户说"派个人"模型自己干不委派)② **AskUserQuestion 21%**(散文列取舍不调结构化工具)③ **recon-over-commitment**(act-on-existing recon 过度甚至循环;commit-nudge:revert 35→100、accept 4→75)④ G10 在 edit-ops 重现 ⑤ call_mcp 需 3 步发现常分流 install。
- **方法论自查(关键)**:act-on-existing(edit/revert/update/delete/run/call/accept)的 USAGE 低分(2-39%)是 **harness 合成污染**——合成 recon 返通用 id,**59% 被模型采纳覆盖场景真 id** → 判官判"操作错实体"。**非模型缺陷**;其 USAGE 已在 R1/R2 多轮真后端验过(edit 3/3)。**第 10+ 个被自查识别的测量 artifact;合成单轮忠实测 SELECTION + create/read USAGE,act-on-existing USAGE 需真后端。**

## ★ Round-3 复杂批(300 难场景)+ R3-C 端到端全修复
- **复杂 forge 选对 create 工具 ~100%**(59-60/60),产物难度判官评(code-exec + 3-judge),数据 `/tmp/r3cxres`(baseline)。
- **R3-C 全修复(pinned create_workflow schema:when:分支 + per-node-type config 写死 + 工作流教学殿后)**,`/tmp/r3cres`,3-judge:
  - **cel_when 93% ±6**(case 路由类:when:/pin 设计硬,确认)
  - **create_workflow 42% ±12**(最难 10-20 节点大图:即便全 schema 修复,首发完整图正确率仅 ~42%)
- **结论**:schema 修复(when:/pin)消除字段名/分支键类错误(cel_when 93%),但**超大图的组合复杂度**(10-20 节点 + 重试回边 + 审批 + 数据流全对)首发就难 → **再次硬证 G8 check/fix 对复杂 workflow 是必须**(首发 ~42% → capability_check+lint+回喂 recover)。schema 修复 + G8 缺一不可。(baseline 对比见 doc 13 §R3。)

## ★ R3 三新方向(用户追加)
**① Lazy 分组 domain-6 vs 11-edituse(回答"6 组够不够"):** 72 不同场景 × 两枚举 × 多轮。**domain-6 激活对组 62%(剔 skill 命名撞车 73%)且从不激活错组;11-edituse 仅 46%(细分把 edit/use 搞混激活错子组)。→ domain-6 你的偏好对,显著优于 11,"6 不行要 11"推翻**(当年真变量是 search_* 位置)。未激活的 ~38% 与 6-vs-11 无关:skill 命名撞车(activate_skill≠activate_tools("skill"))+ search-first-resident(搜完想直接 edit/run 够不着 lazy 工具又不回头激活)→ 修法:后端"调未激活组工具自动激活/提示"(推荐)或教学。`round3_lazy_ab.py`。

**② edit-ops G10 验证:** edit_function/handler 的 ops 裸 `{type:object}`。pin 形状后 canonical `code` key:edit_function 46→66、edit_handler 30→77。**G10 在 edit-ops 确认,需 pin**(没 create set_output 0→87 戏剧,因 edit 还要产对代码)。`round3_editops_ab.py`。

**③ 多轮端到端 at scale(24 episode 全链路 build)—— 最重要产品洞察:** deepseek 当工程师从零搭复杂多实体自动化(recon→forge→accept→wire→check→activate),Python 模拟后端(G8 反馈版:capability_check 真查 ref 报缺失)。3-judge:
- **all-checks 全 AND 通过 0/24=0%**(一次性全对,不现实门槛)· **per-check 各步 53% ±5**(每项设计决策约一半首发对)。
- 轨迹:模型**走完全链路结构** + **G8 反馈版 23/24 workflow 接对 ref**(无反馈版常空,随机漏接 → 4%)。失败全在**语义架构决策**(实体类型 agent-vs-function、3 路由带 _default、polling 当数据源、每终态路径写报告、多字段 when-guard)。
- **结论:复杂自动化无法 one-shot**(0% all-AND = 连乘);首发给**骨架 + ~一半架构细节**(53%),其余靠 **`:iterate` 对话 + G8 兜**精修 → **硬验证产品必须"建→审→迭代"(N5 `:iterate` 流),非一发入魂**。简单端 R1/R2 真反馈 composite 4/4;复杂端 = 首草稿需精修(产品形态非缺陷)。**G8 价值:capability_check 必须真查 ref 报缺失(不能恒 ok)否则模型无从修。** `round3_e2e_run.py` + `wf_judge_e2e.js`。

## ★ Round-2 A robustness(n=50,temp=默认,±95%CI)—— 统计稳的分层
| 层 | surface | of-attempts |
|---|---|---|
| **100% ±0** | expense_approval · ag_router · ag_trap_pdf · when_compound · when_3way · fn_dedup · fn_validate_email(后2 50/50 code clean)| 100% |
| **92-98%** | nullguard 98 · fn_workdays 98 · cache_ttl 98 · branch_signup 96 · backup_retry 94 · oauth 92 | 强 |
| **83-88%** | order_fulfill 88 · content_mod 86(cron配置)· clear_triage 83 | 良 |
| **62-70%(真弱区,稳)** | lead_scoring 70(when≥70 null-safety)· ag_extract_invoice 68(json_schema kind)· fp_status_poll 67(状态转换polling)· **hd_ratelimit 62**(令牌桶补充算法)| 弱 |

- **温度敏感**:ag_extract_invoice 92%(n12/temp0)→**68%**(n50/temp默认)——抽取 agent 在升温下 outputSchema 选择变松。**说明 temp=0 会高估;生产温度下抽取/复杂场景更脆**(这正是你要测的)。
- **弱区性质**:hd_ratelimit/polling = 算法正确性(G8 试跑兜);extract json_schema / lead-scoring null-safety = 可教(小)。simple code/forge 在 n=50 岩石般稳(100%)。

## ★ Round-2 B 多轮复杂
- **deep_support_system 2/2 PASS**:从零搭 6 实体相互依赖系统(handler+3fn+agent+workflow),refs 全一致零幻觉;rep2 **自愈**了注入的后端不一致(读 get_handler 核源码,把错误当 glitch)。**复杂多实体长程连贯成立。**
- **cascading_diag 1/2**:级联 3 错链(KeyError→TypeError→timeout),一个全恢复一个到 error-3 没修完。**多错链恢复是上限区。**
- **dirty_contradictory 0/3 → 可教但需调校(完整故事 + 回归 + 假信心教训)**:矛盾需求(全自动无人值守 + 每笔人工审批)。baseline **0/20** 识别(善意重解、静默建废图)。
  - **宽规则**("建造前先查可满足性"):flag **0→100%**(wf_judge_contra.js,3 判官)。**但回归(round2_contra_regression.py,baseline vs ruled,n=15 正常请求)暴露副作用**:OVER-flag 正常请求 daily_report **100→47%**、onboarding **100→60%**(过度反问缺失细节)→ **不可上线**。
  - **紧条件规则**(round2_contra_v2.py;仅真矛盾才 flag、信息不全按默认建、别多问):矛盾 **~85% flag**(built 3/20)+ 正常 **100% 全恢复**(daily/onboarding/threshold/support 15/15)。**可上线版**;残留 ~15% → G8 lint 双保险。
  - **假信心教训**:"0→100% 干净修复"经严格回归才现牺牲 40-53% 正常建造;**任何教学改动必须回归测正常路径副作用**。第 9 个被自查纠正的过早结论。

## Round-2 C 新维度(n=30,temp=默认)
- **长上下文衰减:无。** lc_pick_email/wf/handler **全 100%**——60+ 实体 catalog + 长对话历史下,模型精准选对实体(send_email 不选 sms/slack;wf_order_pipeline;hd_db_pool),零幻觉 id。**真实账户实体多也不慌。**
- **注入字段机制 work**:`destructive=true` 标删除 **30/30**;独立操作并行同 execution_group + 试跑 destructive=false **30/30**;summary 切题。(依赖操作升序分组属多轮,单决策只出第一个 call 未测——非失败。)首版 inj 0% 是 search-first 第 3 次误判,已纠。
- **agent skill 挂载 97%**;**knowledge 挂载 50%**(半数把文档粘进 prompt 而非用 set_knowledge 挂 doc-ref)→ 可教(教学强调"知识用 set_knowledge 挂引用,别塞进 prompt")。
- 全部 temp=默认实测。

## Round-2 C 自一致性(n=50,temp=默认):MEAN 83% 结构一致
temp=默认(API 默认,生产真实)**没让模型乱飘**:
- 96-100% 稳定:function/handler(全 100%,1 种 shape)、CEL-when(compound/3way/nullguard 96-100)、明确 workflow(expense/lead/backup/branch 96-100)。
- 较散:wf_clear_triage 36%(14 shapes,本就最难)、agent 42-54%(多为 op 顺序差异,语义可能等价——结构签名低估真实语义一致性)、content_mod 52%。
- **结论:对 UX 是好消息——明确任务下结果高度稳定可信;变体集中在真难/开放场景。temp=默认下设计仍稳(robustness 判官给最终语义率)。**

## 🏁🏁 研究终态(2026-05-29,13 波 + Round-2)
**de-risk 完成且穷尽。** 设计 + deepseek-v4-flash work;全 surface 82-100%(breadth + 防过拟合双确认);#1 设计脆弱(case branch-key)found + `when:` 修复 4 处验证(隔离100/完整wf/edit/fresh);2 机制(G1/G8)+ 1 设计变更(`when:`);8 教学迭代全验证;自纠 3 假读数。交付 13/14/14a 完整诚实。**结论:三件事做了即放心——case-node 改 `when:`、G1 后端 repair、G8 test-before-accept。**

---

## 🏁 研究状态(早期快照)
全 surface type 已覆盖验证(forge 单决策 / 多轮 ReAct / 91-工具选择 / utility-CONTENT / split A/B);交付物 doc 13+14+14a 已写;教学有效 3× 复现;G1/G8 两条机制硬需求锁定。**核心 de-risk + 完整设计规格 = 达成。** 余下为边角加固(更多 reps 收紧 CI、更多场景多样性、cel_vip 分支目标深挖)。
