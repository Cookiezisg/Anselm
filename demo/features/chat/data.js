/* Anselm feature — chat 种子数据（会话列表 + @提及池 + 脚本化 live 回合 + 右岛实体工作台清单）。
   后端心智：conversation 是纯线程容器（消息单独取）；一次 Send = 202 + messages SSE 流式回合（每对话同时只一个在途回合）。
   :iterate（AI 编辑实体）/ :triage（AI 诊断执行）都返 conversationId 当普通对话接管——故 chat 是所有 AI 对话的唯一容器。
   【契约铁律】edit_ / create_ 工具写完新版本【立即生效】——后端【无】pending/草稿/采用/审批门；切版本唯一手段是 revert_ 工具（移 active 指针）。
   工具真名：Bash · get_trigger/get_flowrun · WebSearch/WebFetch/Read · create_trigger · edit_function · create_handler/update_handler_config/call_handler · create_agent/invoke_agent · create_workflow/edit_workflow/trigger_workflow · todo_write …
   data 形态：CHAT_CONVOS[id] = { title, crumb, meta, kind, blocks(初始 transcript), autoplay?, turn?(脚本步), islands?(右岛碰过的实体清单), todo?(右岛出 Todo tab), todoFinal?(静态对话的末态 todo) }。
     islands[i] = { id, kind, name, lang?, meta?, revert?, views:[ ViewSpec ] }（= entities 流镜像，每实体一个右岛 tab）；
       ViewSpec = { key:create|edit|run|flowrun|trace|detail|config|mounts, label, 按 key 携 code/before/after/range/note/args/trace/nodes/blocks/rows }。
   脚本步（sea 小解释器消费，对齐后端 Open→Delta*→Close）：
     { ms, push } 追加块（=Open）· { ms, patch } 替换末块（running→settled）· { stream:{type,text,tps} } 文本/推理逐 token（=Delta）·
     { progressStream:{lines,lps} } progress 终端逐行（live 脉冲）· { gate:{onApprove,onDeny} } 等 an-decide（danger approve/deny · ask accept/decline，只在对话流渲）·
     { island:{ focus:{id,view}, op?:create|edit|run|flowrun|trace, code/before/after/cps/nodes/lps } } 驱动右岛实体面板（与同步 push/patch 并行=双写）· { islandTodo:[…] } 喂右岛 Todo 看板。
   #4：tool_call 默认收起——只有需用户操作的（danger gate / ask）才自动展开（block-tree 据 items 的 gate/ask 自判），故此处不写 open:true。 */
