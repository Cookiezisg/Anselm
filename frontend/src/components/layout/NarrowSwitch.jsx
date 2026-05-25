// NarrowSwitch — bottom tab switcher visible only when narrow=true and 2
// panes are open. Tap a tab to make that pane visible (the other hides).
//
// NarrowSwitch —— narrow=true 且开 2 个 pane 时显示的底部 tab 条。

import { useTranslation } from "react-i18next";
import { PANE_META } from "./PaneFrame.jsx";
import { useUIStore } from "../../store/ui.js";

export function NarrowSwitch() {
  const { t } = useTranslation("sidebar");
  const openPanes = useUIStore((s) => s.openPanes);
  const narrow = useUIStore((s) => s.narrow);
  const activeNarrowPane = useUIStore((s) => s.activeNarrowPane);
  const setActiveNarrowPane = useUIStore((s) => s.setActiveNarrowPane);

  if (!narrow || openPanes.length < 2) return null;

  const paneLabel = (k) => {
    const meta = PANE_META[k];
    if (!meta) return k;
    return meta.labelKey ? t(meta.labelKey) : (meta.label || k);
  };

  return (
    <div className="narrow-switch">
      {openPanes.map((k) => (
        <button
          key={k}
          className={"narrow-switch-btn" + (activeNarrowPane === k ? " is-active" : "")}
          onClick={() => setActiveNarrowPane(k)}
        >
          {paneLabel(k)}
        </button>
      ))}
    </div>
  );
}
