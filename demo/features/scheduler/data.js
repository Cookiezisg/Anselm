/* Anselm feature — scheduler 种子数据（durable 执行：flowrun 时间河 + 节点甘特 + 运行图 + 节点调试）。
   后端心智：一次执行 = 一条 flowrun（fr_，冻结图版本 + pin 闭包 + 状态 running/completed/failed/cancelled）；
     真相 = flowrun_nodes（frn_，每行一个 (节点,轮次) 记忆化 result，record-once）；parked 是唯一非终态（审批挂起）；回边=循环（每决策 +1 iteration）。
   位置 atPct/wPct ∈ [0,100]：时间河（共享时间窗）与节点甘特（单 run 内时段）的纯几何位（demo 预算好，省去时间戳换算）。 */
(function () {
  // 工作流（左岛）：lifecycle active/draining/inactive · concurrency serial/skip/allow_all
  window.SCHED_WORKFLOWS = [
    { id: "wf_9f2a7c1b", label: "pr_merge_flow", dot: "run", meta: "active · serial", lifecycle: "active", concurrency: "serial" },
    { id: "wf_3c1d8e40", label: "nightly_etl", dot: "done", meta: "active · skip", lifecycle: "active", concurrency: "skip" },
    { id: "wf_77a0b2f9", label: "support_triage", dot: "wait", meta: "draining · 1 在途", lifecycle: "draining", concurrency: "allow_all" },
  ];
  window.SCHED_WINDOW = "近 6 小时 · cron 刻度每时";

  // pr_merge_flow 的冻结图（5 节点 + 回边 retry）——run 态叠加各异
  const PR_NODES = [
    { id: "on_pr_merged", kind: "trigger", ref: "trg_3a1f" },
    { id: "run_tests", kind: "action", ref: "fn_5b2e1a" },
    { id: "branch_result", kind: "control", ref: "ctl_7d4c" },
    { id: "approve_rollback", kind: "approval", ref: "apf_2e9b" },
    { id: "do_rollback", kind: "action", ref: "hd_8a3f.rollback" },
  ];
  const PR_EDGES = [
    { id: "e1", from: "on_pr_merged", to: "run_tests" },
    { id: "e2", from: "run_tests", to: "branch_result" },
    { id: "e3", from: "branch_result", to: "approve_rollback", port: "fail" },
    { id: "e4", from: "branch_result", to: "run_tests", port: "retry" },
    { id: "e5", from: "approve_rollback", to: "do_rollback", port: "yes" },
  ];
  const prGraph = (run) => ({ nodes: PR_NODES.map((n) => ({ ...n })), edges: PR_EDGES.map((e) => ({ ...e })), run });

  // flowrun 列表（时间河沿时间轴铺；选中 → 切运行图 + 节点甘特 + 节点调试）
  window.SCHED_RUNS = [
    {
      id: "fr_b7e0c431", wf: "wf_9f2a7c1b", wfLabel: "pr_merge_flow", status: "parked",
      trigger: "webhook · pr #1287", when: "12:09 · 在途", atPct: 78, wPct: 13, replay: 0, selected: true,
      head: [
        ["flowrun ID", "fr_b7e0c431"], ["workflow", "pr_merge_flow · wfv_7（pin 冻结）"],
        ["状态", "running · 当前 parked@approve_rollback"], ["触发", "webhook · firing trf_b7e0"],
        ["payload", "{ pr: 1287, branch: \"main\" }"], ["节点记忆化", "4/5 node_id 已落行"],
        ["pin 闭包", "fn_5b2e1a@v4 · ctl_7d4c@v2 · apf_2e9b@v1（活态 hd 不 pin）"], ["耗时至 parked", "1.4s"],
      ],
      graph: prGraph({
        state: { on_pr_merged: "completed", run_tests: "completed", branch_result: "completed", approve_rollback: "parked", do_rollback: "future" },
        iters: { on_pr_merged: 1, run_tests: 2, branch_result: 2, approve_rollback: 1, do_rollback: 0 },
        memo: { approve_rollback: { parked: true, prompt: "run_tests×2 轮均 fail，是否放行回滚 main？", ddl: "8h 后自动驳回" } },
        taken: ["e1", "e2", "e3"], live: null,
      }),
      // 节点甘特：on_pr_merged → run_tests(×2 迭代,回边) → branch_result(×2) → approve_rollback(parked 等待) → do_rollback(未起)
      gantt: [
        { id: "on_pr_merged", kind: "trigger", label: "on_pr_merged", status: "done", atPct: 0, wPct: 4 },
        { id: "run_tests", kind: "action", label: "run_tests", status: "done", iters: [{ atPct: 5, wPct: 26 }, { atPct: 40, wPct: 28 }] },
        { id: "branch_result", kind: "control", label: "branch_result", status: "done", iters: [{ atPct: 32, wPct: 5 }, { atPct: 69, wPct: 5 }] },
        { id: "approve_rollback", kind: "approval", label: "approve_rollback", status: "parked", atPct: 75, wPct: 23, parked: true },
        { id: "do_rollback", kind: "action", label: "do_rollback", status: "future", atPct: 0, wPct: 0 },
      ],
      // 逐节点调试（点图节点 / 甘特行 → 右岛）：记忆化 result / 状态 / 耗时 / 错误 / 迭代
      nodeDetail: {
        on_pr_merged: { kv: [["状态", "completed"], ["iteration", "1"], ["耗时", "12ms"], ["result", "seed · payload 落 frn 行"]], json: { pr: 1287, branch: "main", sha: "a1c8…" } },
        run_tests: { kv: [["状态", "completed（第 2 轮）"], ["iteration", "1 → 2（retry 回边）"], ["耗时", "i1 760ms · i2 540ms"], ["错误", "i1 exitCode≠0；i2 仍 fail"]], code: "$ pytest -q\n12 passed, 3 failed\nexit code 1", lang: "text" },
        branch_result: { kv: [["状态", "completed"], ["iteration", "2"], ["求值", "first-true-wins"], ["选中分支", "fail（→ approve_rollback）"], ["__port", "fail"]], code: "exitCode != 0  →  port: \"fail\"", lang: "cel" },
        approve_rollback: { kv: [["状态", "parked（待人工）"], ["iteration", "1"], ["DDL", "8h 后自动驳回"], ["决策规则", "first-wins（人 vs 超时）"]], parked: { prompt: "run_tests×2 轮均 fail，是否放行回滚 main？", ddl: "剩余 7h 41m" } },
        do_rollback: { kv: [["状态", "future（未起）"], ["前驱", "approve_rollback yes 分支"], ["说明", "审批通过后才 seed 本节点"]] },
      },
    },
    { id: "fr_a1c89f02", wf: "wf_9f2a7c1b", wfLabel: "pr_merge_flow", status: "completed", trigger: "webhook · pr #1284", when: "12:04", atPct: 60, wPct: 9, replay: 0,
      head: [["flowrun ID", "fr_a1c89f02"], ["状态", "completed"], ["节点记忆化", "5/5 全记忆化"], ["路径", "merged→tests→branch(fail)→approve(yes)→rollback"], ["耗时", "1.4s"]],
      graph: prGraph({ state: { on_pr_merged: "completed", run_tests: "completed", branch_result: "completed", approve_rollback: "completed", do_rollback: "completed" }, iters: { on_pr_merged: 1, run_tests: 1, branch_result: 1, approve_rollback: 1, do_rollback: 1 }, memo: {}, taken: ["e1", "e2", "e3", "e5"], live: null }),
      gantt: [
        { id: "on_pr_merged", kind: "trigger", label: "on_pr_merged", status: "done", atPct: 0, wPct: 6 },
        { id: "run_tests", kind: "action", label: "run_tests", status: "done", atPct: 7, wPct: 34 },
        { id: "branch_result", kind: "control", label: "branch_result", status: "done", atPct: 42, wPct: 6 },
        { id: "approve_rollback", kind: "approval", label: "approve_rollback", status: "done", atPct: 49, wPct: 30 },
        { id: "do_rollback", kind: "action", label: "do_rollback", status: "done", atPct: 80, wPct: 18 },
      ],
      nodeDetail: {},
    },
    { id: "fr_c3d471a8", wf: "wf_9f2a7c1b", wfLabel: "pr_merge_flow", status: "failed", trigger: "webhook · pr #1279", when: "昨 18:21", atPct: 18, wPct: 6, replay: 1,
      head: [["flowrun ID", "fr_c3d471a8"], ["状态", "failed · 可 :replay"], ["终态节点", "run_tests failed（exitCode≠0，retry 2 轮仍非 0）"], ["节点记忆化", "2/5"], ["replay", ":replay 清 failed 行、保留前置、自 run_tests 续跑"]],
      graph: prGraph({ state: { on_pr_merged: "completed", run_tests: "failed", branch_result: "future", approve_rollback: "future", do_rollback: "future" }, iters: { on_pr_merged: 1, run_tests: 2, branch_result: 0, approve_rollback: 0, do_rollback: 0 }, memo: { run_tests: { error: "子进程退出码 1，retry 2 轮仍非 0" } }, taken: ["e1"], live: null }),
      gantt: [
        { id: "on_pr_merged", kind: "trigger", label: "on_pr_merged", status: "done", atPct: 0, wPct: 6 },
        { id: "run_tests", kind: "action", label: "run_tests", status: "err", iters: [{ atPct: 7, wPct: 30 }, { atPct: 45, wPct: 30 }] },
        { id: "branch_result", kind: "control", label: "branch_result", status: "future", atPct: 0, wPct: 0 },
      ],
      nodeDetail: {},
    },
    { id: "fr_5e80b21c", wf: "wf_3c1d8e40", wfLabel: "nightly_etl", status: "completed", trigger: "cron · 02:00", when: "02:00", atPct: 4, wPct: 22, replay: 0,
      head: [["flowrun ID", "fr_5e80b21c"], ["状态", "completed"], ["节点记忆化", "3/3"], ["耗时", "4.1s"]],
      graph: { nodes: [{ id: "cron", kind: "trigger", ref: "trg_cron" }, { id: "extract", kind: "action", ref: "fn_extract" }, { id: "load", kind: "action", ref: "hd_pg.load" }], edges: [{ id: "n1", from: "cron", to: "extract" }, { id: "n2", from: "extract", to: "load" }], run: { state: { cron: "completed", extract: "completed", load: "completed" }, iters: { cron: 1, extract: 1, load: 1 }, memo: {}, taken: ["n1", "n2"], live: null } },
      gantt: [
        { id: "cron", kind: "trigger", label: "cron", status: "done", atPct: 0, wPct: 4 },
        { id: "extract", kind: "action", label: "extract", status: "done", atPct: 5, wPct: 55 },
        { id: "load", kind: "action", label: "load", status: "done", atPct: 61, wPct: 38 },
      ],
      nodeDetail: {},
    },
    { id: "fr_2d0f6a14", wf: "wf_3c1d8e40", wfLabel: "nightly_etl", status: "completed", trigger: "cron · 昨 02:00", when: "昨 02:00", atPct: 2, wPct: 20, replay: 0,
      head: [["flowrun ID", "fr_2d0f6a14"], ["状态", "completed"], ["耗时", "3.8s"]],
      graph: { nodes: [{ id: "cron", kind: "trigger" }, { id: "extract", kind: "action" }, { id: "load", kind: "action" }], edges: [{ id: "n1", from: "cron", to: "extract" }, { id: "n2", from: "extract", to: "load" }], run: { state: { cron: "completed", extract: "completed", load: "completed" }, iters: {}, memo: {}, taken: ["n1", "n2"], live: null } },
      gantt: [], nodeDetail: {},
    },
  ];
})();
