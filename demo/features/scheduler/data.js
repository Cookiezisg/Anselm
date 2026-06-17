/* Anselm feature — scheduler 种子数据（durable 执行：flowrun 时间河 + 节点甘特 + 运行图 + 节点调试）。
   后端心智：一次执行 = 一条 flowrun（fr_，冻结图版本 + pin 闭包 + 状态 running/completed/failed/cancelled）；
     真相 = flowrun_nodes（frn_，每行一个 (节点,轮次) 记忆化 result，record-once）；parked 唯一非终态；回边=循环（每决策 +1 iteration）。
   时间河：run.tMin = 距今分钟（起始时刻），sea 据 SCHED_WINDOW_MIN 算胶囊横位 + 刻度。节点甘特 gantt[].atPct/wPct = run 内相对时段（[0,100]）。 */
(function () {
  window.SCHED_WORKFLOWS = [
    { id: "wf_9f2a7c1b", label: "pr_merge_flow", dot: "run", meta: "active · serial", lifecycle: "active", concurrency: "serial" },
    { id: "wf_3c1d8e40", label: "nightly_etl", dot: "done", meta: "active · skip", lifecycle: "active", concurrency: "skip" },
    { id: "wf_77a0b2f9", label: "support_triage", dot: "run", meta: "draining · 1 在途", lifecycle: "draining", concurrency: "allow_all" },
  ];
  window.SCHED_WINDOW = "近 12 小时 · 刻度每时";
  window.SCHED_WINDOW_MIN = 720;

  const PR_NODES = [
    { id: "on_pr_merged", kind: "trigger", ref: "trg_3a1f" }, { id: "run_tests", kind: "action", ref: "fn_5b2e1a" },
    { id: "branch_result", kind: "control", ref: "ctl_7d4c" }, { id: "approve_rollback", kind: "approval", ref: "apf_2e9b" },
    { id: "do_rollback", kind: "action", ref: "hd_8a3f.rollback" },
  ];
  const PR_EDGES = [
    { id: "e1", from: "on_pr_merged", to: "run_tests" }, { id: "e2", from: "run_tests", to: "branch_result" },
    { id: "e3", from: "branch_result", to: "approve_rollback", port: "fail" }, { id: "e4", from: "branch_result", to: "run_tests", port: "retry" },
    { id: "e5", from: "approve_rollback", to: "do_rollback", port: "yes" },
  ];
  const prGraph = (run) => ({ nodes: PR_NODES.map((n) => ({ ...n })), edges: PR_EDGES.map((e) => ({ ...e })), run });

  // support_triage 图：webhook → triage agent → control 分级 → notify
  const SUP_NODES = [
    { id: "ticket_in", kind: "trigger", ref: "trg_zendesk" }, { id: "triage", kind: "agent", ref: "ag_91c3de07" },
    { id: "severity", kind: "control", ref: "ctl_sev" }, { id: "notify", kind: "action", ref: "hd_slack.post" },
  ];
  const SUP_EDGES = [{ id: "s1", from: "ticket_in", to: "triage" }, { id: "s2", from: "triage", to: "severity" }, { id: "s3", from: "severity", to: "notify", port: "p1" }];
  const supGraph = (run) => ({ nodes: SUP_NODES.map((n) => ({ ...n })), edges: SUP_EDGES.map((e) => ({ ...e })), run });

  window.SCHED_RUNS = [
    {
      id: "fr_b7e0c431", wf: "wf_9f2a7c1b", wfLabel: "pr_merge_flow", status: "parked",
      trigger: "webhook · pr #1287", when: "12:09 · 在途", tMin: 13, replay: 0, selected: true,
      head: [
        ["flowrun ID", "fr_b7e0c431"], ["workflow", "pr_merge_flow · wfv_7（pin 冻结）"], ["状态", "running · 当前 parked@approve_rollback"],
        ["触发", "webhook · firing trf_b7e0"], ["payload", "{ pr: 1287, branch: \"main\" }"], ["节点记忆化", "4/5 node_id 已落行"],
        ["pin 闭包", "fn_5b2e1a@v4 · ctl_7d4c@v2 · apf_2e9b@v1（活态 hd 不 pin）"], ["耗时至 parked", "1.4s"],
      ],
      graph: prGraph({ state: { on_pr_merged: "completed", run_tests: "completed", branch_result: "completed", approve_rollback: "parked", do_rollback: "future" }, iters: { on_pr_merged: 1, run_tests: 2, branch_result: 2, approve_rollback: 1, do_rollback: 0 }, memo: { approve_rollback: { parked: true } }, taken: ["e1", "e2", "e3"], live: null }),
      gantt: [
        { id: "on_pr_merged", kind: "trigger", label: "on_pr_merged", status: "done", atPct: 0, wPct: 4 },
        { id: "run_tests", kind: "action", label: "run_tests", status: "done", iters: [{ atPct: 5, wPct: 26 }, { atPct: 40, wPct: 28 }] },
        { id: "branch_result", kind: "control", label: "branch_result", status: "done", iters: [{ atPct: 32, wPct: 5 }, { atPct: 69, wPct: 5 }] },
        { id: "approve_rollback", kind: "approval", label: "approve_rollback", status: "parked", atPct: 75, wPct: 23, parked: true },
        { id: "do_rollback", kind: "action", label: "do_rollback", status: "future", atPct: 0, wPct: 0 },
      ],
      nodeDetail: {
        on_pr_merged: { kv: [["状态", "completed"], ["iteration", "1"], ["耗时", "12ms"], ["result", "seed · payload 落 frn 行"]], json: { pr: 1287, branch: "main", sha: "a1c8…" } },
        run_tests: { kv: [["状态", "completed（第 2 轮）"], ["iteration", "1 → 2（retry 回边）"], ["耗时", "i1 760ms · i2 540ms"], ["错误", "i1 exitCode≠0；i2 仍 fail"]], code: "$ pytest -q\n12 passed, 3 failed\nexit code 1", lang: "text" },
        branch_result: { kv: [["状态", "completed"], ["iteration", "2"], ["求值", "first-true-wins"], ["选中分支", "fail（→ approve_rollback）"], ["__port", "fail"]], code: "exitCode != 0  →  port: \"fail\"", lang: "cel" },
        approve_rollback: { kv: [["状态", "parked（待人工）"], ["iteration", "1"], ["DDL", "8h 后自动驳回"], ["决策规则", "first-wins（人 vs 超时）"]], parked: { prompt: "run_tests×2 轮均 fail，是否放行回滚 main？", ddl: "剩余 7h 41m" } },
        do_rollback: { kv: [["状态", "future（未起）"], ["前驱", "approve_rollback yes 分支"], ["说明", "审批通过后才 seed 本节点"]] },
      },
    },
    { id: "fr_a1c89f02", wf: "wf_9f2a7c1b", wfLabel: "pr_merge_flow", status: "completed", trigger: "webhook · pr #1284", when: "10:30", tMin: 112, replay: 0,
      head: [["flowrun ID", "fr_a1c89f02"], ["状态", "completed"], ["节点记忆化", "5/5 全记忆化"], ["路径", "merged→tests→branch(fail)→approve(yes)→rollback"], ["耗时", "1.4s"]],
      graph: prGraph({ state: { on_pr_merged: "completed", run_tests: "completed", branch_result: "completed", approve_rollback: "completed", do_rollback: "completed" }, iters: { run_tests: 1 }, memo: {}, taken: ["e1", "e2", "e3", "e5"], live: null }),
      gantt: [
        { id: "on_pr_merged", kind: "trigger", label: "on_pr_merged", status: "done", atPct: 0, wPct: 6 },
        { id: "run_tests", kind: "action", label: "run_tests", status: "done", atPct: 7, wPct: 34 },
        { id: "branch_result", kind: "control", label: "branch_result", status: "done", atPct: 42, wPct: 6 },
        { id: "approve_rollback", kind: "approval", label: "approve_rollback", status: "done", atPct: 49, wPct: 30 },
        { id: "do_rollback", kind: "action", label: "do_rollback", status: "done", atPct: 80, wPct: 18 },
      ], nodeDetail: {},
    },
    { id: "fr_c3d471a8", wf: "wf_9f2a7c1b", wfLabel: "pr_merge_flow", status: "failed", trigger: "webhook · pr #1279", when: "08:15", tMin: 247, replay: 1,
      head: [["flowrun ID", "fr_c3d471a8"], ["状态", "failed · 可 :replay"], ["终态节点", "run_tests failed（exitCode≠0，retry 2 轮仍非 0）"], ["节点记忆化", "2/5"], ["replay", ":replay 清 failed 行、保留前置、自 run_tests 续跑"]],
      graph: prGraph({ state: { on_pr_merged: "completed", run_tests: "failed", branch_result: "future", approve_rollback: "future", do_rollback: "future" }, iters: { run_tests: 2 }, memo: { run_tests: { error: "退出码 1，retry 2 轮仍非 0" } }, taken: ["e1"], live: null }),
      gantt: [
        { id: "on_pr_merged", kind: "trigger", label: "on_pr_merged", status: "done", atPct: 0, wPct: 6 },
        { id: "run_tests", kind: "action", label: "run_tests", status: "err", iters: [{ atPct: 7, wPct: 30 }, { atPct: 45, wPct: 30 }] },
        { id: "branch_result", kind: "control", label: "branch_result", status: "future", atPct: 0, wPct: 0 },
      ],
      nodeDetail: { run_tests: { kv: [["状态", "failed"], ["iteration", "2（retry 仍 fail）"], ["错误码", "—（子进程退出码 1）"], ["耗时", "i1 700ms · i2 690ms"]], code: "$ pytest -q\n9 passed, 5 failed\nexit code 1", lang: "text" } },
    },
    { id: "fr_5e80b21c", wf: "wf_3c1d8e40", wfLabel: "nightly_etl", status: "completed", trigger: "cron · 02:00", when: "02:00", tMin: 622, replay: 0,
      head: [["flowrun ID", "fr_5e80b21c"], ["状态", "completed"], ["触发", "cron · firing trf_5e80（tick 02:00）"], ["节点记忆化", "3/3"], ["耗时", "4.1s"]],
      graph: { nodes: [{ id: "cron", kind: "trigger", ref: "trg_cron" }, { id: "extract", kind: "action", ref: "fn_extract" }, { id: "load", kind: "action", ref: "hd_pg.load" }], edges: [{ id: "n1", from: "cron", to: "extract" }, { id: "n2", from: "extract", to: "load" }], run: { state: { cron: "completed", extract: "completed", load: "completed" }, iters: {}, memo: {}, taken: ["n1", "n2"], live: null } },
      gantt: [
        { id: "cron", kind: "trigger", label: "cron", status: "done", atPct: 0, wPct: 4 },
        { id: "extract", kind: "action", label: "extract", status: "done", atPct: 5, wPct: 55 },
        { id: "load", kind: "action", label: "load", status: "done", atPct: 61, wPct: 38 },
      ], nodeDetail: { extract: { kv: [["状态", "completed"], ["耗时", "2.6s"], ["输出", "1820 行 → staging"]] } },
    },
    {
      id: "fr_9a40e1d7", wf: "wf_77a0b2f9", wfLabel: "support_triage", status: "running",
      trigger: "webhook · ticket #4821", when: "12:18 · 在途", tMin: 4, replay: 0,
      head: [["flowrun ID", "fr_9a40e1d7"], ["状态", "running · triage agent 进行中"], ["触发", "webhook · firing trf_9a40"], ["节点记忆化", "1/4 已落行"], ["pin 闭包", "ag_91c3@v4 → 递归挂载 fn/hd"], ["耗时", "2.3s（在途）"]],
      graph: supGraph({ state: { ticket_in: "completed", triage: "running", severity: "future", notify: "future" }, iters: { ticket_in: 1 }, memo: {}, taken: ["s1"], live: "s1" }),
      gantt: [
        { id: "ticket_in", kind: "trigger", label: "ticket_in", status: "done", atPct: 0, wPct: 8 },
        { id: "triage", kind: "agent", label: "triage", status: "done", atPct: 9, wPct: 70 },
        { id: "severity", kind: "control", label: "severity", status: "future", atPct: 0, wPct: 0 },
        { id: "notify", kind: "action", label: "notify", status: "future", atPct: 0, wPct: 0 },
      ],
      nodeDetail: {
        ticket_in: { kv: [["状态", "completed"], ["耗时", "8ms"]], json: { ticket: 4821, subject: "登录 500" } },
        triage: { kv: [["状态", "running（粗粒度 activity）"], ["iteration", "1"], ["步数", "读 transcript → 检索知识 → 归纳（进行中）"], ["Token", "1.2k（在途）"], ["说明", "agent 只记忆化最终 result，子步重放为预留"]] },
      },
    },
    { id: "fr_2f7a0931", wf: "wf_77a0b2f9", wfLabel: "support_triage", status: "completed", trigger: "webhook · ticket #4790", when: "09:20", tMin: 178, replay: 0,
      head: [["flowrun ID", "fr_2f7a0931"], ["状态", "completed"], ["节点记忆化", "4/4"], ["耗时", "5.2s"]],
      graph: supGraph({ state: { ticket_in: "completed", triage: "completed", severity: "completed", notify: "completed" }, iters: {}, memo: {}, taken: ["s1", "s2", "s3"], live: null }),
      gantt: [
        { id: "ticket_in", kind: "trigger", label: "ticket_in", status: "done", atPct: 0, wPct: 6 },
        { id: "triage", kind: "agent", label: "triage", status: "done", atPct: 7, wPct: 60 },
        { id: "severity", kind: "control", label: "severity", status: "done", atPct: 68, wPct: 6 },
        { id: "notify", kind: "action", label: "notify", status: "done", atPct: 75, wPct: 24 },
      ], nodeDetail: {},
    },
  ];
})();
