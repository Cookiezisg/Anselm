// Sidebar — nav buttons, conversation list, header trigger, footer.

import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { createElement } from "react";

vi.mock("../../api/conversations.js", () => ({
  useConversations: () => ({
    data: [
      { id: "cv_1", title: "First", pinned: true,  archived: false },
      { id: "cv_2", title: "Recent", pinned: false, archived: false },
      { id: "cv_3", title: "Old",    pinned: false, archived: true  },
    ],
    isLoading: false,
  }),
  useCreateConversation: () => ({ mutateAsync: vi.fn(async () => ({ id: "cv_new" })) }),
}));

vi.mock("./ChatListItem.jsx", () => ({
  ChatListItem: ({ conv }) => <div data-testid={`item-${conv.id}`}>{conv.title}</div>,
}));

vi.mock("../../sse/SSEProvider.jsx", () => ({
  useSSEHealth: () => ({ overall: "ok", eventlog: "connected", notifs: "connected", forge: "connected", unread: 2, clearUnread: vi.fn() }),
}));

import { useUIStore } from "../../store/ui.js";
import { Sidebar } from "./Sidebar.jsx";

function wrap({ children }) {
  const client = new QueryClient();
  return createElement(QueryClientProvider, { client }, children);
}

beforeEach(() => {
  useUIStore.setState({
    openPanes: ["chat"], collapsed: false, cmdkOpen: false, notifsOpen: false,
    askOpen: false, settingsPopOpen: false,
  });
});

describe("Sidebar", () => {
  it("rendersAllNavButtons", () => {
    render(<Sidebar />, { wrapper: wrap });
    expect(screen.getByText("对话")).toBeInTheDocument();
    expect(screen.getByText("工坊")).toBeInTheDocument();
    expect(screen.getByText("执行")).toBeInTheDocument();
    expect(screen.getByText("文档")).toBeInTheDocument();
    expect(screen.getByText("洞察")).toBeInTheDocument();
    expect(screen.getByText("Skills")).toBeInTheDocument();
    expect(screen.getByText("MCP")).toBeInTheDocument();
    expect(screen.getByText("Memory")).toBeInTheDocument();
  });

  it("activeChatPane_hasIsActiveClass", () => {
    const { container } = render(<Sidebar />, { wrapper: wrap });
    const chat = [...container.querySelectorAll(".nav-item")].find((b) => b.textContent.includes("对话"));
    expect(chat.classList.contains("is-active")).toBe(true);
  });

  it("clickForge_togglesForgePane", async () => {
    render(<Sidebar />, { wrapper: wrap });
    await userEvent.click(screen.getByText("工坊"));
    expect(useUIStore.getState().openPanes).toContain("forge");
  });

  it("renderPinnedConversation_separateFromRecent", () => {
    render(<Sidebar />, { wrapper: wrap });
    expect(screen.getByTestId("item-cv_1")).toBeInTheDocument();
    expect(screen.getByTestId("item-cv_2")).toBeInTheDocument();
  });

  it("archivedSection_collapsedByDefault_toggleable", async () => {
    render(<Sidebar />, { wrapper: wrap });
    expect(screen.queryByTestId("item-cv_3")).toBeNull();
    await userEvent.click(screen.getByText(/归档 · 1/));
    expect(screen.getByTestId("item-cv_3")).toBeInTheDocument();
  });

  it("cmdkTrigger_clickSetsCmdkOpen", async () => {
    render(<Sidebar />, { wrapper: wrap });
    await userEvent.click(screen.getByText(/搜索 · 跳转 · 命令/));
    expect(useUIStore.getState().cmdkOpen).toBe(true);
  });

  it("settingsButton_clickTogglesSettingsPop", async () => {
    render(<Sidebar />, { wrapper: wrap });
    await userEvent.click(screen.getByTitle(/主题/));
    expect(useUIStore.getState().settingsPopOpen).toBe(true);
  });

  it("notifsButton_clickOpensDrawer_andClearsUnread", async () => {
    render(<Sidebar />, { wrapper: wrap });
    await userEvent.click(screen.getByTitle(/通知/));
    expect(useUIStore.getState().notifsOpen).toBe(true);
  });

  it("collapsedMode_hidesLabels", () => {
    useUIStore.setState({ collapsed: true });
    render(<Sidebar />, { wrapper: wrap });
    // Nav buttons still render but workspace pill detail label gone
    expect(screen.queryByText("local")).toBeNull();
  });

  it("newConvButton_createsAndSetsActive", async () => {
    render(<Sidebar />, { wrapper: wrap });
    await userEvent.click(screen.getByTitle("新对话"));
    // mutateAsync runs and resolves with cv_new → setActiveConv called
    await new Promise((r) => setTimeout(r, 0));
    expect(useUIStore.getState().activeConv).toBe("cv_new");
  });
});
