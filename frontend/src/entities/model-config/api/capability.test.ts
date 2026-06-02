// entities/model-config capability hooks + capabilityFor utility.

import { beforeEach, describe, expect, it } from "vitest";
import { setupFetchSpy, renderQuery, type FetchCall } from "../../../shared/api/_testHarness";
import { useModelCapabilities } from "./model-config.js";
import { capabilityFor } from "../model/capability.js";
import type { ModelCapability } from "../model/types.js";

let calls: FetchCall[];
beforeEach(async () => {
  calls = setupFetchSpy();
  const bridge = await import("../../../shared/bridge/wails.js");
  await bridge.initBaseUrl();
});

const fakeCap: ModelCapability = {
  provider: "anthropic",
  modelId: "claude-sonnet-4-5",
  displayName: "Claude Sonnet 4.5",
  contextWindow: 200000,
  maxOutput: 16000,
  options: [
    {
      key: "thinking",
      label: "Thinking",
      control: "segmented",
      values: [
        { value: "off", label: "Off" },
        { value: "on", label: "On" },
      ],
      defaultValue: "off",
    },
  ],
};

describe("useModelCapabilities query", () => {
  it("useModelCapabilities_fetchesCapabilitiesList", async () => {
    const { result } = await renderQuery(useModelCapabilities);
    expect(calls[0].url).toContain("/model-capabilities");
    expect(calls[0].method).toBe("GET");
    expect(result.current.isSuccess).toBe(true);
  });
});

describe("capabilityFor", () => {
  const caps: ModelCapability[] = [
    fakeCap,
    { ...fakeCap, provider: "openai", modelId: "gpt-4o", displayName: "GPT-4o", options: [] },
  ];

  it("returnsMatchingCap", () => {
    expect(capabilityFor(caps, "anthropic", "claude-sonnet-4-5")).toBe(fakeCap);
  });

  it("returnsUndefinedWhenProviderMissing", () => {
    expect(capabilityFor(caps, "deepseek", "claude-sonnet-4-5")).toBeUndefined();
  });

  it("returnsUndefinedWhenModelIdMissing", () => {
    expect(capabilityFor(caps, "anthropic", "claude-opus-4")).toBeUndefined();
  });

  it("doesNotPartialMatchModelId", () => {
    expect(capabilityFor(caps, "openai", "gpt-4")).toBeUndefined();
  });
});
