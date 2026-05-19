// Sidebar — left navigation rail. Static skeleton in Phase 2; real
// conversation list lands in Phase 3 via useConversations().
//
// Sidebar —— 左侧导航。Phase 2 静态骨架；Phase 3 接 useConversations() 出
// 真实对话列表。

import { useState } from "react";
import { motion } from "framer-motion";
import { Icon } from "../primitives/Icon.jsx";
import { Kbd } from "../primitives/Kbd.jsx";
import { useUIStore } from "../../store/ui.js";
import { spring } from "../../motion/tokens.js";

function NavItem({ icon: I, label, active, onClick, badge }) {
  return (
    <button
      className={"nav-item" + (active ? " is-active" : "")}
      onClick={onClick}
    >
      {I && <I className="icon" />}
      <span className="label">{label}</span>
      {badge != null && <span className="badge">{badge}</span>}
    </button>
  );
}

export function Sidebar() {
  const openPanes = useUIStore((s) => s.openPanes);
  const togglePane = useUIStore((s) => s.togglePane);
  const collapsed = useUIStore((s) => s.collapsed);
  const setCmdkOpen = useUIStore((s) => s.setCmdkOpen);
  const setNotifsOpen = useUIStore((s) => s.setNotifsOpen);
  const setAskOpen = useUIStore((s) => s.setAskOpen);
  const setSettingsPopOpen = useUIStore((s) => s.setSettingsPopOpen);
  const settingsPopOpen = useUIStore((s) => s.settingsPopOpen);

  const isOpen = (k) => openPanes.includes(k);

  return (
    <motion.aside
      className={"sidebar" + (collapsed ? " is-collapsed" : "")}
      animate={{ width: collapsed ? 56 : 248 }}
      transition={spring}
      style={{ overflow: "hidden" }}
    >
      <div className="sidebar-header">
        <div className="workspace-pill">
          <div style={{ flex: 1, minWidth: 0 }}>
            <div className="workspace-name">Forgify</div>
            {!collapsed && (
              <div style={{ fontSize: 10, color: "var(--fg-faint)" }}>local</div>
            )}
          </div>
          {!collapsed && <Icon.ChevronDown style={{ width: 12, height: 12, color: "var(--fg-faint)" }} />}
        </div>

        {!collapsed && (
          <button className="cmdk-trigger" onClick={() => setCmdkOpen(true)}>
            <Icon.Search className="icon" />
            <span className="label">搜索 · 跳转 · 命令</span>
            <Kbd>⌘</Kbd>
            <Kbd>K</Kbd>
          </button>
        )}
      </div>

      <div className="nav-section">
        <div style={{ height: 4 }} />
        <NavItem icon={Icon.MessageSquare} label="对话"  active={isOpen("chat")}      onClick={() => togglePane("chat")} />
        <NavItem icon={Icon.Hammer}        label="锻造"  active={isOpen("forge")}     onClick={() => togglePane("forge")} />
        <NavItem icon={Icon.Play}          label="执行"  active={isOpen("execute")}   onClick={() => togglePane("execute")} />
        <NavItem icon={Icon.FileText}      label="文档"  active={isOpen("documents")} onClick={() => togglePane("documents")} />
      </div>

      <div className="nav-section">
        {!collapsed && <div className="nav-section-title"><span>资源库</span></div>}
        <NavItem icon={Icon.Sparkles}      label="Skills" active={isOpen("skills")} onClick={() => togglePane("skills")} />
        <NavItem icon={Icon.Server}        label="MCP"    active={isOpen("mcp")}    onClick={() => togglePane("mcp")} />
        <NavItem icon={Icon.Brain}         label="Memory" active={isOpen("memory")} onClick={() => togglePane("memory")} />
      </div>

      <div className="nav-section nav-conv-section" style={{ overflowY: "auto", flex: 1, paddingBottom: 12 }}>
        {!collapsed && (
          <div className="nav-section-title">
            <span>最近对话</span>
            <button className="add-btn" title="新对话"><Icon.Plus /></button>
          </div>
        )}
        {!collapsed && (
          <div style={{ padding: "16px 10px", fontSize: 11, color: "var(--fg-faint)", textAlign: "center" }}>
            （Phase 3 接真实数据）
          </div>
        )}
      </div>

      <div className="sidebar-footer">
        <div className="user-pill">
          <div className="user-avatar">S</div>
          {!collapsed && <div className="user-name">本地</div>}
          {!collapsed && (
            <>
              <span className="user-status" title="后端在线" />
              <div style={{ flex: 1 }} />
            </>
          )}
          <button className="icon-btn" onClick={() => setAskOpen(true)} title="待回答的 agent 问题">
            <Icon.HelpCircle />
          </button>
          <button className="icon-btn" onClick={() => setNotifsOpen(true)} title="通知">
            <Icon.Bell />
          </button>
          <button
            className="icon-btn"
            onClick={() => setSettingsPopOpen(!settingsPopOpen)}
            title="主题 / 密度 / Accent"
          >
            <Icon.Settings />
          </button>
        </div>
      </div>
    </motion.aside>
  );
}
