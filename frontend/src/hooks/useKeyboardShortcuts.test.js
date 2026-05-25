// useKeyboardShortcuts — global Cmd+K/B + Esc dismissal priority.

import { beforeEach, describe, expect, it } from "vitest";
import { renderHook } from "@testing-library/react";
import { fireEvent } from "@testing-library/dom";
import { useUIStore } from "../store/ui.js";
import { useKeyboardShortcuts } from "./useKeyboardShortcuts.js";

beforeEach(() => {
  useUIStore.setState({
    cmdkOpen: false, askOpen: false, notifsOpen: false,
    collapsed: false,
  });
});

describe("useKeyboardShortcuts", () => {
  it("metaK_togglesCmdkOpen", () => {
    renderHook(() => useKeyboardShortcuts());
    fireEvent.keyDown(window, { key: "k", metaKey: true });
    expect(useUIStore.getState().cmdkOpen).toBe(true);
    fireEvent.keyDown(window, { key: "k", metaKey: true });
    expect(useUIStore.getState().cmdkOpen).toBe(false);
  });

  it("ctrlK_alsoTogglesCmdkOpen", () => {
    renderHook(() => useKeyboardShortcuts());
    fireEvent.keyDown(window, { key: "K", ctrlKey: true });
    expect(useUIStore.getState().cmdkOpen).toBe(true);
  });

  it("metaB_togglesCollapsed", () => {
    renderHook(() => useKeyboardShortcuts());
    fireEvent.keyDown(window, { key: "b", metaKey: true });
    expect(useUIStore.getState().collapsed).toBe(true);
  });

  it("escape_priorityCmdkFirst", () => {
    renderHook(() => useKeyboardShortcuts());
    useUIStore.setState({ cmdkOpen: true, askOpen: true });
    fireEvent.keyDown(window, { key: "Escape" });
    expect(useUIStore.getState().cmdkOpen).toBe(false);
    expect(useUIStore.getState().askOpen).toBe(true); // not yet
  });

  it("escape_thenAskThenNotifs", () => {
    renderHook(() => useKeyboardShortcuts());
    useUIStore.setState({ askOpen: true });
    fireEvent.keyDown(window, { key: "Escape" });
    expect(useUIStore.getState().askOpen).toBe(false);

    useUIStore.setState({ notifsOpen: true });
    fireEvent.keyDown(window, { key: "Escape" });
    expect(useUIStore.getState().notifsOpen).toBe(false);
  });

  it("escape_inInputField_doesNotTriggerDismiss", () => {
    renderHook(() => useKeyboardShortcuts());
    useUIStore.setState({ cmdkOpen: true });
    const input = document.createElement("input");
    document.body.appendChild(input);
    fireEvent.keyDown(input, { key: "Escape" });
    expect(useUIStore.getState().cmdkOpen).toBe(true);
    document.body.removeChild(input);
  });
});
