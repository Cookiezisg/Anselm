// useForge — subscribes to /api/v1/forge. 4 events: started / op_applied
// / env_attempt / completed. Writes into useForgeProgress (shared/model)
// so detail views and forge list can read it without reversing FSD layers.
//
// useForge —— /api/v1/forge 4 个事件；写入 shared/model/forgeProgress；
// 详情页与列表行顺向读 shared，不反向依赖 app/sse。

import { useEffect, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { createSSE } from "@shared/api/sse";
import { useSessionStore } from "@entities/session";
import { qk } from "@shared/api/queryKeys";
import { useForgeProgress } from "@shared/model";

export { useForgeProgress };

const scopeKey = (scope: { kind?: string; id?: string } | undefined) => `${scope?.kind}:${scope?.id}`;

export function useForge() {
  const qc = useQueryClient();
  const [status, setStatus] = useState("connecting");
  const activeUserId = useSessionStore((s) => s.currentUserId);

  useEffect(() => {
    const store = useForgeProgress.getState();

    const ctrl = createSSE({
      path: "/forge",
      eventHandlers: {
        forge_started: (e: unknown) => {
          const ev = e as { scope?: { kind: string; id: string }; operation?: string; conversationId?: string; toolCallId?: string };
          const key = scopeKey(ev.scope);
          store.put(key, {
            scope: ev.scope,
            operation: ev.operation,
            conversationId: ev.conversationId,
            toolCallId: ev.toolCallId,
            ops: [],
            envAttempts: [],
            status: "running",
          });
        },
        forge_op_applied: (e: unknown) => {
          const ev = e as { scope?: { kind: string; id: string }; index: number; op: unknown };
          const key = scopeKey(ev.scope);
          const cur = useForgeProgress.getState().active[key];
          if (!cur) return;
          store.put(key, { ...cur, ops: [...(cur.ops ?? []), { index: ev.index, op: ev.op }] });
        },
        forge_env_attempt: (e: unknown) => {
          const ev = e as { scope?: { kind: string; id: string }; attempt: number; status: string; stage?: string; detail?: string; error?: string };
          const key = scopeKey(ev.scope);
          const cur = useForgeProgress.getState().active[key];
          if (!cur) return;
          store.put(key, {
            ...cur,
            envAttempts: [
              ...(cur.envAttempts ?? []),
              { attempt: ev.attempt, status: ev.status, stage: ev.stage, detail: ev.detail, error: ev.error },
            ],
          });
        },
        forge_completed: (e: unknown) => {
          const ev = e as { scope?: { kind: string; id: string }; status: string; versionId?: string; envStatus?: string; attemptsUsed?: number; error?: string };
          const key = scopeKey(ev.scope);
          const cur = useForgeProgress.getState().active[key];
          store.put(key, {
            ...(cur || { scope: ev.scope }),
            status: ev.status,
            versionId: ev.versionId,
            envStatus: ev.envStatus,
            attemptsUsed: ev.attemptsUsed,
            error: ev.error,
            finishedAt: Date.now(),
          });
          // refresh entity caches once forging finishes
          if (ev.scope?.kind && ev.scope?.id) {
            const kind = ev.scope.kind;
            const id = ev.scope.id;
            if (kind === "function") {
              qc.invalidateQueries({ queryKey: qk.functions() });
              qc.invalidateQueries({ queryKey: qk.function(id) });
              qc.invalidateQueries({ queryKey: qk.functionVersions(id) });
            } else if (kind === "handler") {
              qc.invalidateQueries({ queryKey: qk.handlers() });
              qc.invalidateQueries({ queryKey: qk.handler(id) });
              qc.invalidateQueries({ queryKey: qk.handlerVersions(id) });
            } else if (kind === "workflow") {
              qc.invalidateQueries({ queryKey: qk.workflows() });
              qc.invalidateQueries({ queryKey: qk.workflow(id) });
              qc.invalidateQueries({ queryKey: qk.workflowVersions(id) });
            }
          }
        },
      },
      onStatus: setStatus,
    });
    return () => ctrl.close();
  }, [qc, activeUserId]);

  return status;
}
