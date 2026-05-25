// Placeholder for panes whose real implementation lands in later phases.
// Renders a minimal page-shell so the AppShell wiring is visible without
// blocking pane open/close.
//
// 后续 Phase 才落地的 pane 临时占位；page 外观完整，不阻塞 shell 验证。

import { useTranslation } from "react-i18next";
import { Icon } from "../components/primitives/Icon.jsx";

export function PlaceholderPane({ title, phase, lead }) {
  const { t } = useTranslation("misc");
  return (
    <div className="page">
      <div className="page-header">
        <div className="page-header-text">
          <div className="page-title">{title}</div>
          <div className="page-subtitle">{lead}</div>
        </div>
      </div>
      <div className="page-body" style={{ padding: 32 }}>
        <div className="empty">
          <Icon.Hammer className="icon" />
          <div className="title">{t("placeholderPane.implementing", { phase })}</div>
          <div className="sub">{t("placeholderPane.subtitle")}</div>
        </div>
      </div>
    </div>
  );
}
