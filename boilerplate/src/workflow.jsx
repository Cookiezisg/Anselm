/* eslint-disable react/prop-types */
// Workflow editor — drag-drop canvas + node palette + properties panel

const { useState: useWfState, useRef: useWfRef, useEffect: useWfEffect, useMemo: useWfMemo } = React;

// ── Node palette (LHS) ───────────────────────────────────────────────────
const NODE_KINDS = [
  { kind: "trigger",   label: "Trigger",   icon: "Zap",      desc: "Cron / Webhook / Manual" },
  { kind: "function",  label: "Function",  icon: "Code",     desc: "纯函数 · 沙箱执行" },
  { kind: "handler",   label: "Handler",   icon: "Server",   desc: "Stateful 类调用" },
  { kind: "mcp",       label: "MCP Tool",  icon: "Server",   desc: "调 MCP server" },
  { kind: "skill",     label: "Skill",     icon: "Sparkles", desc: "SKILL.md 模板" },
  { kind: "llm",       label: "LLM",       icon: "Brain",    desc: "纯 LLM 节点" },
  { kind: "http",      label: "HTTP",      icon: "Globe",    desc: "外部 API 调用" },
  { kind: "condition", label: "Condition", icon: "GitBranch",desc: "分支判断" },
  { kind: "loop",      label: "Loop",      icon: "Refresh",  desc: "迭代" },
  { kind: "parallel",  label: "Parallel",  icon: "Layers",   desc: "并行 fan-out" },
  { kind: "approval",  label: "Approval",  icon: "Pause",    desc: "等待人工" },
  { kind: "wait",      label: "Wait",      icon: "Clock",    desc: "定时延迟" },
  { kind: "variable",  label: "Variable",  icon: "Database", desc: "读写变量" },
];

function Palette({ onAdd }) {
  const [q, setQ] = useWfState("");
  const list = NODE_KINDS.filter(k => (k.label + k.desc).toLowerCase().includes(q.toLowerCase()));
  return (
    <aside className="wf-palette">
      <div className="search-input" style={{ width: "100%" }}>
        <Icon.Search className="icon" />
        <input placeholder="拖入节点…" value={q} onChange={e => setQ(e.target.value)} />
      </div>
      <div className="wf-palette-label">节点</div>
      <div className="wf-palette-list">
        {list.map(k => {
          const Ic = Icon[k.icon] || Icon.Code;
          return (
            <button
              key={k.kind}
              className="wf-palette-item"
              draggable
              onDragStart={e => e.dataTransfer.setData("kind", k.kind)}
              onClick={() => onAdd(k.kind)}
            >
              <div className="wf-palette-icon"><Ic /></div>
              <div>
                <div className="wf-palette-name">{k.label}</div>
                <div className="wf-palette-desc">{k.desc}</div>
              </div>
            </button>
          );
        })}
      </div>
    </aside>
  );
}

// ── Canvas node ──────────────────────────────────────────────────────────
function CanvasNode({ node, selected, onMouseDown, onClick, dragOver, connectingFrom }) {
  // version mismatch detection: dummy — flag aggregate_week node
  const versionMismatch = node.sub && node.sub.includes("aggregate_week");
  const Ic = Icon[
    node.kind === "trigger" ? "Zap" :
    node.kind === "function" ? "Code" :
    node.kind === "handler" ? "Server" :
    node.kind === "approval" ? "Pause" :
    node.kind === "variable" ? "Database" :
    node.kind === "condition" ? "GitBranch" :
    node.kind === "loop" ? "Refresh" :
    node.kind === "parallel" ? "Layers" :
    node.kind === "wait" ? "Clock" :
    node.kind === "skill" ? "Sparkles" :
    node.kind === "mcp" ? "Server" :
    node.kind === "llm" ? "Brain" :
    node.kind === "http" ? "Globe" :
    "Code"
  ] || Icon.Code;

  return (
    <div
      className={[
        "wf-node",
        selected && "is-selected",
        (node.error || versionMismatch) && "has-error",
        dragOver && "is-drop-target",
      ].filter(Boolean).join(" ")}
      style={{ left: node.x, top: node.y }}
      onMouseDown={onMouseDown}
      onClick={onClick}
      data-id={node.id}
    >
      <div className={"wf-node-handle in"} data-handle="in" data-id={node.id} />
      <div className="wf-node-head">
        <div className={"wf-node-icon kind-" + node.kind}><Ic /></div>
        <div className="wf-node-title">{node.label}</div>
        {versionMismatch && (
          <span className="version-mismatch" title="该 forge 已升级到 v2，此 workflow 仍引用 pending 版本 — 点击同步">
            <Icon.AlertCircle /> v 过时
          </span>
        )}
        {node.error && !versionMismatch && <Icon.AlertCircle style={{ color: "var(--status-warn)", width: 12, height: 12 }} />}
      </div>
      <div className="wf-node-sub">{node.sub}</div>
      <div
        className={"wf-node-handle out" + (connectingFrom === node.id ? " is-active" : "")}
        data-handle="out"
        data-id={node.id}
      />
    </div>
  );
}

