// ActionMenu — popover open/close, item click, divider, custom trigger.

import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { ActionMenu } from "./ActionMenu.jsx";
import { Icon } from "../primitives/Icon.jsx";

describe("ActionMenu", () => {
  it("closedByDefault_doesNotRenderMenuItems", () => {
    render(<ActionMenu items={[{ label: "A", onClick: () => {} }]} />);
    expect(screen.queryByText("A")).toBeNull();
  });

  it("clickTrigger_opensMenu", async () => {
    render(<ActionMenu items={[{ label: "A", onClick: () => {} }]} />);
    await userEvent.click(screen.getByTitle("更多"));
    expect(screen.getByText("A")).toBeInTheDocument();
  });

  it("clickMenuItem_firesOnClickAndCloses", async () => {
    const onA = vi.fn();
    render(<ActionMenu items={[{ label: "A", onClick: onA }]} />);
    await userEvent.click(screen.getByTitle("更多"));
    await userEvent.click(screen.getByText("A"));
    expect(onA).toHaveBeenCalled();
    expect(screen.queryByText("A")).toBeNull();
  });

  it("dividerString_rendersDividerNotButton", async () => {
    render(<ActionMenu items={[{ label: "A", onClick: () => {} }, "divider", { label: "B", onClick: () => {} }]} />);
    await userEvent.click(screen.getByTitle("更多"));
    const { container } = render(<ActionMenu items={[{ label: "A", onClick: () => {} }, "divider"]} />);
    await userEvent.click(container.querySelector("[title='更多']"));
    expect(document.body.querySelector(".action-menu-divider")).toBeTruthy();
  });

  it("dangerFlag_addsIsDangerClass", async () => {
    render(<ActionMenu items={[{ label: "Delete", danger: true, onClick: () => {} }]} />);
    await userEvent.click(screen.getByTitle("更多"));
    expect(document.body.querySelector(".action-menu-item.is-danger")).toBeTruthy();
  });

  it("customRenderTrigger_replacesDefaultButton", async () => {
    render(<ActionMenu
      items={[{ label: "A", onClick: () => {} }]}
      renderTrigger={({ ref, ...p }) => (
        <button ref={ref} {...p} aria-label="custom">go</button>
      )}
    />);
    expect(screen.getByLabelText("custom")).toBeInTheDocument();
    await userEvent.click(screen.getByLabelText("custom"));
    expect(screen.getByText("A")).toBeInTheDocument();
  });

  it("itemWithShortcut_rendersKbd", async () => {
    render(<ActionMenu items={[{ label: "A", shortcut: "⌘K", onClick: () => {} }]} />);
    await userEvent.click(screen.getByTitle("更多"));
    expect(document.body.querySelector(".action-menu kbd")?.textContent).toBe("⌘K");
  });
});
