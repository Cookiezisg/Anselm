// app/model — pane open/close state machine, narrow mode, focus entity,
// overlay flags, sidebar collapse, toast queue.
// Migrated from src/store/ui.test.js (4b.5 recovery).
// useUIStore was split into usePaneStore + useOverlayStore + useSidebarStore;
// toasts live in useToastStore (shared/ui). Tests updated to new store APIs.

import { beforeEach, describe, expect, it, vi } from "vitest";
import { usePaneStore } from "./paneStore";
import { useOverlayStore } from "./overlayStore";
import { useSidebarStore } from "./sidebarStore";
import { useToastStore } from "../../shared/ui/toastStore";

function reset() {
  usePaneStore.setState({
    openPanes: ["chat"], activeConv: null,
    activeFlowRun: null, activeDocument: null, leftPct: 50,
    narrow: false, activeNarrowPane: null,
    focusEntity: {},
  });
  useOverlayStore.setState({
    cmdkOpen: false, notifsOpen: false,
    askOpen: false, settingsOpen: false, pendingAsk: null,
  });
  useSidebarStore.setState({ collapsed: false });
  useToastStore.setState({ toasts: [] });
}

beforeEach(() => reset());

describe("pane state machine", () => {
  it("openPane_newPane_addsToEnd", () => {
    usePaneStore.getState().openPane("forge");
    expect(usePaneStore.getState().openPanes).toEqual(["chat", "forge"]);
  });

  it("openPane_alreadyOpen_setsActiveOnly", () => {
    usePaneStore.getState().openPane("chat");
    expect(usePaneStore.getState().openPanes).toEqual(["chat"]);
    expect(usePaneStore.getState().activeNarrowPane).toBe("chat");
  });

  it("openPane_exceedsMax_evictsOldest", () => {
    usePaneStore.getState().openPane("forge");
    usePaneStore.getState().openPane("execute");
    expect(usePaneStore.getState().openPanes).toEqual(["forge", "execute"]);
  });

  it("togglePane_closed_opens", () => {
    usePaneStore.getState().togglePane("forge");
    expect(usePaneStore.getState().openPanes).toEqual(["chat", "forge"]);
  });

  it("togglePane_open_closes", () => {
    usePaneStore.getState().togglePane("chat");
    expect(usePaneStore.getState().openPanes).toEqual([]);
  });

  it("togglePane_atMaxAddingNew_evictsOldest", () => {
    usePaneStore.getState().openPane("forge");
    usePaneStore.getState().togglePane("execute");
    expect(usePaneStore.getState().openPanes).toEqual(["forge", "execute"]);
  });

  it("closePane_existing_removesIt", () => {
    usePaneStore.getState().openPane("forge");
    usePaneStore.getState().closePane("chat");
    expect(usePaneStore.getState().openPanes).toEqual(["forge"]);
  });

  it("closePane_activeNarrowPane_switchesToLastRemaining", () => {
    usePaneStore.getState().openPane("forge");
    usePaneStore.setState({ activeNarrowPane: "forge" });
    usePaneStore.getState().closePane("forge");
    expect(usePaneStore.getState().activeNarrowPane).toBe("chat");
  });

  it("closePane_lastPane_activeNarrowPaneBecomesNull", () => {
    usePaneStore.setState({ activeNarrowPane: "chat" });
    usePaneStore.getState().closePane("chat");
    expect(usePaneStore.getState().activeNarrowPane).toBeNull();
  });
});

