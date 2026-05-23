// ToastTray — renders queued toasts + dismiss button.

import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useUIStore } from "../../store/ui.js";
import { ToastTray } from "./ToastTray.jsx";

beforeEach(() => {
  useUIStore.setState({ toasts: [] });
});

describe("ToastTray", () => {
  it("emptyQueue_rendersEmptyContainer", () => {
    const { container } = render(<ToastTray />);
    expect(container.querySelector(".toast-tray")).toBeTruthy();
    expect(container.querySelectorAll(".toast")).toHaveLength(0);
  });

  it("renderToastWithKindAndTitle", () => {
    useUIStore.setState({
      toasts: [{ id: "1", kind: "success", title: "Saved!", duration: 0 }],
    });
    render(<ToastTray />);
    expect(screen.getByText("Saved!")).toBeInTheDocument();
  });

  it("errorKind_appliesIsErrorClass", () => {
    useUIStore.setState({
      toasts: [{ id: "1", kind: "error", title: "Boom", duration: 0 }],
    });
    const { container } = render(<ToastTray />);
    expect(container.querySelector(".toast.is-error")).toBeTruthy();
  });

  it("dismissButton_clickRemovesToast", async () => {
    useUIStore.setState({
      toasts: [{ id: "1", kind: "info", title: "hi", duration: 0 }],
    });
    const { container } = render(<ToastTray />);
    const btns = container.querySelectorAll(".icon-btn");
    await userEvent.click(btns[btns.length - 1]);
    expect(useUIStore.getState().toasts).toHaveLength(0);
  });

  it("undoCallback_clickCallsUndoAndDismisses", async () => {
    const undo = vi.fn();
    useUIStore.setState({
      toasts: [{ id: "1", kind: "info", title: "deleted", duration: 0, undo }],
    });
    render(<ToastTray />);
    await userEvent.click(screen.getByText("撤销"));
    expect(undo).toHaveBeenCalled();
    expect(useUIStore.getState().toasts).toHaveLength(0);
  });

  it("descRenderedWhenPresent", () => {
    useUIStore.setState({
      toasts: [{ id: "1", kind: "info", title: "t", desc: "more info", duration: 0 }],
    });
    render(<ToastTray />);
    expect(screen.getByText("more info")).toBeInTheDocument();
  });
});
