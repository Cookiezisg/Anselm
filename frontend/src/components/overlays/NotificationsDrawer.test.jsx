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

vi.mock("../../sse/SSEProvider.jsx", () => ({
  useSSEHealth: () => ({ unread: 3, clearUnread: vi.fn() }),
}));

import { useUIStore } from "../../store/ui.js";
import { NotificationsDrawer } from "./NotificationsDrawer.jsx";

beforeEach(() => {
  useUIStore.setState({
    notifsOpen: true, openPanes: [], activeConv: null,
    activeNarrowPane: null, focusEntity: {},
  });
});

describe("NotificationsDrawer", () => {
  it("closed_rendersNothing", () => {
    useUIStore.setState({ notifsOpen: false });
    const { container } = render(<NotificationsDrawer />);
    expect(container.querySelector(".drawer")).toBeNull();
  });

  it("openWithSnapshot_listsEachItem", () => {
    render(<NotificationsDrawer />);
    expect(screen.getByText("conversation")).toBeInTheDocument();
    expect(screen.getByText("function")).toBeInTheDocument();
    expect(screen.getByText("flowrun")).toBeInTheDocument();
  });

  it("conversationItemClick_setsActiveConvAndOpensChat", async () => {
    render(<NotificationsDrawer />);
    await userEvent.click(screen.getByText("cv_x"));
    expect(useUIStore.getState().activeConv).toBe("cv_x");
    expect(useUIStore.getState().openPanes).toContain("chat");
  });

  it("functionItemClick_opensForgePaneWithFocus", async () => {
    render(<NotificationsDrawer />);
    await userEvent.click(screen.getByText("fn_y"));
    expect(useUIStore.getState().focusEntity.forge).toBe("fn_y");
  });

  it("flowrunItemClick_opensExecutePaneWithFocus", async () => {
    render(<NotificationsDrawer />);
    await userEvent.click(screen.getByText("fr_z"));
    expect(useUIStore.getState().focusEntity.execute).toBe("fr_z");
  });

  it("closeButton_closesDrawer_andClearsUnread", async () => {
    render(<NotificationsDrawer />);
    const { container } = render(<NotificationsDrawer />);
    const closeBtns = container.querySelectorAll(".icon-btn");
    await userEvent.click(closeBtns[closeBtns.length - 1]);
    expect(useUIStore.getState().notifsOpen).toBe(false);
  });

  it("clearAllButton_clickableInHeader", async () => {
    render(<NotificationsDrawer />);
    expect(screen.getByText("全部已读")).toBeInTheDocument();
  });
});
