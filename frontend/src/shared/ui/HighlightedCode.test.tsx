// HighlightedCode — language dispatch rules.
//
// Historical bug: lowlight.highlightAuto runs over ~37 languages and was
// firing on every SSE delta during streaming, locking the tab. Streaming
// + no lang must NOT call highlightAuto. The tests below spy on the
// lowlight instance to assert this.

import { describe, expect, it, vi } from "vitest";
import { render } from "@testing-library/react";
import { HighlightedCode } from "./HighlightedCode.tsx";
import { lowlight } from "../lib/highlight/index.js";

describe("HighlightedCode", () => {
  it("HighlightedCode_explicitLang_callsSingleLanguageHighlight", () => {
    const spy = vi.spyOn(lowlight, "highlight");
    render(<HighlightedCode source="print(1)" lang="python" />);
    expect(spy).toHaveBeenCalledWith("python", "print(1)");
    spy.mockRestore();
  });

  it("HighlightedCode_streamingNoLang_skipsAutodetect", () => {
    const spy = vi.spyOn(lowlight, "highlightAuto");
    render(<HighlightedCode source="some code" streaming={true} />);
    expect(spy).not.toHaveBeenCalled();
    spy.mockRestore();
  });

  it("HighlightedCode_completedNoLang_runsAutodetectOnce", () => {
    const spy = vi.spyOn(lowlight, "highlightAuto");
    render(<HighlightedCode source="function foo() {}" streaming={false} />);
    expect(spy).toHaveBeenCalledTimes(1);
    spy.mockRestore();
  });

  it("HighlightedCode_streamingWithExplicitLang_stillHighlights", () => {
    const spy = vi.spyOn(lowlight, "highlight");
    render(<HighlightedCode source="x = 1" lang="python" streaming={true} />);
    expect(spy).toHaveBeenCalledWith("python", "x = 1");
    spy.mockRestore();
  });

  it("HighlightedCode_unregisteredLangNoStream_fallsToAutodetect", () => {
    const auto = vi.spyOn(lowlight, "highlightAuto");
    render(<HighlightedCode source="x" lang="zzz-not-a-real-lang" />);
    expect(auto).toHaveBeenCalled();
    auto.mockRestore();
  });

  it("HighlightedCode_emptySource_rendersNothingDoesNotCallLowlight", () => {
    const auto = vi.spyOn(lowlight, "highlightAuto");
    const sing = vi.spyOn(lowlight, "highlight");
    const { container } = render(<HighlightedCode source="" lang="python" />);
    expect(auto).not.toHaveBeenCalled();
    expect(sing).not.toHaveBeenCalled();
    expect(container.textContent).toBe("");
    auto.mockRestore();
    sing.mockRestore();
  });

  it("HighlightedCode_throwsInHighlight_fallsBackToRawSource", () => {
    const spy = vi.spyOn(lowlight, "highlight").mockImplementation(() => { throw new Error("boom"); });
    const { container } = render(<HighlightedCode source="raw code" lang="python" />);
    expect(container.textContent).toBe("raw code");
    spy.mockRestore();
  });

  it("HighlightedCode_isMemoed_stableSourceSkipsRehighlight", () => {
    const spy = vi.spyOn(lowlight, "highlight");
    const { rerender } = render(<HighlightedCode source="x = 1" lang="python" />);
    const callsAfterFirst = spy.mock.calls.length;
    // Same props → memo should skip; lowlight.highlight must not be called again.
    rerender(<HighlightedCode source="x = 1" lang="python" />);
    expect(spy.mock.calls.length).toBe(callsAfterFirst);
    spy.mockRestore();
  });

  it("HighlightedCode_sourceChanges_rehighlights", () => {
    const spy = vi.spyOn(lowlight, "highlight");
    const { rerender } = render(<HighlightedCode source="x = 1" lang="python" />);
    const calls1 = spy.mock.calls.length;
    rerender(<HighlightedCode source="x = 2" lang="python" />);
    expect(spy.mock.calls.length).toBe(calls1 + 1);
    spy.mockRestore();
  });
});
