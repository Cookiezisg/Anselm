// ChatHeader — title + id + per-conv model override button + close.

import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

vi.mock("../../../widgets/entity-rel-meta/EntityRelMeta.tsx", () => ({
  EntityRelMeta: (): null => null,
}));

vi.mock("@features/conversation-model-override", () => ({
  ModelOverrideEditor: ({ conversationId }: { conversationId: string }) => (
    <div data-testid="moe-mock">override-editor:{conversationId}</div>
  ),
}));

import { ChatHeader } from "./ChatHeader.tsx";

describe("ChatHeader", () => {
  it("noConv_rendersNothing", () => {
    const { container } = render(<ChatHeader conv={null} />);
    expect(container.firstChild).toBeNull();
  });

  it("withConv_showsTitle_andId", () => {
    render(<ChatHeader conv={{ id: "cv_a", title: "Hello" }} />);
    expect(screen.getByText("Hello")).toBeInTheDocument();
    expect(screen.getByText("cv_a")).toBeInTheDocument();
  });

  it("noTitle_fallsBackToParenLabel", () => {
    render(<ChatHeader conv={{ id: "cv_a" }} />);
    expect(screen.getByText("(无标题)")).toBeInTheDocument();
  });

  it("noOverride_showsDefaultLabel_buttonMuted", () => {
    render(<ChatHeader conv={{ id: "cv_a" }} />);
    const btn = screen.getByTitle("为此对话设置专用模型");
    expect(btn).toHaveTextContent("默认");
    expect(btn.classList.contains("is-active")).toBe(false);
  });

  it("overridePresent_showsModelId_buttonActive", () => {
    render(<ChatHeader conv={{
      id: "cv_a",
      modelOverride: { apiKeyId: "aki_1", modelId: "claude-opus-4-7" },
    }} />);
    const btn = screen.getByTitle("为此对话设置专用模型");
    expect(btn).toHaveTextContent("claude-opus-4-7");
    expect(btn.classList.contains("is-active")).toBe(true);
  });

  it("clickModelBtn_opensEditor_secondClickCloses", async () => {
    render(<ChatHeader conv={{ id: "cv_a" }} />);
    const btn = screen.getByTitle("为此对话设置专用模型");
    expect(screen.queryByTestId("moe-mock")).toBeNull();
    await userEvent.click(btn);
    expect(screen.getByTestId("moe-mock")).toBeInTheDocument();
    await userEvent.click(btn);
    expect(screen.queryByTestId("moe-mock")).toBeNull();
  });

  it("onClose_clickFiresCallback", async () => {
    const onClose = vi.fn();
    render(<ChatHeader conv={{ id: "cv_a" }} onClose={onClose} />);
    await userEvent.click(screen.getByTitle("关闭"));
    expect(onClose).toHaveBeenCalled();
  });

  it("noOnClose_doesNotRenderCloseButton", () => {
    render(<ChatHeader conv={{ id: "cv_a" }} />);
    expect(screen.queryByTitle("关闭")).toBeNull();
  });
});
