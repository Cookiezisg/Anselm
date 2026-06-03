// AgentDetail — current version full view (prompt / skill / knowledge /
// tools / outputSchema / modelOverride) + Runs history + split diff +
// VersionRail. pending versions surface Accept/Revert at the head; an
// inline invoke drawer runs the agent synchronously.
//
// AgentDetail —— 当前版本完整视图（提示词/技能/知识/工具/输出契约/模型）
// + 执行历史 + 分屏 diff + 右侧 VersionRail；内置 invoke drawer 同步调用。

import React, { useState } from "react";
import { useTranslation } from "react-i18next";
import { motion, AnimatePresence, type MotionProps } from "framer-motion";
import { Icon } from "@shared/ui/Icon";
import { Button } from "@shared/ui/Button";
import { Badge } from "@shared/ui/Badge";
import { KindChip } from "@shared/ui/KindChip.tsx";
import { StatusBadge } from "@shared/ui/StatusBadge.tsx";
import { RelTime } from "@shared/ui/RelTime.tsx";
import { EntityRelMeta } from "@/widgets/entity-rel-meta/EntityRelMeta.tsx";
import { EntityLink } from "@/widgets/entity-link";
import { VersionRail, SplitDiff } from "@/widgets/version-rail/VersionRail.tsx";
import { AskAiTrigger } from "@/widgets/ask-ai-trigger/AskAiTrigger.tsx";
import type { Agent, AgentVersion, AgentExecution, ToolRef, OutputSchema } from "@entities/agent";
import { useAgent, useAgentVersions, useAgentExecutions, useInvokeAgent } from "@entities/agent";
import { useForgeProgress } from "@shared/model";
import { useForgeReview } from "@features/forge-review";
import { slideRight, scrim } from "@shared/lib/motion";
import { useToastStore } from "@shared/ui/toastStore";

interface ForgeEntity {
  id: string;
  [key: string]: unknown;
}

// Runtime shape of a version item — AgentVersion plus the UI-computed
// state/label fields the VersionRail + detail views read.
interface AgentVersionShape extends Omit<Partial<AgentVersion>, "id"> {
  id: string;
  state?: string;
  label?: string;
  versionLabel?: string;
}

// Runtime shape of the agent entity (may be partial before full load).
interface AgRuntime {
  id: string;
  name?: string;
  description?: string;
  desc?: string;
  status?: string;
  [key: string]: unknown;
}

interface AgentDetailProps {
  forge: ForgeEntity;
  onBack: () => void;
}

