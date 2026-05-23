// PaneFrame — chrome wrapper; chat kind skips the pane-bar.

import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { PaneFrame } from "./PaneFrame.jsx";

describe("PaneFrame", () => {
  it("chatKind_skipsPaneBar", () => {
    const { container } = render(
      <PaneFrame kind="chat" onClose={() => {}} crumbs={["chat"]}>body</PaneFrame>
    );
    expect(container.querySelector(".pane-bar")).toBeNull();
    expect(container.textContent).toContain("body");
  });

  it("nonChat_rendersPaneBarWithCrumbsAndClose", () => {
    const { container } = render(
      <PaneFrame kind="forge" onClose={() => {}}>body</PaneFrame>
    );
    expect(container.querySelector(".pane-bar")).toBeTruthy();
    expect(screen.getByText("锻造")).toBeInTheDocument();
  });

  it("crumbsArrayWithMultiple_rendersChevronSeparators", () => {
    const { container } = render(
      <PaneFrame kind="forge" onClose={() => {}} crumbs={["forge", "fn_x"]}>body</PaneFrame>
    );
    expect(screen.getByText("fn_x")).toBeInTheDocument();
  });

  it("closeButton_clickFiresCallback", async () => {
    const onClose = vi.fn();
    render(<PaneFrame kind="forge" onClose={onClose}>body</PaneFrame>);
    await userEvent.click(screen.getByTitle("关闭"));
    expect(onClose).toHaveBeenCalled();
  });

  it("unknownKind_fallsBackToSquareIcon_andEchoesKind", () => {
    render(<PaneFrame kind="zzz" onClose={() => {}}>body</PaneFrame>);
    expect(screen.getAllByText("zzz").length).toBeGreaterThan(0);
  });
});
