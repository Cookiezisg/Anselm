# Welcome + Sidebar Gemini-style Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Forgify's current sidebar + Dashboard with a Gemini-style minimal layout — rotating greetings pool of 360 lines, smart adaptive context strip, hover-morph collapse, collapsible "工具" / "最近" sections, footer with avatar-badge + hover-gear.

**Architecture:** Pure CSS + zustand + React. Five new hooks/components under `frontend/src/panes/dashboard/` and `frontend/src/components/layout/`. `Sidebar.jsx` + `Dashboard.jsx` full rewrites. Icons stay on `lucide-react`(size/stroke overridden per call). All state in localStorage. Zero backend changes.

**Tech Stack:** React 18, Vite, Framer Motion (collapse spring), Zustand (UI state), TanStack Query (data), lucide-react (icons), Vitest + @testing-library/react (tests).

**Reference spec:** [`docs/superpowers/specs/2026-05-25-welcome-sidebar-gemini-redesign-design.md`](../specs/2026-05-25-welcome-sidebar-gemini-redesign-design.md)

---

## File map

**Create:**
- `frontend/src/hooks/useDisplayName.js` + `.test.js`
- `frontend/src/panes/dashboard/greetings.js` + `.test.js` (360 entries)
- `frontend/src/panes/dashboard/useGreeting.js` + `.test.js`
- `frontend/src/panes/dashboard/useContextStrip.js` + `.test.js`
- `frontend/src/panes/dashboard/WelcomeInput.jsx` + `.test.jsx`
- `frontend/src/components/layout/SidebarSection.jsx` + `.test.jsx`
- `frontend/src/panes/dashboard/Dashboard.test.jsx` (new)

**Modify:**
- `frontend/src/components/primitives/Icon.jsx` — add 5 icons (SquarePen, BarChart3, Plug, PanelLeftClose, PanelLeftOpen)
- `frontend/src/store/ui.js` — add `toolsExpanded` / `recentExpanded` / `displayName` + localStorage persist
- `frontend/src/components/layout/Sidebar.jsx` — full rewrite
- `frontend/src/components/layout/Sidebar.test.jsx` — full rewrite
- `frontend/src/components/layout/PaneFrame.jsx` — forge label `锻造` → `工坊`
- `frontend/src/panes/dashboard/Dashboard.jsx` — full rewrite
- `frontend/src/components/overlays/NotificationsDrawer.jsx` — add 待办 tab
- `frontend/src/components/overlays/SettingsPopover.jsx` — displayName input
- `frontend/src/styles/components.css` — rewrite `.sidebar-*` / `.nav-*` / `.dash-*` sections
- `documents/version-1.2/frontend-prd.md` — §8 sidebar structure, §16 已修 entries
- `DESIGN.md` — new §10 问候语调性
- `documents/version-1.2/progress-record.md` — dev logs

**Out of scope:** ChatPane, ForgePane, ExecutePane, DocumentsPane, ObservePane, SkillsPane, McpPane, MemoryPane internals. Backend code, API contract.

---

## Task 1: Add 5 icons to Icon.jsx

**Files:**
- Modify: `frontend/src/components/primitives/Icon.jsx`

- [ ] **Step 1: Add imports + exports**

Edit `Icon.jsx`. In the import block (lines 10-19), add `SquarePen, BarChart3, Plug, PanelLeftClose, PanelLeftOpen` (alphabetize within the line is fine):

```js
import {
  Search, Plus, ChevronRight, ChevronDown, ChevronUp, X, Check, Bell, Command,
  Settings, MessageSquare, Hammer, Play, Library, User, Bot, Brain, Wrench,
  Code, Paperclip, File, FileText, Image, Send, Square, Sparkles, AtSign,
  Mic, AlertCircle, CheckCircle, Clock, Folder, Database, Globe, Workflow,
  GitBranch, Cpu, Zap, Layers, KeyRound, Brush, Eye, EyeOff, Copy, Trash,
  RefreshCw, StopCircle, ArrowUp, ArrowRight, CornerDownLeft, Pin, Filter,
  MoreHorizontal, Menu, Inbox, Terminal, HelpCircle, Pause, Activity, Server,
  Box, Boxes, Package, ListChecks, Edit, Sun, Moon, Archive,
  SquarePen, BarChart3, Plug, PanelLeftClose, PanelLeftOpen,
} from "lucide-react";
```

Then in the `export const Icon` object, append:

```js
  SquarePen: wrap(SquarePen),
  BarChart3: wrap(BarChart3),
  Plug: wrap(Plug),
  PanelLeftClose: wrap(PanelLeftClose),
  PanelLeftOpen: wrap(PanelLeftOpen),
```

- [ ] **Step 2: Verify build**

```bash
cd frontend && npm run build 2>&1 | tail -5
```
Expected: build succeeds, no "Cannot resolve SquarePen" error.

- [ ] **Step 3: Commit**

```bash
git add frontend/src/components/primitives/Icon.jsx
git commit -m "feat(frontend): 加 SquarePen / BarChart3 / Plug / PanelLeftClose / PanelLeftOpen 5 个 lucide icon"
git push origin main
```

---

## Task 2: useDisplayName hook

**Files:**
- Create: `frontend/src/hooks/useDisplayName.js`
- Create: `frontend/src/hooks/useDisplayName.test.js`

**Contract:**
- `useDisplayName()` returns `[displayName, setDisplayName]`
- Persists to `localStorage` key `forgify.user.displayName`
- Returns `""` (empty string) when unset
- `setDisplayName(value)` writes to localStorage immediately + re-renders all consumers

- [ ] **Step 1: Write the test**

Write `frontend/src/hooks/useDisplayName.test.js`:

```js
import { describe, it, expect, beforeEach } from "vitest";
import { renderHook, act } from "@testing-library/react";
import { useDisplayName } from "./useDisplayName.js";

describe("useDisplayName", () => {
  beforeEach(() => localStorage.clear());

  it("returns empty string when unset", () => {
    const { result } = renderHook(() => useDisplayName());
    expect(result.current[0]).toBe("");
  });

  it("reads from localStorage on mount", () => {
    localStorage.setItem("forgify.user.displayName", "Weilin");
    const { result } = renderHook(() => useDisplayName());
    expect(result.current[0]).toBe("Weilin");
  });

  it("persists on set", () => {
    const { result } = renderHook(() => useDisplayName());
    act(() => result.current[1]("Mia"));
    expect(localStorage.getItem("forgify.user.displayName")).toBe("Mia");
    expect(result.current[0]).toBe("Mia");
  });

  it("syncs across instances via storage event", () => {
    const a = renderHook(() => useDisplayName());
    const b = renderHook(() => useDisplayName());
    act(() => a.result.current[1]("Zoe"));
    expect(b.result.current[0]).toBe("Zoe");
  });
});
```

- [ ] **Step 2: Run test (verify failure)**

```bash
cd frontend && npx vitest run src/hooks/useDisplayName.test.js
```
Expected: FAIL — `Cannot find module './useDisplayName.js'`.

- [ ] **Step 3: Implement**

Write `frontend/src/hooks/useDisplayName.js`:

```js
// useDisplayName — local-only user display name kept in localStorage.
// Multiple instances stay in sync via a tiny in-module event bus.
//
// useDisplayName —— 本地单用户的显示名,走 localStorage;多个实例
// 通过模块内事件总线同步,避免不同组件读到不同值。

import { useEffect, useState } from "react";

const KEY = "forgify.user.displayName";
const listeners = new Set();

function read() {
  try { return localStorage.getItem(KEY) || ""; }
  catch { return ""; }
}

function write(value) {
  try {
    localStorage.setItem(KEY, value || "");
    listeners.forEach((fn) => fn(value || ""));
  } catch {
    // ignore quota / SSR
  }
}

export function useDisplayName() {
  const [value, setValue] = useState(read);

  useEffect(() => {
    const fn = (v) => setValue(v);
    listeners.add(fn);
    return () => listeners.delete(fn);
  }, []);

  return [value, write];
}
```

- [ ] **Step 4: Run test (verify pass)**

```bash
cd frontend && npx vitest run src/hooks/useDisplayName.test.js
```
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/hooks/useDisplayName.js frontend/src/hooks/useDisplayName.test.js
git commit -m "feat(frontend): useDisplayName hook (localStorage,事件总线跨实例同步)"
git push origin main
```

---

## Task 3: greetings.js — 360 句池子

**Files:**
- Create: `frontend/src/panes/dashboard/greetings.js`
- Create: `frontend/src/panes/dashboard/greetings.test.js`

**Contract:**
- Exports `GREETINGS`: array of `{ text: string, tags: string[] }`
- 360 unique entries
- Tags from fixed enum: `['A','B','C','D','E','F','G','G-morning','G-night','H','I','J','K','L','M','N','O']` (G splits into morning / night sub-buckets)
- `text` may contain literal `{name}` placeholder

- [ ] **Step 1: Write the test**

Write `frontend/src/panes/dashboard/greetings.test.js`:

```js
import { describe, it, expect } from "vitest";
import { GREETINGS } from "./greetings.js";

describe("GREETINGS", () => {
  it("has 360 entries", () => {
    expect(GREETINGS.length).toBe(360);
  });

  it("every entry has text + tags", () => {
    for (const g of GREETINGS) {
      expect(typeof g.text).toBe("string");
      expect(g.text.length).toBeGreaterThan(0);
      expect(Array.isArray(g.tags)).toBe(true);
      expect(g.tags.length).toBeGreaterThan(0);
    }
  });

  it("all texts are unique", () => {
    const seen = new Set();
    for (const g of GREETINGS) {
      expect(seen.has(g.text)).toBe(false);
      seen.add(g.text);
    }
  });

  it("category M entries all contain {name}", () => {
    const m = GREETINGS.filter((g) => g.tags.includes("M"));
    expect(m.length).toBeGreaterThan(10);
    for (const g of m) expect(g.text).toContain("{name}");
  });

  it("name-free subset has at least 250 entries", () => {
    const free = GREETINGS.filter((g) => !g.text.includes("{name}"));
    expect(free.length).toBeGreaterThanOrEqual(250);
  });

  it("G has morning and night sub-tags", () => {
    expect(GREETINGS.some((g) => g.tags.includes("G-morning"))).toBe(true);
    expect(GREETINGS.some((g) => g.tags.includes("G-night"))).toBe(true);
  });
});
```

- [ ] **Step 2: Run test (verify failure)**

```bash
cd frontend && npx vitest run src/panes/dashboard/greetings.test.js
```
Expected: FAIL — `Cannot find module './greetings.js'`.

- [ ] **Step 3: Create greetings.js with the 360 entries**

Write `frontend/src/panes/dashboard/greetings.js`:

```js
// GREETINGS — 360-line rotating pool for the welcome page.
// Tag taxonomy:
//   A confident "Your X"   B forge/anvil theme   C build/ship/make
//   D what/where/how       E continuation        F short imperatives
//   G time-aware (G-morning / G-night sub-buckets)
//   H high-stakes drama    I deadpan/witty       J soft/patient
//   K AI self-reference    L aphorisms           M name-bearing ({name})
//   N self-mentioning Forgify   O misc
//
// GREETINGS —— 360 条欢迎页问候语池,15 大类。含 {name} 的句子在
// useGreeting 里按 displayName 是否可用过滤。

