// useKeyboardShortcuts — global keyboard shortcuts.
//   ⌘K  toggle command palette
//   ⌘B  toggle sidebar
//   ⌘1-9 jump to nth conversation (Phase 3 wires real list)
//   Esc  close active overlay (priority: cmdk > ask > notifs)
//
// 输入框内的 Esc 不触发全局：检测 INPUT/TEXTAREA tag 跳过。

import { useEffect } from "react";
import { useUIStore } from "../store/ui.js";

export function useKeyboardShortcuts() {
  useEffect(() => {
    const onKey = (e) => {
      const tag = e.target?.tagName;
      const inField = tag === "INPUT" || tag === "TEXTAREA" || e.target?.isContentEditable;

      const s = useUIStore.getState();

      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        s.setCmdkOpen(!s.cmdkOpen);
        return;
      }
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "b") {
        e.preventDefault();
        s.setCollapsed(!s.collapsed);
        return;
      }
      if (e.key === "Escape" && !inField) {
        if (s.cmdkOpen) { s.setCmdkOpen(false); return; }
        if (s.askOpen) { s.setAskOpen(false); return; }
        if (s.notifsOpen) { s.setNotifsOpen(false); return; }
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);
}
