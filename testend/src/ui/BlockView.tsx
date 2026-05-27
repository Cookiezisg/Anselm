import { useState } from "react";
import type { BlockNode } from "@/stores/chat";
import { StatusBadge } from "./StatusBadge";

export function BlockView({ block, depth = 0 }: { block: BlockNode; depth?: number }) {
  const [open, setOpen] = useState(block.type !== "reasoning");
  const indent = depth * 12;
  const headerBg = depth === 0 ? "var(--bg-paper)" : "var(--bg-elev)";
  const summary = headerSummary(block);

  return (
    <div style={{
      marginLeft: indent,
      borderLeft: depth > 0 ? "1px solid var(--border-soft)" : undefined,
      paddingLeft: depth > 0 ? 8 : 0,
    }}>
      <div onClick={() => setOpen(!open)} style={{
        cursor: "pointer", padding: "4px 8px", background: headerBg,
        display: "flex", gap: 8, alignItems: "center", fontSize: 12,
      }}>
        <span style={{ width: 12 }}>{open ? "▾" : "▸"}</span>
        <code style={{ fontSize: 11, color: "var(--fg-muted)" }}>{block.type}</code>
        <StatusBadge status={block.status} />
        <span style={{
          color: "var(--fg-muted)", flex: 1, overflow: "hidden",
          textOverflow: "ellipsis", whiteSpace: "nowrap",
        }}>{summary}</span>
        {block.durationMs != null && (
          <span className="muted" style={{ fontSize: 11 }}>{block.durationMs}ms</span>
        )}
      </div>
      {open && (
        <div style={{ padding: "6px 8px" }}>
          {block.type === "text" && <div style={{ whiteSpace: "pre-wrap" }}>{block.content}</div>}
          {block.type === "reasoning" && (
            <div style={{ whiteSpace: "pre-wrap", color: "var(--fg-muted)", fontStyle: "italic" }}>
              {block.content}
            </div>
          )}
          {block.type === "tool_call" && (
            <pre className="raw-json">{prettyArgs(getAttrString(block.attrs, "toolName"), block.content)}</pre>
          )}
          {block.type === "tool_result" && <pre className="raw-json">{block.content}</pre>}
          {block.type === "progress" && <div className="muted">{block.content}</div>}
          {block.type === "compaction" && <pre className="raw-json">{block.content}</pre>}
          {block.type === "message" && <div className="muted">→ nested message</div>}
          {block.children?.map((c) => <BlockView key={c.id} block={c} depth={depth + 1} />)}
        </div>
      )}
    </div>
  );
}

function getAttrString(attrs: unknown, key: string): string | undefined {
  if (attrs && typeof attrs === "object") {
    const v = (attrs as Record<string, unknown>)[key];
    if (typeof v === "string") return v;
  }
  return undefined;
}

function headerSummary(b: BlockNode): string {
  const a = (b.attrs ?? {}) as Record<string, unknown>;
  if (b.type === "tool_call") {
    const toolName = (a.toolName as string | undefined) ?? "?";
    const summary = a.summary as string | undefined;
    return `${toolName}${summary ? ` — ${summary}` : ""}`;
  }
  if (b.type === "compaction") {
    return `covers seq ${a.coversFromSeq}–${a.coversToSeq}`;
  }
  if (b.type === "progress") return String(a.stage ?? "");
  return (b.content || "").slice(0, 80);
}

function prettyArgs(toolName: string | undefined, raw: string): string {
  let args: unknown = raw;
  try { args = JSON.parse(raw); } catch { /* keep raw */ }
  return `${toolName ?? "tool"}(${typeof args === "string" ? args : JSON.stringify(args, null, 2)})`;
}
