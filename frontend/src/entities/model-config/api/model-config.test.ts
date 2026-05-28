// entities/model-config api — all hooks: useProviders, useModelConfigs,
// useUpsertModelConfig.

import { beforeEach, describe, expect, it } from "vitest";
import { waitFor } from "@testing-library/react";
import { setupFetchSpy, renderQuery, renderMutation, type FetchCall } from "../../../shared/api/_testHarness";
import {
  useProviders,
  useModelConfigs,
  useUpsertModelConfig,
} from "./model-config.js";

let calls: FetchCall[];
beforeEach(async () => {
  calls = setupFetchSpy();
  const bridge = await import("../../../shared/bridge/wails.js");
  await bridge.initBaseUrl();
});

describe("model-config query hooks", () => {
  it("useProviders_fetchesProvidersList", async () => {
    const { result } = await renderQuery(useProviders);
    expect(calls[0].url).toContain("/providers");
    expect(result.current.isSuccess).toBe(true);
  });

  it("useModelConfigs_fetchesModelConfigsList", async () => {
    const { result } = await renderQuery(useModelConfigs);
    expect(calls[0].url).toContain("/model-configs");
    expect(result.current.isSuccess).toBe(true);
  });
});

describe("useUpsertModelConfig mutation", () => {
  it("putsToCorrectScenarioEndpoint", async () => {
    const { result } = await renderMutation(useUpsertModelConfig);
    result.current.mutate({ scenario: "dialogue", apiKeyId: "aki_x", modelId: "deepseek-chat" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/model-configs/dialogue", method: "PUT" });
  });
});