describe("openEntity", () => {
  it("openEntity_existingPane_setsFocusKeepsPanes", () => {
    usePaneStore.getState().openEntity("chat", "cv_x");
    expect(usePaneStore.getState().focusEntity).toEqual({ chat: "cv_x" });
    expect(usePaneStore.getState().openPanes).toEqual(["chat"]);
  });

  it("openEntity_newPane_opensAndFocuses", () => {
    usePaneStore.getState().openEntity("forge", "fn_y");
    expect(usePaneStore.getState().openPanes).toEqual(["chat", "forge"]);
    expect(usePaneStore.getState().focusEntity["forge"]).toBe("fn_y");
  });

  it("openEntity_atMax_evictsOldest", () => {
    usePaneStore.getState().openPane("forge");
    usePaneStore.getState().openEntity("execute", "fr_z");
    expect(usePaneStore.getState().openPanes).toEqual(["forge", "execute"]);
  });

  it("consumeFocusEntity_returnsThenClears", () => {
    usePaneStore.getState().openEntity("chat", "cv_x");
    expect(usePaneStore.getState().consumeFocusEntity("chat")).toBe("cv_x");
    expect(usePaneStore.getState().focusEntity["chat"]).toBeUndefined();
  });

  it("consumeFocusEntity_emptySlot_returnsNull", () => {
    expect(usePaneStore.getState().consumeFocusEntity("chat")).toBeNull();
  });
});

describe("layout knobs", () => {
  it("setLeftPct_clampsToBounds", () => {
    usePaneStore.getState().setLeftPct(5);
    expect(usePaneStore.getState().leftPct).toBe(20);
    usePaneStore.getState().setLeftPct(95);
    expect(usePaneStore.getState().leftPct).toBe(80);
    usePaneStore.getState().setLeftPct(50);
    expect(usePaneStore.getState().leftPct).toBe(50);
  });

  it("setCollapsed_supportsBooleanAndFunction", () => {
    useSidebarStore.getState().setCollapsed(true);
    expect(useSidebarStore.getState().collapsed).toBe(true);
    useSidebarStore.getState().setCollapsed((p) => !p);
    expect(useSidebarStore.getState().collapsed).toBe(false);
  });

  it("setNarrow_coercesToBoolean", () => {
    usePaneStore.getState().setNarrow(1);
    expect(usePaneStore.getState().narrow).toBe(true);
    usePaneStore.getState().setNarrow(null);
    expect(usePaneStore.getState().narrow).toBe(false);
  });

  it("setActiveConv_setsConvId", () => {
    usePaneStore.getState().setActiveConv("cv_a");
    expect(usePaneStore.getState().activeConv).toBe("cv_a");
  });

  it("overlay flags toggle independently", () => {
    const { setCmdkOpen, setNotifsOpen, setAskOpen, setSettingsOpen } = useOverlayStore.getState();
    setCmdkOpen(true); setNotifsOpen(true); setAskOpen(true); setSettingsOpen(true);
    const s = useOverlayStore.getState();
    expect(s.cmdkOpen && s.notifsOpen && s.askOpen && s.settingsOpen).toBe(true);
  });
});

describe("toasts", () => {
  it("pushToast_appendsWithUniqueId", () => {
    const id1 = useToastStore.getState().pushToast({ kind: "info", title: "a", duration: 0 });
    const id2 = useToastStore.getState().pushToast({ kind: "info", title: "b", duration: 0 });
    expect(id1).not.toBe(id2);
    expect(useToastStore.getState().toasts).toHaveLength(2);
  });

  it("pushToast_autoDismissesAfterDuration", () => {
    vi.useFakeTimers();
    useToastStore.getState().pushToast({ kind: "info", title: "x", duration: 1000 });
    expect(useToastStore.getState().toasts).toHaveLength(1);
    vi.advanceTimersByTime(1500);
    expect(useToastStore.getState().toasts).toHaveLength(0);
    vi.useRealTimers();
  });

  it("dismissToast_removesById", () => {
    const id = useToastStore.getState().pushToast({ kind: "info", title: "x", duration: 0 });
    useToastStore.getState().dismissToast(id);
    expect(useToastStore.getState().toasts).toHaveLength(0);
  });

  it("pushToast_durationZero_neverAutoDismisses", () => {
    vi.useFakeTimers();
    useToastStore.getState().pushToast({ kind: "warn", title: "x", duration: 0 });
    vi.advanceTimersByTime(60_000);
    expect(useToastStore.getState().toasts).toHaveLength(1);
    vi.useRealTimers();
  });
});