export const GREETINGS = [
  // A — Your move family (25)
  { text: "Your move, {name}.", tags: ["A","M"] },
  { text: "Your call, {name}.", tags: ["A","M"] },
  { text: "Your turn.", tags: ["A"] },
  { text: "Your shot.", tags: ["A"] },
  { text: "Your serve.", tags: ["A"] },
  { text: "Your play.", tags: ["A"] },
  { text: "Your move.", tags: ["A"] },
  { text: "The mic's yours.", tags: ["A"] },
  { text: "The floor is yours.", tags: ["A"] },
  { text: "Take the floor.", tags: ["A"] },
  { text: "Take the wheel.", tags: ["A"] },
  { text: "Take the lead.", tags: ["A"] },
  { text: "Take it from here.", tags: ["A"] },
  { text: "Lead the way.", tags: ["A"] },
  { text: "Set the pace.", tags: ["A"] },
  { text: "Set the table.", tags: ["A"] },
  { text: "Call it.", tags: ["A"] },
  { text: "Make the call.", tags: ["A"] },
  { text: "You drive.", tags: ["A"] },
  { text: "Steer the ship.", tags: ["A"] },
  { text: "It's all you.", tags: ["A"] },
  { text: "Over to you.", tags: ["A"] },
  { text: "You first.", tags: ["A"] },
  { text: "All yours.", tags: ["A"] },
  { text: "The day's yours, {name}.", tags: ["A","M"] },

  // B — Forge/anvil theme (45)
  { text: "The forge is hot.", tags: ["B"] },
  { text: "The forge is breathing.", tags: ["B"] },
  { text: "The forge is awake.", tags: ["B"] },
  { text: "The forge is yours.", tags: ["B"] },
  { text: "The anvil's waiting.", tags: ["B"] },
  { text: "The anvil's ringing.", tags: ["B"] },
  { text: "The iron is ready.", tags: ["B"] },
  { text: "The iron is hot.", tags: ["B"] },
  { text: "The fire's lit.", tags: ["B"] },
  { text: "The fire's high.", tags: ["B"] },
  { text: "The kiln is loud.", tags: ["B"] },
  { text: "The kiln is warming up.", tags: ["B"] },
  { text: "The bellows are ready.", tags: ["B"] },
  { text: "The coal's burning, {name}.", tags: ["B","M"] },
  { text: "The smithy's open.", tags: ["B"] },
  { text: "The shop is open, {name}.", tags: ["B","M"] },
  { text: "The flame's steady.", tags: ["B"] },
  { text: "Strike while it's hot.", tags: ["B"] },
  { text: "Strike clean.", tags: ["B"] },
  { text: "Hammer's in your hand.", tags: ["B"] },
  { text: "Hammer down.", tags: ["B"] },
  { text: "Sparks fly when you say so.", tags: ["B"] },
  { text: "Spark something.", tags: ["B"] },
  { text: "Lay it on the anvil.", tags: ["B"] },
  { text: "Lay the iron down.", tags: ["B"] },
  { text: "Hot iron, sharp mind.", tags: ["B"] },
  { text: "Quench it later.", tags: ["B"] },
  { text: "Tempered and ready.", tags: ["B"] },
  { text: "Steel sharpens steel.", tags: ["B"] },
  { text: "Iron doesn't shape itself.", tags: ["B"] },
  { text: "Heat. Strike. Repeat.", tags: ["B"] },
  { text: "Stoke the fire.", tags: ["B"] },
  { text: "Light the forge.", tags: ["B"] },
  { text: "Forge mode: on.", tags: ["B"] },
  { text: "Sharpen something today.", tags: ["B"] },
  { text: "On the anvil today.", tags: ["B"] },
  { text: "What's burning?", tags: ["B","D"] },
  { text: "What's on the anvil?", tags: ["B","D"] },
  { text: "What needs forging?", tags: ["B","D"] },
  { text: "What are we forging today?", tags: ["B","D"] },
  { text: "What are we hammering today?", tags: ["B","D"] },
  { text: "From iron to instrument.", tags: ["B"] },
  { text: "From cold to forged.", tags: ["B"] },
  { text: "From kindling to flame.", tags: ["B"] },
  { text: "From spark to ship.", tags: ["B"] },

  // C — Build/Ship/Make (40)
  { text: "Let's build something.", tags: ["C"] },
  { text: "Let's make something.", tags: ["C"] },
  { text: "Let's ship something.", tags: ["C"] },
  { text: "Let's get into it.", tags: ["C"] },
  { text: "Let's get to work.", tags: ["C"] },
  { text: "Let's roll.", tags: ["C"] },
  { text: "Let's go.", tags: ["C"] },
  { text: "Let's see what you've got.", tags: ["C"] },
  { text: "Build something real.", tags: ["C"] },
  { text: "Build it small. Ship it fast.", tags: ["C"] },
  { text: "Make something.", tags: ["C"] },
  { text: "Make it count.", tags: ["C"] },
  { text: "Make it sharp.", tags: ["C"] },
  { text: "Make it true, then make it fast.", tags: ["C"] },
  { text: "Ship something good.", tags: ["C"] },
  { text: "Ready to ship.", tags: ["C"] },
  { text: "Time to make something.", tags: ["C"] },
  { text: "Today we build.", tags: ["C"] },
  { text: "Today we forge.", tags: ["C","B"] },
  { text: "Today we ship.", tags: ["C"] },
  { text: "Today we move.", tags: ["C"] },
  { text: "Today we cut deep.", tags: ["C"] },
  { text: "Today we hit clean.", tags: ["C"] },
  { text: "Today we land the change.", tags: ["C"] },
  { text: "Today we end the open loops.", tags: ["C"] },
  { text: "Today we close the tab.", tags: ["C"] },
  { text: "From zero to draft.", tags: ["C"] },
  { text: "From draft to ship.", tags: ["C"] },
  { text: "From idea to artifact.", tags: ["C"] },
  { text: "From rough to finished.", tags: ["C"] },
  { text: "From scratch to scale.", tags: ["C"] },
  { text: "Build first. Polish later.", tags: ["C"] },
  { text: "Forge first. Doubt later.", tags: ["C","B"] },
  { text: "Sketch or ship today?", tags: ["C","D"] },
  { text: "Build or break today?", tags: ["C","D"] },
  { text: "Idea or execution today?", tags: ["C","D"] },
  { text: "Push or polish today?", tags: ["C","D"] },
  { text: "Forge or fix today?", tags: ["C","D","B"] },
  { text: "Plan or pounce today?", tags: ["C","D"] },
  { text: "Notes or code today?", tags: ["C","D"] },

  // D — What/Where/How (30)
  { text: "What's first?", tags: ["D"] },
  { text: "What's next?", tags: ["D"] },
  { text: "What's hot?", tags: ["D"] },
  { text: "What's cooking?", tags: ["D"] },
  { text: "What's brewing?", tags: ["D"] },
  { text: "What's the plan?", tags: ["D"] },
  { text: "What's the play?", tags: ["D"] },
  { text: "What's the move?", tags: ["D"] },
  { text: "What are we building today?", tags: ["D","C"] },
  { text: "What are we shipping today?", tags: ["D","C"] },
  { text: "What are we wiring today?", tags: ["D"] },
  { text: "What's burning brightest?", tags: ["D","B"] },
  { text: "Where to today?", tags: ["D"] },
  { text: "Where are we headed?", tags: ["D"] },
  { text: "Where are we taking this?", tags: ["D"] },
  { text: "Where do we start?", tags: ["D"] },
  { text: "How can I help?", tags: ["D","K"] },
  { text: "How big are we thinking?", tags: ["D"] },
  { text: "How bold are we feeling?", tags: ["D"] },
  { text: "How fast can we ship?", tags: ["D","C"] },
  { text: "Why not now?", tags: ["D"] },
  { text: "Easy or hard today?", tags: ["D"] },
  { text: "Big or small today?", tags: ["D"] },
  { text: "New or unfinished today?", tags: ["D"] },
  { text: "Long day or short sprint?", tags: ["D"] },
  { text: "Got a flow to wire?", tags: ["D"] },
  { text: "Got a function to forge?", tags: ["D","B"] },
  { text: "Got a handler to ship?", tags: ["D","C"] },
  { text: "Got a workflow to test?", tags: ["D"] },
  { text: "Got a bug to corner?", tags: ["D"] },

  // E — Continuation (15)
  { text: "Pick up where you left off.", tags: ["E"] },
  { text: "Pick up the thread.", tags: ["E"] },
  { text: "Right where you left off.", tags: ["E"] },
  { text: "Resume the chase.", tags: ["E"] },
  { text: "Back at it.", tags: ["E"] },
  { text: "Back in.", tags: ["E"] },
  { text: "Back to it.", tags: ["E"] },
  { text: "Back to forging.", tags: ["E","B"] },
  { text: "Welcome back, {name}.", tags: ["E","M"] },
  { text: "Where were we?", tags: ["E"] },
  { text: "Keep going.", tags: ["E"] },
  { text: "Continue the build.", tags: ["E","C"] },
  { text: "Don't break stride.", tags: ["E"] },
  { text: "Pick up the iron.", tags: ["E","B"] },
  { text: "Open thread, hot forge.", tags: ["E","B"] },

  // F — Short imperatives (30)
  { text: "Begin.", tags: ["F"] },
  { text: "Speak.", tags: ["F"] },
  { text: "Strike.", tags: ["F","B"] },
  { text: "Build.", tags: ["F","C"] },
  { text: "Ship.", tags: ["F","C"] },
  { text: "Forge.", tags: ["F","B"] },
  { text: "Make.", tags: ["F","C"] },
  { text: "Move.", tags: ["F"] },
  { text: "Go.", tags: ["F"] },
  { text: "Start.", tags: ["F"] },
  { text: "Now.", tags: ["F"] },
  { text: "Today.", tags: ["F"] },
  { text: "Whenever.", tags: ["F"] },
  { text: "Hit it.", tags: ["F"] },
  { text: "Send it.", tags: ["F"] },
  { text: "Press send.", tags: ["F"] },
  { text: "Sound off.", tags: ["F"] },
  { text: "Light it up.", tags: ["F"] },
  { text: "Open the floor, {name}.", tags: ["F","M"] },
  { text: "Roll the dice.", tags: ["F"] },
  { text: "Game on.", tags: ["F"] },
  { text: "Lay it on me.", tags: ["F","K"] },
  { text: "Just say the word.", tags: ["F"] },
  { text: "Ready when you are.", tags: ["F","K"] },
  { text: "Just start.", tags: ["F"] },
  { text: "Just begin.", tags: ["F"] },
  { text: "Start anywhere.", tags: ["F"] },
  { text: "Start sloppy.", tags: ["F"] },
  { text: "Start before doubt.", tags: ["F"] },
  { text: "Start before perfect.", tags: ["F"] },

  // G — Time-aware (20). 13 morning / 7 night
  { text: "Morning, {name}.", tags: ["G","G-morning","M"] },
  { text: "Good morning. What's first?", tags: ["G","G-morning"] },
  { text: "Coffee's down. Ideas up?", tags: ["G","G-morning"] },
  { text: "First light. First move.", tags: ["G","G-morning"] },
  { text: "Fresh start.", tags: ["G","G-morning"] },
  { text: "Day's young. So are we.", tags: ["G","G-morning"] },
  { text: "Caffeine acquired?", tags: ["G","G-morning"] },
  { text: "Post-lunch sharpening.", tags: ["G"] },
  { text: "Afternoon stretch — and ship.", tags: ["G","C"] },
  { text: "Sun's high. Forge higher.", tags: ["G","B"] },
  { text: "Working late, {name}.", tags: ["G","G-night","M"] },
  { text: "Burning the midnight oil.", tags: ["G","G-night"] },
  { text: "Still here? Let's go.", tags: ["G","G-night"] },
  { text: "Late shift's the best shift.", tags: ["G","G-night"] },
  { text: "Quiet hours. Loud ideas.", tags: ["G","G-night"] },
  { text: "After-hours forge.", tags: ["G","G-night","B"] },
  { text: "Night forge.", tags: ["G","G-night","B"] },
  { text: "Weekend forge.", tags: ["G","B"] },
  { text: "Saturday build.", tags: ["G","C"] },
  { text: "Sunday strikes hit different.", tags: ["G"] },

  // H — High-stakes drama (20)
  { text: "The clock's running.", tags: ["H"] },
  { text: "Big day, {name}.", tags: ["H","M"] },
  { text: "Stage is set.", tags: ["H"] },
  { text: "Lights are on.", tags: ["H"] },
  { text: "Crowd's quiet.", tags: ["H"] },
  { text: "Curtain's up.", tags: ["H"] },
  { text: "Make it matter.", tags: ["H"] },
  { text: "No half-measures.", tags: ["H"] },
  { text: "Go big.", tags: ["H"] },
  { text: "Burn it bright.", tags: ["H"] },
  { text: "Don't blink.", tags: ["H"] },
  { text: "Eyes forward.", tags: ["H"] },
  { text: "Bring your A game.", tags: ["H"] },
  { text: "This one counts.", tags: ["H"] },
  { text: "Set the bar.", tags: ["H"] },
  { text: "Raise the bar.", tags: ["H"] },
  { text: "Reset the bar.", tags: ["H"] },
  { text: "Pull no punches.", tags: ["H"] },
  { text: "Don't be polite about it.", tags: ["H"] },
  { text: "Aim for finished.", tags: ["H","C"] },

  // I — Deadpan / Witty (25)
  { text: "Don't keep me waiting.", tags: ["I"] },
  { text: "I cleared my schedule.", tags: ["I","K"] },
  { text: "The fire's been hot for an hour.", tags: ["I","B"] },
  { text: "Surprise me.", tags: ["I","K"] },
  { text: "Impress yourself.", tags: ["I"] },
  { text: "Hope you brought ideas.", tags: ["I"] },
  { text: "The good ones come early.", tags: ["I"] },
  { text: "Best to start before second-guessing.", tags: ["I"] },
  { text: "Try not to ship a bug.", tags: ["I"] },
  { text: "Try not to break prod.", tags: ["I"] },
  { text: "Try not to make it weird.", tags: ["I"] },
  { text: "Today, we earn the lunch break.", tags: ["I"] },
  { text: "I'm not above flattery. Just start.", tags: ["I","K"] },
  { text: "Surprise the anvil.", tags: ["I","B"] },
  { text: "Bad ideas welcome — fire fixes them.", tags: ["I"] },
  { text: "Half-baked is half-cooked is half-done.", tags: ["I"] },
  { text: "Even bad ideas spark fire.", tags: ["I"] },
  { text: "Especially the half-baked ones.", tags: ["I"] },
  { text: "Doodles welcome (in text).", tags: ["I"] },
  { text: "Word-vomit it. Then we polish.", tags: ["I"] },
  { text: "The polish comes free.", tags: ["I"] },
  { text: "Type fast. Edit later.", tags: ["I"] },
  { text: "Stream of consciousness welcome.", tags: ["I"] },
  { text: "Half-finished is fine. Get to half.", tags: ["I"] },
  { text: "Even one sentence is a start.", tags: ["I"] },

  // J — Soft / Patient (20)
  { text: "Take your time, {name}.", tags: ["J","M"] },
  { text: "Tell me everything.", tags: ["J","K"] },
  { text: "Show me what you've got.", tags: ["J"] },
  { text: "No rush. But also — go.", tags: ["J"] },
  { text: "I'll wait. But not for long.", tags: ["J","K"] },
  { text: "Whenever you're ready.", tags: ["J"] },
  { text: "Whatever you've got.", tags: ["J"] },
  { text: "Wherever this leads.", tags: ["J"] },
  { text: "Whatever feels right.", tags: ["J"] },
  { text: "However you want to.", tags: ["J"] },
  { text: "As big or as small as you want.", tags: ["J"] },
  { text: "Bring me anything.", tags: ["J","K"] },
  { text: "Bring me a problem.", tags: ["J","K"] },
  { text: "Bring me a brief.", tags: ["J","K"] },
  { text: "Bring me a question.", tags: ["J","K"] },
  { text: "Bring me an idea worth forging.", tags: ["J","K","B"] },
  { text: "Drop something in.", tags: ["J"] },
  { text: "Drop the brief.", tags: ["J"] },
  { text: "Drop the seed.", tags: ["J"] },
  { text: "Plant the question.", tags: ["J"] },

  // K — AI self-reference (20)
  { text: "I'm all ears, {name}.", tags: ["K","M"] },
  { text: "I'm ready when you are.", tags: ["K"] },
  { text: "Standing by.", tags: ["K"] },
  { text: "Locked in.", tags: ["K"] },
  { text: "Tuned in.", tags: ["K"] },
  { text: "Cued up.", tags: ["K"] },
  { text: "On your mark.", tags: ["K"] },
  { text: "Hand on the bellows.", tags: ["K","B"] },
  { text: "Pen up, page open.", tags: ["K"] },
  { text: "Sharpened up.", tags: ["K","B"] },
  { text: "Whenever you say.", tags: ["K"] },
  { text: "Hand me the spark.", tags: ["K","B"] },
  { text: "Hand me the brief.", tags: ["K"] },
  { text: "Hand me the puzzle.", tags: ["K"] },
  { text: "Throw me a curveball.", tags: ["K"] },
  { text: "Pass me the iron.", tags: ["K","B"] },
  { text: "Pass me the design.", tags: ["K"] },
  { text: "Tell me the shape of it.", tags: ["K"] },
  { text: "Show me the rough draft.", tags: ["K"] },
  { text: "Bring the chaos. I'll bring order.", tags: ["K"] },

  // L — Aphorisms (15)
  { text: "Slow is smooth, smooth is fast.", tags: ["L"] },
  { text: "Done is the polish.", tags: ["L"] },
  { text: "The hard part is starting.", tags: ["L"] },
  { text: "The next move is always the move.", tags: ["L"] },
  { text: "Begin badly, refine ruthlessly.", tags: ["L"] },
  { text: "Discipline beats inspiration.", tags: ["L"] },
  { text: "Make small bets. Win often.", tags: ["L"] },
  { text: "Compounding is silent.", tags: ["L"] },
  { text: "Friction first, fluency after.", tags: ["L"] },
  { text: "Pace beats sprint.", tags: ["L"] },
  { text: "Confidence first, edits later.", tags: ["L"] },
  { text: "Aim higher.", tags: ["L"] },
  { text: "Stillness, then strike.", tags: ["L","B"] },
  { text: "Hush. Then hammer.", tags: ["L","B"] },
  { text: "Quiet hands, sharp ideas.", tags: ["L"] },

  // M — Personalized with Weilin/{name} (15)
  { text: "Game face, {name}.", tags: ["M"] },
  { text: "Steady hand, {name}.", tags: ["M"] },
  { text: "Sharp eye, {name}.", tags: ["M"] },
  { text: "Light hands, {name}.", tags: ["M"] },
  { text: "Tight loop, {name}.", tags: ["M"] },
  { text: "Right tool, {name}.", tags: ["M"] },
  { text: "Big idea, {name}?", tags: ["M"] },
  { text: "Easy mode or hard mode, {name}?", tags: ["M"] },
  { text: "Place your bets, {name}.", tags: ["M"] },
  { text: "Start anyway, {name}.", tags: ["M","F"] },
  { text: "Forgify is yours, {name}.", tags: ["M","N"] },
  { text: "Hand on the hammer, {name}.", tags: ["M","B"] },
  { text: "Eyes on the iron, {name}.", tags: ["M","B"] },
  { text: "Sound off, {name}.", tags: ["M","F"] },
  { text: "The smithy is open, {name}.", tags: ["M","B"] },

  // N — Forgify self-mention (10)
  { text: "Forgify, lights on.", tags: ["N"] },
  { text: "Forgify is up.", tags: ["N"] },
  { text: "Forgify is hot.", tags: ["N","B"] },
  { text: "Forgify is open.", tags: ["N"] },
  { text: "Forgify, ready.", tags: ["N"] },
  { text: "Forgify, listening.", tags: ["N","K"] },
  { text: "Forgify says: speak.", tags: ["N","K"] },
  { text: "The smithy is named Forgify.", tags: ["N","B"] },
  { text: "Forgify is online.", tags: ["N"] },
  { text: "Forgify is warmed up.", tags: ["N","B"] },

  // O — Misc (50)
  { text: "Plot something.", tags: ["O"] },
  { text: "Pull a rabbit from the kiln.", tags: ["O","B"] },
  { text: "The blueprint's in your head — let it out.", tags: ["O"] },
  { text: "Let it leak.", tags: ["O"] },
  { text: "Let it spill.", tags: ["O"] },
  { text: "Let it flow.", tags: ["O"] },
  { text: "Speak it into the editor.", tags: ["O"] },
  { text: "Whisper it. I'll hear.", tags: ["O","K"] },
  { text: "One sentence. Then we go.", tags: ["O"] },
  { text: "One line. Then I'll guess the rest.", tags: ["O","K"] },
  { text: "Outlines welcome.", tags: ["O"] },
  { text: "Drafts welcome.", tags: ["O"] },
  { text: "The shop is quiet — fill it.", tags: ["O","B"] },
  { text: "The pipeline's quiet — fill it.", tags: ["O"] },
  { text: "The runway is clean.", tags: ["O"] },
  { text: "The path is yours.", tags: ["O","A"] },
  { text: "The dock is clear — ship.", tags: ["O","C"] },
  { text: "Cursor in. Mind in.", tags: ["O"] },
  { text: "Slow hands, fast brain.", tags: ["O","L"] },
  { text: "Click of the keyboard, ring of the anvil.", tags: ["O","B"] },
  { text: "Plumbing today, or polish?", tags: ["O","D"] },
  { text: "A handler before lunch?", tags: ["O"] },
  { text: "A function before lunch?", tags: ["O"] },
  { text: "New flow, new fire.", tags: ["O","B"] },
  { text: "New function, new spark.", tags: ["O","B"] },
  { text: "The flow needs you.", tags: ["O"] },
  { text: "Functions on the anvil?", tags: ["O","B"] },
  { text: "Workflow on the anvil?", tags: ["O","B"] },
  { text: "Spelunking today?", tags: ["O","D"] },
  { text: "Hunting bugs today?", tags: ["O","D"] },
  { text: "Drafting today?", tags: ["O","D"] },
  { text: "Sketching today?", tags: ["O","D"] },
  { text: "Wiring today?", tags: ["O","D"] },
  { text: "Forging today?", tags: ["O","D","B"] },
  { text: "Hammering today?", tags: ["O","D","B"] },
  { text: "Shipping today?", tags: ["O","D","C"] },
  { text: "Building today?", tags: ["O","D","C"] },
  { text: "Show me audacity.", tags: ["O","H"] },
  { text: "Show me a finished thing.", tags: ["O","C"] },
  { text: "Show me power.", tags: ["O","H"] },
  { text: "Be loud, on the inside.", tags: ["O"] },
  { text: "Got a thread to follow?", tags: ["O","D"] },
  { text: "Got a mess to sort?", tags: ["O","D"] },
  { text: "Got a doc to draft?", tags: ["O","D"] },
  { text: "A flow before the standup?", tags: ["O"] },
  { text: "A function before tea?", tags: ["O"] },
  { text: "Brief, scope, ship.", tags: ["O","C"] },
  { text: "Brief me.", tags: ["O","K"] },
  { text: "Scope me.", tags: ["O"] },
  { text: "Surface area first, depth later.", tags: ["O","L"] },
];
```

- [ ] **Step 4: Run test (verify pass)**

```bash
cd frontend && npx vitest run src/panes/dashboard/greetings.test.js
```
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/panes/dashboard/greetings.js frontend/src/panes/dashboard/greetings.test.js
git commit -m "feat(frontend): greetings.js — 360 句问候语池(15 类,{name} 占位)"
git push origin main
```

