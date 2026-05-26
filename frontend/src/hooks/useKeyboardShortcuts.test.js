// useKeyboardShortcuts — global Cmd+K/B + Esc dismissal priority.

import { beforeEach, describe, expect, it } from "vitest";
import { renderHook } from "@testing-library/react";
import { fireEvent } from "@testing-library/dom";
import { useOverlayStore, useSidebarStore } from "@app/model";
import { useKeyboardShortcuts } from "./useKeyboardShortcuts.js";

beforeEach(() => {
  useOverlayStore.setState({ cmdkOpen: false, askOpen: false, notifsOpen: false });
  useSidebarStore.setState({ collapsed: false });
});

describe("useKeyboardShortcuts", () => {
  it("metaK_togglesCmdkOpen", () => {
    renderHook(() => useKeyboardShortcuts());
    fireEvent.keyDown(window, { key: "k", metaKey: true });
    expect(useOverlayStore.getState().cmdkOpen).toBe(true);
    fireEvent.keyDown(window, { key: "k", metaKey: true });
    expect(useOverlayStore.getState().cmdkOpen).toBe(false);
  });

  it("ctrlK_alsoTogglesCmdkOpen", () => {
    renderHook(() => useKeyboardShortcuts());
    fireEvent.keyDown(window, { key: "K", ctrlKey: true });
    expect(useOverlayStore.getState().cmdkOpen).toBe(true);
  });

  it("metaB_togglesCollapsed", () => {
    renderHook(() => useKeyboardShortcuts());
    fireEvent.keyDown(window, { key: "b", metaKey: true });
    expect(useSidebarStore.getState().collapsed).toBe(true);
  });

  it("escape_priorityCmdkFirst", () => {
    renderHook(() => useKeyboardShortcuts());
    useOverlayStore.setState({ cmdkOpen: true, askOpen: true });
    fireEvent.keyDown(window, { key: "Escape" });
    expect(useOverlayStore.getState().cmdkOpen).toBe(false);
    expect(useOverlayStore.getState().askOpen).toBe(true); // not yet
  });

  it("escape_thenAskThenNotifs", () => {
    renderHook(() => useKeyboardShortcuts());
    useOverlayStore.setState({ askOpen: true });
    fireEvent.keyDown(window, { key: "Escape" });
    expect(useOverlayStore.getState().askOpen).toBe(false);

    useOverlayStore.setState({ notifsOpen: true });
    fireEvent.keyDown(window, { key: "Escape" });
    expect(useOverlayStore.getState().notifsOpen).toBe(false);
  });

  it("escape_inInputField_doesNotTriggerDismiss", () => {
    renderHook(() => useKeyboardShortcuts());
    useOverlayStore.setState({ cmdkOpen: true });
    const input = document.createElement("input");
    document.body.appendChild(input);
    fireEvent.keyDown(input, { key: "Escape" });
    expect(useOverlayStore.getState().cmdkOpen).toBe(true);
    document.body.removeChild(input);
  });
});