// ── Edge path between two nodes ─────────────────────────────────────────
function edgeBetween(a, b) {
  const sx = a.x + 92, sy = a.y + 64;
  const ex = b.x + 92, ey = b.y;
  const dy = Math.max(30, (ey - sy) / 2);
  return `M ${sx} ${sy} C ${sx} ${sy + dy}, ${ex} ${ey - dy}, ${ex} ${ey}`;
}

// ── Properties panel (RHS) ──────────────────────────────────────────────
function Properties({ node, onChange, onDelete }) {
  if (!node) {
    return (
      <aside className="wf-props">
        <div className="empty" style={{ padding: "32px 16px" }}>
          <Icon.Filter className="icon" />
          <div className="title">没有选中节点</div>
          <div className="sub">点画布上的节点查看 / 编辑属性</div>
        </div>
      </aside>
    );
  }
  return (
    <aside className="wf-props">
      <div className="wf-props-head">
        <KindChip kind={node.kind === "function" ? "function" : node.kind === "handler" ? "handler" : node.kind === "skill" ? "skill" : node.kind === "mcp" ? "mcp" : "function"} />
        <span className="cell-mono">{node.id}</span>
        <div style={{ flex: 1 }} />
        <button className="icon-btn" onClick={onDelete}><Icon.Trash /></button>
      </div>
      <div className="wf-props-body">
        <label className="wf-field">
          <span>标签</span>
          <input className="cfg-input" value={node.label} onChange={e => onChange({ ...node, label: e.target.value })} />
        </label>
        <label className="wf-field">
          <span>引用</span>
          <input className="cfg-input" value={node.sub || ""} onChange={e => onChange({ ...node, sub: e.target.value })} placeholder="fn_xxx / hd_xxx / wf_xxx" />
        </label>
        <div className="wf-field">
          <span>重试</span>
          <div className="wf-field-row">
            <input className="cfg-input" defaultValue="3" style={{ width: 60 }} />
            <span style={{ fontSize: 12, color: "var(--fg-muted)" }}>次</span>
            <span style={{ fontSize: 12, color: "var(--fg-muted)" }}>· 指数退避</span>
          </div>
        </div>
        <div className="wf-field">
          <span>超时</span>
          <div className="wf-field-row">
            <input className="cfg-input" defaultValue="30" style={{ width: 60 }} />
            <span style={{ fontSize: 12, color: "var(--fg-muted)" }}>秒</span>
          </div>
        </div>
        <div className="wf-field">
          <span>onError</span>
          <select className="cfg-input"><option>fail</option><option>skip</option><option>retry</option></select>
        </div>
        {node.kind === "approval" && (
          <div className="wf-field">
            <span>等待时长</span>
            <input className="cfg-input" defaultValue="24h" />
          </div>
        )}
      </div>
    </aside>
  );
}