---

## Task 4: useGreeting hook

**Files:**
- Create: `frontend/src/panes/dashboard/useGreeting.js`
- Create: `frontend/src/panes/dashboard/useGreeting.test.js`

**Contract:**
- `useGreeting({ hasRecentConv, displayName })` returns a single string,locked via `useMemo`(same inputs → same string within session)
- Selection order:
  1. hour ≥ 22 or < 6 → 50% from G-night
  2. hour ≥ 6 and < 11 → 50% from G-morning
  3. hasRecentConv → 50% from E
  4. else / fallback → random from full pool
- When `displayName` is falsy, candidates are filtered to entries that don't contain `{name}`
- When picked entry contains `{name}`, replace literal `{name}` with `displayName`

- [ ] **Step 1: Write the test**

Write `frontend/src/panes/dashboard/useGreeting.test.js`:

```js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { renderHook } from "@testing-library/react";
import { useGreeting } from "./useGreeting.js";
import { GREETINGS } from "./greetings.js";

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date("2026-05-25T14:00:00")); // 14:00 (afternoon)
  vi.spyOn(Math, "random").mockReturnValue(0.5);
});
afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
});

describe("useGreeting", () => {
  it("returns a non-empty string", () => {
    const { result } = renderHook(() => useGreeting({ hasRecentConv: false, displayName: "" }));
    expect(typeof result.current).toBe("string");
    expect(result.current.length).toBeGreaterThan(0);
  });

  it("substitutes {name} when displayName is set", () => {
    // Force pick of an entry containing {name}
    const idx = GREETINGS.findIndex((g) => g.text === "Your move, {name}.");
    vi.spyOn(Math, "random").mockImplementation(() => idx / GREETINGS.length + 1e-9);
    const { result } = renderHook(() => useGreeting({ hasRecentConv: false, displayName: "Weilin" }));
    expect(result.current).not.toContain("{name}");
  });

  it("never picks a {name}-bearing entry when displayName is empty", () => {
    for (let seed = 0; seed < 50; seed++) {
      vi.spyOn(Math, "random").mockReturnValue(seed / 50);
      const { result } = renderHook(() => useGreeting({ hasRecentConv: false, displayName: "" }));
      expect(result.current).not.toContain("{name}");
    }
  });

  it("memoizes — same inputs return same string", () => {
    const { result, rerender } = renderHook(
      (props) => useGreeting(props),
      { initialProps: { hasRecentConv: false, displayName: "" } }
    );
    const first = result.current;
    rerender({ hasRecentConv: false, displayName: "" });
    expect(result.current).toBe(first);
  });

  it("at night picks a G-night entry roughly half the time", () => {
    vi.setSystemTime(new Date("2026-05-25T23:30:00"));
    let nightHits = 0;
    const nightTexts = new Set(
      GREETINGS.filter((g) => g.tags.includes("G-night")).map((g) => g.text)
    );
    for (let seed = 0; seed < 100; seed++) {
      vi.spyOn(Math, "random").mockReturnValue(seed / 100);
      const { result } = renderHook(() => useGreeting({ hasRecentConv: false, displayName: "" }));
      if (nightTexts.has(result.current)) nightHits++;
    }
    // 50% bias + small share from G-night in random pool → expect ≥ 30%
    expect(nightHits).toBeGreaterThan(30);
  });
});
```

- [ ] **Step 2: Run test (verify failure)**

```bash
cd frontend && npx vitest run src/panes/dashboard/useGreeting.test.js
```
Expected: FAIL — `Cannot find module './useGreeting.js'`.

- [ ] **Step 3: Implement**

Write `frontend/src/panes/dashboard/useGreeting.js`:

```js
// useGreeting — picks a single greeting per mount,biased by hour and
// whether the user has a recent conv. Memoized so re-renders don't reshuffle.
//
// useGreeting —— 每次 mount 抽一句问候语;凌晨/深夜或早晨各 50% 偏置时间感
// 子集;有最近对话时 50% 偏置续接类;displayName 空时只抽 name-free 子集。

import { useMemo } from "react";
import { GREETINGS } from "./greetings.js";

function pickFrom(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function filterByName(pool, displayName) {
  if (displayName) return pool;
  return pool.filter((g) => !g.text.includes("{name}"));
}

function selectGreeting({ hasRecentConv, displayName }) {
  const hour = new Date().getHours();
  const pool = filterByName(GREETINGS, displayName);

  const tryBucket = (tag, prob) => {
    if (Math.random() < prob) {
      const sub = pool.filter((g) => g.tags.includes(tag));
      if (sub.length) return pickFrom(sub);
    }
    return null;
  };

  let pick = null;
  if (hour >= 22 || hour < 6) pick = tryBucket("G-night", 0.5);
  else if (hour >= 6 && hour < 11) pick = tryBucket("G-morning", 0.5);
  if (!pick && hasRecentConv) pick = tryBucket("E", 0.5);
  if (!pick) pick = pickFrom(pool);

  return pick.text.replaceAll("{name}", displayName || "");
}

export function useGreeting({ hasRecentConv, displayName }) {
  return useMemo(
    () => selectGreeting({ hasRecentConv, displayName }),
    [hasRecentConv, displayName]
  );
}
```

