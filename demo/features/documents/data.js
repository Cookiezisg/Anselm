/* Anselm feature — documents 种子数据（Notion 式嵌套文档树 + 一篇打开文档）。
   后端心智：单 workspace 的 markdown 树——父子有序、path 寻址 /a/b/c、[[wikilink]] 出边进 relation 图、可被 @ 引用、可挂载。
   左岛 = 嵌套【文档】树（非文件夹）：每个节点本身是一篇文档、又能有子文档。
   block 模型（编辑器渲染）：h1/h2/h3 · p（spans 含 @ref）· bullet · todo · quote · code · callout · divider。 */
(function () {
  // 嵌套文档树（id / label / 子文档）。dot 省略——文档无运行态。
  window.DOC_TREE = [
    { id: "doc_prod", label: "产品 · Anselm", children: [
      { id: "doc_prd", label: "PRD · Anselm v0.3", open: true, children: [
        { id: "doc_prd_flows", label: "核心流程拆解" },
        { id: "doc_prd_metrics", label: "成功度量" },
      ]},
      { id: "doc_research", label: "竞品调研" },
      { id: "doc_roadmap", label: "路线图 2026" },
    ]},
    { id: "doc_eng", label: "工程", children: [
      { id: "doc_arch", label: "架构决策记录（ADR）" },
      { id: "doc_durable", label: "Durable 执行设计" },
    ]},
    { id: "doc_ops", label: "运营", children: [
      { id: "doc_daily", label: "竞品动态日报流程" },
    ]},
  ];

  // 当前打开文档（doc_prd）：内容 blocks + 反链/出链 + 大纲 + 元信息 + AI 编辑历史。
  window.DOC_OPEN = {
    id: "doc_prd",
    title: "PRD · Anselm v0.3",
    path: "/产品 · Anselm/PRD · Anselm v0.3",
    blocks: [
      { type: "callout", tone: "info", html: "状态 <b>评审中</b> · owner @weilin · 目标里程碑 <b>本地优先 v0.3</b>" },
      { type: "h2", text: "背景" },
      { type: "p", spans: [
        { t: "团队现在靠人肉串起" },
        { ref: { kind: "function", id: "fn_5e1a9c4d", label: "fetch_article" } },
        { t: " 抓取 → " },
        { ref: { kind: "agent", id: "ag_91c3de07", label: "triage_agent" } },
        { t: " 诊断 → 人工审批回滚，链路脆且不可重放。本文定义把它编排成一条 durable workflow。" },
      ]},
      { type: "h2", text: "目标" },
      { type: "bullet", text: "节点结果记忆化：崩溃后从断点续跑，绝不重跑已完成节点。" },
      { type: "bullet", text: "失败分支挂人工审批门，决策 first-wins、支持超时自动驳回。" },
      { type: "bullet", text: "全程本地、单进程、SQLite 落盘——不做 SaaS。" },
      { type: "h2", text: "核心编排" },
      { type: "p", spans: [
        { t: "见 " },
        { ref: { kind: "workflow", id: "wf_9f2a7c1b", label: "pr_merge_flow" } },
        { t: "：on_pr_merged → run_tests → branch_result，失败走 " },
        { ref: { kind: "approval", id: "apf_release", label: "approve_rollback" } },
        { t: " 审批门。回滚分支的判定用 CEL：" },
      ]},
      { type: "code", lang: "cel", text: "branch_result.exitCode != 0 && payload.branch == \"main\"" },
      { type: "h2", text: "待办" },
      { type: "todo", checked: true, text: "图校验：全节点从 trigger 可达、回边只出自 control/approval" },
      { type: "todo", checked: true, text: "pin 闭包：跑前冻结引用实体的 active 版本" },
      { type: "todo", checked: false, text: "审批超时 timer（5s tick 扫 parked 行）" },
      { type: "todo", checked: false, text: "前端 scheduler 面：执行时间线 + 运行图 + 节点调试" },
      { type: "quote", text: "Durable 为魂——节点记忆化 + 解释器幂等重走，非事件溯源。" },
      { type: "divider" },
      { type: "p", spans: [
        { t: "相关：" },
        { ref: { kind: "doc", id: "doc_durable", label: "Durable 执行设计" } },
        { t: " · " },
        { ref: { kind: "trigger", id: "trg_3a1f", label: "webhook · pr" } },
      ]},
    ],
    // 反链（谁 [[链]] 或 @ 了本文）= relation link 入边
    backlinks: [
      { icon: "doc", label: "路线图 2026", meta: "document", hint: "「v0.3 详见 [[PRD · Anselm v0.3]]」" },
      { icon: "workflow", label: "pr_merge_flow", meta: "workflow", hint: "描述字段引用本 PRD" },
      { icon: "doc", label: "竞品动态日报流程", meta: "document", hint: "「参考 PRD 的 durable 心智」" },
    ],
    // 出链（本文 @ / [[ ]] 了谁）= relation link 出边
    outlinks: [
      { icon: "function", label: "fetch_article", meta: "fn_5e1a…" },
      { icon: "agent", label: "triage_agent", meta: "ag_91c3…" },
      { icon: "workflow", label: "pr_merge_flow", meta: "wf_9f2a…" },
      { icon: "approval", label: "approve_rollback", meta: "apf_rel…" },
      { icon: "doc", label: "Durable 执行设计", meta: "document" },
      { icon: "trigger", label: "webhook · pr", meta: "trg_3a1f" },
    ],
    // 大纲（标题树）
    outline: [
      { level: 2, text: "背景" },
      { level: 2, text: "目标" },
      { level: 2, text: "核心编排" },
      { level: 2, text: "待办" },
    ],
    // 元信息（文档身份证）
    meta: [
      ["path", "/产品 · Anselm/PRD · Anselm v0.3"],
      ["更新", "2026-06-17 11:20 · @weilin"],
      ["字数", "约 1.2k · 6.4 KB"],
      ["子文档", "2（核心流程拆解 · 成功度量）"],
      ["挂载到", "对话 cv_2b7e · agent triage_agent(knowledge)"],
    ],
    // AI 编辑历史（:iterate → conversationId）
    history: [
      { icon: "iterate", label: "AI · 补「核心编排」节", meta: "v4", hint: "2026-06-17 11:20" },
      { icon: "edit", label: "手动 · 调整目标列表", meta: "v3", hint: "2026-06-16 18:02" },
      { icon: "iterate", label: "AI · 初稿生成", meta: "v1", hint: "2026-06-15 09:30" },
    ],
  };

  // @ / 斜杠选取池（统一搜索的投影）：实体 + 文档，供 @ 提及 picker。
  window.DOC_MENTIONS = [
    { kind: "function", id: "fn_5e1a9c4d", label: "fetch_article", desc: "抓取 URL 正文" },
    { kind: "handler", id: "hd_4c1a9f02", label: "slack_client", desc: "常驻 Slack 客户端" },
    { kind: "agent", id: "ag_91c3de07", label: "triage_agent", desc: "诊断失败执行" },
    { kind: "workflow", id: "wf_9f2a7c1b", label: "pr_merge_flow", desc: "PR 合并后跑测试 + 审批回滚" },
    { kind: "trigger", id: "trg_3a1f", label: "webhook · pr", desc: "监听 GitHub PR webhook" },
    { kind: "doc", id: "doc_durable", label: "Durable 执行设计", desc: "引擎设计文档" },
    { kind: "doc", id: "doc_roadmap", label: "路线图 2026", desc: "产品路线" },
  ];
})();
