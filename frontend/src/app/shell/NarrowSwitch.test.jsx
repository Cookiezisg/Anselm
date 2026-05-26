// NarrowSwitch — visibility + tab switching.

import { beforeEach, describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { usePaneStore } from "@app/model";
import { NarrowSwitch } from "./NarrowSwitch.jsx";

beforeEach(() => {
  usePaneStore.setState({
    openPanes: ["chat", "forge"], narrow: true, activeNarrowPane: "chat",
  });
});

describe("NarrowSwitch", () => {
  it("notNarrow_rendersNothing", () => {
    usePaneStore.setState({ narrow: false });
    const { container } = render(<NarrowSwitch />);
    expect(container.firstChild).toBeNull();
  });

  it("oneOpenPane_rendersNothing", () => {
    usePaneStore.setState({ openPanes: ["chat"], narrow: true });
    const { container } = render(<NarrowSwitch />);
    expect(container.firstChild).toBeNull();
  });

  it("rendersOneButtonPerOpenPane", () => {
    render(<NarrowSwitch />);
    expect(screen.getByText("对话")).toBeInTheDocument();
    expect(screen.getByText("工坊")).toBeInTheDocument();
  });

  it("clickButton_updatesActiveNarrowPane", async () => {
    render(<NarrowSwitch />);
    await userEvent.click(screen.getByText("工坊"));
    expect(usePaneStore.getState().activeNarrowPane).toBe("forge");
  });

  it("activeButton_hasIsActiveClass", () => {
    const { container } = render(<NarrowSwitch />);
    const btns = container.querySelectorAll(".narrow-switch-btn");
    const active = [...btns].find((b) => b.classList.contains("is-active"));
    expect(active.textContent).toBe("对话");
  });
});