// ── Workflow editor ───────────────────────────────────────────────────────
function WorkflowEditor({ initialNodes, initialEdges, onChange }) {
  const [nodes, setNodes] = useWfState(() => initialNodes.map(n => ({ ...n })));
  const [edges, setEdges] = useWfState(() => initialEdges.map(e => ({ ...e })));
  const [selected, setSelected] = useWfState("n_agg");
  const [dragNodeId, setDragNodeId] = useWfState(null);
  const [dragOffset, setDragOffset] = useWfState({ x: 0, y: 0 });
  const [connecting, setConnecting] = useWfState(null);
  const [paletteOpen, setPaletteOpen] = useWfState(false);
  const [propsOpen, setPropsOpen] = useWfState(false);
  const canvasRef = useWfRef(null);

  const byId = useWfMemo(() => Object.fromEntries(nodes.map(n => [n.id, n])), [nodes]);
  const selectedNode = byId[selected];

  // Drag node
  const onNodeMouseDown = (e, id) => {
    e.stopPropagation();
    if (e.target.dataset.handle === "out") {
      setConnecting({ from: id, x: e.clientX, y: e.clientY });
      return;
    }
    const node = byId[id];
    setDragNodeId(id);
    setDragOffset({ x: e.clientX - node.x, y: e.clientY - node.y });
    setSelected(id);
    onChange?.();
  };

  useWfEffect(() => {
    if (!dragNodeId && !connecting) return;
    const onMove = (e) => {
      if (dragNodeId) {
        setNodes(ns => ns.map(n => n.id === dragNodeId ? { ...n, x: Math.max(8, e.clientX - dragOffset.x), y: Math.max(8, e.clientY - dragOffset.y) } : n));
      } else if (connecting) {
        setConnecting(c => c && { ...c, x: e.clientX, y: e.clientY });
      }
    };
    const onUp = (e) => {
      if (connecting) {
        // see if dropped on a node's `in` handle
        const target = document.elementFromPoint(e.clientX, e.clientY);
        const id = target?.closest("[data-id]")?.dataset.id;
        if (id && id !== connecting.from) {
          setEdges(es => es.find(x => x.from === connecting.from && x.to === id) ? es : [...es, { from: connecting.from, to: id }]);
        }
        setConnecting(null);
      }
      setDragNodeId(null);
    };
    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onUp);
    return () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("mouseup", onUp);
    };
  }, [dragNodeId, dragOffset, connecting]);

  // Drop from palette
  const onCanvasDrop = (e) => {
    e.preventDefault();
    const kind = e.dataTransfer.getData("kind");
    if (!kind) return;
    const rect = canvasRef.current.getBoundingClientRect();
    const id = "n_" + Math.random().toString(36).slice(2, 7);
    setNodes(ns => [...ns, { id, kind, label: kind, sub: "", x: e.clientX - rect.left - 90, y: e.clientY - rect.top - 30 }]);
    setSelected(id);
    onChange?.();
  };

  // Add via click (puts in center)
  const onPaletteAdd = (kind) => {
    const id = "n_" + Math.random().toString(36).slice(2, 7);
    setNodes(ns => [...ns, { id, kind, label: kind, sub: "", x: 280, y: 220 }]);
    setSelected(id);
    onChange?.();
  };

  // Delete
  const onDelete = () => {
    if (!selected) return;
    setNodes(ns => ns.filter(n => n.id !== selected));
    setEdges(es => es.filter(e => e.from !== selected && e.to !== selected));
    setSelected(null);
    onChange?.();
  };

  useWfEffect(() => {
    const onKey = (e) => {
      if ((e.key === "Backspace" || e.key === "Delete") && selected && e.target.tagName !== "INPUT") onDelete();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [selected]);

  return (
    <div className={"wf-editor" + (paletteOpen ? " is-palette-open" : "") + (propsOpen ? " is-props-open" : "")}>
      <Palette onAdd={onPaletteAdd} />
      <button className="pane-side-toggle" title="切换节点 palette" onClick={() => setPaletteOpen(o => !o)}>
        <Icon.Layers />
      </button>
      <button className="pane-side-toggle right" title="切换属性面板" onClick={() => setPropsOpen(o => !o)}>
        <Icon.Settings />
      </button>

      <div
        ref={canvasRef}
        className="wf-canvas"
        onDragOver={e => e.preventDefault()}
        onDrop={onCanvasDrop}
        onClick={() => setSelected(null)}
      >
        <svg className="wf-edges" width="100%" height="100%">
          <defs>
            <marker id="wf-arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
              <path d="M0 0 L10 5 L0 10 z" fill="var(--border-strong)" />
            </marker>
          </defs>
          {edges.map((e, i) => {
            const a = byId[e.from], b = byId[e.to];
            if (!a || !b) return null;
            const isActive = e.from === selected || e.to === selected;
            return (
              <path
                key={i}
                d={edgeBetween(a, b)}
                fill="none"
                stroke={isActive ? "var(--accent)" : "var(--border-strong)"}
                strokeWidth={isActive ? 2 : 1.4}
                markerEnd="url(#wf-arr)"
              />
            );
          })}
          {connecting && (() => {
            const a = byId[connecting.from];
            if (!a || !canvasRef.current) return null;
            const rect = canvasRef.current.getBoundingClientRect();
            const sx = a.x + 92, sy = a.y + 64;
            const ex = connecting.x - rect.left, ey = connecting.y - rect.top;
            return <path d={`M ${sx} ${sy} L ${ex} ${ey}`} stroke="var(--accent)" strokeWidth="1.6" strokeDasharray="5 4" fill="none" />;
          })()}
        </svg>

        {nodes.map(n => (
          <CanvasNode
            key={n.id}
            node={n}
            selected={selected === n.id}
            onMouseDown={(e) => onNodeMouseDown(e, n.id)}
            onClick={(e) => { e.stopPropagation(); setSelected(n.id); }}
            connectingFrom={connecting?.from}
          />
        ))}

        <div className="wf-canvas-toolbar">
          <button className="icon-btn" title="自动排列"><Icon.Layers /></button>
          <button className="icon-btn" title="放大"><Icon.Plus /></button>
          <button className="icon-btn" title="缩小"><Icon.X /></button>
          <div className="wf-zoom">100%</div>
        </div>
        <div className="wf-canvas-hint">
          拖拽节点移动 · 从节点底部圆点拖到另一节点顶部连线 · <kbd>Backspace</kbd> 删除
        </div>
      </div>

      <Properties
        node={selectedNode}
        onChange={(updated) => setNodes(ns => ns.map(n => n.id === updated.id ? updated : n))}
        onDelete={onDelete}
      />
    </div>
  );
}

function WorkflowView({ forge, onBack }) {
  const [dirty, setDirty] = useWfState(false);
  // Fake auto-save: become "saved" 1.5s after any dirty toggle
  React.useEffect(() => {
    if (!dirty) return;
    const t = setTimeout(() => setDirty(false), 1500);
    return () => clearTimeout(t);
  }, [dirty]);

  return (
    <div className="page">
      <div className="page-header" style={{ paddingTop: 18 }}>
        <div className="page-header-text" style={{ gap: 6 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, fontSize: 12, color: "var(--fg-muted)" }}>
            {onBack && <button onClick={onBack} className="btn btn-xs btn-ghost">← 返回</button>}
            <KindChip kind="workflow" />
            <span className="cell-mono" style={{ color: "var(--fg-faint)" }}>{forge?.id || "wf_weekly_training"}</span>
            <StatusBadge s={forge?.status || "draft"} />
          </div>
          <div className="page-title" style={{ fontFamily: "var(--font-mono)" }}>{forge?.name || "weekly-training-summary"}</div>
          <div className="page-subtitle">{forge?.desc || "每周一早 7:30 把训练数据写到 Notion · 由对话锻造产生"}</div>
        </div>
        <div className="page-actions">
          <span className={"wf-saved" + (dirty ? " is-dirty" : "")}>
            <span className="dot" />
            {dirty ? "未保存的改动" : "已保存"}
          </span>
          <button className="btn btn-sm"><Icon.Eye /> Capability check</button>
          <button className="btn btn-sm"><Icon.Play /> 试跑</button>
          <AskAiTrigger
            context={"Workflow · " + (forge?.name || "weekly-training-summary")}
            suggestions={[
              "在 Notion 写入之前加一个失败重试",
              "把 trigger 改成每天 8 点",
              "在节点之间加一个 Slack 通知节点",
            ]}
          />
          <button className="btn btn-sm btn-accent"><Icon.Check /> 部署</button>
        </div>
      </div>
      <WorkflowEditor initialNodes={Forgify.dagNodes} initialEdges={Forgify.dagEdges} onChange={() => setDirty(true)} />
    </div>
  );
}

window.WorkflowView = WorkflowView;