export function AgentDetail({ forge, onBack }: AgentDetailProps) {
  const { t } = useTranslation(["forge", "common"]);
  const { data: agData = forge } = useAgent(forge.id);
  const ag = agData as AgRuntime;
  const { data: versionsRaw = [] } = useAgentVersions(forge.id);
  const versions = versionsRaw as AgentVersionShape[];
  const { accept: onAccept, reject: onReject, revert: onRevert } = useForgeReview("agent", forge.id, ag.name as string | undefined);
  const progress = useForgeProgress((s) => s.active[`agent:${forge.id}`]);

  const currentV = versions.find((v) => v.state === "current") || versions[0];
  const pendingV = versions.find((v) => v.state === "pending");

  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [invokeOpen, setInvokeOpen] = useState(false);
  const effectiveSelected = selectedId || pendingV?.id || currentV?.id;
  const selectedV = versions.find((v) => v.id === effectiveSelected) || currentV;
  const isViewingCurrent = selectedV?.id === currentV?.id;

  return (
    <div className="page">
      <div className="page-header" style={{ paddingTop: 18 }}>
        <div className="page-header-text" style={{ gap: 6 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, fontSize: 12, color: "var(--fg-muted)" }}>
            <Button size="xs" variant="ghost" onClick={onBack}>
              <Icon.ChevronRight style={{ transform: "rotate(180deg)" }} /> {t("common:back")}
            </Button>
            <span>·</span>
            <KindChip kind="agent" />
            <span className="cell-mono" style={{ color: "var(--fg-faint)" }}>{forge.id}</span>
            {progress && progress.status === "running" && (
              <span className="badge streaming"><span className="dot" />{t("detail.forging")}</span>
            )}
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <div className="page-title" style={{ fontFamily: "var(--font-mono)" }}>{ag.name}</div>
            {!pendingV && <StatusBadge status={ag.status || "ready"} />}
          </div>
          <div className="page-subtitle" style={{ display: "flex", alignItems: "center", gap: 4, flexWrap: "wrap" }}>
            <span>{ag.desc || ag.description || ""}</span>
            <EntityRelMeta entityId={ag.id} kind="agent" />
          </div>
        </div>
        <div className="page-actions">
          {pendingV ? (
            <>
              <Button size="sm" variant="danger" onClick={onReject}>
                <Icon.X /> {t("detail.revert")}
              </Button>
              <Button size="sm" variant="accent" onClick={onAccept}>
                <Icon.Check /> {t("detail.accept")}
              </Button>
            </>
          ) : (
            <>
              <Button size="sm" onClick={() => setInvokeOpen(true)}><Icon.Play /> {t("agent.runBtn")}</Button>
              <AskAiTrigger
                kind="agent"
                entityId={ag.id}
                context={`Agent · ${ag.name}`}
                suggestions={t("agent.aiSuggestions", { returnObjects: true }) as string[]}
              />
            </>
          )}
        </div>
      </div>

      <div className="vr-shell">
        <div className="vr-main">
          {isViewingCurrent
            ? <AgentFullView v={selectedV} ag={ag} />
            : <AgentDiffView currentV={currentV} otherV={selectedV} pendingV={pendingV} />
          }
        </div>
        <VersionRail
          versions={versions}
          currentId={currentV?.id}
          pendingId={pendingV?.id}
          selectedId={effectiveSelected}
          onSelect={setSelectedId}
          onAccept={onAccept}
          onRevert={onRevert ?? onReject}
        />
      </div>
      <InvokeDrawer open={invokeOpen} onClose={() => setInvokeOpen(false)} ag={ag} />
    </div>
  );
}

function FieldRow({ label, value }: { label: React.ReactNode; value: React.ReactNode }) {
  return (
    <div className="fn-field-row">
      <div className="fn-field-label">{label}</div>
      <div className="fn-field-value">{value}</div>
    </div>
  );
}

function ToolPill({ tool }: { tool: ToolRef }) {
  // ref prefix decides whether it links to a forge entity (fn_/hd_) or is a
  // bare mcp: tool string that has no detail page.
  const linkable = /^(fn_|hd_)/.test(tool.ref);
  return (
    <span className="tag" style={{ display: "inline-flex", alignItems: "center", gap: 5 }}>
      <Icon.Wrench style={{ width: 11, height: 11 }} />
      {linkable ? <EntityLink id={tool.ref.split(".")[0]} /> : <code style={{ fontFamily: "var(--font-mono)" }}>{tool.name || tool.ref}</code>}
    </span>
  );
}

function OutputSchemaView({ schema }: { schema: OutputSchema }) {
  const { t } = useTranslation("forge");
  if (schema.kind === "free_text") return <Badge>{t("agent.outputKind.free_text")}</Badge>;
  if (schema.kind === "enum") {
    return (
      <div style={{ display: "flex", alignItems: "center", gap: 6, flexWrap: "wrap" }}>
        <Badge kind="info">{t("agent.outputKind.enum")}</Badge>
        {(schema.enums || []).map((e) => <code key={e} className="tag" style={{ fontFamily: "var(--font-mono)" }}>{e}</code>)}
      </div>
    );
  }
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
      <Badge kind="warn">{t("agent.outputKind.json_schema")}</Badge>
      <pre className="code-block">{JSON.stringify(schema.schema ?? {}, null, 2)}</pre>
    </div>
  );
}

