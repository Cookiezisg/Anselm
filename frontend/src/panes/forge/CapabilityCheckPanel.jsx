// CapabilityCheckPanel — inline expandable panel under WorkflowDetail
// header. Triggers POST /workflows/{id}:capability-check and renders the
// list of required capabilities + whether each is satisfied.
//
// CapabilityCheckPanel —— 工作流详情头部下折叠面板；按需触发能力检查并
// 渲染结果（每项 capability + 是否 ready）。

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Icon } from "../../components/primitives/Icon.jsx";
import { Button } from "../../components/primitives/Button.jsx";
import { useCapabilityCheck } from "../../api/forge.js";
import { useUIStore } from "../../store/ui.js";

export function CapabilityCheckPanel({ workflowId }) {
  const [open, setOpen] = useState(false);
  const [result, setResult] = useState(null);
  const check = useCapabilityCheck();
  const pushToast = useUIStore((s) => s.pushToast);

  const run = async () => {
    setOpen(true);
    try {
      const r = await check.mutateAsync(workflowId);
      setResult(r);
    } catch (e) {
      pushToast({ kind: "error", title: "Capability check 失败", desc: e.message });
    }
  };

  return (
    <>
      <Button size="sm" onClick={run} disabled={check.isPending}>
        {check.isPending ? <><span className="spinner" /> 检查中…</> : <><Icon.Eye /> Capability check</>}
      </Button>
      <AnimatePresence>
        {open && (
          <motion.div
            initial={{ opacity: 0, y: -6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -4 }}
            className="cap-panel"
          >
            <div className="cap-panel-head">
              <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                <Icon.Eye />
                <strong>能力检查</strong>
                {result?.allReady && <span className="badge success">全部就绪</span>}
                {result && !result.allReady && <span className="badge warn">{(result.missing || []).length} 项缺失</span>}
              </div>
              <button className="icon-btn" onClick={() => setOpen(false)}><Icon.X /></button>
            </div>
            <div className="cap-panel-body">
              {!result && check.isPending && <div className="empty"><div className="sub">运行 capability check…</div></div>}
              {result && (
                <CapabilityResult result={result} />
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}

function CapabilityResult({ result }) {
  const items = result.items || result.capabilities || [];
  if (items.length === 0) {
    return (
      <div className="empty" style={{ padding: 12 }}>
        <div className="sub">该工作流不需要外部能力</div>
      </div>
    );
  }
  return (
    <div className="cap-list">
      {items.map((it, i) => {
        const ok = it.ready ?? it.satisfied ?? (!it.missing);
        return (
          <div key={i} className={"cap-row" + (ok ? " is-ok" : " is-missing")}>
            {ok
              ? <Icon.Check style={{ color: "var(--status-success)", width: 13, height: 13 }} />
              : <Icon.AlertCircle style={{ color: "var(--status-error)", width: 13, height: 13 }} />}
            <span className="cell-mono">{it.kind || it.type || "capability"}</span>
            <span style={{ flex: 1 }}>{it.name || it.id || it.label}</span>
            {it.reason && <span style={{ color: "var(--fg-muted)", fontSize: 11 }}>{it.reason}</span>}
          </div>
        );
      })}
    </div>
  );
}
