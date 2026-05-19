// ChatListItem — one row in the sidebar conversation list.
// status dot reflects conversation state (streaming pulses, approval =
// warn color), title is left-aligned and truncates. Hover shows ActionMenu.
//
// ChatListItem —— sidebar 对话项；status dot 透露 streaming/approval；
// hover 显示 ActionMenu。

import { useUIStore } from "../../store/ui.js";
import { Icon } from "../primitives/Icon.jsx";
import { ActionMenu } from "../shared/ActionMenu.jsx";

export function ChatListItem({ conv }) {
  const activeConv = useUIStore((s) => s.activeConv);
  const setActiveConv = useUIStore((s) => s.setActiveConv);
  const openPane = useUIStore((s) => s.openPane);
  const openPanes = useUIStore((s) => s.openPanes);

  const isStreaming = conv.status === "streaming";
  const isApproval = conv.status === "approval";
  const isActive = openPanes.includes("chat") && activeConv === conv.id;

  return (
    <div className={"nav-item-wrap" + (isActive ? " is-active" : "")}>
      <button
        className={"nav-item" + (isActive ? " is-active" : "") + (isStreaming ? " is-streaming" : "")}
        title={conv.title || "(无标题)"}
        onClick={() => {
          setActiveConv(conv.id);
          if (!openPanes.includes("chat")) openPane("chat");
        }}
      >
        <span
          className={"dot" + (isStreaming ? " is-streaming" : "")}
          style={isApproval ? { background: "var(--status-warn)" } : undefined}
        />
        <span className="label">{conv.title || "(无标题)"}</span>
        {isApproval && (
          <span
            className="badge"
            style={{
              background: "color-mix(in srgb, var(--status-warn) 16%, transparent)",
              color: "var(--status-warn)",
            }}
          >!</span>
        )}
      </button>
      <ConvMenu conv={conv} />
    </div>
  );
}

function ConvMenu({ conv }) {
  return (
    <ActionMenu
      placement="bottom-end"
      renderTrigger={({ ref, ...rest }) => (
        <button ref={ref} className="rel-more-btn" title="对话操作" {...rest}>
          <Icon.MoreHorizontal />
        </button>
      )}
      items={[
        { label: conv.pinned ? "取消置顶" : "置顶", icon: Icon.Pin },
        { label: "重命名", icon: Icon.Edit },
        { label: conv.archived ? "取消归档" : "归档", icon: Icon.Folder },
        "divider",
        { label: "删除", icon: Icon.Trash, danger: true },
      ]}
    />
  );
}