function AgentFullView({ v, ag }: { v: AgentVersionShape | undefined; ag: AgRuntime }) {
  const { t } = useTranslation("forge");
  const [tab, setTab] = useState("definition");
  if (!v) return <div className="empty" style={{ padding: 32 }}><div className="sub">{t("agent.noVersion")}</div></div>;

  const tools = (v.tools || []) as ToolRef[];
  const knowledge = v.knowledge || [];

  return (
    <>
      <div className="page-tabs">
        {[["definition", t("agent.tabs.definition")], ["runs", t("agent.tabs.runs")]].map(([k, l]) => (
          <button key={k} className={"page-tab" + (tab === k ? " is-active" : "")} onClick={() => setTab(k)}>
            {l}
          </button>
        ))}
      </div>

      {tab === "definition" && (
        <div className="fn-view">
          <h3 className="section-label" style={{ marginTop: 0, display: "flex", alignItems: "center", gap: 8 }}>
            {v.label || v.versionLabel || v.id}
            {v.state === "current" && <span className="vr-badge vr-current">{t("detail.badgeCurrent")}</span>}
            {v.state === "pending" && <span className="vr-badge vr-pending"><Icon.Sparkles /> {t("detail.badgePending")}</span>}
          </h3>

          <FieldRow label={t("agent.fieldLabel.description")} value={
            <div style={{ lineHeight: 1.6 }}>
              {ag.description || <span style={{ color: "var(--fg-faint)" }}>—</span>}
            </div>
          } />

          <FieldRow label={t("agent.fieldLabel.skill")} value={
            v.skill
              ? <code style={{ fontFamily: "var(--font-mono)" }}>{v.skill}</code>
              : <span style={{ color: "var(--fg-faint)" }}>{t("agent.fieldLabel.none")}</span>
          } />

          <FieldRow label={t("agent.fieldLabel.knowledge")} value={
            knowledge.length > 0
              ? <div style={{ display: "flex", flexWrap: "wrap", gap: 5 }}>{knowledge.map((k) => <EntityLink key={k} id={k} />)}</div>
              : <span style={{ color: "var(--fg-faint)" }}>{t("agent.fieldLabel.none")}</span>
          } />

          <FieldRow label={t("agent.fieldLabel.tools")} value={
            tools.length > 0
              ? <div style={{ display: "flex", flexWrap: "wrap", gap: 5 }}>{tools.map((tl) => <ToolPill key={tl.ref} tool={tl} />)}</div>
              : <span style={{ color: "var(--fg-faint)" }}>{t("agent.fieldLabel.none")}</span>
          } />

          <FieldRow label={t("agent.fieldLabel.outputSchema")} value={
            v.outputSchema
              ? <OutputSchemaView schema={v.outputSchema} />
              : <span style={{ color: "var(--fg-faint)" }}>{t("agent.outputKind.free_text")}</span>
          } />

          <FieldRow label={t("agent.fieldLabel.model")} value={
            v.modelOverride
              ? <code style={{ fontFamily: "var(--font-mono)" }}>{v.modelOverride.modelId}</code>
              : <span style={{ color: "var(--fg-faint)" }}>{t("agent.fieldLabel.modelDefault")}</span>
          } />

          {v.changeReason && (
            <FieldRow label={t("agent.fieldLabel.changeReason")} value={
              <span style={{ color: "var(--fg-muted)" }}>{v.changeReason}</span>
            } />
          )}

          <h4 className="section-label" style={{ marginTop: 20 }}>{t("agent.fieldLabel.prompt")}</h4>
          {v.prompt
            ? <pre className="code-block agent-prompt">{v.prompt}</pre>
            : <div className="empty" style={{ padding: 18 }}><div className="sub">{t("agent.noPrompt")}</div></div>}
        </div>
      )}

      {tab === "runs" && <AgentRuns agentId={ag.id} />}
    </>
  );
}

