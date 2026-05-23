import { Icon } from "../primitives/Icon.jsx";

// PaneCollapseToggle — hover-only floating button used to expand a
// collapsed sub-pane. Sits absolutely on the page edge, vertically
// centred, invisible until the user's mouse enters the trigger zone.
//
// PaneCollapseToggle —— 折叠子面板的 hover-only 浮按钮；
// 贴边缘垂直居中，鼠标进入触发区才浮现。

export function PaneCollapseToggle({ side = "left", onClick, title }) {
  return (
    <button
      type="button"
      className={"pane-toggle pane-toggle-" + side}
      onClick={onClick}
      title={title || "展开"}
      aria-label={title || "展开侧栏"}
    >
      <Icon.ChevronRight />
    </button>
  );
}
