// ObservePane — pane shell around the full RelGraph. Force-directed view
// of all entities in the workspace + relations between them.
//
// ObservePane —— 全图谱 pane（RelGraph 力导向 + filter + node detail）。

import { useTranslation } from "react-i18next";
import { Icon } from "../../components/primitives/Icon.jsx";
import { RelGraph } from "../../components/shared/RelGraph.jsx";

export function ObservePane() {
  const { t } = useTranslation("misc");
  return (
    <div className="page" style={{ display: "flex", flexDirection: "column", overflow: "hidden" }}>
      <div className="page-header">
        <div className="page-header-text">
          <div className="page-title"><Icon.GitBranch /> {t("observePane.title")}</div>
          <div className="page-subtitle">{t("observePane.subtitle")}</div>
        </div>
      </div>
      <div style={{ flex: 1, minHeight: 0 }}>
        <RelGraph />
      </div>
    </div>
  );
}