function AgentRuns({ agentId }: { agentId: string }) {
  const { t } = useTranslation("forge");
  const { data } = useAgentExecutions(agentId);
  const executions = (data?.executions || []) as AgentExecution[];

  if (executions.length === 0) {
    return (
      <div style={{ padding: "16px 32px" }}>
        <div className="empty" style={{ padding: 18 }}>
          <Icon.ListChecks className="icon" />
          <div className="title">{t("agent.tabs.runs")}</div>
          <div className="sub">{t("agent.runsPlaceholder")}</div>
        </div>
      </div>
    );
  }

  return (
    <div style={{ padding: "16px 32px" }}>
      <table className="t">
        <thead>
          <tr>
            <th>{t("agent.runs.id")}</th>
            <th>{t("agent.runs.status")}</th>
            <th>{t("agent.runs.triggeredBy")}</th>
            <th>{t("agent.runs.elapsed")}</th>
            <th>{t("agent.runs.startedAt")}</th>
          </tr>
        </thead>
        <tbody>
          {executions.map((x) => (
            <tr key={x.id}>
              <td><span className="cell-mono" style={{ color: "var(--fg-faint)" }}>{x.id}</span></td>
              <td>
                <Badge kind={x.status === "ok" ? "success" : x.status === "timeout" ? "warn" : "error"}>{x.status}</Badge>
              </td>
              <td><span className="cell-mono">{x.triggeredBy}</span></td>
              <td><span className="cell-mono">{x.elapsedMs}ms</span></td>
              <td>{x.startedAt ? <RelTime ts={x.startedAt} /> : "—"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function AgentDiffView({ currentV, otherV, pendingV }: { currentV: AgentVersionShape | undefined; otherV: AgentVersionShape | undefined; pendingV: AgentVersionShape | undefined }) {
  const { t } = useTranslation("forge");
  if (!otherV || !currentV) {
    return <div className="empty" style={{ padding: 32 }}><div className="sub">{t("agent.noVersionForDiff")}</div></div>;
  }
  const isPending = otherV.id === pendingV?.id;

  const promptChanged = (currentV.prompt || "") !== (otherV.prompt || "");
  const skillChanged = (currentV.skill || "") !== (otherV.skill || "");
  const toolsA = JSON.stringify(currentV.tools || []);
  const toolsB = JSON.stringify(otherV.tools || []);
  const toolsChanged = toolsA !== toolsB;
  const knowledgeChanged = JSON.stringify(currentV.knowledge || []) !== JSON.stringify(otherV.knowledge || []);
  const outputChanged = JSON.stringify(currentV.outputSchema || null) !== JSON.stringify(otherV.outputSchema || null);

  const total = [promptChanged, skillChanged, toolsChanged, knowledgeChanged, outputChanged].filter(Boolean).length;

  return (
    <div className="fn-view">
      <h3 className="section-label" style={{ marginTop: 0, display: "flex", alignItems: "center", gap: 8 }}>
        Diff · {currentV.label || "current"} ⇆ {otherV.label || otherV.id}
        {isPending && <span className="vr-badge vr-pending"><Icon.Sparkles /> pending</span>}
        <span style={{ color: "var(--fg-faint)", fontWeight: 400, textTransform: "none", letterSpacing: 0 }}>
          · {t("agent.changes", { count: total })}
        </span>
      </h3>

      {total === 0 && (
        <div style={{ padding: 24, color: "var(--fg-faint)", textAlign: "center" }}>{t("agent.identical")}</div>
      )}

      {promptChanged && (
        <div className="fn-diff-section">
          <div className="fn-diff-section-label">{t("agent.fieldLabel.prompt")}</div>
          <SplitDiff
            leftLabel={(currentV.label || "current") + " · current"}
            rightLabel={(otherV.label || otherV.id) + (isPending ? " · pending" : "")}
            leftSrc={currentV.prompt || ""}
            rightSrc={otherV.prompt || ""}
          />
        </div>
      )}

      {skillChanged && (
        <div className="fn-diff-section">
          <div className="fn-diff-section-label">{t("agent.fieldLabel.skill")}</div>
          <div className="fn-diff-2col">
            <div className="fn-diff-side"><code>{currentV.skill || <span style={{ color: "var(--fg-faint)" }}>{t("agent.fieldLabel.none")}</span>}</code></div>
            <div className="fn-diff-side"><code className="is-diff">{otherV.skill || <span style={{ color: "var(--fg-faint)" }}>{t("agent.fieldLabel.none")}</span>}</code></div>
          </div>
        </div>
      )}

      {toolsChanged && (
        <div className="fn-diff-section">
          <div className="fn-diff-section-label">{t("agent.fieldLabel.tools")}</div>
          <SplitDiff
            leftLabel={currentV.label || "current"}
            rightLabel={otherV.label || otherV.id}
            leftSrc={JSON.stringify(currentV.tools || [], null, 2)}
            rightSrc={JSON.stringify(otherV.tools || [], null, 2)}
          />
        </div>
      )}

      {knowledgeChanged && (
        <div className="fn-diff-section">
          <div className="fn-diff-section-label">{t("agent.fieldLabel.knowledge")}</div>
          <SplitDiff
            leftLabel={currentV.label || "current"}
            rightLabel={otherV.label || otherV.id}
            leftSrc={JSON.stringify(currentV.knowledge || [], null, 2)}
            rightSrc={JSON.stringify(otherV.knowledge || [], null, 2)}
          />
        </div>
      )}

      {outputChanged && (
        <div className="fn-diff-section">
          <div className="fn-diff-section-label">{t("agent.fieldLabel.outputSchema")}</div>
          <SplitDiff
            leftLabel={currentV.label || "current"}
            rightLabel={otherV.label || otherV.id}
            leftSrc={JSON.stringify(currentV.outputSchema || null, null, 2)}
            rightSrc={JSON.stringify(otherV.outputSchema || null, null, 2)}
          />
        </div>
      )}
    </div>
  );
}

function safeParse(text: string): [Record<string, unknown> | null, string | null] {
  const s = text.trim();
  if (!s) return [{}, null];
  try { return [JSON.parse(s), null]; }
  catch (e) { return [null, e instanceof Error ? e.message : String(e)]; }
}

// InvokeDrawer — input form for agent :invoke. Synchronous: shows the
// terminal output + step/token stats inline once the run returns.
function InvokeDrawer({ open, onClose, ag }: { open: boolean; onClose: () => void; ag: AgRuntime }) {
  const { t } = useTranslation(["forge", "execute", "common"]);
  const invoke = useInvokeAgent();
  const pushToast = useToastStore((s) => s.pushToast);
  const [body, setBody] = useState("{\n  \n}");
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<Awaited<ReturnType<typeof invoke.mutateAsync>> | null>(null);

  const submit = async () => {
    const [parsed, perr] = safeParse(body);
    if (perr) { setError(t("execute:runDrawer.jsonError", { detail: perr })); return; }
    setError(null); setResult(null);
    try {
      const res = await invoke.mutateAsync({ id: ag.id, input: parsed ?? {} });
      setResult(res);
      pushToast({
        kind: res.ok ? "success" : "error",
        title: res.ok ? t("agent.invoke.toastOk") : t("agent.invoke.toastFail"),
        desc: res.executionId,
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  };

  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div className="overlay-scrim" {...(scrim as MotionProps)} onClick={onClose} />
          <motion.aside className="drawer drawer-right run-drawer" {...(slideRight as MotionProps)} onClick={(e) => e.stopPropagation()}>
            <header className="drawer-head">
              <div className="drawer-title"><Icon.Play /> {t("agent.invoke.title")}</div>
              <button className="icon-btn" onClick={onClose} title={t("common:close")}><Icon.X /></button>
            </header>

            <div className="drawer-body" style={{ display: "flex", flexDirection: "column", gap: 14 }}>
              <div style={{ fontSize: 12, color: "var(--fg-muted)" }}>
                <span style={{ fontFamily: "var(--font-mono)", color: "var(--accent)" }}>{ag.id}</span>
                {ag.name && <> · {ag.name}</>}
              </div>

              <div>
                <label className="drawer-label">{t("agent.invoke.inputLabel")}</label>
                <textarea
                  className="run-drawer-input"
                  value={body}
                  onChange={(e) => setBody(e.target.value)}
                  spellCheck={false}
                  rows={10}
                />
                {error && <div className="run-drawer-error">{error}</div>}
              </div>

              {result && (
                <>
                  <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                    <Badge kind={result.ok ? "success" : "error"}>{result.status}</Badge>
                    <Badge>{t("agent.invoke.steps", { count: result.steps })}</Badge>
                    <Badge>{t("agent.invoke.tokens", { in: result.tokensIn, out: result.tokensOut })}</Badge>
                    <Badge>{result.elapsedMs}ms</Badge>
                  </div>
                  <div>
                    <label className="drawer-label">{t("execute:runDrawer.resultLabel")}</label>
                    <pre className="code-block run-drawer-result">{JSON.stringify(result.output, null, 2)}</pre>
                  </div>
                </>
              )}
            </div>

            <footer className="drawer-foot">
              <div style={{ flex: 1 }} />
              <Button size="sm" variant="ghost" onClick={onClose}>{t("common:cancel")}</Button>
              <Button size="sm" variant="accent" onClick={submit} disabled={invoke.isPending}>
                {invoke.isPending ? <><span className="spinner" /> {t("agent.invoke.running")}</> : <><Icon.Play /> {t("agent.invoke.submit")}</>}
              </Button>
            </footer>
          </motion.aside>
        </>
      )}
    </AnimatePresence>
  );
}
