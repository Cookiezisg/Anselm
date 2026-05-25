// store/ui — pane open/close state machine, narrow mode, focus entity,
// toast queue. Pane LRU enforces MAX_PANES=2 (oldest evicted).

import { beforeEach, describe, expect, it, vi } from "vitest";
import { useUIStore } from "./ui.js";

function reset() {
  useUIStore.setState({
    baseUrl: null, openPanes: ["chat"], activeConv: null,
    activeFlowRun: null, activeDocument: null, leftPct: 50,
    collapsed: false, narrow: false, activeNarrowPane: null,
    focusEntity: {}, cmdkOpen: false, notifsOpen: false,
    askOpen: false, settingsOpen: false, pendingAsk: null,
    toasts: [],
  });
}

beforeEach(() => reset());

// ── Pane open / close / toggle ────────────────────────────────────────
describe("pane state machine", () => {
  it("openPane_newPane_addsToEnd", () => {
    useUIStore.getState().openPane("forge");
    expect(useUIStore.getState().openPanes).toEqual(["chat", "forge"]);
  });

  it("openPane_alreadyOpen_setsActiveOnly", () => {
    useUIStore.getState().openPane("chat");
    expect(useUIStore.getState().openPanes).toEqual(["chat"]);
    expect(useUIStore.getState().activeNarrowPane).toBe("chat");
  });

  it("openPane_exceedsMax_evictsOldest", () => {
    useUIStore.getState().openPane("forge");
    useUIStore.getState().openPane("execute");
    expect(useUIStore.getState().openPanes).toEqual(["forge", "execute"]);
  });

  it("togglePane_closed_opens", () => {
    useUIStore.getState().togglePane("forge");
    expect(useUIStore.getState().openPanes).toEqual(["chat", "forge"]);
  });

  it("togglePane_open_closes", () => {
    useUIStore.getState().togglePane("chat");
    expect(useUIStore.getState().openPanes).toEqual([]);
  });

  it("togglePane_atMaxAddingNew_evictsOldest", () => {
    useUIStore.getState().openPane("forge");
    useUIStore.getState().togglePane("execute");
    expect(useUIStore.getState().openPanes).toEqual(["forge", "execute"]);
  });

  it("closePane_existing_removesIt", () => {
    useUIStore.getState().openPane("forge");
    useUIStore.getState().closePane("chat");
    expect(useUIStore.getState().openPanes).toEqual(["forge"]);
  });

  it("closePane_activeNarrowPane_switchesToLastRemaining", () => {
    useUIStore.getState().openPane("forge");
    useUIStore.setState({ activeNarrowPane: "forge" });
    useUIStore.getState().closePane("forge");
    expect(useUIStore.getState().activeNarrowPane).toBe("chat");
  });

  it("closePane_lastPane_activeNarrowPaneBecomesNull", () => {
    useUIStore.setState({ activeNarrowPane: "chat" });
    useUIStore.getState().closePane("chat");
    expect(useUIStore.getState().activeNarrowPane).toBeNull();
  });
});

// ── openEntity — focus + pane open in one shot ───────────────────────
describe("openEntity", () => {
  it("openEntity_existingPane_setsFocusKeepsPanes", () => {
    useUIStore.getState().openEntity("chat", "cv_x");
    expect(useUIStore.getState().focusEntity).toEqual({ chat: "cv_x" });
    expect(useUIStore.getState().openPanes).toEqual(["chat"]);
  });

  it("openEntity_newPane_opensAndFocuses", () => {
    useUIStore.getState().openEntity("forge", "fn_y");
    expect(useUIStore.getState().openPanes).toEqual(["chat", "forge"]);
    expect(useUIStore.getState().focusEntity.forge).toBe("fn_y");
  });

  it("openEntity_atMax_evictsOldest", () => {
    useUIStore.getState().openPane("forge");
    useUIStore.getState().openEntity("execute", "fr_z");
    expect(useUIStore.getState().openPanes).toEqual(["forge", "execute"]);
  });

  it("consumeFocusEntity_returnsThenClears", () => {
    useUIStore.getState().openEntity("chat", "cv_x");
    expect(useUIStore.getState().consumeFocusEntity("chat")).toBe("cv_x");
    expect(useUIStore.getState().focusEntity.chat).toBeUndefined();
  });

  it("consumeFocusEntity_emptySlot_returnsNull", () => {
    expect(useUIStore.getState().consumeFocusEntity("chat")).toBeNull();
  });
});

// ── Layout & flags ────────────────────────────────────────────────────
describe("layout knobs", () => {
  it("setLeftPct_clampsToBounds", () => {
    useUIStore.getState().setLeftPct(5);
    expect(useUIStore.getState().leftPct).toBe(20);
    useUIStore.getState().setLeftPct(95);
    expect(useUIStore.getState().leftPct).toBe(80);
    useUIStore.getState().setLeftPct(50);
    expect(useUIStore.getState().leftPct).toBe(50);
  });

  it("setCollapsed_supportsBooleanAndFunction", () => {
    useUIStore.getState().setCollapsed(true);
    expect(useUIStore.getState().collapsed).toBe(true);
    useUIStore.getState().setCollapsed((p) => !p);
    expect(useUIStore.getState().collapsed).toBe(false);
  });

  it("setNarrow_coercesToBoolean", () => {
    useUIStore.getState().setNarrow(1);
    expect(useUIStore.getState().narrow).toBe(true);
    useUIStore.getState().setNarrow(null);
    expect(useUIStore.getState().narrow).toBe(false);
  });

  it("setActiveConv_setsConvId", () => {
    useUIStore.getState().setActiveConv("cv_a");
    expect(useUIStore.getState().activeConv).toBe("cv_a");
  });

  it("overlay flags toggle independently", () => {
    const { setCmdkOpen, setNotifsOpen, setAskOpen, setSettingsOpen } = useUIStore.getState();
    setCmdkOpen(true); setNotifsOpen(true); setAskOpen(true); setSettingsOpen(true);
    const s = useUIStore.getState();
    expect(s.cmdkOpen && s.notifsOpen && s.askOpen && s.settingsOpen).toBe(true);
  });
});

// ── Toasts ────────────────────────────────────────────────────────────
describe("toasts", () => {
  it("pushToast_appendsWithUniqueId", () => {
    const id1 = useUIStore.getState().pushToast({ kind: "info", title: "a", duration: 0 });
    const id2 = useUIStore.getState().pushToast({ kind: "info", title: "b", duration: 0 });
    expect(id1).not.toBe(id2);
    expect(useUIStore.getState().toasts).toHaveLength(2);
  });

  it("pushToast_autoDismissesAfterDuration", () => {
    vi.useFakeTimers();
    useUIStore.getState().pushToast({ kind: "info", title: "x", duration: 1000 });
    expect(useUIStore.getState().toasts).toHaveLength(1);
    vi.advanceTimersByTime(1500);
    expect(useUIStore.getState().toasts).toHaveLength(0);
    vi.useRealTimers();
  });

  it("dismissToast_removesById", () => {
    const id = useUIStore.getState().pushToast({ kind: "info", title: "x", duration: 0 });
    useUIStore.getState().dismissToast(id);
    expect(useUIStore.getState().toasts).toHaveLength(0);
  });

  it("pushToast_durationZero_neverAutoDismisses", () => {
    vi.useFakeTimers();
    useUIStore.getState().pushToast({ kind: "warn", title: "x", duration: 0 });
    vi.advanceTimersByTime(60_000);
    expect(useUIStore.getState().toasts).toHaveLength(1);
    vi.useRealTimers();
  });
});
