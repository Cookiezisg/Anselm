import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Sidebar } from "./Sidebar.jsx";
import { useUIStore } from "../../store/ui.js";

vi.mock("../../api/conversations.js", () => ({
  useConversations: () => ({ data: [] }),
  useCreateConversation: () => ({
    mutateAsync: vi.fn().mockResolvedValue({ id: "cv_new" }),
  }),
}));

vi.mock("../../sse/SSEProvider.jsx", () => ({
  useSSEHealth: () => ({
    overall: "ok",
    eventlog: "ok",
    notifs: "ok",
    forge: "ok",
    unread: 0,
    clearUnread: vi.fn(),
  }),
}));

vi.mock("../../hooks/useDisplayName.js", () => ({
  useDisplayName: () => ["Weilin"],
}));

vi.mock("./ChatListItem.jsx", () => ({
  ChatListItem: ({ conv }) => <div data-testid={`chat-item-${conv.id}`}>{conv.title}</div>,
}));

vi.mock("./SidebarSection.jsx", () => ({
  SidebarSection: ({ label, children, expanded, onToggle }) => (
    <div data-testid={`section-${label}`}>
      <button onClick={onToggle} data-testid={`toggle-${label}`}>
        {label}
      </button>
      {expanded && <div data-testid={`content-${label}`}>{children}</div>}
    </div>
  ),
}));

function renderSidebar() {
  const qc = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={qc}>
      <Sidebar />
    </QueryClientProvider>
  );
}

beforeEach(() => {
  localStorage.clear();
  useUIStore.setState({
    openPanes: [],
    collapsed: false,
    toolsExpanded: true,
    recentExpanded: true,
    cmdkOpen: false,
    notifsOpen: false,
    settingsPopOpen: false,
  });
});

describe("Sidebar", () => {
  it("renders Forgify logo", () => {
    renderSidebar();
    expect(screen.getByText("Forgify")).toBeInTheDocument();
  });

  it("renders all 4 workbenches + 4 tools", () => {
    renderSidebar();
    for (const label of ["对话", "工坊", "执行", "文档", "洞察", "Skills", "MCP", "Memory"]) {
      expect(screen.getByText(label)).toBeInTheDocument();
    }
  });

  it("primary 新对话 button calls create-conv and sets active", async () => {
    renderSidebar();
    const newConvBtn = screen.getByText("新对话");
    fireEvent.click(newConvBtn);
    // Wait for mutateAsync to resolve
    await new Promise((r) => setTimeout(r, 10));
    expect(useUIStore.getState().activeConv).toBe("cv_new");
  });

  it("toggle button collapses sidebar and persists state", () => {
    renderSidebar();
    const toggleBtn = screen.getByLabelText("toggle sidebar");
    fireEvent.click(toggleBtn);
    expect(useUIStore.getState().collapsed).toBe(true);
  });

  it("hides Forgify name in collapsed mode", () => {
    useUIStore.setState({ collapsed: true });
    renderSidebar();
    expect(screen.queryByText("Forgify")).not.toBeInTheDocument();
  });

  it("collapses tools section on toggle", () => {
    renderSidebar();
    const toolsToggle = screen.getByTestId("toggle-工具");
    fireEvent.click(toolsToggle);
    expect(useUIStore.getState().toolsExpanded).toBe(false);
  });

  it("footer avatar click opens notifications", () => {
    renderSidebar();
    const avatarBtn = screen.getByText("W");
    fireEvent.click(avatarBtn);
    expect(useUIStore.getState().notifsOpen).toBe(true);
  });

  it("settings button opens settings popover", () => {
    renderSidebar();
    const settingsBtn = screen.getByLabelText("settings");
    fireEvent.click(settingsBtn);
    expect(useUIStore.getState().settingsPopOpen).toBe(true);
  });

  it("shows initial from displayName in avatar", () => {
    renderSidebar();
    expect(screen.getByText("W")).toBeInTheDocument();
  });

  it("chat pane toggle updates openPanes state", () => {
    renderSidebar();
    const chatBtn = screen.getByText("对话");
    fireEvent.click(chatBtn);
    expect(useUIStore.getState().openPanes).toContain("chat");
  });
});
