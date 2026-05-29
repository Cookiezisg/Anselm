// entities/model-config capability hooks + capabilityFor utility.

import { beforeEach, describe, expect, it } from "vitest";
import { waitFor } from "@testing-library/react";
import { setupFetchSpy, renderQuery, renderMutation, type FetchCall } from "../../../shared/api/_testHarness";
import {
  useModelCapabilities,
  useSetModelCapabilityOverride,
  useClearModelCapabilityOverride,
} from "./model-config.js";
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
  thinkingShape: "budget",
  effortValues: [],
  budgetMin: 1024,
  budgetMax: 32000,
  contextWindow: 200000,
  maxOutput: 16000,
  contextMode: "full",
};

describe("useModelCapabilities query", () => {
  it("useModelCapabilities_fetchesCapabilitiesList", async () => {
    const { result } = await renderQuery(useModelCapabilities);
    expect(calls[0].url).toContain("/model-capabilities");
    expect(calls[0].method).toBe("GET");
    expect(result.current.isSuccess).toBe(true);
  });
});

describe("useSetModelCapabilityOverride mutation", () => {
  it("putsToCorrectProviderModelPath", async () => {
    const { result } = await renderMutation(useSetModelCapabilityOverride);
    result.current.mutate({
      provider: "anthropic",
      modelId: "claude-sonnet-4-5",
      thinkingShape: "budget",
    });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({
      url: "/api/v1/model-capabilities/anthropic/claude-sonnet-4-5",
      method: "PUT",
    });
  });

  it("encodesModelIdWithSlash", async () => {
    const { result } = await renderMutation(useSetModelCapabilityOverride);
    result.current.mutate({ provider: "openai", modelId: "gpt-4o/mini" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0].url).toContain(encodeURIComponent("gpt-4o/mini"));
  });
});

describe("useClearModelCapabilityOverride mutation", () => {
  it("deletesToCorrectProviderModelPath", async () => {
    const { result } = await renderMutation(useClearModelCapabilityOverride);
    result.current.mutate({ provider: "anthropic", modelId: "claude-sonnet-4-5" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({
      url: "/api/v1/model-capabilities/anthropic/claude-sonnet-4-5",
      method: "DELETE",
    });
  });
});

describe("capabilityFor", () => {
  const caps: ModelCapability[] = [
    fakeCap,
    { ...fakeCap, provider: "openai", modelId: "gpt-4o", thinkingShape: "none" },
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
