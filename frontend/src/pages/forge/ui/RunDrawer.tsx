// RunDrawer — input form for function :run, handler :call, workflow :trigger.
// Single component handles all three kinds so the UX stays consistent and
// every invoke surface (forge list, detail page) can open it the same way.
//
// RunDrawer —— function/handler/workflow 三种触发入口的统一表单 drawer。

import { useEffect, useMemo, useRef, useState } from "react";
import { useTranslation } from "react-i18next";
import { motion, AnimatePresence } from "framer-motion";
import { Icon } from "@shared/ui/Icon";
import { Button } from "@shared/ui/Button";
import { Select } from "@shared/ui/Select";
import type { MotionProps } from "framer-motion";
import { useRunFunction } from "@entities/function";
import { useCallHandler } from "@entities/handler";
import { useRunWorkflow } from "@entities/workflow";
import { useInvokeAgent } from "@entities/agent";
import { useToastStore } from "@shared/ui/toastStore";
import { slideRight, scrim } from "@shared/lib/motion";

function safeParse(text: string) {
  const t = text.trim();
  if (!t) return [{}, null];
  try { return [JSON.parse(t), null]; }
  catch (e) { return [null, e instanceof Error ? e.message : String(e)]; }
}

interface RunDrawerProps {
  open: boolean;
  onClose: () => void;
  kind?: string;
  entity: { id?: string; name?: string; methods?: Array<{ name: string; sig?: string; signature?: string }>; currentVersion?: { methods?: Array<{ name: string; sig?: string; signature?: string }> } };
  onOpenExecute?: (id: string) => void;
  triggerNodes?: Array<{ id: string; config?: Record<string, unknown> }>;
}

