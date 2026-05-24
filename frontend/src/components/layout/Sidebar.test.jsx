import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent, act } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Sidebar } from "./Sidebar.jsx";
import { useUIStore } from "../../store/ui.js";

vi.mock("../../api/conversations.js", () => ({
  useConversations:        () => ({ data: [] }),
  useCreateConversation:   () => ({ mutateAsync: vi.fn().mockResolvedValue({ id: "cv_new" }) }),
  useUpdateConversation:   () => ({ mutate: vi.fn() }),
  useDeleteConversation:   () => ({ mutate: vi.fn() }),
}));
vi.mock("../../sse/SSEProvider.jsx", () => ({
  useSSEHealth: () => ({ overall: "ok", eventlog: "ok", notifs: "ok", forge: "ok", unread: 0, clearUnread: vi.fn() }),
}));

function renderSidebar() {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={qc}>
      <Sidebar />
    </QueryClientProvider>
  );
}

beforeEach(() => {
  localStorage.clear();
  useUIStore.setState({
    openPanes: [], collapsed: false, toolsExpanded: true, recentExpanded: true,
    cmdkOpen: false, notifsOpen: false, settingsPopOpen: false,
  });
});

describe("Sidebar", () => {
  it("renders Forgify logo + name when expanded", () => {
    renderSidebar();
    expect(screen.getByText("Forgify")).toBeInTheDocument();
  });

  it("renders all 4 workbenches + 4 tools", () => {
    renderSidebar();
    for (const label of ["对话", "工坊", "执行", "文档", "洞察", "Skills", "MCP", "Memory"]) {
      expect(screen.getByText(label)).toBeInTheDocument();
    }
  });

  it("primary 新对话 button calls create-conv and switches to chat pane", async () => {
    renderSidebar();
    await act(async () => {
      fireEvent.click(screen.getByText("新对话"));
    });
    expect(useUIStore.getState().openPanes).toContain("chat");
    expect(useUIStore.getState().activeConv).toBe("cv_new");
  });

  it("toggle collapses sidebar (state + localStorage)", () => {
    renderSidebar();
    fireEvent.click(screen.getByLabelText(/toggle sidebar/i));
    expect(useUIStore.getState().collapsed).toBe(true);
    expect(localStorage.getItem("sidebar.collapsed")).toBe("1");
  });

  it("hides Forgify name + recent section in collapsed mode", () => {
    useUIStore.setState({ collapsed: true });
    renderSidebar();
    expect(screen.queryByText("Forgify")).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "最近" })).not.toBeInTheDocument();
  });

  it("collapses tools section on click and persists state", () => {
    renderSidebar();
    fireEvent.click(screen.getByRole("button", { name: "工具" }));
    expect(useUIStore.getState().toolsExpanded).toBe(false);
    expect(localStorage.getItem("sidebar.toolsExpanded")).toBe("0");
    expect(screen.queryByText("洞察")).not.toBeInTheDocument();
  });

  it("footer avatar click opens NotificationsDrawer", () => {
    renderSidebar();
    const slot = screen.getByTitle(/通知/i);
    fireEvent.click(slot);
    expect(useUIStore.getState().notifsOpen).toBe(true);
  });

  it("footer gear opens settings popover", () => {
    renderSidebar();
    fireEvent.click(screen.getByLabelText("settings"));
    expect(useUIStore.getState().settingsPopOpen).toBe(true);
  });

  it("shows initial from displayName in avatar", () => {
    localStorage.setItem("forgify.user.displayName", "Weilin");
    renderSidebar();
    expect(screen.getByText("W")).toBeInTheDocument();
  });
});