- [ ] **Step 4: Run test (verify pass)**

```bash
cd frontend && npx vitest run src/panes/dashboard/useGreeting.test.js
```
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/panes/dashboard/useGreeting.js frontend/src/panes/dashboard/useGreeting.test.js
git commit -m "feat(frontend): useGreeting hook(时间感 / 续接偏置 + {name} 替换)"
git push origin main
```

---

## Task 5: useContextStrip hook

**Files:**
- Create: `frontend/src/panes/dashboard/useContextStrip.js`
- Create: `frontend/src/panes/dashboard/useContextStrip.test.js`

**Contract:**
- `useContextStrip()` returns one of: `null`, `{ kind: "waiting"|"failed"|"running"|"recent", payload }`
- Priority order (first match wins): `waiting` > `failed` > `running` > `recent`
- `recent` = a conversation with updatedAt within 24h
- Reads from `useFlowRuns()` and `useConversations()`

- [ ] **Step 1: Write the test**

Write `frontend/src/panes/dashboard/useContextStrip.test.js`:

```js
import { describe, it, expect, vi, beforeEach } from "vitest";
import { renderHook } from "@testing-library/react";
import { useContextStrip } from "./useContextStrip.js";

vi.mock("../../api/flowruns.js", () => ({
  useFlowRuns: vi.fn(),
}));
vi.mock("../../api/conversations.js", () => ({
  useConversations: vi.fn(),
}));

import { useFlowRuns } from "../../api/flowruns.js";
import { useConversations } from "../../api/conversations.js";

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date("2026-05-25T12:00:00"));
});

describe("useContextStrip", () => {
  it("returns null when there's nothing of interest", () => {
    useFlowRuns.mockReturnValue({ data: [] });
    useConversations.mockReturnValue({ data: [] });
    const { result } = renderHook(() => useContextStrip());
    expect(result.current).toBeNull();
  });

  it("P1 waiting wins over P2/P3/P4", () => {
    useFlowRuns.mockReturnValue({
      data: [
        { id: "fr_1", status: "waiting_approval", workflow: "data-pipeline", startedAt: "2026-05-25T11:00:00Z" },
        { id: "fr_2", status: "failed", workflow: "etl", startedAt: "2026-05-25T10:00:00Z" },
        { id: "fr_3", status: "running", workflow: "build", startedAt: "2026-05-25T11:30:00Z" },
      ],
    });
    useConversations.mockReturnValue({
      data: [{ id: "cv_a", title: "RAG 数据准备", updatedAt: "2026-05-25T11:55:00Z" }],
    });
    const { result } = renderHook(() => useContextStrip());
    expect(result.current.kind).toBe("waiting");
    expect(result.current.payload.count).toBe(1);
    expect(result.current.payload.flowName).toBe("data-pipeline");
  });

  it("P2 failed wins over P3/P4 when no waiting", () => {
    useFlowRuns.mockReturnValue({
      data: [{ id: "fr_x", status: "failed", workflow: "etl" }],
    });
    useConversations.mockReturnValue({ data: [{ id: "cv_a", title: "x", updatedAt: "2026-05-25T11:00:00Z" }] });
    const { result } = renderHook(() => useContextStrip());
    expect(result.current.kind).toBe("failed");
    expect(result.current.payload.count).toBe(1);
  });

  it("P3 running wins over P4 recent", () => {
    useFlowRuns.mockReturnValue({
      data: [{ id: "fr_x", status: "running", workflow: "build", startedAt: "2026-05-25T11:30:00Z" }],
    });
    useConversations.mockReturnValue({ data: [{ id: "cv_a", title: "x", updatedAt: "2026-05-25T11:00:00Z" }] });
    const { result } = renderHook(() => useContextStrip());
    expect(result.current.kind).toBe("running");
    expect(result.current.payload.count).toBe(1);
    expect(result.current.payload.latestStartedAt).toBe("2026-05-25T11:30:00Z");
  });

  it("P4 recent: shows newest conv within 24h", () => {
    useFlowRuns.mockReturnValue({ data: [] });
    useConversations.mockReturnValue({
      data: [
        { id: "cv_old", title: "stale", updatedAt: "2026-05-20T00:00:00Z" },
        { id: "cv_new", title: "RAG", updatedAt: "2026-05-25T11:00:00Z" },
      ],
    });
    const { result } = renderHook(() => useContextStrip());
    expect(result.current.kind).toBe("recent");
    expect(result.current.payload.convId).toBe("cv_new");
    expect(result.current.payload.convTitle).toBe("RAG");
  });

  it("P4 ignores convs older than 24h", () => {
    useFlowRuns.mockReturnValue({ data: [] });
    useConversations.mockReturnValue({
      data: [{ id: "cv_old", title: "stale", updatedAt: "2026-05-20T00:00:00Z" }],
    });
    const { result } = renderHook(() => useContextStrip());
    expect(result.current).toBeNull();
  });
});
```

- [ ] **Step 2: Run test (verify failure)**

```bash
cd frontend && npx vitest run src/panes/dashboard/useContextStrip.test.js
```
Expected: FAIL — `Cannot find module './useContextStrip.js'`.

- [ ] **Step 3: Implement**

Write `frontend/src/panes/dashboard/useContextStrip.js`:

```js
// useContextStrip — adaptive single-line status hint for the welcome page.
// Priority: waiting_approval > failed > running > recent conv (<24h).
//
// useContextStrip —— 欢迎页底下自适应一行;按 P1>P2>P3>P4 优先级取最重要的;
// 都没就返 null,整行隐藏。

import { useFlowRuns } from "../../api/flowruns.js";
import { useConversations } from "../../api/conversations.js";

const DAY_MS = 24 * 60 * 60 * 1000;

export function useContextStrip() {
  const { data: flowruns = [] } = useFlowRuns();
  const { data: convs = [] } = useConversations();

  const waiting = flowruns.filter((f) => f.status === "waiting_approval");
  if (waiting.length > 0) {
    return {
      kind: "waiting",
      payload: { count: waiting.length, flowName: waiting[0].workflow || waiting[0].workflowId, flowRunId: waiting[0].id },
    };
  }

  const failed = flowruns.filter((f) => f.status === "failed");
  if (failed.length > 0) {
    return { kind: "failed", payload: { count: failed.length } };
  }

  const running = flowruns.filter((f) => f.status === "running");
  if (running.length > 0) {
    const latest = running.reduce((a, b) =>
      new Date(a.startedAt) > new Date(b.startedAt) ? a : b
    );
    return {
      kind: "running",
      payload: { count: running.length, latestStartedAt: latest.startedAt },
    };
  }

  const now = Date.now();
  const recent = convs
    .filter((c) => c.updatedAt && now - new Date(c.updatedAt).getTime() < DAY_MS)
    .sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt));
  if (recent.length > 0) {
    return {
      kind: "recent",
      payload: { convId: recent[0].id, convTitle: recent[0].title || "(无标题)", updatedAt: recent[0].updatedAt },
    };
  }

  return null;
}
```

- [ ] **Step 4: Run test (verify pass)**

```bash
cd frontend && npx vitest run src/panes/dashboard/useContextStrip.test.js
```
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/panes/dashboard/useContextStrip.js frontend/src/panes/dashboard/useContextStrip.test.js
git commit -m "feat(frontend): useContextStrip hook(P1 waiting > P2 failed > P3 running > P4 recent)"
git push origin main
```

---

## Task 6: ui.js — toolsExpanded / recentExpanded with localStorage persist

**Files:**
- Modify: `frontend/src/store/ui.js`

- [ ] **Step 1: Add persist helpers + state fields**

Edit `frontend/src/store/ui.js`. Add the helpers at the top of the file(after the `const MAX_PANES = 2;` line):

```js
function readBool(key, fallback) {
  try {
    const v = localStorage.getItem(key);
    if (v === null) return fallback;
    return v === "1";
  } catch { return fallback; }
}
function writeBool(key, value) {
  try { localStorage.setItem(key, value ? "1" : "0"); } catch {}
}
```

In the `create((set, get) => ({...}))` body, after `narrow: false,`,add:

```js
  toolsExpanded:  readBool("sidebar.toolsExpanded",  true),
  recentExpanded: readBool("sidebar.recentExpanded", true),
```

And in the actions block (alongside `setCollapsed`),add:

```js
  setToolsExpanded: (b) => {
    const next = typeof b === "function" ? b(get().toolsExpanded) : !!b;
    writeBool("sidebar.toolsExpanded", next);
    set({ toolsExpanded: next });
  },
  setRecentExpanded: (b) => {
    const next = typeof b === "function" ? b(get().recentExpanded) : !!b;
    writeBool("sidebar.recentExpanded", next);
    set({ recentExpanded: next });
  },
```

Also update `setCollapsed` to persist:

```js
  setCollapsed: (b) => {
    const next = typeof b === "function" ? b(get().collapsed) : !!b;
    writeBool("sidebar.collapsed", next);
    set({ collapsed: next });
  },
```

And update the initial `collapsed: false` line to:

```js
  collapsed: readBool("sidebar.collapsed", false),
```

- [ ] **Step 2: Build + smoke test in test runner**

```bash
cd frontend && npm test -- --run src/store 2>&1 | tail -20
```
Expected: any existing store tests pass; no test failures introduced.

- [ ] **Step 3: Commit**

```bash
git add frontend/src/store/ui.js
git commit -m "feat(frontend): sidebar collapse / 工具 / 最近 折叠状态持久化到 localStorage"
git push origin main
```

---

## Task 7: SidebarSection component

**Files:**
- Create: `frontend/src/components/layout/SidebarSection.jsx`
- Create: `frontend/src/components/layout/SidebarSection.test.jsx`

**Contract:**
- Props: `label` (string), `expanded` (bool), `onToggle` (fn), `collapsedSidebar` (bool, optional), `children` (ReactNode)
- Renders section header(label or — when `collapsedSidebar` — a 18px short line)
- On hover header,a ▾ Chevron appears(opacity 0→1)
- Click header calls `onToggle`
- Children rendered only when `expanded`

- [ ] **Step 1: Write the test**

Write `frontend/src/components/layout/SidebarSection.test.jsx`:

```jsx
import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { SidebarSection } from "./SidebarSection.jsx";

describe("SidebarSection", () => {
  it("renders label and child when expanded", () => {
    render(
      <SidebarSection label="工具" expanded={true} onToggle={() => {}}>
        <div>child-content</div>
      </SidebarSection>
    );
    expect(screen.getByText("工具")).toBeInTheDocument();
    expect(screen.getByText("child-content")).toBeInTheDocument();
  });

  it("hides children when collapsed", () => {
    render(
      <SidebarSection label="工具" expanded={false} onToggle={() => {}}>
        <div>child-content</div>
      </SidebarSection>
    );
    expect(screen.queryByText("child-content")).not.toBeInTheDocument();
  });

  it("calls onToggle on header click", () => {
    const onToggle = vi.fn();
    render(
      <SidebarSection label="工具" expanded={true} onToggle={onToggle}>
        <div />
      </SidebarSection>
    );
    fireEvent.click(screen.getByRole("button", { name: /工具/i }));
    expect(onToggle).toHaveBeenCalledTimes(1);
  });

  it("renders short-line indicator when collapsedSidebar", () => {
    render(
      <SidebarSection label="工具" expanded={true} onToggle={() => {}} collapsedSidebar={true}>
        <div>child</div>
      </SidebarSection>
    );
    // label text should not be rendered when sidebar is collapsed
    expect(screen.queryByText("工具")).not.toBeInTheDocument();
    // header is still clickable
    expect(screen.getByRole("button")).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test (verify failure)**

```bash
cd frontend && npx vitest run src/components/layout/SidebarSection.test.jsx
```
Expected: FAIL — module not found.

- [ ] **Step 3: Implement**

Write `frontend/src/components/layout/SidebarSection.jsx`:

```jsx
// SidebarSection — collapsible group header with hover-only ▾ chevron.
// In collapsed-sidebar mode the label is replaced by a thin horizontal
// divider; chevron still fades in on hover for symmetry.
//
// SidebarSection —— 可折叠分组标题;hover 才显示 ▾;sidebar 收起态下
// label 降级成 18px 短横线,chev 行为不变。

import { Icon } from "../primitives/Icon.jsx";

