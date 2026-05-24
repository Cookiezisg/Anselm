// SidebarSection — collapsible group header with hover-only ▾ chevron.
// In collapsed-sidebar mode the label is replaced by a thin horizontal
// divider; chevron still fades in on hover for symmetry.
//
// SidebarSection —— 可折叠分组标题;hover 才显示 ▾;sidebar 收起态下
// label 降级成 18px 短横线,chev 行为不变。

import { Icon } from "../primitives/Icon.jsx";

export function SidebarSection({ label, expanded, onToggle, collapsedSidebar = false, children }) {
  const cls = "sb-section" + (collapsedSidebar ? " is-collapsed-sb" : "") + (expanded ? " is-expanded" : "");
  return (
    <>
      <button type="button" className={cls} aria-label={label} onClick={onToggle}>
        {!collapsedSidebar && <span className="sb-section-label">{label}</span>}
        {collapsedSidebar && <span className="sb-section-divider" />}
        <Icon.ChevronDown
          size={14}
          strokeWidth={2}
          className={"sb-section-chev" + (expanded ? "" : " is-closed")}
        />
      </button>
      {expanded && children}
    </>
  );
}
