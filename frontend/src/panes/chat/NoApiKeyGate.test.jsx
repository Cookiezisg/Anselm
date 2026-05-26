// NoApiKeyGate — first-run empty state, click → open settings modal.

import { beforeEach, describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { usePaneStore, useOverlayStore } from "@app/model";
import { NoApiKeyGate } from "./NoApiKeyGate.jsx";

beforeEach(() => {
  usePaneStore.setState({ openPanes: ["chat"], activeNarrowPane: null });
  useOverlayStore.setState({ settingsOpen: false });
});

describe("NoApiKeyGate", () => {
  it("rendersHeadingAndConfigButton", () => {
    render(<NoApiKeyGate />);
    expect(screen.getByText(/先配一把钥匙/)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /去配置/ })).toBeInTheDocument();
  });

  it("clickConfigButton_opensSettingsModal", async () => {
    render(<NoApiKeyGate />);
    await userEvent.click(screen.getByRole("button", { name: /去配置/ }));
    expect(useOverlayStore.getState().settingsOpen).toBe(true);
  });

  it("noSecondaryButton_onlyOneActionButton", () => {
    render(<NoApiKeyGate />);
    const buttons = screen.getAllByRole("button");
    expect(buttons).toHaveLength(1);
  });
});