export function RunDrawer({ open, onClose, kind, entity, onOpenExecute, triggerNodes }: RunDrawerProps) {
  const { t } = useTranslation("execute");
  const run = useRunFunction();
  const call = useCallHandler();
  const trig = useRunWorkflow();
  const invoke = useInvokeAgent();
  const pushToast = useToastStore((s) => s.pushToast);

  const [body, setBody] = useState("{\n  \n}");
  const [method, setMethod] = useState("");
  const [triggerNodeId, setTriggerNodeId] = useState("");
  const [result, setResult] = useState<unknown>(null);
  const [error, setError] = useState<string | null>(null);
  const ta = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (!open) return;
    setResult(null); setError(null);
    setBody("{\n  \n}");
    if (kind === "handler") {
      const methods = entity?.methods || entity?.currentVersion?.methods || [];
      setMethod(methods[0]?.name || "");
    }
    if (kind === "workflow") {
      setTriggerNodeId(triggerNodes?.[0]?.id ?? "");
    }
    setTimeout(() => ta.current?.focus(), 80);
  }, [open, kind, entity?.id, triggerNodes]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") onClose(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  const submit = async () => {
    const [parsed, perr] = safeParse(body);
    if (perr) { setError(t("runDrawer.jsonError", { detail: perr })); return; }
    setError(null); setResult(null);
    try {
      let res;
      if (kind === "function") {
        res = await run.mutateAsync({ id: entity.id ?? "", inputs: parsed });
      } else if (kind === "handler") {
        if (!method) { setError(t("runDrawer.noMethod")); return; }
        res = await call.mutateAsync({ id: entity.id ?? "", method, args: parsed });
      } else if (kind === "workflow") {
        res = await trig.mutateAsync({ id: entity.id ?? "", input: parsed, ...(triggerNodeId ? { triggerNodeId } : {}) });
        const runId = ((res as Record<string, unknown>)?.flowRunId || (res as Record<string, unknown>)?.id || (res as Record<string, unknown>)?.runId) as string | undefined;
        pushToast({ kind: "success", title: t("runDrawer.toast.triggerSuccess"), desc: runId || t("runDrawer.toast.triggerDefaultDesc") });
        if (runId) {
          onOpenExecute?.(runId);
        }
      } else if (kind === "agent") {
        res = await invoke.mutateAsync({ id: entity.id ?? "", input: parsed });
      }
      setResult(res);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  };

  const busy = run.isPending || call.isPending || trig.isPending || invoke.isPending;
  const methods = kind === "handler"
    ? (entity?.methods || entity?.currentVersion?.methods || [])
    : [];

  // Dynamic key is safe here — all runDrawer.title.{kind} keys exist in ns.
  const title = String(t(`runDrawer.title.${kind}` as never, kind as string));

  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div className="overlay-scrim" {...(scrim as MotionProps)} onClick={onClose} />
          <motion.aside
            className="drawer drawer-right run-drawer"
            {...(slideRight as MotionProps)}
            onClick={(e) => e.stopPropagation()}
          >
            <header className="drawer-head">
              <div className="drawer-title">
                <Icon.Play /> {title}
              </div>
              <button className="icon-btn" onClick={onClose} title={t("runDrawer.closeTitle")}><Icon.X /></button>
            </header>

            <div className="drawer-body" style={{ display: "flex", flexDirection: "column", gap: 14 }}>
              <div style={{ fontSize: 12, color: "var(--fg-muted)" }}>
                <span style={{ fontFamily: "var(--font-mono)", color: "var(--accent)" }}>{entity?.id}</span>
                {entity?.name && <> · {entity.name}</>}
              </div>

              {kind === "handler" && (
                <div>
                  <label className="drawer-label">{t("runDrawer.methodLabel")}</label>
                  {methods.length === 0 ? (
                    <div className="empty" style={{ padding: 12 }}>
                      <div className="sub">{t("runDrawer.noMethods")}</div>
                    </div>
                  ) : (
                    <Select
                      mono
                      ariaLabel={t("runDrawer.methodAriaLabel")}
                      value={method}
                      onChange={setMethod}
                      options={methods.map((m) => ({
                        value: m.name,
                        label: m.name + (m.sig || m.signature ? " " + (m.sig || m.signature) : ""),
                      }))}
                    />
                  )}
                </div>
              )}

              {kind === "workflow" && triggerNodes && triggerNodes.length > 1 && (
                <div>
                  <label className="drawer-label">{t("runDrawer.triggerNodeLabel")}</label>
                  <Select
                    mono
                    ariaLabel={t("runDrawer.triggerNodeAriaLabel")}
                    value={triggerNodeId}
                    onChange={setTriggerNodeId}
                    options={triggerNodes.map((n) => ({
                      value: n.id,
                      label: `${n.id}${n.config?.kind ? ` · ${n.config.kind}` : ""}`,
                    }))}
                  />
                </div>
              )}

              <div>
                <label className="drawer-label">
                  {kind === "function" ? "inputs (JSON)" : kind === "handler" ? "args (JSON)" : "input (JSON)"}
                </label>
                {/* agent/workflow both use the "input (JSON)" label above */}
                <textarea
                  ref={ta}
                  className="run-drawer-input"
                  value={body}
                  onChange={(e) => setBody(e.target.value)}
                  spellCheck={false}
                  rows={10}
                />
                {error && <div className="run-drawer-error">{error}</div>}
              </div>

              {result != null && (
                <div>
                  <label className="drawer-label">{t("runDrawer.resultLabel")}</label>
                  <pre className="code-block run-drawer-result">{JSON.stringify(result, null, 2)}</pre>
                </div>
              )}
            </div>

            <footer className="drawer-foot">
              <span style={{ fontSize: 11, color: "var(--fg-faint)" }}>
                {t("runDrawer.footerHint")}
              </span>
              <div style={{ flex: 1 }} />
              <Button size="sm" variant="ghost" onClick={onClose}>{t("common:cancel")}</Button>
              <Button size="sm" variant="accent" onClick={submit} disabled={busy}>
                {busy ? <><span className="spinner" /> {t("runDrawer.submittingBtn")}</> : <><Icon.Play /> {t("runDrawer.submitBtn")}</>}
              </Button>
            </footer>
          </motion.aside>
        </>
      )}
    </AnimatePresence>
  );
}
