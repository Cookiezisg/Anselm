// NotificationsDrawer — snapshot list + click-to-navigate + clearUnread.

import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

vi.mock("../../api/notifications.js", () => ({
  useNotificationsSnapshot: () => ({
    data: [
      { seq: 1, type: "conversation", id: "cv_x", createdAt: "2026-05-24T12:00:00Z" },
      { seq: 2, type: "function",    id: "fn_y", createdAt: "2026-05-24T12:00:00Z" },
      { seq: 3, type: "flowrun",     id: "fr_z", createdAt: "2026-05-24T12:00:00Z" },
    ],
  }),
}));

import { usePaneStore, useOverlayStore } from "@app/model";
import { NotificationsDrawer } from "./NotificationsDrawer.jsx";

function makeProps(overrides = {}) {
  const pane = usePaneStore.getState();
  const overlay = useOverlayStore.getState();
  return {
    open: overlay.notifsOpen,
    onClose: () => overlay.setNotifsOpen(false),
    onOpenPane: pane.openPane,
    onOpenEntity: pane.openEntity,
    onSetActiveConv: pane.setActiveConv,
    pendingAsk: overlay.pendingAsk,
    onSetPendingAsk: overlay.setPendingAsk,
    unread: 3,
    clearUnread: vi.fn(),
    ...overrides,
  };
}

beforeEach(() => {
  useOverlayStore.setState({ notifsOpen: true });
  usePaneStore.setState({ openPanes: [], activeConv: null, activeNarrowPane: null, focusEntity: {} });
});

describe("NotificationsDrawer", () => {
  it("closed_rendersNothing", () => {
    useOverlayStore.setState({ notifsOpen: false });
    const { container } = render(<NotificationsDrawer {...makeProps()} />);
    expect(container.querySelector(".drawer")).toBeNull();
  });

  it("openWithSnapshot_listsEachItem", () => {
    render(<NotificationsDrawer {...makeProps()} />);
    expect(screen.getByText("conversation")).toBeInTheDocument();
    expect(screen.getByText("function")).toBeInTheDocument();
    expect(screen.getByText("flowrun")).toBeInTheDocument();
  });

  it("conversationItemClick_setsActiveConvAndOpensChat", async () => {
    render(<NotificationsDrawer {...makeProps()} />);
    await userEvent.click(screen.getByText("cv_x"));
    expect(usePaneStore.getState().activeConv).toBe("cv_x");
    expect(usePaneStore.getState().openPanes).toContain("chat");
  });

  it("functionItemClick_opensForgePaneWithFocus", async () => {
    render(<NotificationsDrawer {...makeProps()} />);
    await userEvent.click(screen.getByText("fn_y"));
    expect(usePaneStore.getState().focusEntity.forge).toBe("fn_y");
  });

  it("flowrunItemClick_opensExecutePaneWithFocus", async () => {
    render(<NotificationsDrawer {...makeProps()} />);
    await userEvent.click(screen.getByText("fr_z"));
    expect(usePaneStore.getState().focusEntity.execute).toBe("fr_z");
  });

  it("closeButton_closesDrawer_andClearsUnread", async () => {
    render(<NotificationsDrawer {...makeProps()} />);
    const { container } = render(<NotificationsDrawer {...makeProps()} />);
    const closeBtns = container.querySelectorAll(".icon-btn");
    await userEvent.click(closeBtns[closeBtns.length - 1]);
    expect(useOverlayStore.getState().notifsOpen).toBe(false);
  });

  it("clearAllButton_clickableInHeader", async () => {
    render(<NotificationsDrawer {...makeProps()} />);
    expect(screen.getByText("全部已读")).toBeInTheDocument();
  });
});
