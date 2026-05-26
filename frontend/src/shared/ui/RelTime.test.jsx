// RelTime — relative time format thresholds + absolute tooltip.

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { render } from "@testing-library/react";
import { RelTime } from "./RelTime.jsx";

const NOW = new Date("2026-05-24T12:00:00Z");

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(NOW);
});

afterEach(() => vi.useRealTimers());

describe("RelTime", () => {
  it("ageUnder5s_showsJustNow", () => {
    const ts = new Date(NOW.getTime() - 2000);
    const { container } = render(<RelTime ts={ts} />);
    expect(container.textContent).toBe("刚刚");
  });

  it("ageUnder1m_showsSeconds", () => {
    const ts = new Date(NOW.getTime() - 30_000);
    const { container } = render(<RelTime ts={ts} />);
    expect(container.textContent).toBe("30 秒前");
  });

  it("ageUnder1h_showsMinutes", () => {
    const ts = new Date(NOW.getTime() - 5 * 60_000);
    const { container } = render(<RelTime ts={ts} />);
    expect(container.textContent).toBe("5 分钟前");
  });

  it("ageUnder1d_showsHours", () => {
    const ts = new Date(NOW.getTime() - 3 * 3600_000);
    const { container } = render(<RelTime ts={ts} />);
    expect(container.textContent).toBe("3 小时前");
  });

  it("ageUnder30d_showsDays", () => {
    const ts = new Date(NOW.getTime() - 5 * 86400_000);
    const { container } = render(<RelTime ts={ts} />);
    expect(container.textContent).toBe("5 天前");
  });

  it("ageOver30d_fallsBackToCalendarDate", () => {
    const ts = new Date(NOW.getTime() - 60 * 86400_000);
    const { container } = render(<RelTime ts={ts} />);
    expect(container.textContent).not.toContain("前");
  });

  it("tsNullOrInvalid_rendersNothing", () => {
    expect(render(<RelTime ts={null} />).container.textContent).toBe("");
    expect(render(<RelTime ts="not-a-date" />).container.textContent).toBe("");
  });

  it("prefixProp_prependsToOutput", () => {
    const ts = new Date(NOW.getTime() - 2000);
    const { container } = render(<RelTime ts={ts} prefix="开始: " />);
    expect(container.textContent).toBe("开始: 刚刚");
  });

  it("acceptsNumericMsTimestamp", () => {
    const { container } = render(<RelTime ts={NOW.getTime() - 2000} />);
    expect(container.textContent).toBe("刚刚");
  });

  it("absoluteTimeInTitleAttribute", () => {
    const ts = new Date(NOW.getTime() - 2000);
    const { container } = render(<RelTime ts={ts} />);
    expect(container.querySelector("time").title).toMatch(/2026/);
  });
});
