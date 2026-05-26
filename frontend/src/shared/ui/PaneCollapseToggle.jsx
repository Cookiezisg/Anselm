import { useTranslation } from "react-i18next";
import { Icon } from "./Icon.tsx";

// PaneCollapseToggle — hover-only floating button used to expand a
// collapsed sub-pane. Sits absolutely on the page edge, vertically
// centred, invisible until the user's mouse enters the trigger zone.
//
// PaneCollapseToggle —— 折叠子面板的 hover-only 浮按钮；
// 贴边缘垂直居中，鼠标进入触发区才浮现。

export function PaneCollapseToggle({ side = "left", onClick, title }) {
  const { t } = useTranslation("misc");
  return (
    <button
      type="button"
      className={"pane-toggle pane-toggle-" + side}
      onClick={onClick}
      title={title || t("paneCollapse.expand")}
      aria-label={title || t("paneCollapse.expandAria")}
    >
      <Icon.ChevronRight />
    </button>
  );
}