(function () {
  // ── 实体源码/图常量（右岛 create/edit 视图的种子与流式终值）──
  const SYNC_V1 = "import requests\n\ndef sync_inventory(warehouse, dry_run=False):\n    skus = fetch_skus(warehouse)\n    return upsert(skus, dry_run=dry_run)\n";
  const SYNC_V2 = "import time, requests\n\ndef sync_inventory(warehouse, dry_run=False):\n    skus = fetch_skus(warehouse)\n    for attempt in range(3):            # 指数退避重试\n        try:\n            return upsert(skus, dry_run=dry_run)\n        except requests.RequestException:\n            if attempt == 2: raise\n            time.sleep(2 ** attempt)\n";

  const INV_V2 = "def validate_invoice(inv):\n    if inv['total'] != sum(l['amt'] for l in inv['lines']):\n        raise ValueError('total mismatch')\n    return True\n";
  const INV_V3 = "def validate_invoice(inv):\n    calc = sum(l['amt'] for l in inv['lines'])\n    if abs(inv['total'] - calc) > 0.01:        # 允许 ±0.01 舍入误差\n        raise ValueError('total mismatch')\n    return True\n";

  const HD_SRC = "from slack_sdk import WebClient\n\nclass Handler:\n    def __init__(self, bot_token, default_channel='#alerts'):\n        self.client = WebClient(token=bot_token)\n        self.channel = default_channel\n\n    def post_message(self, channel=None, text=''):\n        resp = self.client.chat_postMessage(\n            channel=channel or self.channel, text=text)\n        return { 'ok': resp['ok'], 'ts': resp['ts'] }\n";

  const AG_PROMPT = "你是发布说明撰写助手。给定一个 PR 的 diff：\n1. 用 WebFetch 取 diff 正文\n2. 按 feat / fix / chore 归类改动\n3. 输出一段 Markdown 发布说明，每条一行、动词开头\n\n只输出发布说明本身，不要寒暄。\n";

  // workflow graph（JSON 形态的拓扑——本实体只存/校验/钉图，执行归 scheduler）
  const WF_V4 = '{\n  "trigger": { "ref": "trg_pr_webhook", "concurrency": "all_allow" },\n  "nodes": {\n    "fetch":     { "kind": "action",   "ref": "fn_fetch_pr" },\n    "transform": { "kind": "action",   "ref": "fn_transform" },\n    "approve":   { "kind": "approval", "ref": "apf_merge" }\n  },\n  "edges": ["trigger -> fetch", "trigger -> transform", "transform -> approve"]\n}\n';
  const WF_V5 = '{\n  "trigger": { "ref": "trg_pr_webhook", "concurrency": "serial" },\n  "nodes": {\n    "fetch":     { "kind": "action",   "ref": "fn_fetch_pr",\n                   "retry": { "max": 3, "backoff": "exp" } },\n    "transform": { "kind": "action",   "ref": "fn_transform" },\n    "approve":   { "kind": "approval", "ref": "apf_merge" }\n  },\n  "edges": ["trigger -> fetch", "trigger -> transform", "transform -> approve"]\n}\n';
  const WFB_OPS = '{\n  "set_meta": { "name": "pr_pipeline" },\n  "add_node": [\n    { "id": "test",  "kind": "action",   "ref": "fn_run_tests" },\n    { "id": "gate",  "kind": "approval", "ref": "apf_merge" },\n    { "id": "merge", "kind": "action",   "ref": "fn_merge_pr" }\n  ],\n  "add_edge": [\n    "trigger -> test",\n    "test -> gate    when: result.passed",\n    "gate -> merge   when: approved"\n  ]\n}\n';

  // 会话列表（rail）：置顶 / 今天 / 昨天 / 已归档。dot 只映射【isGenerating】（在途回合=run，否则无 dot）——conversation 无对话级态。
  window.CHAT_CONVOS_LIST = [
    { group: "置顶", open: true, rows: [
      { id: "cv_daily", label: "竞品动态日报流程", dot: "run", meta: "刚刚" },
    ]},
    { group: "今天", open: true, rows: [
      { id: "cv_iterate", label: "AI 编辑 · sync_inventory 加重试", meta: "10 分钟前" },
      { id: "cv_handler", label: "接 Slack 客户端 + 试调", meta: "20 分钟前" },
      { id: "cv_research", label: "调研竞品 durable 方案", meta: "30 分钟前" },
      { id: "cv_agent_new", label: "造一个发布说明 Agent", meta: "40 分钟前" },
      { id: "cv_triage", label: "诊断 · flowrun frn_8a1c 失败", meta: "1 时前" },
      { id: "cv_workflow_build", label: "搭 PR 合并流水线", meta: "1 时前" },
    ]},
    { group: "昨天", open: true, rows: [
      { id: "cv_invoice", label: "发票处理 v3 迭代", meta: "昨天 18:20" },
    ]},
    { group: "已归档", open: false, rows: [
      { id: "cv_weekly", label: "周报汇总", meta: "上周" },
    ]},
  ];
  window.CHAT_DEFAULT = "cv_daily";

  // @ / 提及池（统一搜索投影）：实体 + 文档（与 documents 同源语汇）
  window.CHAT_MENTIONS = [
    { kind: "function", id: "fn_5e1a9c4d", label: "sync_inventory", desc: "同步仓库库存" },
    { kind: "function", id: "fn_3b2c7e10", label: "fetch_article", desc: "抓取 URL 正文" },
    { kind: "handler", id: "hd_4c1a9f02", label: "slack_client", desc: "常驻 Slack 客户端" },
    { kind: "agent", id: "ag_91c3de07", label: "triage_agent", desc: "诊断失败执行" },
    { kind: "agent", id: "ag_release", label: "release_notes_agent", desc: "PR diff → 发布说明" },
    { kind: "workflow", id: "wf_9f2a7c1b", label: "pr_merge_flow", desc: "PR 合并后跑测试 + 审批回滚" },
    { kind: "workflow", id: "wf_new", label: "pr_pipeline", desc: "webhook → 测试 → 合并" },
    { kind: "trigger", id: "trg_3a1f8c2d", label: "cron · 每天 9:00", desc: "0 9 * * * 定时" },
    { kind: "approval", id: "apf_release", label: "approve_rollback", desc: "回滚审批门" },
    { kind: "doc", id: "doc_durable", label: "Durable 执行设计", desc: "引擎设计文档" },
  ];

  window.CHAT_CONVOS = {
    // ── 旗舰：多实体右岛（trigger 配置 + function 终端）+ 脚本 live 回合（reasoning → 工具 → 危险确认门 → 终端结果 → subagent 子树 → 回答）──
    cv_daily: {
      id: "cv_daily", title: "竞品动态日报流程", crumb: "Chat", kind: "chat", meta: "claude-opus · 刚刚",
      islands: [
        { id: "trg_3a1f8c2d", kind: "trigger", name: "cron · 9:00", meta: "监听中", views: [
          { key: "detail", label: "配置", rows: [
            { key: "schedule", value: "0 9 * * *" }, { key: "target", value: "fn_5e1a9c4d:run" },
            { key: "tz", value: "Asia/Singapore" }, { key: "listening", value: "true" }, { key: "triggerId", value: "trg_3a1f8c2d" },
          ] },
        ] },
        { id: "fn_5e1a9c4d", kind: "function", name: "sync_inventory", lang: "python", meta: "v1 · env ready", views: [
          { key: "run", label: "终端", args: '{\n  "warehouse": "SG-01"\n}', trace: {
            lines: ["→ spawn sandbox (py3.12)", "fetch_skus(SG-01) → 1,284 skus", "upsert → 1,284 ok", "stdout: synced"],
            result: { st: "ok", out: "{ synced: 1284 }", ms: 842, json: { synced: 1284, warehouse: "SG-01" } } } },
        ] },
      ],
      blocks: [
        { type: "text", role: "user", html: '帮我把 <an-ref-pill kind="function" id="fn_5e1a9c4d" label="sync_inventory" contenteditable="false"></an-ref-pill> 接到每天 9 点的 cron，跑前先手动验一次，并清理 2024 年的过期快照目录。' },
      ],
      autoplay: true,
      turn: [
        { ms: 400, stream: { type: "reasoning", open: true, label: "推理", text: "三件事：①建 cron trigger（0 9 * * *）接到 :run ②手动 run 一次验证 ③Bash 清理 2024 快照（不可逆、需确认）。", tps: 46 } },
        { ms: 600, push: { type: "tool_call", running: true, status: "正在创建 cron trigger…", items: [{ verb: "create_trigger", name: "cron · 0 9 * * *" }] } },
        { ms: 1100, island: { focus: { id: "trg_3a1f8c2d", view: "detail" } }, patch: { type: "tool_call", summary: "已创建 cron trigger 并接线到 sync_inventory:run", items: [
          { verb: "create_trigger", name: "cron · 0 9 * * *", danger: "safe",
            args: { schedule: "0 9 * * *", target: "fn_5e1a9c4d:run", tz: "Asia/Singapore" },
            result: { json: { triggerId: "trg_3a1f8c2d", listening: true } } },
        ] } },
        { ms: 600, push: { type: "tool_call", running: true, status: "手动 run_function 验证…", items: [{ verb: "run_function", name: "sync_inventory" }] } },
        { ms: 300, island: { focus: { id: "fn_5e1a9c4d", view: "run" }, op: "run" } },
        { ms: 200, patch: { type: "tool_call", summary: "sync_inventory 跑通（1,284 skus · 842ms）", items: [
          { verb: "run_function", name: "sync_inventory", danger: "cautious",
            result: { json: { synced: 1284, warehouse: "SG-01", elapsedMs: 842 } } },
        ] } },
        { ms: 600, push: { type: "tool_call", items: [
          { verb: "Bash", name: "Bash", danger: "dangerous", gate: true,
            summary: "将删除 2024 年的过期快照目录（不可逆）。", args: '{\n  "command": "rm -rf /data/snapshots/2024-*"\n}' },
        ] } },
        { gate: {
          onApprove: { ms: 700, patch: { type: "tool_call", summary: "已清理过期快照（释放 3.4 GB）", items: [
            { verb: "Bash", name: "Bash", danger: "dangerous",
              result: { term: "removed /data/snapshots/2024-01 … 2024-12 (12 dirs)\nfreed 3.4 GB\n\n[exit code: 0]" } },
          ] } },
          onDeny: { ms: 300, stream: { type: "text", text: "好的，已**跳过**快照清理，仅保留 cron 接线与一次验证。", tps: 24 } },
        } },
        { ms: 750, push: { type: "subtree", label: "subagent · general-purpose（核对接线）", open: false, blocks: [
          { type: "text", text: "核对 cron trigger 是否真接到 sync_inventory。" },
          { type: "tool_call", items: [{ verb: "get_trigger", name: "trg_3a1f8c2d", result: { json: { schedule: "0 9 * * *", target: "fn_5e1a9c4d:run", listening: true } } }] },
          { type: "text", text: "接线正确，trigger 监听中。" },
        ] } },
        { ms: 500, stream: { type: "text", tps: 22, text: "完成 ✅\n\n- **cron trigger** `trg_3a1f8c2d`（`0 9 * * *`）已接到 `sync_inventory:run`，监听中。\n- 手动验证一次：同步 **1,284** 个 SKU。\n- 过期快照已清理，释放 **3.4 GB**。\n\n右岛可切「cron 配置 / sync_inventory 终端」两个面板。需要再加「失败告警」吗？" } },
      ],
    },

    // ── :iterate 对话：AI 编辑 Function → 右岛流式红绿 Diff（edit_function 写新版本立即生效，可 revert，无草稿/采用门）──
    cv_iterate: {
      id: "cv_iterate", title: "AI 编辑 · sync_inventory 加重试", crumb: "Chat · iterate", kind: "iterate", meta: "claude-opus · 10 分钟前",
      islands: [
        { id: "fn_5e1a9c4d", kind: "function", name: "sync_inventory", lang: "python", meta: "v2 · 已生效", revert: "revert 回 v1", views: [
          { key: "edit", label: "Diff", range: "v1 → v2", note: "加指数退避重试", before: SYNC_V1, after: SYNC_V1 },
          { key: "detail", label: "详情", rows: [
            { key: "functionId", value: "fn_5e1a9c4d" }, { key: "versionId", value: "fnv_7c2e8a1d" },
            { key: "version", value: "2" }, { key: "envStatus", value: "ready" }, { key: "opsApplied", value: "1" },
          ] },
        ] },
      ],
      blocks: [
        { type: "text", role: "user", html: '给 <an-ref-pill kind="function" id="fn_5e1a9c4d" label="sync_inventory" contenteditable="false"></an-ref-pill> 加失败重试：网络抖动时指数退避重试 3 次。' },
      ],
      autoplay: true,
      turn: [
        { ms: 400, stream: { type: "reasoning", open: true, label: "推理", tps: 46, text: "读 sync_inventory 现有定义 → 在 upsert 外包一层指数退避重试（3 次）。调 edit_function 写新版本 v2，立即生效；用户不满意可 revert 回旧版本号。" } },
        { ms: 600, push: { type: "tool_call", running: true, status: "正在编辑 sync_inventory…", items: [{ verb: "edit_function", name: "sync_inventory" }] } },
        { ms: 350, island: { focus: { id: "fn_5e1a9c4d", view: "edit" }, op: "edit", before: SYNC_V1, after: SYNC_V2, cps: 170 } },
        { ms: 400, patch: { type: "tool_call", summary: "已编辑 sync_inventory → 新版本 v2（立即生效）", items: [
          { verb: "edit_function", name: "sync_inventory", danger: "cautious",
            result: { json: { id: "fn_5e1a9c4d", versionId: "fnv_7c2e8a1d", version: 2, envStatus: "ready", opsApplied: 1 } } },
        ] } },
        { ms: 400, stream: { type: "text", tps: 22, text: "已更新到 **v2**（**立即生效**，见右侧红绿 Diff）：`upsert` 失败时按指数退避（1s/2s）重试，最多 3 次。\n\n不满意可让我 **revert** 回 v1；要改重试次数也告诉我。" } },
      ],
    },

    // ── 新建 Handler：create_handler 流式 class 源码 → update_handler_config 配置 → call_handler 终端（常驻进程 RPC）──
    cv_handler: {
      id: "cv_handler", title: "接 Slack 客户端 + 试调", crumb: "Chat", kind: "chat", meta: "claude-opus · 20 分钟前",
      islands: [
        { id: "hd_4c1a9f02", kind: "handler", name: "slack_client", lang: "python", meta: "v1 · 待启动", revert: "revert 回退", views: [
          { key: "create", label: "新建", code: HD_SRC },
          { key: "config", label: "配置", rows: [
            { key: "bot_token", value: "xoxb-••••••••" }, { key: "default_channel", value: "#alerts" }, { key: "instanceId", value: "hdi_2c9a（首调启动）" },
          ] },
          { key: "run", label: "终端", args: '{\n  "method": "post_message",\n  "args": { "channel": "#alerts", "text": "build green ✅" }\n}', trace: {
            lines: ["→ RPC post_message → instance hdi_2c9a", "yield: resolving channel #alerts", "yield: posting…", "stdout: ok ts=1718.45"],
            result: { st: "ok", out: "{ ok: true, ts: '1718.45' }", ms: 312, json: { ok: true, channel: "C012", ts: "1718.45" } } } },
        ] },
      ],
      blocks: [
        { type: "text", role: "user", text: "帮我接一个常驻 Slack 客户端，能往 #alerts 发消息。" },
      ],
      autoplay: true,
      turn: [
        { ms: 400, stream: { type: "reasoning", open: true, label: "推理", tps: 46, text: "Handler = 常驻进程实体。create_handler 写一个 class（__init__ 建 WebClient + post_message 方法），首版立即生效但不启动进程；填 config（token）后首次 call 才按 __init__ 启动实例。" } },
        { ms: 600, push: { type: "tool_call", running: true, status: "正在创建 slack_client…", items: [{ verb: "create_handler", name: "slack_client" }] } },
        { ms: 300, island: { focus: { id: "hd_4c1a9f02", view: "create" }, op: "create", code: HD_SRC, cps: 200 } },
        { ms: 300, patch: { type: "tool_call", summary: "已创建 slack_client → v1（类已生效，进程待启动）", items: [
          { verb: "create_handler", name: "slack_client", danger: "cautious",
            result: { json: { id: "hd_4c1a9f02", versionId: "hdv_1a2b3c", version: 1, members: ["post_message"], instance: "not_started" } } },
        ] } },
        { ms: 500, stream: { type: "text", tps: 24, text: "class 已建好（右侧『新建』）。常驻实例需要 config + 首调才启动——我把 Slack token 填进 config。" } },
        { ms: 600, push: { type: "tool_call", running: true, status: "写 handler config（加密存储）…", items: [{ verb: "update_handler_config", name: "slack_client" }] } },
        { ms: 300, island: { focus: { id: "hd_4c1a9f02", view: "config" } }, patch: { type: "tool_call", summary: "已写 config（整 blob 重加密，实例将于首调启动）", items: [
          { verb: "update_handler_config", name: "slack_client", danger: "cautious",
            result: { json: { handlerId: "hd_4c1a9f02", configKeys: ["bot_token", "default_channel"], willRestart: true } } },
        ] } },
        { ms: 500, stream: { type: "text", tps: 24, text: "config 已加密存好。试调一次 `post_message`（首调会按 `__init__` 启动常驻实例）：" } },
        { ms: 600, push: { type: "tool_call", running: true, status: "call_handler post_message…", items: [{ verb: "call_handler", name: "slack_client" }] } },
        { ms: 300, island: { focus: { id: "hd_4c1a9f02", view: "run" }, op: "run" } },
        { ms: 200, patch: { type: "tool_call", summary: "post_message 调通（instance hdi_2c9a · 312ms）", items: [
          { verb: "call_handler", name: "slack_client", danger: "cautious",
            result: { json: { ok: true, channel: "C012", ts: "1718.45", instanceId: "hdi_2c9a" } } },
        ] } },
        { ms: 500, stream: { type: "text", tps: 22, text: "**slack_client** 已就绪：`post_message` 调通，返回 `ts`。右岛三面板：新建源码 / 配置 / 终端。\n\n要不要把它接到某个 workflow 的告警节点？" } },
      ],
    },

    // ── 综合场景：ask_user 提问门 + todo 看板（同步喂右岛 Todo tab）+ 并行工具批 + 多形态结果 + progress live 流（无实体右岛、仅 Todo）──
    cv_research: {
      id: "cv_research", title: "调研竞品 durable 方案", crumb: "Chat", kind: "chat", meta: "claude-opus · 30 分钟前",
      todo: true,
      blocks: [
        { type: "text", role: "user", text: "调研一下竞品的 durable execution 方案，整理成要点。" },
      ],
      autoplay: true,
      turn: [
        { ms: 400, stream: { type: "reasoning", open: true, label: "推理", tps: 46, text: "先确认要点语言，再列任务清单 → 并行检索 → 抓正文 → 汇总。" } },
        // ask_user 提问门（accept{answer}/decline，options 单选）——区别于 danger 确认门
        { ms: 500, push: { type: "tool_call", items: [
          { verb: "ask_user", name: "ask_user", ask: { message: "要点用中文还是英文整理？", options: ["中文", "英文", "中英对照"] } },
        ] } },
        { gate: {
          onApprove: { ms: 400, push: { type: "text", text: "好，用**中文**整理。" } },
          onDeny: { ms: 400, push: { type: "text", text: "好，我按默认中文整理。" } },
        } },
        // todo 看板（LLM 规划任务，整表写入；恰一项 in_progress）——同步喂对话流 todo 块 + 右岛 Todo tab
        { ms: 600, push: { type: "todo", open: true, items: [
          { content: "并行检索竞品 durable 资料", status: "in_progress", activeForm: "正在检索竞品资料" },
          { content: "抓取并摘要各家文档", status: "pending" },
          { content: "汇总成中文要点", status: "pending" },
        ] }, islandTodo: [
          { content: "并行检索竞品 durable 资料", status: "in_progress", activeForm: "正在检索竞品资料" },
          { content: "抓取并摘要各家文档", status: "pending" },
          { content: "汇总成中文要点", status: "pending" },
        ] },
        // 并行工具批（同 executionGroup：3 项同时 running → 一并 settle；含 1 个 tool error）
        { ms: 700, push: { type: "tool_call", summary: "并行检索 3 个来源（executionGroup）", items: [
          { verb: "WebSearch", name: "Temporal durable execution", running: true },
          { verb: "WebSearch", name: "Restate durable", running: true },
          { verb: "Read", name: "docs/competitors.md", running: true },
        ] } },
        { ms: 1500, patch: { type: "tool_call", summary: "检索完成（2 成功 · 1 失败）", items: [
          { verb: "WebSearch", name: "Temporal durable execution", result: { list: [
            { title: "Temporal: Durable Execution", meta: "temporal.io", hint: "事件溯源 + 确定性重放，用户代码重跑" },
            { title: "Workflow as Code", meta: "docs.temporal.io", hint: "SDK 内写 workflow，引擎负责持久化" },
          ] } },
          { verb: "WebSearch", name: "Restate durable", result: { list: [
            { title: "Restate: Durable Execution & State", meta: "restate.dev", hint: "日志式 durable，handler 侵入式 SDK" },
          ] } },
          { verb: "Read", name: "docs/competitors.md", error: "ENOENT: no such file or directory, open 'docs/competitors.md'" },
        ] } },
        { ms: 600, push: { type: "todo", open: true, items: [
          { content: "并行检索竞品 durable 资料", status: "completed" },
          { content: "抓取并摘要各家文档", status: "in_progress", activeForm: "正在抓取 temporal.io/docs" },
          { content: "汇总成中文要点", status: "pending" },
        ] }, islandTodo: [
          { content: "并行检索竞品 durable 资料", status: "completed" },
          { content: "抓取并摘要各家文档", status: "in_progress", activeForm: "正在抓取 temporal.io/docs" },
          { content: "汇总成中文要点", status: "pending" },
        ] },
        // progress 终端式 live 流（WebFetch 抓正文，逐行脉冲）
        { ms: 500, push: { type: "tool_call", running: true, status: "WebFetch temporal.io/docs…", items: [{ verb: "WebFetch", name: "temporal.io/docs" }] } },
        { progressStream: { label: "WebFetch · temporal.io/docs", lps: 5, lines: ["→ GET https://temporal.io/docs", "← 200 (text/html · 84 KB)", "提取正文 → markdown", "摘要 3 段"] } },
        { ms: 300, patch: { type: "tool_call", summary: "已抓取并摘要 temporal.io/docs", items: [
          { verb: "WebFetch", name: "temporal.io/docs", result: { text: "Temporal 用事件溯源 + 确定性重放实现 durable：workflow 代码须确定性、崩溃后逐事件重放还原状态。（已摘要 3 段）" } },
        ] } },
        { ms: 500, push: { type: "todo", open: false, items: [
          { content: "并行检索竞品 durable 资料", status: "completed" },
          { content: "抓取并摘要各家文档", status: "completed" },
          { content: "汇总成中文要点", status: "completed" },
        ] }, islandTodo: [
          { content: "并行检索竞品 durable 资料", status: "completed" },
          { content: "抓取并摘要各家文档", status: "completed" },
          { content: "汇总成中文要点", status: "completed" },
        ] },
        { ms: 500, stream: { type: "text", tps: 22, text: "调研要点 ✅\n\n- **Temporal**：事件溯源 + 确定性重放（用户代码重跑），心智重。\n- **Restate**：日志式 durable，handler SDK 侵入。\n- **本项目（Anselm）**：**节点结果记忆化 + 解释器幂等重走**——无用户代码重放，心智更简。\n\n（`docs/competitors.md` 不存在，已跳过本地文档。右岛 Todo 看板同步了进度。）" } },
      ],
    },

    // ── 新建 Agent：create_agent 流式指令 + 配置/挂载（声明式实体，无 code body，tool 宇宙 = 挂载集）→ invoke_agent 轨迹 ──
    cv_agent_new: {
      id: "cv_agent_new", title: "造一个发布说明 Agent", crumb: "Chat", kind: "chat", meta: "claude-opus · 40 分钟前",
      islands: [
        { id: "ag_release", kind: "agent", name: "release_notes_agent", lang: "markdown", meta: "v1 · 已生效", revert: "revert 回退", views: [
          { key: "create", label: "指令", code: AG_PROMPT },
          { key: "config", label: "配置", rows: [
            { key: "model", value: "claude-opus" }, { key: "maxTurns", value: "6" }, { key: "input", value: "pr_url: string" }, { key: "output", value: "notes: string" },
          ] },
          { key: "mounts", label: "挂载", rows: [
            { key: "WebFetch", value: "✓ 系统 IO" }, { key: "fn_3b2c7e10 · fetch_article", value: "✓ 已解析" }, { key: "get_function", value: "✓ 实体读" },
          ] },
          { key: "trace", label: "轨迹", blocks: [
            { type: "reasoning", label: "推理", text: "取 PR diff 正文 → 归类 feat/fix/chore → 生成发布说明。" },
            { type: "tool_call", items: [{ verb: "WebFetch", name: "github.com/anselm/pull/482.diff", result: { text: "+ feat: durable retry on fetch\n+ fix: 429 backoff\n（已摘要）" } }] },
            { type: "text", text: "## v0.3.1\n- **feat**: fetch 节点 durable 重试\n- **fix**: 429 限流退避" },
          ] },
        ] },
      ],
      blocks: [
        { type: "text", role: "user", text: "造一个 Agent：读 PR 的 diff，写一段 Markdown 发布说明。" },
      ],
      autoplay: true,
      turn: [
        { ms: 400, stream: { type: "reasoning", open: true, label: "推理", tps: 46, text: "Agent 是声明式实体：指令 + 挂载工具，无 code body。create_agent 写 prompt + 挂 WebFetch / fetch_article；它的 tool 宇宙 = 挂载集，永远看不到通用系统工具。" } },
        { ms: 600, push: { type: "tool_call", running: true, status: "正在创建 release_notes_agent…", items: [{ verb: "create_agent", name: "release_notes_agent" }] } },
        { ms: 300, island: { focus: { id: "ag_release", view: "create" }, op: "create", code: AG_PROMPT, cps: 150 } },
        { ms: 300, patch: { type: "tool_call", summary: "已创建 release_notes_agent → v1（立即生效）", items: [
          { verb: "create_agent", name: "release_notes_agent", danger: "cautious",
            result: { json: { id: "ag_release", versionId: "agv_9f1e", version: 1, tools: ["WebFetch", "fn_3b2c7e10"], mounts: "resolved" } } },
        ] } },
        { ms: 500, stream: { type: "text", tps: 24, text: "指令写好了（右侧『指令』）。它只能用挂载的工具（**WebFetch + fetch_article**），配置见『配置』/『挂载』。跑一次 `invoke` 试试：" } },
        { ms: 600, push: { type: "tool_call", running: true, status: "invoke release_notes_agent…", items: [{ verb: "invoke_agent", name: "release_notes_agent" }] } },
        { ms: 300, island: { focus: { id: "ag_release", view: "trace" }, op: "trace" } },
        { ms: 200, patch: { type: "tool_call", summary: "invoke 完成（2 步 · completed）", items: [
          { verb: "invoke_agent", name: "release_notes_agent", danger: "safe",
            args: { agentId: "ag_release", input: { pr_url: "github.com/anselm/pull/482" } },
            result: { json: { ok: true, output: { notes: "## v0.3.1\n- feat: durable retry\n- fix: 429 backoff" }, executionId: "agx_7a2c", status: "completed", steps: 2 } } },
        ] } },
        { ms: 500, stream: { type: "text", tps: 22, text: "**release_notes_agent** 已就绪，invoke 跑通，产出发布说明（右岛『轨迹』是它的 ReAct，耐久在 Execution.transcript）。\n\n要不要接到 `pr_merge_flow` 的合并后节点，自动发说明？" } },
      ],
    },

    // ── :triage 对话：诊断失败 flowrun → 右岛 Workflow 运行图（fetch 红）+ Agent 轨迹 + Workflow 图 Diff（多实体 tab + 多子视图）──
    cv_triage: {
      id: "cv_triage", title: "诊断 · flowrun frn_8a1c 失败", crumb: "Chat · triage", kind: "triage", meta: "claude-opus · 1 时前",
      islands: [
        { id: "wf_9f2a7c1b", kind: "workflow", name: "pr_merge_flow", lang: "json", meta: "v5 · 已生效", revert: "revert 回 v4", views: [
          { key: "flowrun", label: "运行图", nodes: [
            { id: "trigger", kind: "trigger", label: "pr.webhook", status: "completed", atPct: 0, wPct: 10 },
            { id: "fetch", kind: "action", label: "fetch", status: "failed", atPct: 12, wPct: 38 },
            { id: "transform", kind: "action", label: "transform", status: "completed", atPct: 12, wPct: 26 },
            { id: "approve", kind: "approval", label: "approve_merge", status: "future", atPct: 0, wPct: 0 },
          ] },
          { key: "edit", label: "图 Diff", range: "v4 → v5", note: "给 fetch 加 durable 重试 + trigger 改 serial", before: WF_V4, after: WF_V4 },
          { key: "detail", label: "flowrun", rows: [
            { key: "flowrunId", value: "frn_8a1c4f2e" }, { key: "status", value: "failed" }, { key: "versionId", value: "wfv_3d9a1b" }, { key: "failedNode", value: "fetch · HTTP 429" },
          ] },
        ] },
        { id: "ag_91c3de07", kind: "agent", name: "triage_agent", meta: "completed · 3 步", views: [
          { key: "trace", label: "轨迹", blocks: [
            { type: "reasoning", label: "推理", text: "读 fetch 节点 input/output + 上游 trigger 并发配置，判断瞬时限流还是配额耗尽。" },
            { type: "tool_call", items: [{ verb: "get_trigger", name: "trg_pr_webhook", result: { json: { concurrency: "all_allow", rateLimit: "none" } } }] },
            { type: "text", text: "上游 trigger 并发 all_allow → 瞬时打爆下游限流（429）。建议 fetch 加 durable 重试 + trigger 改 serial。" },
          ] },
        ] },
      ],
      blocks: [
        { type: "text", role: "user", text: "这个 flowrun 为什么失败了？帮我看看。" },
      ],
      autoplay: true,
      turn: [
        { ms: 400, stream: { type: "reasoning", open: true, label: "推理", tps: 46, text: "triage 上下文已注入失败 flowrun 的全节点行。先 get_flowrun 看哪一步 failed、错误是什么。" } },
        { ms: 600, push: { type: "tool_call", running: true, status: "读取 flowrun 头 + 全节点记忆化结果…", items: [{ verb: "get_flowrun", name: "frn_8a1c…" }] } },
        { ms: 300, island: { focus: { id: "wf_9f2a7c1b", view: "flowrun" }, op: "flowrun", lps: 3, nodes: [
          { id: "trigger", kind: "trigger", label: "pr.webhook", status: "completed", atPct: 0, wPct: 10 },
          { id: "fetch", kind: "action", label: "fetch", status: "failed", atPct: 12, wPct: 38 },
          { id: "transform", kind: "action", label: "transform", status: "completed", atPct: 12, wPct: 26 },
          { id: "approve", kind: "approval", label: "approve_merge", status: "future", atPct: 0, wPct: 0 },
        ] } },
        { ms: 300, patch: { type: "tool_call", summary: "flowrun frn_8a1c 失败于 fetch（HTTP 429）", items: [
          { verb: "get_flowrun", name: "frn_8a1c…", danger: "safe",
            result: { json: { flowrun: { id: "frn_8a1c4f2e", status: "failed", versionId: "wfv_3d9a1b" }, nodes: [
              { nodeId: "fetch", iteration: 0, kind: "action", status: "failed", error: "HTTP 429 Too Many Requests" },
              { nodeId: "transform", iteration: 0, kind: "action", status: "completed" },
            ] } } },
        ] } },
        { ms: 500, stream: { type: "text", tps: 24, text: "右岛运行图：**`fetch`** 红了（HTTP 429）。深一层用 `invoke_agent` 看根因——是瞬时限流还是配额耗尽：" } },
        { ms: 600, push: { type: "tool_call", running: true, status: "invoke triage_agent 深度诊断…", items: [{ verb: "invoke_agent", name: "triage_agent" }] } },
        { ms: 300, island: { focus: { id: "ag_91c3de07", view: "trace" }, op: "trace" } },
        { ms: 200, patch: { type: "tool_call", summary: "triage_agent 诊断完成：瞬时限流 + fetch 无重试", items: [
          { verb: "invoke_agent", name: "triage_agent", danger: "safe",
            args: { agentId: "ag_91c3de07", input: { flowrunId: "frn_8a1c4f2e" } },
            result: { json: { ok: true, output: { rootCause: "瞬时限流 + fetch 无重试", fix: "fetch 加 durable 重试 + trigger 改 serial" }, executionId: "agx_5d1f", status: "completed", steps: 3 } } },
        ] } },
        { ms: 500, stream: { type: "text", tps: 24, text: "根因：上游 trigger 并发 `all_allow` 瞬时打爆下游 → **429**，且 `fetch` 没配 durable 重试。我直接 `edit_workflow` 给 fetch 加重试 + trigger 改 serial（写新版本立即生效）：" } },
        { ms: 600, push: { type: "tool_call", running: true, status: "edit_workflow：fetch 加重试 + trigger 改 serial…", items: [{ verb: "edit_workflow", name: "pr_merge_flow" }] } },
        { ms: 300, island: { focus: { id: "wf_9f2a7c1b", view: "edit" }, op: "edit", before: WF_V4, after: WF_V5, cps: 150 } },
        { ms: 300, patch: { type: "tool_call", summary: "已 edit_workflow → 新版本 v5（立即生效）", items: [
          { verb: "edit_workflow", name: "pr_merge_flow", danger: "cautious",
            result: { json: { id: "wf_9f2a7c1b", versionId: "wfv_4e2a7c", version: 5, opsApplied: 2 } } },
        ] } },
        { ms: 500, stream: { type: "text", tps: 22, text: "修复已写入 **v5**（**立即生效**，见右岛『图 Diff』）：`fetch` 加 3 次指数退避重试、`trigger` 改 serial。\n\n我**不会自动重跑**——请到 Scheduler 对 `frn_8a1c…` 点 **replay**（物删 failed 行后幂等重走）。" } },
        { ms: 400, push: { type: "compaction", coversUpToSeq: 18, summarizedCount: 6 } },
      ],
    },

    // ── 搭 Workflow：create_workflow 流式 graph ops + 三层校验 → trigger_workflow 冒烟跑（节点点亮）+ Todo 规划（多 tab：workflow + Todo）──
    cv_workflow_build: {
      id: "cv_workflow_build", title: "搭 PR 合并流水线", crumb: "Chat", kind: "chat", meta: "claude-opus · 1 时前",
      todo: true,
      islands: [
        { id: "wf_new", kind: "workflow", name: "pr_pipeline", lang: "json", meta: "v1 · 已校验", revert: "revert 回退", views: [
          { key: "create", label: "新建图", code: WFB_OPS },
          { key: "flowrun", label: "运行图", nodes: [
            { id: "trigger", kind: "trigger", label: "pr.webhook", status: "completed", atPct: 0, wPct: 8 },
            { id: "test", kind: "action", label: "run_tests", status: "completed", atPct: 10, wPct: 46 },
            { id: "gate", kind: "approval", label: "approve_merge", status: "completed", atPct: 58, wPct: 6 },
            { id: "merge", kind: "action", label: "merge_pr", status: "completed", atPct: 66, wPct: 22 },
          ] },
          { key: "detail", label: "校验", rows: [
            { key: "nodes", value: "4" }, { key: "edges", value: "3" }, { key: "validate", value: "✓ CEL 编译 + 祖先可见性" }, { key: "capability", value: "✓ 引用实体齐备" },
          ] },
        ] },
      ],
      blocks: [
        { type: "text", role: "user", text: "搭一条 PR 合并流水线：webhook 触发 → 跑测试 → 通过则人审后合并。" },
      ],
      autoplay: true,
      turn: [
        { ms: 400, stream: { type: "reasoning", open: true, label: "推理", tps: 46, text: "先列建图步骤，再 create_workflow 钉静态 DAG（此实体只存/校验/钉图，执行归 scheduler）。三层校验过了再 trigger 跑一次冒烟。" } },
        { ms: 500, push: { type: "todo", open: true, items: [
          { content: "建 pr_pipeline 图（test → gate → merge）", status: "in_progress", activeForm: "正在建图" },
          { content: "三层校验（CEL + 可见性 + capability）", status: "pending" },
          { content: "trigger 跑一次冒烟", status: "pending" },
        ] }, islandTodo: [
          { content: "建 pr_pipeline 图（test → gate → merge）", status: "in_progress", activeForm: "正在建图" },
          { content: "三层校验（CEL + 可见性 + capability）", status: "pending" },
          { content: "trigger 跑一次冒烟", status: "pending" },
        ] },
        { ms: 600, push: { type: "tool_call", running: true, status: "create_workflow：拼 graph ops…", items: [{ verb: "create_workflow", name: "pr_pipeline" }] } },
        { ms: 300, island: { focus: { id: "wf_new", view: "create" }, op: "create", code: WFB_OPS, cps: 200 } },
        { ms: 300, patch: { type: "tool_call", summary: "已 create_workflow → v1（三层校验通过）", items: [
          { verb: "create_workflow", name: "pr_pipeline", danger: "cautious",
            result: { json: { id: "wf_new", versionId: "wfv_a1", version: 1, nodes: 4, validate: "ok", capability: "ok" } } },
        ] } },
        { ms: 400, push: { type: "todo", open: true, items: [
          { content: "建 pr_pipeline 图（test → gate → merge）", status: "completed" },
          { content: "三层校验（CEL + 可见性 + capability）", status: "completed" },
          { content: "trigger 跑一次冒烟", status: "in_progress", activeForm: "正在冒烟" },
        ] }, islandTodo: [
          { content: "建 pr_pipeline 图（test → gate → merge）", status: "completed" },
          { content: "三层校验（CEL + 可见性 + capability）", status: "completed" },
          { content: "trigger 跑一次冒烟", status: "in_progress", activeForm: "正在冒烟" },
        ] },
        { ms: 500, stream: { type: "text", tps: 24, text: "图建好并通过三层校验（右岛『校验』全绿）。trigger 跑一次冒烟：" } },
        { ms: 600, push: { type: "tool_call", running: true, status: "trigger_workflow 冒烟…", items: [{ verb: "trigger_workflow", name: "pr_pipeline" }] } },
        { ms: 300, island: { focus: { id: "wf_new", view: "flowrun" }, op: "flowrun", lps: 4, nodes: [
          { id: "trigger", kind: "trigger", label: "pr.webhook", status: "completed", atPct: 0, wPct: 8 },
          { id: "test", kind: "action", label: "run_tests", status: "completed", atPct: 10, wPct: 46 },
          { id: "gate", kind: "approval", label: "approve_merge", status: "completed", atPct: 58, wPct: 6 },
          { id: "merge", kind: "action", label: "merge_pr", status: "completed", atPct: 66, wPct: 22 },
        ] } },
        { ms: 300, patch: { type: "tool_call", summary: "冒烟跑通：flowrun frn_smoke 4 节点全绿", items: [
          { verb: "trigger_workflow", name: "pr_pipeline", danger: "cautious",
            result: { json: { flowrunId: "frn_smoke01", status: "completed", nodes: 4, elapsedMs: 5210 } } },
        ] } },
        { ms: 400, push: { type: "todo", open: false, items: [
          { content: "建 pr_pipeline 图（test → gate → merge）", status: "completed" },
          { content: "三层校验（CEL + 可见性 + capability）", status: "completed" },
          { content: "trigger 跑一次冒烟", status: "completed" },
        ] }, islandTodo: [
          { content: "建 pr_pipeline 图（test → gate → merge）", status: "completed" },
          { content: "三层校验（CEL + 可见性 + capability）", status: "completed" },
          { content: "trigger 跑一次冒烟", status: "completed" },
        ] },
        { ms: 500, stream: { type: "text", tps: 22, text: "**pr_pipeline** 上线：冒烟跑通（4 节点全绿，见右岛『运行图』）。右岛两 tab：workflow + Todo。\n\n需要我把它接到真实 PR webhook（serial 并发）吗？" } },
      ],
    },

    // ── 完成态静态 transcript（edit_function 写完即 active，无 pending；max_steps 诚实终态）：右岛 Function 静态 Diff（非流式重建）──
    cv_invoice: {
      id: "cv_invoice", title: "发票处理 v3 迭代", crumb: "Chat", kind: "chat", meta: "claude-opus · 昨天 18:20",
      islands: [
        { id: "fn_9b3c1a2d", kind: "function", name: "validate_invoice", lang: "python", meta: "v3 · 已生效", revert: "revert 回 v2", views: [
          { key: "edit", label: "Diff", range: "v2 → v3", note: "金额校验放宽 ±0.01", before: INV_V2, after: INV_V3 },
          { key: "detail", label: "详情", rows: [
            { key: "functionId", value: "fn_9b3c1a2d" }, { key: "versionId", value: "fnv_4a1b6e22" }, { key: "version", value: "3" }, { key: "envStatus", value: "ready" },
          ] },
        ] },
      ],
      blocks: [
        { type: "text", role: "user", text: "把发票金额校验改成允许 ±1 分的误差。" },
        { type: "tool_call", summary: "编辑 validate_invoice：金额校验放宽 ±0.01", items: [
          { verb: "edit_function", name: "validate_invoice", danger: "cautious",
            result: { json: { id: "fn_9b3c1a2d", versionId: "fnv_4a1b6e22", version: 3, envStatus: "ready", opsApplied: 1 } } },
        ] },
        { type: "text", text: "已更新到 **v3**（立即生效，右岛 Diff）：金额校验现允许 ±0.01 的舍入误差，其余规则不变。" },
        { type: "turnEnd", stopReason: "max_steps", code: "MAX_STEPS_REACHED" },
      ],
    },

    // ── 归档静态（无实体右岛）──
    cv_weekly: {
      id: "cv_weekly", title: "周报汇总", crumb: "Chat · 已归档", kind: "chat", meta: "上周",
      blocks: [
        { type: "text", role: "user", text: "汇总本周三条 workflow 的运行情况成一段周报。" },
        { type: "text", text: "本周 3 条 workflow 共运行 142 次，成功率 97.2%；`pr_merge_flow` 触发 1 次审批回滚，其余正常。详情见各 run 记录。" },
      ],
    },
  };
})();
