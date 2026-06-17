/* Anselm feature — chat 种子数据（会话列表 + @提及池 + 脚本化 live 回合）。
   后端心智：conversation 是纯线程容器（消息单独取）；一次 Send = 202 + messages SSE 流式回合（每对话同时只一个在途回合）。
   :iterate（AI 编辑实体）/ :triage（AI 诊断执行）都返 conversationId 当普通对话接管——故 chat 是所有 AI 对话的唯一容器。
   【契约铁律】edit_ / create_ 工具写完新版本【立即生效】——后端【无】pending/草稿/采用/审批门；切版本唯一手段是 revert_ 工具（移 active 指针）。
   工具名必须用后端真名：Bash（非 run_shell）· get_trigger/get_flowrun（非 read_*）· create_trigger · edit_function · revert_function …
   data 形态：CHAT_CONVOS[id] = { title, crumb, meta, kind, blocks(初始 transcript), autoplay?, turn?(脚本步), island?(右岛 = entities build 流镜像，立即生效) }。
   脚本步（sea 小解释器消费，对齐后端 Open→Delta*→Close）：
     { ms, push } 追加块（=Open，整渲一次）· { ms, patch } 替换末块（running→settled）· { stream:{type,text,tps} } 文本/推理逐 token 流出（=Delta）·
     { islandStream:{code,cps} } 右岛代码逐字流入（= entities build 流镜像，写完即 active）· { gate:{onApprove,onDeny} } 等 an-decide（分支本身也是步，可流式）。 */
(function () {
  // 会话列表（rail）：置顶 / 今天 / 昨天 / 已归档（lastMessageAt 降序）。
  // dot 只映射【isGenerating】（在途回合=run，否则无 dot）——conversation 无 wait/err/done 等对话级态。
  window.CHAT_CONVOS_LIST = [
    { group: "置顶", open: true, rows: [
      { id: "cv_daily", label: "竞品动态日报流程", dot: "run", meta: "刚刚" },
    ]},
    { group: "今天", open: true, rows: [
      { id: "cv_iterate", label: "AI 编辑 · sync_inventory 加重试", meta: "10 分钟前" },
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
    // ── 旗舰：脚本化 live 回合（reasoning → tool_call → 危险确认 → 终端结果 → subagent 子树 → 回答）──
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
          // Bash 结果是【终端文本】（合并 stdout+stderr + [exit code: N] 页脚），非 JSON
          onApprove: { ms: 700, patch: { type: "tool_call", open: true, summary: "已清理过期快照（释放 3.4 GB）", items: [
            { verb: "Bash", name: "Bash", danger: "dangerous",
              result: { text: "removed /data/snapshots/2024-01 … 2024-12 (12 dirs)\nfreed 3.4 GB\n\n[exit code: 0]" } },
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
        // 右岛代码逐字流入（= entities build 流镜像：edit_function 的 arg delta 实时镜像到右岛实体面，close 快照 = 新 active 版本）
        { ms: 350, islandStream: { cps: 150, code: "import time, requests\n\ndef sync_inventory(warehouse, dry_run=False):\n    skus = fetch_skus(warehouse)\n    for attempt in range(3):            # 指数退避重试\n        try:\n            return upsert(skus, dry_run=dry_run)\n        except requests.RequestException:\n            if attempt == 2: raise\n            time.sleep(2 ** attempt)\n" } },
        { ms: 400, patch: { type: "tool_call", open: true, summary: "已编辑 sync_inventory → 新版本 v2（立即生效）", items: [
          { verb: "edit_function", name: "sync_inventory", danger: "cautious",
            result: { json: { id: "fn_5e1a9c4d", versionId: "fnv_7c2e8a1d", version: 2, envStatus: "ready", opsApplied: 1 } } },
        ] } },
        { ms: 400, stream: { type: "text", tps: 22, text: "已更新到 **v2**（**立即生效**，见右侧）：`upsert` 失败时按指数退避（1s/2s）重试，最多 3 次。\n\n不满意可让我 **revert** 回 v1；要改重试次数也告诉我。" } },
      ],
    },

    // ── :triage 对话：诊断失败的 flowrun（get_flowrun 返 {flowrun, nodes}）──
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
        { type: "text", text: "根因找到了：节点 **`fetch`** 在第 0 轮因 **HTTP 429（限流）** 失败，且该节点**没配 durable 重试**。\n\n两个修法：\n1. 给 `fetch` 节点加 durable 重试（指数退避，避开瞬时限流）；\n2. 给上游 trigger 加并发上限（serial）。\n\n我可以直接 `edit_workflow` 给 fetch 加重试（写新版本立即生效），要我改吗？改完你手动 retry 该执行即可（我不会自动重跑）。" },
        { type: "compaction" },
      ],
    },

    // ── 完成态静态 transcript（edit_function 写完即 active，无 pending）──
    cv_invoice: {
      id: "cv_invoice", title: "发票处理 v3 迭代", crumb: "Chat", kind: "chat", meta: "claude-opus · 昨天 18:20",
      blocks: [
        { type: "text", role: "user", text: "把发票金额校验改成允许 ±1 分的误差。" },
        { type: "tool_call", open: false, summary: "编辑 validate_invoice：金额校验放宽 ±0.01", items: [
          { verb: "edit_function", name: "validate_invoice", danger: "cautious",
            result: { json: { id: "fn_9b3c1a2d", versionId: "fnv_4a1b6e22", version: 3, envStatus: "ready", opsApplied: 1 } } },
        ] },
        { type: "text", text: "已更新到 **v3**（立即生效）：金额校验现允许 ±0.01 的舍入误差，其余规则不变。" },
        { type: "turnEnd", code: "MAX_STEPS_REACHED" },
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
