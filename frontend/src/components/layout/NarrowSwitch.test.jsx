// NarrowSwitch — visibility + tab switching.

import { beforeEach, describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useUIStore } from "../../store/ui.js";
import { NarrowSwitch } from "./NarrowSwitch.jsx";

beforeEach(() => {
  useUIStore.setState({
    openPanes: ["chat", "forge"], narrow: true, activeNarrowPane: "chat",
  });
});

describe("NarrowSwitch", () => {
  it("notNarrow_rendersNothing", () => {
    useUIStore.setState({ narrow: false });
    const { container } = render(<NarrowSwitch />);
    expect(container.firstChild).toBeNull();
  });

  it("oneOpenPane_rendersNothing", () => {
    useUIStore.setState({ openPanes: ["chat"], narrow: true });
    const { container } = render(<NarrowSwitch />);
    expect(container.firstChild).toBeNull();
  });

  it("rendersOneButtonPerOpenPane", () => {
    render(<NarrowSwitch />);
    expect(screen.getByText("对话")).toBeInTheDocument();
    expect(screen.getByText("锻造")).toBeInTheDocument();
  });

  it("clickButton_updatesActiveNarrowPane", async () => {
    render(<NarrowSwitch />);
    await userEvent.click(screen.getByText("锻造"));
    expect(useUIStore.getState().activeNarrowPane).toBe("forge");
  });

  it("activeButton_hasIsActiveClass", () => {
    const { container } = render(<NarrowSwitch />);
    const btns = container.querySelectorAll(".narrow-switch-btn");
    const active = [...btns].find((b) => b.classList.contains("is-active"));
    expect(active.textContent).toBe("对话");
  });
});
