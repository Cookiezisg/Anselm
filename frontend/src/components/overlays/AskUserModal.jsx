// AskUserModal — surfaces backend AskUserQuestion tool calls. Opens
// automatically when pendingAsk is set (set by the notifications SSE
// dispatch for type="ask"). Submit POSTs the answer to the
// pending-questions :resolve endpoint.
//
// AskUserModal —— 后端 AskUserQuestion 工具触发；提交走 :resolve 端点。

import { useEffect, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { Icon } from "../primitives/Icon.jsx";
import { Button } from "../primitives/Button.jsx";
import { useUIStore } from "../../store/ui.js";
import { apiFetch } from "../../api/client.js";
import { scaleIn, fadeIn } from "../../motion/tokens.js";

export function AskUserModal() {
  const pending = useUIStore((s) => s.pendingAsk);
  const askOpen = useUIStore((s) => s.askOpen);
  const setAskOpen = useUIStore((s) => s.setAskOpen);
  const setPendingAsk = useUIStore((s) => s.setPendingAsk);
  const pushToast = useUIStore((s) => s.pushToast);

  // open when pending arrives; manually-opened via setAskOpen too
  const isOpen = askOpen || !!pending;

  const [selected, setSelected] = useState(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => { setSelected(null); }, [pending?.id]);

  useEffect(() => {
    if (!isOpen) return;
    const onKey = (e) => {
      if (e.key === "Escape") { close(); return; }
      const n = parseInt(e.key, 10);
      if (n >= 1 && n <= 9 && pending?.options?.[n - 1]) {
        setSelected(pending.options[n - 1].id || pending.options[n - 1].value);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [isOpen, pending]);

  const close = () => {
    setAskOpen(false);
    setPendingAsk(null);
  };

  if (!pending) {
    // No pending question — show "no questions" empty state if manually opened
    return (
      <AnimatePresence>
        {askOpen && (
          <motion.div className="overlay" {...fadeIn} onClick={() => setAskOpen(false)}>
            <motion.div className="ask-card" {...scaleIn} onClick={(e) => e.stopPropagation()}>
              <div className="ask-head">
                <div className="icon-wrap"><Icon.HelpCircle /></div>
                <div className="meta">
                  <div className="label">没有待回答的问题</div>
                  <div className="title">Agent 没在等你</div>
                </div>
                <button className="icon-btn" onClick={() => setAskOpen(false)} style={{ marginLeft: "auto" }}>
                  <Icon.X />
                </button>
              </div>
              <div className="ask-body">
                <div className="ask-question">
                  如果 agent 在工作流中需要你的输入，会在这里弹出。
                </div>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    );
  }

  const options = pending.options || [];
  const submit = async () => {
    if (!selected) return;
    setSubmitting(true);
    try {
      await apiFetch(`/conversations/${pending.conversationId}/pending-questions/${pending.toolCallId}:resolve`, {
        method: "POST", body: { answer: selected },
      });
      pushToast({ kind: "success", title: "已提交答复" });
      close();
    } catch (err) {
      pushToast({ kind: "error", title: "提交失败", desc: err.message });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div className="overlay" {...fadeIn} onClick={close}>
          <motion.div className="ask-card" {...scaleIn} onClick={(e) => e.stopPropagation()}>
            <div className="ask-head">
              <div className="icon-wrap"><Icon.HelpCircle /></div>
              <div className="meta">
                <div className="label">AGENT 暂停 · 等待你的输入</div>
                <div className="title">{pending.question || "需要你确认一下"}</div>
              </div>
              <button className="icon-btn" onClick={close} style={{ marginLeft: "auto" }}>
                <Icon.X />
              </button>
            </div>
            <div className="ask-body">
              {pending.context && <div className="ask-question">{pending.context}</div>}
              <div className="ask-options">
                {options.length === 0 && (
                  <div style={{ padding: 16, color: "var(--fg-faint)", fontSize: 12 }}>
                    （无候选选项 — 请等待 agent 推送）
                  </div>
                )}
                {options.map((o, i) => (
                  <div
                    key={o.id || i}
                    className={"ask-option" + (selected === (o.id || o.value) ? " is-selected" : "")}
                    onClick={() => setSelected(o.id || o.value)}
                  >
                    <div className="key">{i + 1}</div>
                    <div className="text">{o.text || o.label}<span className="sub">{o.sub || ""}</span></div>
                    <Icon.Check className="check" />
                  </div>
                ))}
              </div>
            </div>
            <div className="ask-footer">
              <div className="hint">数字键选择 · <Icon.CornerDownLeft style={{ width: 11, height: 11 }} /> 确认 · esc 推迟</div>
              <div className="actions">
                <Button size="sm" variant="ghost" onClick={close}>推迟到稍后</Button>
                <Button size="sm" variant="accent" disabled={!selected || submitting} loading={submitting} onClick={submit}>
                  <Icon.Check /> 提交答复
                </Button>
              </div>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
