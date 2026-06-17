/* Anselm feature — chat 种子数据（会话列表 + @提及池 + 脚本化 live 回合）。
   后端心智：conversation 是纯线程容器（消息单独取）；一次 Send = 202 + messages SSE 流式回合（每对话同时只一个在途回合）。
   :iterate（AI 编辑实体）/ :triage（AI 诊断执行）都返 conversationId 当普通对话接管——故 chat 是所有 AI 对话的唯一容器。
   【契约铁律】edit_ / create_ 工具写完新版本【立即生效】——后端【无】pending/草稿/采用/审批门；切版本唯一手段是 revert_ 工具（移 active 指针）。
   工具名必须用后端真名：Bash（非 run_shell）· get_trigger/get_flowrun（非 read_*）· WebSearch/WebFetch/Read（首字母大写）· create_trigger · edit_function · invoke_agent · todo_write …
   data 形态：CHAT_CONVOS[id] = { title, crumb, meta, kind, blocks(初始 transcript), autoplay?, turn?(脚本步), island?(右岛 = entities build 流镜像，立即生效) }。
   脚本步（sea 小解释器消费，对齐后端 Open→Delta*→Close）：
     { ms, push } 追加块（=Open）· { ms, patch } 替换末块（running→settled）· { stream:{type,text,tps} } 文本/推理逐 token（=Delta）·
     { islandStream:{code,cps} } 右岛代码逐字（build 流镜像）· { progressStream:{lines,lps} } progress 终端逐行（live 脉冲）· { gate:{onApprove,onDeny} } 等 an-decide（danger approve/deny · ask accept/decline）。 */