export function SidebarSection({ label, expanded, onToggle, collapsedSidebar = false, children }) {
  const cls = "sb-section" + (collapsedSidebar ? " is-collapsed-sb" : "") + (expanded ? " is-expanded" : "");
  return (
    <>
      <button type="button" className={cls} aria-label={label} onClick={onToggle}>
        {!collapsedSidebar && <span className="sb-section-label">{label}</span>}
        {collapsedSidebar && <span className="sb-section-divider" />}
        <Icon.ChevronDown
          size={14}
          strokeWidth={2}
          className={"sb-section-chev" + (expanded ? "" : " is-closed")}
        />
      </button>
      {expanded && children}
    </>
  );
}
```

- [ ] **Step 4: Run test (verify pass)**

```bash
cd frontend && npx vitest run src/components/layout/SidebarSection.test.jsx
```
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/components/layout/SidebarSection.jsx frontend/src/components/layout/SidebarSection.test.jsx
git commit -m "feat(frontend): SidebarSection 可折叠组件(hover-▾,两态对齐)"
git push origin main
```

---

## Task 8: PaneFrame.jsx — 锻造 → 工坊

**Files:**
- Modify: `frontend/src/components/layout/PaneFrame.jsx`

- [ ] **Step 1: Edit the label**

In `PaneFrame.jsx`,find:

```js
  forge:     { icon: "Hammer",        label: "锻造" },
```

Change to:

```js
  forge:     { icon: "Hammer",        label: "工坊" },
```

- [ ] **Step 2: Grep other places using "锻造" string in frontend**

```bash
grep -rn "锻造" /Users/SP14921/Documents/Personal/PersonalCodeBase/Forgify/frontend/src 2>&1 | grep -v node_modules | grep -v coverage
```

If any user-facing label uses "锻造", change it to "工坊". Leave internal docstrings as-is for now. Code-side `forge` identifier — DO NOT change.

- [ ] **Step 3: Run tests**

