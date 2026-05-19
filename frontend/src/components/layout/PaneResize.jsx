// PaneResize — vertical drag handle between two panes. While dragging,
// listens window-level mousemove/mouseup and pushes pointer-events:none
// on body to prevent iframes/canvas swallowing events.
//
// PaneResize —— 双 pane 中间垂直拖动条。拖动时在 window 监听 mouse；body
// 加 pointer-events:none 防 iframe/canvas 抢事件。

import { useEffect, useState } from "react";

export function PaneResize({ onDrag }) {
  const [dragging, setDragging] = useState(false);

  useEffect(() => {
    if (!dragging) return;
    const onMove = (e) => onDrag(e.clientX);
    const onUp = () => setDragging(false);
    document.body.style.userSelect = "none";
    document.body.style.cursor = "col-resize";
    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onUp);
    return () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("mouseup", onUp);
      document.body.style.userSelect = "";
      document.body.style.cursor = "";
    };
  }, [dragging, onDrag]);

  return (
    <div
      className={"pane-resize" + (dragging ? " is-dragging" : "")}
      onMouseDown={() => setDragging(true)}
      role="separator"
      aria-orientation="vertical"
    />
  );
}
