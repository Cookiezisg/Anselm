// useKeyboardShortcuts — global keyboard shortcuts.
//   ⌘K  toggle command palette
//   ⌘B  toggle sidebar
//   ⌘1-9 jump to nth conversation (Phase 3 wires real list)
//   Esc  close active overlay (priority: cmdk > ask > notifs)
//
// 输入框内的 Esc 不触发全局：检测 INPUT/TEXTAREA tag 跳过。

import { useEffect } from "react";
// TODO(4b): pages props 化后移除 shared-tmp→app 过渡引用
import { useOverlayStore, useSidebarStore } from "@app/model";

export function useKeyboardShortcuts() {
  useEffect(() => {
    const onKey = (e) => {
      const tag = e.target?.tagName;
      const inField = tag === "INPUT" || tag === "TEXTAREA" || e.target?.isContentEditable;

      const overlay = useOverlayStore.getState();
      const sidebar = useSidebarStore.getState();

      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        overlay.setCmdkOpen(!overlay.cmdkOpen);
        return;
      }
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "b") {
        e.preventDefault();
        sidebar.setCollapsed(!sidebar.collapsed);
        return;
      }
      if (e.key === "Escape" && !inField) {
        if (overlay.cmdkOpen) { overlay.setCmdkOpen(false); return; }
        if (overlay.askOpen) { overlay.setAskOpen(false); return; }
        if (overlay.notifsOpen) { overlay.setNotifsOpen(false); return; }
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);
}
