import { useState, useEffect, useMemo } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { getJSON, putJSON } from "@/api/devClient";
import { qk } from "@/hooks/queryKeys";
import { EmptyView } from "@/ui";
import type { ModelConfig, Scenario } from "@frontend/entities/model-config/model/types";
import type { ApiKey } from "@frontend/entities/apikey/model/types";

interface RowState {
  apiKeyId: string;
  modelId: string;
}

// 3-set closed whitelist mirrored from backend domain/model.ScenarioDialogue/Utility/Agent.
// hardcoded here (debug console) since /scenarios just echoes the same set.
const SCENARIOS: Scenario[] = ["dialogue", "utility", "agent"];

export function ModelConfigs() {
  const qc = useQueryClient();
  const [edits, setEdits] = useState<Record<Scenario, RowState>>({} as Record<Scenario, RowState>);

  const configs = useQuery<ModelConfig[]>({
    queryKey: qk.modelConfigs(),
    queryFn: () => getJSON<ModelConfig[]>("/api/v1/model-configs"),
  });
  const apiKeys = useQuery<ApiKey[]>({
    queryKey: qk.apikeys(),
    queryFn: () => getJSON<ApiKey[]>("/api/v1/api-keys"),
  });

  useEffect(() => {
    if (!configs.data) return;
    const init = {} as Record<Scenario, RowState>;
    for (const c of configs.data) {
      init[c.scenario] = { apiKeyId: c.apiKeyId, modelId: c.modelId };
    }
    setEdits(init);
  }, [configs.data]);

  const save = useMutation({
    mutationFn: ({ scenario, body }: { scenario: Scenario; body: RowState }) =>
      putJSON(`/api/v1/model-configs/${scenario}`, body),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.modelConfigs() }),
  });

  // Options: a flat list of (apiKey, modelId) pairs, rendered as <optgroup>
  // by apiKey for legibility. Each leaf option encodes "<apiKeyId>::<modelId>"
  // since native <select> can't carry two values per option.
  const keyOptions = useMemo(() => {
    return (apiKeys.data ?? []).map((k) => ({
      key: k,
      models: k.modelsFound && k.modelsFound.length > 0 ? k.modelsFound : [""],
    }));
  }, [apiKeys.data]);

  const keyById = useMemo(() => {
    const m = new Map<string, ApiKey>();
    for (const k of apiKeys.data ?? []) m.set(k.id, k);
    return m;
  }, [apiKeys.data]);

  if (configs.isLoading || apiKeys.isLoading) return <EmptyView>loading…</EmptyView>;
  if (configs.isError) return <EmptyView>error loading model configs</EmptyView>;
  if (apiKeys.isError) return <EmptyView>error loading api keys</EmptyView>;

  const noKeys = (apiKeys.data ?? []).length === 0;

  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%", overflow: "hidden" }}>
      <div style={{ padding: "8px 12px", borderBottom: "1px solid var(--border)" }}>
        <strong style={{ fontSize: 13 }}>Model Configs</strong>
        <span className="muted" style={{ marginLeft: 8, fontSize: 11 }}>{SCENARIOS.length} scenarios</span>
      </div>
      <div style={{ flex: 1, overflow: "auto" }}>
        {noKeys && <EmptyView>no api keys — add one in API Keys tab first</EmptyView>}
        <table className="dt" style={{ width: "100%" }}>
          <thead>
            <tr>
              <th>Scenario</th>
              <th>API Key · Model</th>
              <th>Current</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {SCENARIOS.map((scenario) => {
              const row = edits[scenario] ?? { apiKeyId: "", modelId: "" };
              const selected = row.apiKeyId && row.modelId ? `${row.apiKeyId}::${row.modelId}` : "";
              const currentKey = row.apiKeyId ? keyById.get(row.apiKeyId) : undefined;
              const currentLabel = currentKey && row.modelId
                ? `${currentKey.displayName || currentKey.provider} · ${currentKey.provider} · ${row.modelId}`
                : "—";
              return (
                <tr key={scenario}>
                  <td style={{ fontFamily: "var(--mono)", fontSize: 12 }}>{scenario}</td>
                  <td>
                    <select
                      value={selected}
                      onChange={(e) => {
                        const v = e.target.value;
                        if (!v) {
                          setEdits((s) => ({ ...s, [scenario]: { apiKeyId: "", modelId: "" } }));
                          return;
                        }
                        const [apiKeyId, modelId] = v.split("::");
                        setEdits((s) => ({ ...s, [scenario]: { apiKeyId, modelId } }));
                      }}
                      style={{ padding: "3px 6px", fontSize: 12, border: "1px solid var(--border)", borderRadius: 3, background: "var(--bg-paper)", minWidth: 280 }}
                      disabled={noKeys}
                    >
                      <option value="">— none —</option>
                      {keyOptions.map(({ key, models }) => (
                        <optgroup
                          key={key.id}
                          label={`${key.displayName || key.provider} (${key.provider})`}
                        >
                          {models.map((m) => (
                            <option key={`${key.id}::${m}`} value={`${key.id}::${m}`}>
                              {m || "(no models discovered — :test the key first)"}
                            </option>
                          ))}
                        </optgroup>
                      ))}
                    </select>
                  </td>
                  <td style={{ fontFamily: "var(--mono)", fontSize: 11, color: "var(--fg-muted)" }}>
                    {currentLabel}
                  </td>
                  <td>
                    <button
                      onClick={() => save.mutate({ scenario, body: row })}
                      disabled={save.isPending || !row.apiKeyId || !row.modelId}
                      style={{ padding: "3px 10px", fontSize: 11, background: "var(--accent)", color: "var(--accent-fg)", border: "none", borderRadius: 3, cursor: "pointer" }}
                    >
                      Save
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