```bash
cd frontend && npm test 2>&1 | tail -10
```
Expected: all tests still pass (existing tests don't depend on "锻造" string).

- [ ] **Step 4: Commit**

```bash
git add frontend/src/components/layout/PaneFrame.jsx $(grep -l "工坊" /Users/SP14921/Documents/Personal/PersonalCodeBase/Forgify/frontend/src -r 2>/dev/null)
git commit -m "refactor(frontend): UI label 锻造 → 工坊(仅前端文案,后端代码不动)"
git push origin main
```

---

## Task 9: Sidebar.jsx — full rewrite

**Files:**
- Modify: `frontend/src/components/layout/Sidebar.jsx`(full rewrite)

This task replaces all 234 lines.

- [ ] **Step 1: Write the new Sidebar.jsx**

Replace the entire file `frontend/src/components/layout/Sidebar.jsx` with:

```jsx
// Sidebar — Gemini-style left rail. Expanded 260px / collapsed 64px.
// Top logo morphs to PanelLeftClose/PanelLeftOpen on hover (no extra row).
// "工具" + "最近" are collapsible via SidebarSection. Footer shows avatar
// (with red-dot badge for combined Help+Bell unread) and reveals a ⚙
// settings button on hover.
//
// Sidebar —— Gemini-style 左栏。展开 260 / 收起 64。顶部 logo hover 变
// panel-toggle 切换收起;"工具" / "最近" 段可折叠。footer 头像角红 dot
// 是 Help+Bell 合并未读,hover 整行浮出 ⚙ 入设置。

import { motion } from "framer-motion";
import { Icon } from "../primitives/Icon.jsx";
import { Kbd } from "../primitives/Kbd.jsx";
import { useUIStore } from "../../store/ui.js";
import { useConversations, useCreateConversation } from "../../api/conversations.js";
import { useSSEHealth } from "../../sse/SSEProvider.jsx";
import { useDisplayName } from "../../hooks/useDisplayName.js";
import { ChatListItem } from "./ChatListItem.jsx";
import { SidebarSection } from "./SidebarSection.jsx";

const SPRING = { type: "spring", stiffness: 280, damping: 28 };

function ForgifyLogo({ size = 22 }) {
  // Anvil + spark mark. Stroke matches Lucide outline weight.
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} fill="none"
      stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M12 2v3" /><path d="M5 5l2 2" /><path d="M19 5l-2 2" />
      <path d="M4 12h4l2-3l4 6l2-3h4" />
      <path d="M5 17h14" /><path d="M7 21l1-4" /><path d="M17 21l-1-4" />
    </svg>
  );
}

function NavItem({ icon: I, label, active, primary, onClick, collapsed }) {
  const cls =
    "sb-item" +
    (active  ? " is-active"  : "") +
    (primary ? " is-primary" : "");
  return (
    <button type="button" className={cls} onClick={onClick} title={collapsed ? label : undefined}>
      <span className="ic-slot"><I size={18} strokeWidth={2} className="ic" /></span>
      {!collapsed && <span className="label">{label}</span>}
    </button>
  );
}

export function Sidebar() {
  const openPanes      = useUIStore((s) => s.openPanes);
  const togglePane     = useUIStore((s) => s.togglePane);
  const openPane       = useUIStore((s) => s.openPane);
  const setActiveConv  = useUIStore((s) => s.setActiveConv);
  const collapsed      = useUIStore((s) => s.collapsed);
  const setCollapsed   = useUIStore((s) => s.setCollapsed);
  const toolsExpanded  = useUIStore((s) => s.toolsExpanded);
  const setToolsExpanded   = useUIStore((s) => s.setToolsExpanded);
  const recentExpanded = useUIStore((s) => s.recentExpanded);
  const setRecentExpanded  = useUIStore((s) => s.setRecentExpanded);
  const setCmdkOpen        = useUIStore((s) => s.setCmdkOpen);
  const setNotifsOpen      = useUIStore((s) => s.setNotifsOpen);
  const setSettingsPopOpen = useUIStore((s) => s.setSettingsPopOpen);

  const { data: conversations = [] } = useConversations();
  const createConv = useCreateConversation();
  const sse = useSSEHealth();
  const [displayName] = useDisplayName();

  const pinned   = conversations.filter((c) => c.pinned   && !c.archived);
  const recent   = conversations.filter((c) => !c.pinned  && !c.archived);

  const isOpen = (k) => openPanes.includes(k);

  const onNewConv = async () => {
    try {
      const created = await createConv.mutateAsync({});
      if (created?.id) {
        setActiveConv(created.id);
        if (!isOpen("chat")) openPane("chat");
      }
    } catch (err) {
      console.error("create conv failed", err);
    }
  };

  const initial = (displayName?.[0] || "?").toUpperCase();
  const unread = sse.unread || 0;
  const sseDot = sse.overall === "err" || sse.overall === "warn"
    ? `var(--status-${sse.overall === "err" ? "error" : "warn"})` : null;

  return (
    <motion.aside
      className={"sidebar" + (collapsed ? " is-collapsed" : "")}
      animate={{ width: collapsed ? 64 : 260 }}
      transition={SPRING}
      style={{ overflow: "hidden" }}
    >
      <div className="sb-head">
        <button
          type="button"
          className="sb-logo-slot"
          onClick={() => setCollapsed(!collapsed)}
          title={collapsed ? "展开 ⌘B" : "收起 ⌘B"}
          aria-label="toggle sidebar"
        >
          <span className="ic-logo"><ForgifyLogo /></span>
          <span className="ic-toggle">
            {collapsed
              ? <Icon.PanelLeftOpen  size={20} strokeWidth={2} />
              : <Icon.PanelLeftClose size={20} strokeWidth={2} />}
          </span>
        </button>
        {!collapsed && <span className="sb-logo-name">Forgify</span>}
      </div>

      <NavItem icon={Icon.SquarePen} label="新对话"  primary onClick={onNewConv} collapsed={collapsed} />
      <NavItem icon={Icon.Search}    label="搜索 或 跳转" onClick={() => setCmdkOpen(true)} collapsed={collapsed} />

      <div style={{ height: 8 }} />

      <NavItem icon={Icon.MessageSquare} label="对话" active={isOpen("chat")}      onClick={() => togglePane("chat")}      collapsed={collapsed} />
      <NavItem icon={Icon.Hammer}        label="工坊" active={isOpen("forge")}     onClick={() => togglePane("forge")}     collapsed={collapsed} />
      <NavItem icon={Icon.Play}          label="执行" active={isOpen("execute")}   onClick={() => togglePane("execute")}   collapsed={collapsed} />
      <NavItem icon={Icon.FileText}      label="文档" active={isOpen("documents")} onClick={() => togglePane("documents")} collapsed={collapsed} />

      <SidebarSection label="工具" expanded={toolsExpanded} onToggle={() => setToolsExpanded(!toolsExpanded)} collapsedSidebar={collapsed}>
        <NavItem icon={Icon.BarChart3} label="洞察"  active={isOpen("observe")} onClick={() => togglePane("observe")} collapsed={collapsed} />
        <NavItem icon={Icon.Sparkles}  label="Skills" active={isOpen("skills")} onClick={() => togglePane("skills")}  collapsed={collapsed} />
        <NavItem icon={Icon.Plug}      label="MCP"    active={isOpen("mcp")}    onClick={() => togglePane("mcp")}     collapsed={collapsed} />
        <NavItem icon={Icon.Brain}     label="Memory" active={isOpen("memory")} onClick={() => togglePane("memory")}  collapsed={collapsed} />
      </SidebarSection>

      {!collapsed && (
        <div className="sb-recent-wrap">
          <SidebarSection label="最近" expanded={recentExpanded} onToggle={() => setRecentExpanded(!recentExpanded)}>
            {pinned.map((c) => <ChatListItem key={c.id} conv={c} />)}
            {recent.map((c) => <ChatListItem key={c.id} conv={c} />)}
            {pinned.length === 0 && recent.length === 0 && (
              <div className="sb-empty">还没有对话</div>
            )}
          </SidebarSection>
        </div>
      )}

      <div className="sb-foot-spacer" />
      <div className="sb-foot">
        <button
          type="button"
          className="sb-avatar-slot"
          onClick={() => { setNotifsOpen(true); sse.clearUnread?.(); }}
          title={unread > 0 ? `${unread} 条未读` : "通知"}
        >
          <span className="sb-avatar">{initial}</span>
          {unread > 0 && <span className="sb-badge-dot" />}
          {sseDot && <span className="sb-sse-dot" style={{ background: sseDot }} />}
        </button>
        {!collapsed && <span className="sb-user">{displayName || ""}</span>}
        <button
          type="button"
          className="sb-gear-btn"
          onClick={() => setSettingsPopOpen(true)}
          title="设置"
          aria-label="settings"
        >
          <Icon.Settings size={16} strokeWidth={2} />
        </button>
      </div>
    </motion.aside>
  );
}
```

- [ ] **Step 2: Run any existing Sidebar tests (likely fail)**

```bash
cd frontend && npx vitest run src/components/layout/Sidebar.test.jsx 2>&1 | tail -20
```
Expected: FAIL — existing tests reference removed nodes (workspace-pill, etc.).

- [ ] **Step 3: Rewrite Sidebar.test.jsx (next task)**

Continue to Task 10 — leave Sidebar.test.jsx failing for now; the rewrite belongs in its own task.

- [ ] **Step 4: Commit (sidebar rewrite without tests yet — this is OK as a stepping commit because next task fixes tests)**

```bash
git add frontend/src/components/layout/Sidebar.jsx
git commit -m "feat(frontend): Sidebar 重写 — Gemini-style logo morph 收起 / 工具段折叠 / 头像 badge footer"
git push origin main
```

---

## Task 10: Sidebar.test.jsx — rewrite

**Files:**
- Modify (rewrite): `frontend/src/components/layout/Sidebar.test.jsx`

- [ ] **Step 1: Inspect current test for what to keep**

```bash
cd frontend && cat src/components/layout/Sidebar.test.jsx 2>&1 | head -40
```

- [ ] **Step 2: Write the new test**

Replace `frontend/src/components/layout/Sidebar.test.jsx` with:

```jsx
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent, act } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Sidebar } from "./Sidebar.jsx";
import { useUIStore } from "../../store/ui.js";

vi.mock("../../api/conversations.js", () => ({
  useConversations:        () => ({ data: [] }),
  useCreateConversation:   () => ({ mutateAsync: vi.fn().mockResolvedValue({ id: "cv_new" }) }),
  useUpdateConversation:   () => ({ mutate: vi.fn() }),
  useDeleteConversation:   () => ({ mutate: vi.fn() }),
}));
vi.mock("../../sse/SSEProvider.jsx", () => ({
  useSSEHealth: () => ({ overall: "ok", eventlog: "ok", notifs: "ok", forge: "ok", unread: 0, clearUnread: vi.fn() }),
}));

function renderSidebar() {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={qc}>
      <Sidebar />
    </QueryClientProvider>
  );
}

beforeEach(() => {
  localStorage.clear();
  // Reset zustand store
  useUIStore.setState({
    openPanes: [], collapsed: false, toolsExpanded: true, recentExpanded: true,
    cmdkOpen: false, notifsOpen: false, settingsPopOpen: false,
  });
});

describe("Sidebar", () => {
  it("renders Forgify logo + name when expanded", () => {
    renderSidebar();
    expect(screen.getByText("Forgify")).toBeInTheDocument();
  });

  it("renders all 4 workbenches + 4 tools", () => {
    renderSidebar();
    for (const label of ["对话", "工坊", "执行", "文档", "洞察", "Skills", "MCP", "Memory"]) {
      expect(screen.getByText(label)).toBeInTheDocument();
    }
  });

  it("primary 新对话 button calls create-conv and switches to chat pane", async () => {
    renderSidebar();
    await act(async () => {
      fireEvent.click(screen.getByText("新对话"));
    });
    expect(useUIStore.getState().openPanes).toContain("chat");
    expect(useUIStore.getState().activeConv).toBe("cv_new");
  });

  it("toggle collapses sidebar (state + localStorage)", () => {
    renderSidebar();
    fireEvent.click(screen.getByLabelText(/toggle sidebar/i));
    expect(useUIStore.getState().collapsed).toBe(true);
    expect(localStorage.getItem("sidebar.collapsed")).toBe("1");
  });

  it("hides Forgify name + recent section in collapsed mode", () => {
    useUIStore.setState({ collapsed: true });
    renderSidebar();
    expect(screen.queryByText("Forgify")).not.toBeInTheDocument();
  });

  it("collapses tools section on click and persists state", () => {
    renderSidebar();
    fireEvent.click(screen.getByRole("button", { name: "工具" }));
    expect(useUIStore.getState().toolsExpanded).toBe(false);
    expect(localStorage.getItem("sidebar.toolsExpanded")).toBe("0");
    // After collapse, tool items should not be in the DOM
    expect(screen.queryByText("洞察")).not.toBeInTheDocument();
  });

  it("footer avatar click opens NotificationsDrawer", () => {
    renderSidebar();
    const slot = screen.getByTitle(/通知/i);
    fireEvent.click(slot);
    expect(useUIStore.getState().notifsOpen).toBe(true);
  });

  it("footer gear opens settings popover", () => {
    renderSidebar();
    fireEvent.click(screen.getByLabelText("settings"));
    expect(useUIStore.getState().settingsPopOpen).toBe(true);
  });

  it("shows initial from displayName in avatar", () => {
    localStorage.setItem("forgify.user.displayName", "Weilin");
    renderSidebar();
    expect(screen.getByText("W")).toBeInTheDocument();
  });
});
```

- [ ] **Step 3: Run test (verify pass)**

```bash
cd frontend && npx vitest run src/components/layout/Sidebar.test.jsx
```
Expected: PASS, 9 tests.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/components/layout/Sidebar.test.jsx
git commit -m "test(frontend): Sidebar 重写 — 覆盖 collapse / tools section / footer avatar+gear"
git push origin main
```

---

## Task 11: components.css — sidebar styles rewrite

**Files:**
- Modify: `frontend/src/styles/components.css`(replace `.sidebar` / `.sidebar-*` / `.nav-*` / `.workspace-*` / `.cmdk-trigger` sections; lines ~89-240 in the current file)

- [ ] **Step 1: Find the existing block ranges to replace**

```bash
grep -n "^\.sidebar\|^\.nav-\|^\.workspace\|^\.cmdk-trigger\|^\.user-pill\|^\.sidebar-footer" frontend/src/styles/components.css | head -30
```

Note the line numbers. The block to replace is contiguous (from first `.sidebar` to last `.sidebar-footer-*`).

- [ ] **Step 2: Replace the block**

Replace the contiguous sidebar styles block (everything matching `.sidebar`, `.sidebar-*`, `.nav-*`, `.workspace-*`, `.cmdk-trigger`, `.user-pill` selectors) with:

```css
/* ============================================================================
   Sidebar — Gemini-style. Width animates 260 ↔ 64 via Framer Motion.
   ============================================================================ */

.sidebar {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: var(--bg-window);
  border-right: 1px solid var(--border);
  padding: 14px 0 12px;
  gap: 2px;
}

/* Header (logo + name) */
.sb-head {
  display: flex;
  align-items: center;
  height: 40px;
  padding: 0 12px 0 14px;
  margin-bottom: 12px;
}
.sb-logo-slot {
  width: 24px; height: 24px;
  position: relative;
  display: flex; align-items: center; justify-content: center;
  background: transparent; border: 0; padding: 0; cursor: pointer;
  color: var(--accent);
}
.sb-logo-slot .ic-logo,
.sb-logo-slot .ic-toggle {
  position: absolute; inset: 0;
  display: flex; align-items: center; justify-content: center;
  transition: opacity var(--t-fast);
}
.sb-logo-slot .ic-toggle { opacity: 0; color: var(--fg-strong); }
.sb-logo-slot:hover .ic-logo   { opacity: 0; }
.sb-logo-slot:hover .ic-toggle { opacity: 1; }
.sb-logo-name {
  font-size: 15px; font-weight: 500; letter-spacing: -0.01em;
  color: var(--fg-strong); margin-left: 14px;
}

/* Nav items (workbenches + tools children) */
.sb-item {
  display: flex; align-items: center;
  height: 38px; padding: 0 14px; margin: 0 8px;
  border-radius: var(--radius-pill);
  background: transparent; border: 0; cursor: pointer;
  color: var(--fg-strong);
  font-size: 14px; font-weight: 400;
  transition: background var(--t-fast), color var(--t-fast);
  text-align: left;
}
.sb-item:hover               { background: var(--bg-hover); }
.sb-item.is-primary          { background: var(--bg-elev-2); font-weight: 500; }
.sb-item.is-primary:hover    { background: var(--bg-active); }
.sb-item.is-active           { background: var(--bg-active); font-weight: 500; }
.sb-item .ic-slot {
  width: 24px; height: 24px;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.sb-item .ic { color: var(--fg-muted); }
.sb-item.is-primary .ic, .sb-item.is-active .ic { color: var(--fg-strong); }
.sb-item .label {
  margin-left: 14px;
  white-space: nowrap; overflow: hidden;
}

/* Collapsed sidebar: items shrink to 40x40 button, label hidden */
.sidebar.is-collapsed .sb-item {
  padding: 0; margin: 0 12px;
  width: 40px; height: 40px;
  justify-content: center;
}
.sidebar.is-collapsed .sb-item .label { display: none; }

/* Section header (工具 / 最近) */
.sb-section {
  display: flex; align-items: center; justify-content: space-between;
  height: 32px;
  padding: 0 22px;
  margin-top: 14px;
  background: transparent; border: 0; cursor: pointer;
  position: relative;
}
.sb-section-label {
  font-size: 11px; color: var(--fg-faint); font-weight: 500;
  letter-spacing: 0.02em;
}
.sb-section-chev {
  color: var(--fg-faint);
  opacity: 0;
  transition: opacity var(--t-fast), transform var(--t-fast);
}
.sb-section.is-expanded .sb-section-chev { /* default down */ }
.sb-section .sb-section-chev.is-closed { transform: rotate(-90deg); }
.sb-section:hover .sb-section-chev { opacity: 1; }

/* Collapsed sidebar: section shows a short line instead of label */
.sb-section.is-collapsed-sb {
  justify-content: center; height: 24px;
  padding: 0; margin: 0 12px 0 12px; margin-top: 14px;
}
.sb-section-divider {
  display: block; width: 18px; height: 1px;
  background: var(--border-strong);
  transition: opacity var(--t-fast);
}
.sb-section.is-collapsed-sb:hover .sb-section-divider { opacity: 0; }
.sb-section.is-collapsed-sb .sb-section-chev {
  position: absolute; left: 50%; transform: translateX(-50%);
}

/* Recent chat list wrap (overflow scroll, expanded only) */
.sb-recent-wrap {
  flex: 1; min-height: 0; overflow-y: auto;
}
.sb-empty {
  padding: 12px 22px; font-size: 11px; color: var(--fg-faint); text-align: center;
}

/* Footer */
.sb-foot-spacer { flex: 1; }
.sb-foot {
  display: flex; align-items: center;
  height: 48px; padding: 0 14px;
  border-top: 1px solid var(--border-soft);
  margin-top: 6px;
  gap: 12px;
}
.sb-avatar-slot {
  position: relative;
  width: 28px; height: 28px;
  background: transparent; border: 0; padding: 0; cursor: pointer;
  flex-shrink: 0;
}
.sb-avatar {
  display: flex; align-items: center; justify-content: center;
  width: 28px; height: 28px; border-radius: 50%;
  background: linear-gradient(135deg, #FCD9B4, #F5A06A);
  color: #FFFFFF; font-size: 12px; font-weight: 500;
}
.sb-badge-dot {
  position: absolute; top: -1px; right: -1px;
  width: 8px; height: 8px; border-radius: 50%;
  background: var(--status-error);
  border: 1.5px solid var(--bg-window);
}
.sb-sse-dot {
  position: absolute; bottom: -1px; right: -1px;
  width: 7px; height: 7px; border-radius: 50%;
  border: 1.5px solid var(--bg-window);
}
.sb-user {
  flex: 1; min-width: 0;
  font-size: 13px; font-weight: 500;
  color: var(--fg-strong);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.sb-gear-btn {
  width: 24px; height: 24px;
  display: flex; align-items: center; justify-content: center;
  background: transparent; border: 0; padding: 0; cursor: pointer;
  color: var(--fg-muted); border-radius: 6px;
  opacity: 0; transition: opacity var(--t-fast), background var(--t-fast);
}
.sb-foot:hover .sb-gear-btn { opacity: 1; }
.sb-gear-btn:hover { background: var(--bg-hover); color: var(--fg-strong); }

/* Collapsed footer: gear stays accessible above avatar on hover */
.sidebar.is-collapsed .sb-foot {
  flex-direction: column-reverse;
  height: auto;
  padding: 8px 0 0;
  gap: 6px;
  justify-content: center;
  align-items: center;
}
.sidebar.is-collapsed .sb-user { display: none; }
```

- [ ] **Step 3: Smoke-build**

```bash
cd frontend && npm run build 2>&1 | tail -5
```
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/styles/components.css
git commit -m "style(frontend): sidebar 样式重写 — Gemini 留白 / 平行翻译 / footer 头像+齿轮"
git push origin main
```

---

## Task 12: NotificationsDrawer — add 待办 (Help) tab

**Files:**
- Modify: `frontend/src/components/overlays/NotificationsDrawer.jsx`

- [ ] **Step 1: Read the current drawer**

```bash
cd frontend && cat src/components/overlays/NotificationsDrawer.jsx | head -80
```

- [ ] **Step 2: Add a "待办" tab to the drawer**

Add a tab state (e.g., `const [tab, setTab] = useState("notifs")`). Render two pill buttons at the top — "待办" and "通知". Default tab is `notifs`; when there's an active `pendingAsk` (from `useUIStore`), default to `待办`. The 待办 tab renders the existing AskUserModal's pending-question list (read `pendingAsk` from store + button row to answer); the 通知 tab renders the existing notifications list.

Use this skeleton at the top of the drawer body:

```jsx
const [tab, setTab] = useState(pendingAsk ? "todo" : "notifs");

return (
  <div className="notif-drawer">
    <div className="notif-tabs">
      <button className={"notif-tab" + (tab === "todo" ? " is-active" : "")} onClick={() => setTab("todo")}>
        待办{pendingAsk ? " · 1" : ""}
      </button>
      <button className={"notif-tab" + (tab === "notifs" ? " is-active" : "")} onClick={() => setTab("notifs")}>
        通知
      </button>
    </div>
    {tab === "todo" ? <TodoTab /> : <NotifsTab />}
  </div>
);
```

For TodoTab, reuse the same content the AskUserModal renders (extract its question + answer-input as a sub-component, or inline-copy the JSX).

For NotifsTab,keep existing notification list rendering.

Add minimal CSS for `.notif-tabs / .notif-tab` in `components.css`(append at the end):

```css
.notif-tabs {
  display: flex; gap: 8px; padding: 12px 16px 8px;
  border-bottom: 1px solid var(--border-soft);
}
.notif-tab {
  font-size: 13px; padding: 6px 12px; border-radius: var(--radius-pill);
  background: transparent; border: 0; cursor: pointer; color: var(--fg-muted);
}
.notif-tab.is-active { background: var(--bg-active); color: var(--fg-strong); font-weight: 500; }
.notif-tab:hover     { background: var(--bg-hover); color: var(--fg-strong); }
```

- [ ] **Step 3: Build + smoke**

```bash
cd frontend && npm run build 2>&1 | tail -5
```
Expected: build succeeds.

- [ ] **Step 4: Manual verify (dev)**

```bash
cd frontend && npm run dev
```
Open the app, click footer avatar — both tabs render. Click between tabs.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/components/overlays/NotificationsDrawer.jsx frontend/src/styles/components.css
git commit -m "feat(frontend): NotificationsDrawer 加待办 tab — Help/Ask 与 Bell 通知合一"
git push origin main
```

---

## Task 13: SettingsPopover — displayName input

**Files:**
- Modify: `frontend/src/components/overlays/SettingsPopover.jsx`

- [ ] **Step 1: Find the popover content**

```bash
cd frontend && grep -n "SettingsPopover\|displayName\|appearance" src/components/overlays/SettingsPopover.jsx | head -10
```

- [ ] **Step 2: Add the displayName row**

Add to the top of the popover (or in the existing "Account" / "Appearance" sections — whichever makes sense based on the current structure):

```jsx
import { useDisplayName } from "../../hooks/useDisplayName.js";
// ...
const [displayName, setDisplayName] = useDisplayName();
// ...
<div className="settings-row">
  <label className="settings-label" htmlFor="settings-display-name">显示名</label>
  <input
    id="settings-display-name"
    className="settings-input"
    value={displayName}
    onChange={(e) => setDisplayName(e.target.value.slice(0, 24).trim())}
    placeholder="Weilin"
    autoComplete="off"
  />
</div>
```

If the popover doesn't have existing `.settings-row` / `.settings-input` classes, add minimal CSS to `components.css`:

```css
.settings-row   { display: flex; align-items: center; gap: 12px; padding: 8px 0; }
.settings-label { font-size: 12px; color: var(--fg-muted); width: 80px; flex-shrink: 0; }
.settings-input {
  flex: 1; height: 30px; padding: 0 10px;
  background: var(--bg-input); border: 1px solid var(--border);
  border-radius: var(--radius-sm); font-size: 13px; color: var(--fg-strong);
}
.settings-input:focus { outline: 2px solid var(--accent-ring); border-color: var(--accent); }
```

- [ ] **Step 3: Build**

```bash
cd frontend && npm run build 2>&1 | tail -5
```
Expected: succeeds.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/components/overlays/SettingsPopover.jsx frontend/src/styles/components.css
git commit -m "feat(frontend): SettingsPopover 加显示名编辑(写入 localStorage 即生效)"
git push origin main
```

---

## Task 14: WelcomeInput component

**Files:**
- Create: `frontend/src/panes/dashboard/WelcomeInput.jsx`
- Create: `frontend/src/panes/dashboard/WelcomeInput.test.jsx`

**Contract:**
- Pill-shaped input, placeholder `Ask Forgify… or forge something`
- Multiline supported (Shift+Enter); Enter submits
- Calls `onSubmit(text)` prop with the trimmed text
- Clears + blurs on submit (caller routes the user to chat pane)
- Disabled state while a submit is in-flight (caller sets via `isSubmitting`)

- [ ] **Step 1: Write the test**

Write `frontend/src/panes/dashboard/WelcomeInput.test.jsx`:

```jsx
import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { WelcomeInput } from "./WelcomeInput.jsx";

describe("WelcomeInput", () => {
  it("renders with placeholder", () => {
    render(<WelcomeInput onSubmit={() => {}} />);
    expect(screen.getByPlaceholderText("Ask Forgify… or forge something")).toBeInTheDocument();
  });

  it("calls onSubmit with text on Enter", () => {
    const fn = vi.fn();
    render(<WelcomeInput onSubmit={fn} />);
    const input = screen.getByPlaceholderText("Ask Forgify… or forge something");
    fireEvent.change(input, { target: { value: "hello" } });
    fireEvent.keyDown(input, { key: "Enter" });
    expect(fn).toHaveBeenCalledWith("hello");
  });

  it("does not submit on Shift+Enter (multi-line)", () => {
    const fn = vi.fn();
    render(<WelcomeInput onSubmit={fn} />);
    const input = screen.getByPlaceholderText("Ask Forgify… or forge something");
    fireEvent.change(input, { target: { value: "hello" } });
    fireEvent.keyDown(input, { key: "Enter", shiftKey: true });
    expect(fn).not.toHaveBeenCalled();
  });

  it("does not submit empty / whitespace-only", () => {
    const fn = vi.fn();
    render(<WelcomeInput onSubmit={fn} />);
    const input = screen.getByPlaceholderText("Ask Forgify… or forge something");
    fireEvent.change(input, { target: { value: "   " } });
    fireEvent.keyDown(input, { key: "Enter" });
    expect(fn).not.toHaveBeenCalled();
  });

  it("disables while isSubmitting", () => {
    render(<WelcomeInput onSubmit={() => {}} isSubmitting={true} />);
    expect(screen.getByPlaceholderText("Ask Forgify… or forge something")).toBeDisabled();
  });
});
```

- [ ] **Step 2: Run test (verify failure)**

```bash
cd frontend && npx vitest run src/panes/dashboard/WelcomeInput.test.jsx
```
Expected: FAIL — module not found.

- [ ] **Step 3: Implement**

Write `frontend/src/panes/dashboard/WelcomeInput.jsx`:

```jsx
// WelcomeInput — pill-shaped composer on the welcome page. Enter submits
// (Shift+Enter inserts newline). Empty / whitespace-only is no-op.
//
// WelcomeInput —— 欢迎页输入框;Enter 直接发(Shift+Enter 换行);空内容
// 不触发;parent 拿到 text 后串行新建对话 + 发首条消息。

import { useState } from "react";
import { Icon } from "../../components/primitives/Icon.jsx";

export function WelcomeInput({ onSubmit, isSubmitting = false }) {
  const [text, setText] = useState("");

  const submit = () => {
    const trimmed = text.trim();
    if (!trimmed) return;
    onSubmit(trimmed);
    setText("");
  };

  const onKeyDown = (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      submit();
    }
  };

  return (
    <div className="wel-input">
      <span className="wel-input-icon"><Icon.Plus size={18} strokeWidth={2} /></span>
      <textarea
        className="wel-input-area"
        placeholder="Ask Forgify… or forge something"
        value={text}
        onChange={(e) => setText(e.target.value)}
        onKeyDown={onKeyDown}
        disabled={isSubmitting}
        rows={1}
      />
      <button type="button" className="wel-input-send" onClick={submit} disabled={isSubmitting || !text.trim()}>
        <Icon.Send size={16} strokeWidth={2} />
      </button>
    </div>
  );
}
```

- [ ] **Step 4: Run test (verify pass)**

```bash
cd frontend && npx vitest run src/panes/dashboard/WelcomeInput.test.jsx
```
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/panes/dashboard/WelcomeInput.jsx frontend/src/panes/dashboard/WelcomeInput.test.jsx
git commit -m "feat(frontend): WelcomeInput — pill 输入框,Enter 提交,Shift+Enter 换行"
git push origin main
```

---

## Task 15: Dashboard.jsx — full rewrite

**Files:**
- Modify (rewrite): `frontend/src/panes/dashboard/Dashboard.jsx`
- Create: `frontend/src/panes/dashboard/Dashboard.test.jsx`

- [ ] **Step 1: Write the test**

Write `frontend/src/panes/dashboard/Dashboard.test.jsx`:

```jsx
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent, act } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Dashboard } from "./Dashboard.jsx";
import { useUIStore } from "../../store/ui.js";

const createMutateAsync = vi.fn().mockResolvedValue({ id: "cv_n" });

vi.mock("../../api/flowruns.js", () => ({
  useFlowRuns: () => ({ data: [] }),
}));
vi.mock("../../api/conversations.js", () => ({
  useConversations:       () => ({ data: [] }),
  useCreateConversation:  () => ({ mutateAsync: createMutateAsync }),
}));

function renderDash() {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={qc}>
      <Dashboard />
    </QueryClientProvider>
  );
}

beforeEach(() => {
  localStorage.clear();
  useUIStore.setState({ openPanes: [], activeConv: null });
  createMutateAsync.mockClear();
  global.fetch = vi.fn().mockResolvedValue({
    ok: true,
    json: async () => ({}),
  });
});

describe("Dashboard", () => {
  it("renders a non-empty greeting", () => {
    renderDash();
    const greet = document.querySelector(".wel-greet");
    expect(greet).toBeTruthy();
    expect(greet.textContent.trim().length).toBeGreaterThan(0);
  });

  it("renders the input with correct placeholder", () => {
    renderDash();
    expect(screen.getByPlaceholderText("Ask Forgify… or forge something")).toBeInTheDocument();
  });

  it("Enter creates conv, sends first message, switches to chat pane", async () => {
    renderDash();
    const input = screen.getByPlaceholderText("Ask Forgify… or forge something");
    fireEvent.change(input, { target: { value: "hello forge" } });
    await act(async () => {
      fireEvent.keyDown(input, { key: "Enter" });
      await Promise.resolve(); await Promise.resolve();
    });
    expect(createMutateAsync).toHaveBeenCalled();
    expect(global.fetch).toHaveBeenCalledWith(
      expect.stringContaining("/conversations/cv_n/messages"),
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({ text: "hello forge" }),
      })
    );
    expect(useUIStore.getState().openPanes).toContain("chat");
    expect(useUIStore.getState().activeConv).toBe("cv_n");
  });

  it("hides the context strip when there's nothing of interest", () => {
    renderDash();
    expect(document.querySelector(".wel-strip")).toBeNull();
  });
});
```

- [ ] **Step 2: Run test (verify failure)**

```bash
cd frontend && npx vitest run src/panes/dashboard/Dashboard.test.jsx
```
Expected: FAIL — current Dashboard.jsx still renders the old layout, so `.wel-greet` not found.

- [ ] **Step 3: Rewrite Dashboard.jsx**

Replace `frontend/src/panes/dashboard/Dashboard.jsx` with:

```jsx
// Dashboard — Gemini-style welcome page. Single centered greeting + pill
// input + optional smart context strip. Enter submits the first message
// (creates conv → sends → switches to chat pane).
//
// Dashboard —— Gemini-style 欢迎页。居中问候 + pill 输入 + 可选智能条;
// Enter 串行新建 conv + 发首条消息 + 切到 chat pane。

