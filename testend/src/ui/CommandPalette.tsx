import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useUIStore } from "@/stores/ui";

const ROUTES: Array<{ path: string; label: string; section: string }> = [
  { section: "current", path: "/current/wire", label: "Wire Trace" },
  { section: "current", path: "/current/eventlog", label: "Eventlog Raw" },
  { section: "current", path: "/current/notifications", label: "Notifications (scoped)" },
  { section: "current", path: "/current/subagents", label: "SubAgents" },
  { section: "current", path: "/current/tools", label: "Tool Calls" },
  { section: "current", path: "/current/todos", label: "Todos" },
  { section: "current", path: "/current/asks", label: "Asks Pending" },
  { section: "current", path: "/current/attachments", label: "Attachments" },
  { section: "current", path: "/current/compaction", label: "Compaction" },
  { section: "forge", path: "/forge/functions", label: "Functions" },
  { section: "forge", path: "/forge/handlers", label: "Handlers" },
  { section: "forge", path: "/forge/workflows", label: "Workflows" },
  { section: "forge", path: "/forge/tools", label: "Tools Registry" },
  { section: "execute", path: "/execute/triggers", label: "Triggers" },
  { section: "execute", path: "/execute/flowruns", label: "FlowRuns" },
  { section: "execute", path: "/execute/approvals", label: "Approvals Queue" },
  { section: "execute", path: "/execute/executions", label: "Executions" },
  { section: "observe", path: "/observe/live", label: "Live SSE" },
  { section: "observe", path: "/observe/notifications", label: "Notification History" },
  { section: "observe", path: "/observe/catalog", label: "Catalog" },
  { section: "observe", path: "/observe/usage", label: "Usage" },
  { section: "observe", path: "/observe/mock-llm", label: "Mock LLM" },
  { section: "config", path: "/config/apikeys", label: "API Keys" },
  { section: "config", path: "/config/models", label: "Model Configs" },
  { section: "config", path: "/config/skills", label: "Skills" },
  { section: "config", path: "/config/mcp", label: "MCP Servers" },
  { section: "config", path: "/config/sandbox", label: "Sandbox" },
  { section: "config", path: "/config/memory", label: "Memory" },
  { section: "config", path: "/config/documents", label: "Documents" },
  { section: "config", path: "/config/permissions", label: "Permissions" },
  { section: "config", path: "/config/llm-health", label: "LLM Health" },
  { section: "config", path: "/config/profile", label: "Profile" },
  { section: "dev", path: "/dev/sql", label: "SQL Console" },
  { section: "dev", path: "/dev/info", label: "Info" },
  { section: "dev", path: "/dev/routes", label: "Routes" },
  { section: "dev", path: "/dev/logs", label: "Backend Logs" },
  { section: "dev", path: "/dev/processes", label: "Bash Processes" },
  { section: "dev", path: "/dev/metrics", label: "Metrics" },
  { section: "dev", path: "/dev/errors", label: "Errors" },
  { section: "dev", path: "/dev/prompts", label: "Prompts" },
];

export function CommandPalette() {
  const { palette, closePalette } = useUIStore();
  const [q, setQ] = useState("");
  const [idx, setIdx] = useState(0);
  const navigate = useNavigate();

  const filtered = useMemo(() => {
    const ql = q.toLowerCase();
    return ROUTES.filter((r) =>
      r.label.toLowerCase().includes(ql) || r.path.toLowerCase().includes(ql)
    ).slice(0, 12);
  }, [q]);

  useEffect(() => { setIdx(0); }, [q]);

  useEffect(() => {
    if (!palette) return;
    const h = (e: KeyboardEvent) => {
      if (e.key === "Escape") closePalette();
      else if (e.key === "ArrowDown") {
        e.preventDefault();
        setIdx((i) => Math.min(i + 1, filtered.length - 1));
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        setIdx((i) => Math.max(i - 1, 0));
      } else if (e.key === "Enter") {
        const r = filtered[idx];
        if (r) { navigate(r.path); closePalette(); }
      }
    };
    window.addEventListener("keydown", h);
    return () => window.removeEventListener("keydown", h);
  }, [palette, filtered, idx, navigate, closePalette]);

  if (!palette) return null;
  return (
    <div onClick={closePalette} style={{
      position: "fixed", inset: 0, background: "rgba(0,0,0,0.4)",
      zIndex: 150, display: "flex", alignItems: "flex-start", justifyContent: "center", paddingTop: 120,
    }}>
      <div onClick={(e) => e.stopPropagation()} style={{
        background: "var(--bg-paper)", border: "1px solid var(--border)",
        borderRadius: 8, width: 480, padding: 8,
      }}>
        <input autoFocus value={q} onChange={(e) => setQ(e.target.value)} placeholder="跳转…" style={{
          width: "100%", padding: "8px 10px", border: "1px solid var(--border)",
          borderRadius: 4, background: "var(--bg-window)", color: "var(--fg-body)", fontSize: 14,
        }} />
        <div style={{ marginTop: 8, maxHeight: 360, overflowY: "auto" }}>
          {filtered.map((r, i) => (
            <div key={r.path}
              onClick={() => { navigate(r.path); closePalette(); }}
              style={{
                padding: "6px 10px", cursor: "pointer",
                background: i === idx ? "var(--bg-elev)" : "transparent",
                borderRadius: 4, display: "flex", justifyContent: "space-between",
              }}>
              <span><span className="muted" style={{ marginRight: 6 }}>{r.section}</span>{r.label}</span>
              <span className="muted mono" style={{ fontSize: 11 }}>{r.path}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