(function () {
  // 会话列表（rail）：置顶 / 今天 / 昨天 / 已归档。dot 只映射【isGenerating】（在途回合=run，否则无 dot）——conversation 无 wait/err/done 等对话级态。
  window.CHAT_CONVOS_LIST = [
    { group: "置顶", open: true, rows: [
      { id: "cv_daily", label: "竞品动态日报流程", dot: "run", meta: "刚刚" },
    ]},
    { group: "今天", open: true, rows: [
      { id: "cv_iterate", label: "AI 编辑 · sync_inventory 加重试", meta: "10 分钟前" },
      { id: "cv_research", label: "调研竞品 durable 方案", meta: "30 分钟前" },
      { id: "cv_triage", label: "诊断 · flowrun frn_8a1c 失败", meta: "1 时前" },
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
    { kind: "workflow", id: "wf_9f2a7c1b", label: "pr_merge_flow", desc: "PR 合并后跑测试 + 审批回滚" },
    { kind: "trigger", id: "trg_3a1f8c2d", label: "cron · 每天 9:00", desc: "0 9 * * * 定时" },
    { kind: "approval", id: "apf_release", label: "approve_rollback", desc: "回滚审批门" },
    { kind: "doc", id: "doc_durable", label: "Durable 执行设计", desc: "引擎设计文档" },
  ];

  window.CHAT_CONVOS = {
    // ── 旗舰：脚本 live 回合（reasoning → tool_call → 危险确认门 → 终端结果 → subagent 子树 → 回答）──
    cv_daily: {
      id: "cv_daily", title: "竞品动态日报流程", crumb: "Chat", kind: "chat", meta: "claude-opus · 刚刚",
      blocks: [
        { type: "text", role: "user", html: '帮我把 <an-ref-pill kind="function" id="fn_5e1a9c4d" label="sync_inventory" contenteditable="false"></an-ref-pill> 接到每天 9 点的 cron，并清理 2024 年的过期快照目录。' },
      ],
      autoplay: true,
      turn: [
        { ms: 400, stream: { type: "reasoning", open: true, label: "推理", text: "用户要两件事：①每天 9:00 定时跑 sync_inventory ②清理 2024 过期快照。\n先建 cron trigger（0 9 * * *）接线到 :run；再用 Bash 清理（不可逆，需逐次确认）。", tps: 46 } },
        { ms: 600, push: { type: "tool_call", running: true, status: "正在创建 cron trigger…", items: [{ verb: "create_trigger", name: "cron · 0 9 * * *" }] } },
        { ms: 1200, patch: { type: "tool_call", open: true, summary: "已创建 cron trigger 并接线到 sync_inventory:run", items: [
          { verb: "create_trigger", name: "cron · 0 9 * * *", danger: "safe",
            args: { schedule: "0 9 * * *", target: "fn_5e1a9c4d:run", tz: "Asia/Singapore" },
            result: { json: { triggerId: "trg_3a1f8c2d", listening: true } } },
        ] } },
        { ms: 750, push: { type: "tool_call", open: true, items: [
          { verb: "Bash", name: "Bash", danger: "dangerous", gate: true,
            summary: "将删除 2024 年的过期快照目录（不可逆）。",
            args: '{\n  "command": "rm -rf /data/snapshots/2024-*"\n}' },
        ] } },
        { gate: {
          // Bash 结果是【终端文本】（合并 stdout+stderr + [exit code: N] 页脚），非 JSON → term 形态
          onApprove: { ms: 700, patch: { type: "tool_call", open: true, summary: "已清理过期快照（释放 3.4 GB）", items: [
            { verb: "Bash", name: "Bash", danger: "dangerous",
              result: { term: "removed /data/snapshots/2024-01 … 2024-12 (12 dirs)\nfreed 3.4 GB\n\n[exit code: 0]" } },
          ] } },
          onDeny: { ms: 300, stream: { type: "text", text: "好的，已**跳过**快照清理，仅保留 cron 接线。需要清理时再告诉我。", tps: 24 } },
        } },
        // general-purpose subagent（有实体读工具 get_trigger；Explore 仅 Read/LS/Glob/Grep 无此权）
        { ms: 750, push: { type: "subtree", label: "subagent · general-purpose（核对接线）", open: false, blocks: [
          { type: "text", text: "核对 cron trigger 是否真接到 sync_inventory。" },
          { type: "tool_call", open: true, items: [{ verb: "get_trigger", name: "trg_3a1f8c2d", result: { json: { schedule: "0 9 * * *", target: "fn_5e1a9c4d:run", listening: true } } }] },
          { type: "text", text: "接线正确，trigger 监听中。" },
        ] } },
        { ms: 500, stream: { type: "text", tps: 22, text: "完成 ✅\n\n- **cron trigger** `trg_3a1f8c2d`（`0 9 * * *`）已接到 `sync_inventory:run`，监听中。\n- 过期快照已清理，释放 **3.4 GB**。\n\n每天 9:00 会自动同步库存。需要我再加一条「失败时告警」吗？" } },
      ],
    },

    // ── :iterate 对话：AI 编辑实体 → 右岛订阅 entities build 流实时填充【新 active 版本】（立即生效，可 revert，无草稿/采用门）──
    cv_iterate: {
      id: "cv_iterate", title: "AI 编辑 · sync_inventory 加重试", crumb: "Chat · iterate", kind: "iterate", meta: "claude-opus · 10 分钟前",
      island: { entity: "sync_inventory", kind: "function", lang: "python", version: "v2" },
      blocks: [
        { type: "text", role: "user", html: '给 <an-ref-pill kind="function" id="fn_5e1a9c4d" label="sync_inventory" contenteditable="false"></an-ref-pill> 加失败重试：网络抖动时指数退避重试 3 次。' },
      ],
      autoplay: true,
      turn: [
        { ms: 400, stream: { type: "reasoning", open: true, label: "推理", tps: 46, text: "读 sync_inventory 现有定义 → 在 upsert 外包一层指数退避重试（3 次）。调 edit_function 写新版本 v2，立即生效；用户不满意可 revert 回旧版本号。" } },
        { ms: 600, push: { type: "tool_call", running: true, status: "正在编辑 sync_inventory…", items: [{ verb: "edit_function", name: "sync_inventory" }] } },
        { ms: 350, islandStream: { cps: 150, code: "import time, requests\n\ndef sync_inventory(warehouse, dry_run=False):\n    skus = fetch_skus(warehouse)\n    for attempt in range(3):            # 指数退避重试\n        try:\n            return upsert(skus, dry_run=dry_run)\n        except requests.RequestException:\n            if attempt == 2: raise\n            time.sleep(2 ** attempt)\n" } },
        { ms: 400, patch: { type: "tool_call", open: true, summary: "已编辑 sync_inventory → 新版本 v2（立即生效）", items: [
          { verb: "edit_function", name: "sync_inventory", danger: "cautious",
            result: { json: { id: "fn_5e1a9c4d", versionId: "fnv_7c2e8a1d", version: 2, envStatus: "ready", opsApplied: 1 } } },
        ] } },
        { ms: 400, stream: { type: "text", tps: 22, text: "已更新到 **v2**（**立即生效**，见右侧）：`upsert` 失败时按指数退避（1s/2s）重试，最多 3 次。\n\n不满意可让我 **revert** 回 v1；要改重试次数也告诉我。" } },
      ],
    },

    // ── 综合场景：ask_user 提问门 + todo 看板 + 并行工具批 + 多形态结果（列表/终端/错误）+ progress live 流 ──
    cv_research: {
      id: "cv_research", title: "调研竞品 durable 方案", crumb: "Chat", kind: "chat", meta: "claude-opus · 30 分钟前",
      blocks: [
        { type: "text", role: "user", text: "调研一下竞品的 durable execution 方案，整理成要点。" },
      ],
      autoplay: true,
      turn: [
        { ms: 400, stream: { type: "reasoning", open: true, label: "推理", tps: 46, text: "先确认要点语言，再列任务清单 → 并行检索 → 抓正文 → 汇总。" } },
        // ask_user 提问门（accept{answer}/decline，options 单选）——区别于 danger 确认门
        { ms: 500, push: { type: "tool_call", open: true, items: [
          { verb: "ask_user", name: "ask_user", ask: { message: "要点用中文还是英文整理？", options: ["中文", "英文", "中英对照"] } },
        ] } },
        { gate: {
          onApprove: { ms: 400, push: { type: "text", text: "好，用**中文**整理。" } },
          onDeny: { ms: 400, push: { type: "text", text: "好，我按默认中文整理。" } },
        } },
        // todo 看板（LLM 规划任务，整表写入；恰一项 in_progress）
        { ms: 600, push: { type: "todo", open: true, items: [
          { content: "并行检索竞品 durable 资料", status: "in_progress", activeForm: "正在检索竞品资料" },
          { content: "抓取并摘要各家文档", status: "pending" },
          { content: "汇总成中文要点", status: "pending" },
        ] } },
        // 并行工具批（同 executionGroup：3 项同时 running → 一并 settle；含 1 个 tool error）
        { ms: 700, push: { type: "tool_call", open: true, summary: "并行检索 3 个来源（executionGroup）", items: [
          { verb: "WebSearch", name: "Temporal durable execution", running: true },
          { verb: "WebSearch", name: "Restate durable", running: true },
          { verb: "Read", name: "docs/competitors.md", running: true },
        ] } },
        { ms: 1500, patch: { type: "tool_call", open: true, summary: "检索完成（2 成功 · 1 失败）", items: [
          { verb: "WebSearch", name: "Temporal durable execution", result: { list: [
            { title: "Temporal: Durable Execution", meta: "temporal.io", hint: "事件溯源 + 确定性重放，用户代码重跑" },
            { title: "Workflow as Code", meta: "docs.temporal.io", hint: "SDK 内写 workflow，引擎负责持久化" },
          ] } },
          { verb: "WebSearch", name: "Restate durable", result: { list: [
            { title: "Restate: Durable Execution & State", meta: "restate.dev", hint: "日志式 durable，handler 侵入式 SDK" },
          ] } },
          // tool_result 错误态（status=error）：Read 文件不存在
          { verb: "Read", name: "docs/competitors.md", error: "ENOENT: no such file or directory, open 'docs/competitors.md'" },
        ] } },
        { ms: 600, push: { type: "todo", open: true, items: [
          { content: "并行检索竞品 durable 资料", status: "completed" },
          { content: "抓取并摘要各家文档", status: "in_progress", activeForm: "正在抓取 temporal.io/docs" },
          { content: "汇总成中文要点", status: "pending" },
        ] } },
        // progress 终端式 live 流（WebFetch 抓正文，逐行脉冲）
        { ms: 500, push: { type: "tool_call", running: true, status: "WebFetch temporal.io/docs…", items: [{ verb: "WebFetch", name: "temporal.io/docs" }] } },
        { progressStream: { label: "WebFetch · temporal.io/docs", lps: 5, lines: ["→ GET https://temporal.io/docs", "← 200 (text/html · 84 KB)", "提取正文 → markdown", "摘要 3 段"] } },
        { ms: 300, patch: { type: "tool_call", open: true, summary: "已抓取并摘要 temporal.io/docs", items: [
          { verb: "WebFetch", name: "temporal.io/docs", result: { text: "Temporal 用事件溯源 + 确定性重放实现 durable：workflow 代码须确定性、崩溃后逐事件重放还原状态。（已摘要 3 段）" } },
        ] } },
        { ms: 500, push: { type: "todo", open: false, items: [
          { content: "并行检索竞品 durable 资料", status: "completed" },
          { content: "抓取并摘要各家文档", status: "completed" },
          { content: "汇总成中文要点", status: "completed" },
        ] } },
        { ms: 500, stream: { type: "text", tps: 22, text: "调研要点 ✅\n\n- **Temporal**：事件溯源 + 确定性重放（用户代码重跑），心智重。\n- **Restate**：日志式 durable，handler SDK 侵入。\n- **本项目（Anselm）**：**节点结果记忆化 + 解释器幂等重走**——无用户代码重放，心智更简。\n\n（`docs/competitors.md` 不存在，已跳过本地文档。）" } },
      ],
    },

    // ── :triage 对话：诊断失败 flowrun（get_flowrun → invoke_agent 深诊 → edit_workflow 修复 → 手动 retry）──
    cv_triage: {
      id: "cv_triage", title: "诊断 · flowrun frn_8a1c 失败", crumb: "Chat · triage", kind: "triage", meta: "claude-opus · 1 时前",
      blocks: [
        { type: "text", role: "user", text: "这个 flowrun 为什么失败了？帮我看看。" },
        { type: "reasoning", label: "推理", text: "triage 上下文已注入失败 flowrun 的全节点行。先 get_flowrun 看哪一步 failed、错误是什么。" },
        { type: "tool_call", open: true, summary: "读取 flowrun 头 + 全节点记忆化结果", items: [
          { verb: "get_flowrun", name: "frn_8a1c…", danger: "safe",
            result: { json: { flowrun: { id: "frn_8a1c4f2e", status: "failed", versionId: "wfv_3d9a1b" }, nodes: [
              { nodeId: "fetch", iteration: 0, kind: "action", status: "failed", error: "HTTP 429 Too Many Requests" },
              { nodeId: "transform", iteration: 0, kind: "action", status: "completed" },
            ] } } },
        ] },
        // invoke_agent：调 Quadrinity Agent 实体深诊（嵌套 ReAct 子树；轨迹耐久在 Execution.transcript，区别于 Subagent 落 message_blocks）
        { type: "tool_call", open: true, summary: "invoke triage_agent 深度诊断", items: [
          { verb: "invoke_agent", name: "triage_agent", danger: "safe",
            args: { agentId: "ag_91c3de07", input: { flowrunId: "frn_8a1c4f2e" } },
            result: { json: { ok: true, output: { rootCause: "瞬时限流 + fetch 无重试", fix: "fetch 加 durable 重试 + trigger 改 serial" }, executionId: "agx_5d1f", status: "completed", steps: 3 } } },
        ] },
        { type: "subtree", label: "invoke_agent · triage_agent（轨迹耐久在 Execution.transcript）", open: false, blocks: [
          { type: "reasoning", label: "推理", text: "读 fetch 节点 input/output + 上游 trigger 并发配置，判断是瞬时限流还是配额耗尽。" },
          { type: "tool_call", open: true, items: [{ verb: "get_trigger", name: "trg_pr_webhook", result: { json: { concurrency: "all_allow", rateLimit: "none" } } }] },
          { type: "text", text: "上游 trigger 并发 all_allow → 瞬时打爆下游限流（429）。建议 fetch 加 durable 重试 + trigger 改 serial。" },
        ] },
        { type: "text", text: "根因：节点 **`fetch`** 在第 0 轮因 **HTTP 429（限流）** 失败、且**没配 durable 重试**；上游 trigger 并发 `all_allow` 瞬时打爆下游。\n\n我直接 `edit_workflow` 给 fetch 加重试（写新版本立即生效）。" },
        { type: "tool_call", open: false, summary: "edit_workflow：给 fetch 加 durable 重试（新版本立即生效）", items: [
          { verb: "edit_workflow", name: "pr_merge_flow", danger: "cautious",
            result: { json: { id: "wf_9f2a7c1b", versionId: "wfv_4e2a7c", version: 5, opsApplied: 2 } } },
        ] },
        { type: "text", text: "修复已写入 **v5**（**立即生效**）：`fetch` 节点加了 3 次指数退避重试。\n\n我**不会自动重跑**——请你**手动 retry** 该执行：到 Scheduler 对 `frn_8a1c…` 点 **replay** 即可。" },
        { type: "compaction", coversUpToSeq: 18, summarizedCount: 6 },
      ],
    },

    // ── 完成态静态 transcript（edit_function 写完即 active，无 pending；max_steps 诚实终态）──
    cv_invoice: {
      id: "cv_invoice", title: "发票处理 v3 迭代", crumb: "Chat", kind: "chat", meta: "claude-opus · 昨天 18:20",
      blocks: [
        { type: "text", role: "user", text: "把发票金额校验改成允许 ±1 分的误差。" },
        { type: "tool_call", open: false, summary: "编辑 validate_invoice：金额校验放宽 ±0.01", items: [
          { verb: "edit_function", name: "validate_invoice", danger: "cautious",
            result: { json: { id: "fn_9b3c1a2d", versionId: "fnv_4a1b6e22", version: 3, envStatus: "ready", opsApplied: 1 } } },
        ] },
        { type: "text", text: "已更新到 **v3**（立即生效）：金额校验现允许 ±0.01 的舍入误差，其余规则不变。" },
        { type: "turnEnd", stopReason: "max_steps", code: "MAX_STEPS_REACHED" },
      ],
    },

    // ── 归档静态 ──
    cv_weekly: {
      id: "cv_weekly", title: "周报汇总", crumb: "Chat · 已归档", kind: "chat", meta: "上周",
      blocks: [
        { type: "text", role: "user", text: "汇总本周三条 workflow 的运行情况成一段周报。" },
        { type: "text", text: "本周 3 条 workflow 共运行 142 次，成功率 97.2%；`pr_merge_flow` 触发 1 次审批回滚，其余正常。详情见各 run 记录。" },
      ],
    },
  };
})();