import { useState } from "react";
import { Icon } from "../../components/primitives/Icon.jsx";
import { RelTime } from "../../components/shared/RelTime.jsx";
import { useUIStore } from "../../store/ui.js";
import { useConversations, useCreateConversation } from "../../api/conversations.js";
import { useDisplayName } from "../../hooks/useDisplayName.js";
import { WelcomeInput } from "./WelcomeInput.jsx";
import { useGreeting } from "./useGreeting.js";
import { useContextStrip } from "./useContextStrip.js";

function ContextStrip({ strip, onJump }) {
  if (!strip) return null;
  if (strip.kind === "waiting") {
    return (
      <div className="wel-strip">
        <span className="wel-strip-dot" style={{ background: "var(--status-warn)" }} />
        <span><strong>{strip.payload.count} 个流程等你确认</strong> · <button className="wel-strip-link" onClick={() => onJump("execute")}>{strip.payload.flowName}</button></span>
      </div>
    );
  }
  if (strip.kind === "failed") {
    return (
      <div className="wel-strip">
        <span className="wel-strip-dot" style={{ background: "var(--status-error)" }} />
        <span><strong>{strip.payload.count} 个流程卡住了</strong> · <button className="wel-strip-link" onClick={() => onJump("execute")}>查看</button></span>
      </div>
    );
  }
  if (strip.kind === "running") {
    return (
      <div className="wel-strip">
        <span className="wel-strip-dot" style={{ background: "var(--status-info)" }} />
        <span><strong>{strip.payload.count} 个流程在跑</strong> · 最近一次 <RelTime ts={strip.payload.latestStartedAt} /> 启动</span>
      </div>
    );
  }
  if (strip.kind === "recent") {
    return (
      <div className="wel-strip">
        <span className="wel-strip-dot" style={{ background: "var(--fg-faint)" }} />
        <span>继续 · <button className="wel-strip-link" onClick={() => onJump("chat", strip.payload.convId)}>{strip.payload.convTitle}</button> · <RelTime ts={strip.payload.updatedAt} /></span>
      </div>
    );
  }
  return null;
}

export function Dashboard() {
  const openPane      = useUIStore((s) => s.openPane);
  const setActiveConv = useUIStore((s) => s.setActiveConv);

  const { data: conversations = [] } = useConversations();
  const [displayName] = useDisplayName();
  const create  = useCreateConversation();

  const hasRecentConv = conversations.some(
    (c) => c.updatedAt && Date.now() - new Date(c.updatedAt).getTime() < 24 * 60 * 60 * 1000
  );
  const greeting = useGreeting({ hasRecentConv, displayName });
  const strip = useContextStrip();

  const [submitting, setSubmitting] = useState(false);

  const onSubmit = async (text) => {
    setSubmitting(true);
    try {
      const created = await create.mutateAsync({});
      if (created?.id) {
        setActiveConv(created.id);
        openPane("chat");
        await sendMessageDirect(created.id, text);
      }
    } finally {
      setSubmitting(false);
    }
  };

  const onJump = (pane, convId) => {
    if (convId) setActiveConv(convId);
    openPane(pane);
  };

  return (
    <div className="wel">
      <div className="wel-greet">{greeting}</div>
      <WelcomeInput onSubmit={onSubmit} isSubmitting={submitting} />
      <ContextStrip strip={strip} onJump={onJump} />
    </div>
  );
}

// Direct call helper. useSendMessage ties convId at hook-call time; we don't
// have the new id until mid-onSubmit, so we POST directly. ChatPane will
// re-fetch ["conversation", convId, "messages"] when it mounts.
async function sendMessageDirect(convId, text) {
  const res = await fetch(`/api/v1/conversations/${convId}/messages`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text }),
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body?.error?.message || res.statusText);
  }
}
```

**Note:** If the project has a baseUrl-aware fetch wrapper, use it instead of raw `fetch`. Grep for `apiBase` or similar in `frontend/src/api/`. The hand-written `fetch` here works in dev because Vite proxies `/api/v1/` to the backend.

- [ ] **Step 4: Run test (verify pass)**

```bash
cd frontend && npx vitest run src/panes/dashboard/Dashboard.test.jsx
```
Expected: PASS, 4 tests (the test in Step 1 already mocks `global.fetch` and asserts the POST URL/body).

- [ ] **Step 5: Commit**

```bash
git add frontend/src/panes/dashboard/Dashboard.jsx frontend/src/panes/dashboard/Dashboard.test.jsx
git commit -m "feat(frontend): Dashboard 重写 — Gemini-style 居中问候 + WelcomeInput + 智能上下文条"
git push origin main
```

---

## Task 16: components.css — dashboard styles rewrite

**Files:**
- Modify: `frontend/src/styles/components.css`(replace `.dash` / `.dash-*` sections; lines ~3857-4000)

- [ ] **Step 1: Find the existing block to replace**

```bash
grep -n "^\.dash" /Users/SP14921/Documents/Personal/PersonalCodeBase/Forgify/frontend/src/styles/components.css | head -10
```

Identify the contiguous range.

- [ ] **Step 2: Replace `.dash-*` styles with `.wel-*` block**

Delete all selectors starting with `.dash` and replace with:

```css
/* ============================================================================
   Welcome page (Dashboard) — Gemini-style centered greeting + input + strip
   ============================================================================ */

