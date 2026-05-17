/* eslint-disable react/prop-types */
// Overlays: Command Palette, AskUserQuestion modal, Notifications drawer, Approval banner

const { useState: useOvState, useEffect: useOvEffect, useMemo: useOvMemo } = React;

// ── Command palette ──────────────────────────────────────────────────────
function CommandPalette({ open, onClose, onNavigate }) {
  const [q, setQ] = useOvState("");
  const [active, setActive] = useOvState(0);

  const items = useOvMemo(() => {
    const a = [];
    a.push({ group: "导航", icon: Icon.MessageSquare, label: "打开对话", desc: "切换到对话视图", action: () => onNavigate?.("chat") });
    a.push({ group: "导航", icon: Icon.Hammer, label: "打开锻造", desc: "Function / Handler / Workflow", action: () => onNavigate?.("forge") });
    a.push({ group: "导航", icon: Icon.Play, label: "打开执行", desc: "FlowRuns · Triggers · Approvals", action: () => onNavigate?.("execute") });
    a.push({ group: "导航", icon: Icon.Library, label: "打开资源库", desc: "Skills · MCP · Memory", action: () => onNavigate?.("library") });
    a.push({ group: "导航", icon: Icon.Workflow, label: "打开 weekly-training-summary 工作流", desc: "wf_weekly_training · draft", action: () => onNavigate?.("workflow") });

    a.push({ group: "动作", icon: Icon.Plus, label: "新建对话", desc: "在 chat 中开始", action: () => onNavigate?.("chat"), shortcut: "⌘N" });
    a.push({ group: "动作", icon: Icon.Hammer, label: "新建 Function", desc: "锻造一个新工具" });
    a.push({ group: "动作", icon: Icon.Workflow, label: "新建 Workflow", desc: "在画布上拼装" });
    a.push({ group: "动作", icon: Icon.KeyRound, label: "添加 API Key", action: () => onNavigate?.("config") });

    a.push(...Forgify.conversations.slice(0, 5).map(c => ({
      group: "对话", icon: Icon.MessageSquare, label: c.title, desc: relTime(c.updatedAt), action: () => onNavigate?.("chat"),
    })));

    a.push(...Forgify.forges.slice(0, 5).map(f => ({
      group: "Forge", icon: f.kind === "function" ? Icon.Code : f.kind === "handler" ? Icon.Server : Icon.Workflow,
      label: f.name, desc: f.desc, action: () => onNavigate?.("forge"),
    })));

    return a;
  }, []);

  const filtered = useOvMemo(() => {
    const s = q.trim().toLowerCase();
    if (!s) return items;
    return items.filter(i => (i.label + " " + i.desc).toLowerCase().includes(s));
  }, [q, items]);

  // Group by section
  const groups = useOvMemo(() => {
    const m = new Map();
    filtered.forEach(it => {
      if (!m.has(it.group)) m.set(it.group, []);
      m.get(it.group).push(it);
    });
    return [...m.entries()];
  }, [filtered]);

  useOvEffect(() => {
    if (!open) return;
    setQ("");
    setActive(0);
  }, [open]);

  useOvEffect(() => {
    if (!open) return;
    const onKey = (e) => {
      if (e.key === "Escape") { onClose(); return; }
      if (e.key === "ArrowDown") { e.preventDefault(); setActive(a => Math.min(a + 1, filtered.length - 1)); }
      if (e.key === "ArrowUp") { e.preventDefault(); setActive(a => Math.max(a - 1, 0)); }
      if (e.key === "Enter") {
        const it = filtered[active];
        if (it) { it.action?.(); onClose(); }
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, filtered, active, onClose]);

  if (!open) return null;

  let cursor = 0;
  return (
    <div className="overlay" onClick={onClose}>
      <div className="cmdk" onClick={e => e.stopPropagation()}>
        <div className="cmdk-input-wrap">
          <Icon.Search className="icon" />
          <input
            className="cmdk-input"
            autoFocus
            placeholder="搜索对话 / 工具 / 工作流 / 文档，或输入命令…"
            value={q}
            onChange={e => { setQ(e.target.value); setActive(0); }}
          />
          <kbd>ESC</kbd>
        </div>
        <div className="cmdk-list">
          {groups.length === 0 && (
            <div style={{ padding: "32px 16px", textAlign: "center", color: "var(--fg-faint)", fontSize: 13 }}>
              没有匹配 — 试试别的关键词
            </div>
          )}
          {groups.map(([gname, items]) => (
            <React.Fragment key={gname}>
              <div className="cmdk-group-label">{gname}</div>
              {items.map(it => {
                const idx = cursor++;
                const IconX = it.icon || Icon.ChevronRight;
                return (
                  <div
                    key={idx}
                    className={"cmdk-row" + (idx === active ? " is-active" : "")}
                    onMouseEnter={() => setActive(idx)}
                    onClick={() => { it.action?.(); onClose(); }}
                  >
                    <div className="icon-wrap"><IconX /></div>
                    <div className="label">
                      <span>{it.label}</span>
                      {it.desc && <span className="desc">— {it.desc}</span>}
                    </div>
                    <div className="meta">
                      {it.shortcut && <kbd>{it.shortcut}</kbd>}
                      <Icon.CornerDownLeft style={{ width: 11, height: 11, opacity: idx === active ? 1 : 0 }} />
                    </div>
                  </div>
                );
              })}
            </React.Fragment>
          ))}
        </div>
        <div className="cmdk-footer">
          <div className="hint"><kbd>↑</kbd> <kbd>↓</kbd> 移动 · <kbd>↵</kbd> 选择 · <kbd>esc</kbd> 关闭</div>
          <div className="hint">Forgify · 本地</div>
        </div>
      </div>
    </div>
  );
}

// ── AskUserQuestion modal ────────────────────────────────────────────────
function AskUserModal({ open, onClose, onAnswer }) {
  const [selected, setSelected] = useOvState(null);

  if (!open) return null;
  const options = [
    { id: "yes", text: "是的，按周一 07:30 触发", sub: "cron: 30 7 * * 1" },
    { id: "weekday", text: "改成每天早上汇总当天的", sub: "cron: 0 23 * * *" },
    { id: "manual", text: "只手动触发，先不设定时", sub: "trigger.kind = manual" },
    { id: "other", text: "我自己说明 …", sub: "切回 chat 输入" },
  ];

  return (
    <div className="overlay" onClick={onClose}>
      <div className="ask-card" onClick={e => e.stopPropagation()}>
        <div className="ask-head">
          <div className="icon-wrap"><Icon.HelpCircle /></div>
          <div className="meta">
            <div className="label">AGENT 暂停 · 等待你的输入</div>
            <div className="title">触发时机怎么定？</div>
          </div>
          <button className="icon-btn" onClick={onClose} style={{ marginLeft: "auto" }}><Icon.X /></button>
        </div>
        <div className="ask-body">
          <div className="ask-question">
            workflow <code style={{ fontFamily: "var(--font-mono)" }}>weekly-training-summary</code> 准备好了。在我把它部署到调度器之前，确认一下触发时机：
          </div>
          <div className="ask-options">
            {options.map((o, i) => (
              <div key={o.id} className={"ask-option" + (selected === o.id ? " is-selected" : "")} onClick={() => setSelected(o.id)}>
                <div className="key">{i + 1}</div>
                <div className="text">{o.text}<span className="sub">{o.sub}</span></div>
                <Icon.Check className="check" />
              </div>
            ))}
          </div>
        </div>
        <div className="ask-footer">
          <div className="hint"><kbd>1</kbd>–<kbd>4</kbd> 选择 · <kbd>↵</kbd> 确认 · <kbd>esc</kbd> 推迟</div>
          <div className="actions">
            <button className="btn btn-sm btn-ghost" onClick={onClose}>推迟到稍后</button>
            <button className="btn btn-sm btn-accent" disabled={!selected} onClick={() => { onAnswer?.(selected); onClose(); }}>
              <Icon.Check /> 提交答复
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// ── Notifications drawer ─────────────────────────────────────────────────
function NotificationsDrawer({ open, onClose }) {
  // Group consecutive notifs from same entity in same time bucket
  const grouped = [];
  const all = Forgify.notifications.slice();
  for (const n of all) {
    const last = grouped[grouped.length - 1];
    const key = n.type + ":" + (n.title.split(" ").slice(0, 2).join(" "));
    if (last && last.key === key && (Math.abs(n.time - last.items[last.items.length - 1].time) < 24 * 60 * 60 * 1000)) {
      last.items.push(n);
    } else {
      grouped.push({ key, type: n.type, icon: n.icon, items: [n] });
    }
  }

  const NOTIF_TARGET = {
    approval:     "execute",
    flowrun:      "execute",
    forge:        "forge",
    mcp:          "mcp",
    conversation: "chat",
    skill:        "skills",
    memory:       "memory",
  };

  const handleClick = (n) => {
    const target = NOTIF_TARGET[n.type];
    if (target && window.Shell) window.Shell.openPane(target);
    onClose();
  };

  const bucket = (n) => {
    const m = (Date.now() - n.time.getTime()) / 1000 / 60;
    if (m < 60) return "now";
    if (m < 24 * 60) return "today";
    return "older";
  };
  const LABELS = { now: "现在", today: "今天稍早", older: "更早" };

  return (
    <div className={"drawer-wrap" + (open ? " is-open" : "")}>
      <div className="drawer-scrim" onClick={onClose} />
      <div className="drawer">
        <div className="drawer-head">
          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <Icon.Bell style={{ width: 14, height: 14, color: "var(--fg-muted)" }} />
            <div className="drawer-title">通知</div>
            <span className="badge muted">{all.filter(n => n.unread).length} 未读</span>
          </div>
          <div style={{ display: "flex", gap: 4 }}>
            <button className="btn btn-xs btn-ghost">订阅设置</button>
            <button className="btn btn-xs btn-ghost">全部已读</button>
            <button className="icon-btn" onClick={onClose}><Icon.X /></button>
          </div>
        </div>
        <div className="drawer-list">
          {["now", "today", "older"].map(b => {
            const groups = grouped.filter(g => bucket(g.items[0]) === b);
            if (groups.length === 0) return null;
            return (
              <div key={b}>
                <div className="cmdk-group-label">{LABELS[b]}</div>
                {groups.map((g, gi) => {
                  const I = Icon[g.icon] || Icon.Bell;
                  const n = g.items[0];
                  const hasMultiple = g.items.length > 1;
                  return (
                    <div key={gi} className={"notif" + (n.unread ? " is-unread" : "")} onClick={() => handleClick(n)}>
                      <div className="icon-wrap"><I /></div>
                      <div className="meta">
                        <div className="row">
                          {n.title}
                          {hasMultiple && <span className="badge muted" style={{ marginLeft: 6 }}>×{g.items.length}</span>}
                          {n.unread && <span className="dot" style={{ width: 6, height: 6, borderRadius: "50%", background: "var(--accent)", marginLeft: 4 }} />}
                        </div>
                        <div className="desc">
                          {hasMultiple
                            ? `已合并 ${g.items.length} 条 · 最新：${n.desc}`
                            : n.desc}
                        </div>
                        <div className="time">
                          <RelTime ts={n.time} />
                          {hasMultiple && <> · 最早 <RelTime ts={g.items[g.items.length - 1].time} /></>}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

// ── Approval banner (sticky toast) ───────────────────────────────────────
function ApprovalBanner({ onOpen }) {
  return (
    <div className="approval-banner">
      <div className="icon-wrap"><Icon.Pause /></div>
      <div>
        <div className="title">weekly-training-summary 等待批准</div>
        <div className="desc">workflow paused · 节点 3/4 · cron 触发于 28 分钟前</div>
      </div>
      <button className="btn btn-xs btn-ghost" onClick={onOpen}>查看</button>
      <button className="btn btn-xs btn-accent"><Icon.Check /> 批准</button>
    </div>
  );
}

window.CommandPalette = CommandPalette;
window.AskUserModal = AskUserModal;
window.NotificationsDrawer = NotificationsDrawer;
window.ApprovalBanner = ApprovalBanner;
