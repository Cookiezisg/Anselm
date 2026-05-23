// NoApiKeyGate — first-run empty state, click → open config pane.

import { beforeEach, describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useUIStore } from "../../store/ui.js";
import { NoApiKeyGate } from "./NoApiKeyGate.jsx";

beforeEach(() => {
  useUIStore.setState({ openPanes: ["chat"], activeNarrowPane: null });
});

describe("NoApiKeyGate", () => {
  it("rendersHeadingAndBothButtons", () => {
    render(<NoApiKeyGate />);
    expect(screen.getByText(/先来配一个 API Key/)).toBeInTheDocument();
    expect(screen.getByText("查看 Provider 列表")).toBeInTheDocument();
    expect(screen.getByText(/现在去添加/)).toBeInTheDocument();
  });

  it("clickPrimaryButton_opensConfigPane", async () => {
    render(<NoApiKeyGate />);
    await userEvent.click(screen.getByText(/现在去添加/));
    expect(useUIStore.getState().openPanes).toContain("config");
  });

  it("clickSecondaryButton_alsoOpensConfigPane", async () => {
    render(<NoApiKeyGate />);
    await userEvent.click(screen.getByText("查看 Provider 列表"));
    expect(useUIStore.getState().openPanes).toContain("config");
  });
});