.wel {
  display: flex; flex-direction: column;
  align-items: center; justify-content: center;
  gap: 36px;
  min-height: 100%;
  padding: 80px 40px 60px;
  background: var(--bg-window);
}

.wel-greet {
  font-size: 42px;
  font-weight: 500;
  letter-spacing: -0.025em;
  line-height: 1.1;
  text-align: center;
  color: var(--fg-strong);
  animation: rise var(--t-rise) forwards;
}

.wel-input {
  width: 560px; max-width: 90%;
  min-height: 58px;
  border-radius: var(--radius-pill);
  border: 1px solid var(--border);
  background: var(--bg-paper);
  box-shadow: var(--shadow-sm), 0 4px 14px rgba(0,0,0,0.04);
  display: flex; align-items: center;
  padding: 8px 22px;
  gap: 12px;
  animation: rise var(--t-rise) 120ms backwards;
}
.wel-input-icon {
  display: flex; align-items: center; justify-content: center;
  width: 28px; height: 28px; border-radius: 50%;
  color: var(--fg-muted);
  flex-shrink: 0;
}
.wel-input-area {
  flex: 1;
  min-height: 24px; max-height: 200px;
  background: transparent; border: 0; outline: 0;
  resize: none;
  font-family: var(--font-sans);
  font-size: 15px;
  color: var(--fg-strong);
  line-height: 1.5;
}
.wel-input-area::placeholder { color: var(--fg-faint); }
.wel-input-area:disabled { opacity: 0.5; cursor: not-allowed; }
.wel-input-send {
  width: 36px; height: 36px; border-radius: 50%;
  background: var(--bg-elev-2); color: var(--fg-muted);
  border: 0; cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  transition: background var(--t-fast), color var(--t-fast);
  flex-shrink: 0;
}
.wel-input-send:hover:not(:disabled) { background: var(--accent); color: var(--accent-fg); }
.wel-input-send:disabled { opacity: 0.4; cursor: not-allowed; }

.wel-strip {
  display: flex; align-items: center; gap: 12px;
  font-size: 13px; color: var(--fg-muted);
  animation: rise var(--t-rise) 240ms backwards;
}
.wel-strip strong { color: var(--fg-strong); font-weight: 500; }
.wel-strip-dot {
  width: 6px; height: 6px; border-radius: 50%;
  flex-shrink: 0;
}
.wel-strip-link {
  background: transparent; border: 0;
  color: var(--fg-strong); cursor: pointer;
  border-bottom: 1px solid var(--border-strong);
  padding: 0 0 1px; font-size: 13px;
  transition: border-color var(--t-fast);
}
.wel-strip-link:hover { border-color: var(--accent); }
```

- [ ] **Step 3: Smoke-build**

```bash
cd frontend && npm run build 2>&1 | tail -5
```
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/styles/components.css
git commit -m "style(frontend): dashboard 样式重写 — Gemini-style 留白 + pill 输入框 + 智能条"
git push origin main
```

---

## Task 17: PRD §8 + §16 updates

**Files:**
- Modify: `documents/version-1.2/frontend-prd.md`

- [ ] **Step 1: Update §8.2 Sidebar structure**

Replace §8.2 sidebar tree diagram with the new layout. Find lines 599-660ish ("8.2 Sidebar"). Update the ASCII tree to reflect:

```
.sidebar
├── sb-head (logo-slot hover→toggle, name)
├── 新对话 (primary)
├── 搜索 或 跳转
├── 对话
├── 工坊
├── 执行
├── 文档
├── SidebarSection "工具" (collapsible)
│   ├── 洞察
│   ├── Skills
│   ├── MCP
│   └── Memory
├── SidebarSection "最近" (collapsible, expanded-only)
│   └── ChatListItem*
└── sb-foot (avatar+badge, name, hover→gear)
```

Also update the Sidebar collapse note:
- Width 260 ↔ 64, Framer Motion spring
- Logo morph (hover) replaces explicit toggle button
- 工具 / 最近 段折叠状态分别持久化(localStorage `sidebar.toolsExpanded` / `sidebar.recentExpanded`)
- 收起态:label 隐藏 / 工具段标题降级为短线 / 最近段整体隐藏 / footer 头像+齿轮垂直叠

- [ ] **Step 2: Add 4 new entries to §16(已知 Boilerplate Bug)**

Find the §16 table (line 1417ish). Add at the bottom of the table:

```
| Sidebar icon 视觉重量不齐 + 行内未对齐(锤子 14px stroke 1.7 视觉过粗) | 影响所有 nav 行视觉一致性,且 .nav-item .icon 没把 SVG 居中槽 | 重写 Sidebar 用 24×24 居中槽 + Lucide outline 18px stroke 2;所有 icon 改通过 size/strokeWidth prop override 走 wrap()。已修。 |
| Dashboard 重 KPI + 双 section 违 DESIGN.md "克制" | 4 卡 + 2 section 让欢迎页"满",白色优先与大留白原则失守 | Dashboard 改成 Gemini-style:居中大问候 + pill 输入框 + 可选智能条;KPI 全删,继续对话列表挪入 sidebar "最近"段。已修。 |
| Sidebar 头像区 "本地" / "SSE" 字样无意义 | 单用户本地 app 无需 SSE 文案;"本地" 不是用户名 | footer 改成头像(首字母,取 displayName)+ 真实名字 + 通知红 dot + hover ⚙ 设置;displayName 走 localStorage,Settings 可改。已修。 |
| Sidebar nav 锻造 一词不传神 | 名字偏向"工序",不如"工坊"指向"地点+人" | UI label `锻造` → `工坊`;内部代码 / API / DB / contract / pane key 全保留 `forge`。已修。 |
```

- [ ] **Step 3: Update §15 phase tracking**

If §15 has phase tracking checkboxes, find the "Phase 6"(or current frontend phase)entry and mark "Welcome + Sidebar Gemini-style 重做" as 已完成。如果没对应行,append:

```
- [x] Welcome 页 + Sidebar Gemini-style 重做(2026-05-25)
  - greeting 池 360 / WelcomeInput / 智能上下文条 / 平行翻译收起 / 工具段折叠 / footer 头像+齿轮
```

- [ ] **Step 4: Commit**

```bash
git add documents/version-1.2/frontend-prd.md
git commit -m "docs(frontend): PRD §8 / §16 / §15 同步 Gemini-style 重做"
git push origin main
```

---

## Task 18: DESIGN.md — 问候语调性 §10

**Files:**
- Modify: `DESIGN.md`

- [ ] **Step 1: Append §10 to DESIGN.md**

Append after §9 (or at the end of file):

```markdown

---

## 十、问候语调性(Voice for Greetings)

欢迎页问候语是品牌触点,每次进首屏都见。调性原则:

- **语言:** 英文 only。中文与硅谷腔不搭。
- **腔调:** 硅谷腔 — 自信、克制、惜字如金。像一个有把握的工程师拍你肩说一句话。
- **禁:** 感叹号、表情、营销词("超级"/"极致"/"颠覆")、励志金句、咖啡 emoji。
- **可用:** 锻造/锤/铁/火/锚的隐喻;时间感(早 / 深夜);AI 自我引述("I'm all ears.");留 30% 中性/温柔避免硬核疲劳。
- **个性化:** 含 `{name}` 占位的句子用 displayName 替换;displayName 空时,池里 name-bearing 句不参与抽签。

参考池:`frontend/src/panes/dashboard/greetings.js`(360 句,15 类标签 A-O)。

新增/修改问候语规则:
- 添加前 grep 池子防重复:`grep -F "Your phrase" frontend/src/panes/dashboard/greetings.js`
- 加 tag 至少一个;含 `{name}` 必带 M tag
- ≤ 50 字符。超过容易在 input 框上方溢出。
```

- [ ] **Step 2: Commit**

```bash
git add DESIGN.md
git commit -m "docs: DESIGN.md §10 问候语调性 — 硅谷腔英文 + {name} 占位规约"
git push origin main
```

---

## Task 19: progress-record.md dev log

**Files:**
- Modify: `documents/version-1.2/progress-record.md`

- [ ] **Step 1: Append dev log entries**

At the top (or bottom — match existing project convention by checking the first line),add a new entry:

```markdown
### 2026-05-25 · Welcome + Sidebar Gemini-style 重做

落地 18 个任务,涵盖前端 P0(infra)→ P1(sidebar)→ P2(dashboard)→ P3(doc 同步)四阶。

主改动:
- 新 6 文件:greetings.js(360 句池)、useGreeting / useContextStrip / useDisplayName 三 hook、WelcomeInput、SidebarSection
- 重写 Sidebar.jsx(从 234 行 → ~170,布局结构清晰化)、Dashboard.jsx(KPI/双 section 全删,Gemini-empty)
- ui.js 加 toolsExpanded / recentExpanded / displayName 三状态 + localStorage persist
- Icon.jsx 加 5 个 lucide icon(SquarePen / BarChart3 / Plug / PanelLeftClose / PanelLeftOpen)
- components.css 重写 sidebar 段 + dash 段(削减 ~150 行无用 KPI 样式)
- NotificationsDrawer 加待办 tab(吸收 Help/Ask 入口),SettingsPopover 加 displayName input
- UI label 锻造 → 工坊(内部代码 / API / DB 保留 forge identifier)
- PRD §8 sidebar 结构图重画;§16 加 4 条"已修";§15 标 phase 完成
- DESIGN.md 加 §10 问候语调性(硅谷腔英文 + {name} 占位)
- 测试:25 单测新增(greetings / useGreeting / useContextStrip / useDisplayName / SidebarSection / WelcomeInput / Sidebar rewrite / Dashboard new)

测试基线:`cd frontend && npm test` 全绿;`npm run build` 无 warning。
```

- [ ] **Step 2: Commit**

```bash
git add documents/version-1.2/progress-record.md
git commit -m "docs: progress-record 加 2026-05-25 welcome+sidebar redesign dev log"
git push origin main
```

---

## Task 20: Final verification

**Files:** (none — manual)

- [ ] **Step 1: Run full test suite**

```bash
cd frontend && npm test 2>&1 | tail -30
```
Expected: all green. Note pass count baseline.

- [ ] **Step 2: Build**

```bash
cd frontend && npm run build 2>&1 | tail -10
```
Expected: no errors, no warnings about missing icons.

- [ ] **Step 3: Manual smoke in dev server**

```bash
cd frontend && npm run dev
```

Open the app and verify:
1. Welcome page: greeting renders (some non-empty string), pill input + placeholder visible
2. Type "hello" + Enter → switches to chat pane, conv appears in sidebar "最近"
3. Sidebar collapse: hover top logo → morphs to PanelLeftClose; click → animates to 64px; click again from PanelLeftOpen → expands
4. In collapsed state: workbench icons (对话/工坊/执行/文档/洞察/Skills/MCP/Memory) stay visible at the SAME y position as expanded state. Tools section "短线"显示 in place of "工具" label.
5. Hover "工具" / "最近" labels → ▾ chevron fades in. Click → section collapses, items removed. Reload page → state persisted.
6. Footer: avatar shows first letter of displayName (set via Settings)。Hover footer → ⚙ slides in。Click avatar → NotificationsDrawer opens with 待办 + 通知 tabs.
7. Edit displayName in Settings → footer name updates immediately;欢迎页 greeting refresh(reload)显示新名占位替换。

If any of 1-7 fails, fix that task's commit before proceeding.

- [ ] **Step 4: Final commit (if any fix-ups)**

If small fixes were needed during manual verify, commit them as separate `fix(frontend): ...` commits and push.

---

## Self-review checklist (run before finishing)

- [ ] Every task has Files / Steps / commit included
- [ ] No TBD / placeholder / "implement above" — all code blocks complete
- [ ] Task 3 (greetings.js) has all 360 entries (count: ≥ 360)
- [ ] Sidebar.jsx + Dashboard.jsx code blocks compile in isolation (imports correct)
- [ ] Test mocks (useFlowRuns / useConversations / useSSEHealth) match the production hook shape
- [ ] localStorage keys consistent across tasks: `sidebar.collapsed`, `sidebar.toolsExpanded`, `sidebar.recentExpanded`, `forgify.user.displayName`
- [ ] forge → 工坊 only in UI labels, not in identifiers / pane keys / API
- [ ] PRD §16 entries link to actual modules / classes
- [ ] DESIGN.md §10 references the actual greetings.js path
