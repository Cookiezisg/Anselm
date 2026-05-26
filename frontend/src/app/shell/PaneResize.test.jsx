// PaneResize — mouse drag → onDrag callback chain.

import { describe, expect, it, vi } from "vitest";
import { render } from "@testing-library/react";
import { fireEvent } from "@testing-library/dom";
import { PaneResize } from "./PaneResize.jsx";

describe("PaneResize", () => {
  it("rendersWithSeparatorRole", () => {
    const { container } = render(<PaneResize onDrag={() => {}} />);
    expect(container.querySelector("[role='separator']")).toBeTruthy();
  });

  it("mouseDownThenMove_callsOnDragWithClientX", () => {
    const onDrag = vi.fn();
    const { container } = render(<PaneResize onDrag={onDrag} />);
    const handle = container.querySelector(".pane-resize");
    fireEvent.mouseDown(handle);
    fireEvent.mouseMove(window, { clientX: 500 });
    expect(onDrag).toHaveBeenCalledWith(500);
  });

  it("mouseUp_stopsDragging", () => {
    const onDrag = vi.fn();
    const { container } = render(<PaneResize onDrag={onDrag} />);
    const handle = container.querySelector(".pane-resize");
    fireEvent.mouseDown(handle);
    fireEvent.mouseUp(window);
    // Subsequent move should NOT call onDrag
    fireEvent.mouseMove(window, { clientX: 200 });
    expect(onDrag).not.toHaveBeenCalledWith(200);
  });

  it("draggingClass_appliedDuringDrag", () => {
    const { container } = render(<PaneResize onDrag={() => {}} />);
    const handle = container.querySelector(".pane-resize");
    fireEvent.mouseDown(handle);
    expect(handle.classList.contains("is-dragging")).toBe(true);
    fireEvent.mouseUp(window);
    expect(handle.classList.contains("is-dragging")).toBe(false);
  });
});
