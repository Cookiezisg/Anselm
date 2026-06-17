/* Anselm feature — scheduler 侧栏（rail）：active/draining workflow 列表（lifecycle + concurrency 治理态）。
   时间河含全部 run，rail 给工作流概览与治理态（监听中 / draining / 并发策略）。 */
window.FEATURE = window.FEATURE || {};
window.FEATURE.scheduler = Object.assign(window.FEATURE.scheduler || {}, {
  rail: (ctx) => {
    const WFS = window.SCHED_WORKFLOWS || [];
    return ctx.rail([["g", "工作流 · 监听中"]].concat(
      WFS.map((w) => ["r", { dot: w.dot, label: w.label, meta: w.meta, id: w.id }])
    ));
  },
});
