// ChatListItem — status dot variants + click → active conv + ActionMenu actions.

import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

vi.mock("../../api/conversations.js", () => ({
  useUpdateConversation: vi.fn(),
  useDeleteConversation: vi.fn(),
}));

import { useUpdateConversation, useDeleteConversation } from "../../api/conversations.js";
import { useUIStore } from "../../store/ui.js";
import { useToastStore } from "../../shared/ui/toastStore.ts";
import { ChatListItem } from "./ChatListItem.jsx";

let updateMutate, delMutate;

beforeEach(() => {
  updateMutate = vi.fn();
  delMutate    = vi.fn((_id, opts) => opts?.onSuccess?.());
  useUpdateConversation.mockReturnValue({ mutate: updateMutate });
  useDeleteConversation.mockReturnValue({ mutate: delMutate });
  useUIStore.setState({ activeConv: null, openPanes: [] });
  useToastStore.setState({ toasts: [] });
});

describe("ChatListItem", () => {
  it("titlePresent_rendersTitleText", () => {
    render(<ChatListItem conv={{ id: "cv_a", title: "Hello" }} />);
    expect(screen.getByText("Hello")).toBeInTheDocument();
  });

  it("titleMissing_fallsBackToParenLabel", () => {
    render(<ChatListItem conv={{ id: "cv_a" }} />);
    expect(screen.getByText("(无标题)")).toBeInTheDocument();
  });

  it("idleStatus_rendersNoDot", () => {
    const { container } = render(<ChatListItem conv={{ id: "cv_a", title: "Hi", status: "idle" }} />);
    expect(container.querySelector(".cv-dot")).toBeNull();
  });

  it("streamingStatus_rendersStreamingDot", () => {
    const { container } = render(<ChatListItem conv={{ id: "cv_a", title: "Hi", status: "streaming" }} />);
    expect(container.querySelector(".cv-dot.is-streaming")).toBeTruthy();
  });

  it("approvalStatus_rendersApprovalDot", () => {
    const { container } = render(<ChatListItem conv={{ id: "cv_a", title: "Hi", status: "approval" }} />);
    expect(container.querySelector(".cv-dot.is-approval")).toBeTruthy();
  });

  it("clickRow_setsActiveConv_andOpensChatPane", async () => {
    render(<ChatListItem conv={{ id: "cv_a", title: "Hi" }} />);
    await userEvent.click(screen.getByText("Hi"));
    expect(useUIStore.getState().activeConv).toBe("cv_a");
    expect(useUIStore.getState().openPanes).toContain("chat");
  });

  it("clickRow_whenChatPaneAlreadyOpen_doesNotPushDuplicate", async () => {
    useUIStore.setState({ openPanes: ["chat"], activeConv: "cv_other" });
    render(<ChatListItem conv={{ id: "cv_a", title: "Hi" }} />);
    await userEvent.click(screen.getByText("Hi"));
    expect(useUIStore.getState().openPanes.filter((p) => p === "chat").length).toBe(1);
    expect(useUIStore.getState().activeConv).toBe("cv_a");
  });

  it("activeConvAndChatOpen_rendersIsActiveClass", () => {
    useUIStore.setState({ openPanes: ["chat"], activeConv: "cv_a" });
    const { container } = render(<ChatListItem conv={{ id: "cv_a", title: "Hi" }} />);
    expect(container.querySelector(".cv.is-active")).toBeTruthy();
  });

  it("activeConvButChatClosed_skipsIsActive", () => {
    useUIStore.setState({ openPanes: ["forge"], activeConv: "cv_a" });
    const { container } = render(<ChatListItem conv={{ id: "cv_a", title: "Hi" }} />);
    expect(container.querySelector(".cv.is-active")).toBeNull();
  });

  it("menuPinAction_callsUpdateWithPinnedToggled", async () => {
    render(<ChatListItem conv={{ id: "cv_a", title: "Hi", pinned: false }} />);
    await userEvent.click(screen.getByTitle("对话操作"));
    await userEvent.click(screen.getByText("置顶"));
    expect(updateMutate).toHaveBeenCalledWith({ pinned: true }, expect.any(Object));
  });

  it("menuPinAction_whenPinned_labelSaysCancel", async () => {
    render(<ChatListItem conv={{ id: "cv_a", title: "Hi", pinned: true }} />);
    await userEvent.click(screen.getByTitle("对话操作"));
    expect(screen.getByText("取消置顶")).toBeInTheDocument();
  });

  it("menuArchiveAction_callsUpdate_pushesToast", async () => {
    render(<ChatListItem conv={{ id: "cv_a", title: "Hi", archived: false }} />);
    await userEvent.click(screen.getByTitle("对话操作"));
    await userEvent.click(screen.getByText("归档"));
    expect(updateMutate).toHaveBeenCalledWith({ archived: true }, expect.any(Object));
    updateMutate.mock.calls[0][1].onSuccess?.();
    expect(useToastStore.getState().toasts[0]?.title).toBe("已归档");
  });

  it("menuRename_promptCancel_skipsUpdate", async () => {
    const promptSpy = vi.spyOn(window, "prompt").mockReturnValue(null);
    render(<ChatListItem conv={{ id: "cv_a", title: "Hi" }} />);
    await userEvent.click(screen.getByTitle("对话操作"));
    await userEvent.click(screen.getByText("重命名"));
    expect(updateMutate).not.toHaveBeenCalled();
    promptSpy.mockRestore();
  });

  it("menuRename_promptNewTitle_callsUpdate", async () => {
    const promptSpy = vi.spyOn(window, "prompt").mockReturnValue("新名");
    render(<ChatListItem conv={{ id: "cv_a", title: "Hi" }} />);
    await userEvent.click(screen.getByTitle("对话操作"));
    await userEvent.click(screen.getByText("重命名"));
    expect(updateMutate).toHaveBeenCalledWith({ title: "新名" }, expect.any(Object));
    promptSpy.mockRestore();
  });

  it("menuDelete_confirmed_callsDelete_clearsActiveConvIfSelf_pushesToast", async () => {
    useUIStore.setState({ activeConv: "cv_a", openPanes: ["chat"] });
    const confirmSpy = vi.spyOn(window, "confirm").mockReturnValue(true);
    render(<ChatListItem conv={{ id: "cv_a", title: "Hi" }} />);
    await userEvent.click(screen.getByTitle("对话操作"));
    await userEvent.click(screen.getByText("删除"));
    expect(delMutate).toHaveBeenCalledWith("cv_a", expect.any(Object));
    expect(useUIStore.getState().activeConv).toBeNull();
    expect(useToastStore.getState().toasts[0]?.title).toBe("已删除");
    confirmSpy.mockRestore();
  });

  it("menuDelete_declined_skipsDelete", async () => {
    const confirmSpy = vi.spyOn(window, "confirm").mockReturnValue(false);
    render(<ChatListItem conv={{ id: "cv_a", title: "Hi" }} />);
    await userEvent.click(screen.getByTitle("对话操作"));
    await userEvent.click(screen.getByText("删除"));
    expect(delMutate).not.toHaveBeenCalled();
    confirmSpy.mockRestore();
  });
});
