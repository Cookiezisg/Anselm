// testend/src/router.tsx — hash router with 44 placeholder routes.
// Real view components land in P3 (per-section).
//
// 44 路由占位;P3 逐 section 替换为真 view。
import { createHashRouter, Navigate } from "react-router-dom";
import { App } from "./App";

function Placeholder({ name }: { name: string }) {
  return <div className="empty">TODO: {name}</div>;
}

export const router = createHashRouter([
  {
    path: "/",
    element: <App />,
    children: [
      { index: true, element: <Navigate to="/forge/functions" replace /> },

      // current/ (9)
      { path: "current/wire",          element: <Placeholder name="current/WireTrace" /> },
      { path: "current/eventlog",      element: <Placeholder name="current/EventlogRaw" /> },
      { path: "current/notifications", element: <Placeholder name="current/Notifications" /> },
      { path: "current/subagents",     element: <Placeholder name="current/SubAgents" /> },
      { path: "current/tools",         element: <Placeholder name="current/ToolCalls" /> },
      { path: "current/todos",         element: <Placeholder name="current/Todos" /> },
      { path: "current/asks",          element: <Placeholder name="current/AsksPending" /> },
      { path: "current/attachments",   element: <Placeholder name="current/Attachments" /> },
      { path: "current/compaction",    element: <Placeholder name="current/Compaction" /> },

      // forge/ (7 — TestCollections deleted)
      { path: "forge/functions",       element: <Placeholder name="forge/Functions" /> },
      { path: "forge/functions/:id",   element: <Placeholder name="forge/FunctionDetail" /> },
      { path: "forge/handlers",        element: <Placeholder name="forge/Handlers" /> },
      { path: "forge/handlers/:id",    element: <Placeholder name="forge/HandlerDetail" /> },
      { path: "forge/workflows",       element: <Placeholder name="forge/Workflows" /> },
      { path: "forge/workflows/:id",   element: <Placeholder name="forge/WorkflowDetail" /> },
      { path: "forge/tools",           element: <Placeholder name="forge/ToolsRegistry" /> },

      // execute/ (5)
      { path: "execute/triggers",      element: <Placeholder name="execute/Triggers" /> },
      { path: "execute/flowruns",      element: <Placeholder name="execute/FlowRuns" /> },
      { path: "execute/flowruns/:id",  element: <Placeholder name="execute/FlowRunDetail" /> },
      { path: "execute/approvals",     element: <Placeholder name="execute/ApprovalsQueue" /> },
      { path: "execute/executions",    element: <Placeholder name="execute/Executions" /> },

      // observe/ (5)
      { path: "observe/live",          element: <Placeholder name="observe/LiveSSE" /> },
      { path: "observe/notifications", element: <Placeholder name="observe/NotificationHistory" /> },
      { path: "observe/catalog",       element: <Placeholder name="observe/Catalog" /> },
      { path: "observe/usage",         element: <Placeholder name="observe/Usage" /> },
      { path: "observe/mock-llm",      element: <Placeholder name="observe/MockLLM" /> },

      // config/ (10)
      { path: "config/apikeys",        element: <Placeholder name="config/ApiKeys" /> },
      { path: "config/models",         element: <Placeholder name="config/ModelConfigs" /> },
      { path: "config/skills",         element: <Placeholder name="config/Skills" /> },
      { path: "config/mcp",            element: <Placeholder name="config/MCPServers" /> },
      { path: "config/sandbox",        element: <Placeholder name="config/Sandbox" /> },
      { path: "config/memory",         element: <Placeholder name="config/Memory" /> },
      { path: "config/documents",      element: <Placeholder name="config/Documents" /> },
      { path: "config/permissions",    element: <Placeholder name="config/Permissions" /> },
      { path: "config/llm-health",     element: <Placeholder name="config/LLMHealth" /> },
      { path: "config/profile",        element: <Placeholder name="config/Profile" /> },

      // dev/ (8)
      { path: "dev/sql",               element: <Placeholder name="dev/SQL" /> },
      { path: "dev/info",              element: <Placeholder name="dev/Info" /> },
      { path: "dev/routes",            element: <Placeholder name="dev/Routes" /> },
      { path: "dev/logs",              element: <Placeholder name="dev/BackendLogs" /> },
      { path: "dev/processes",         element: <Placeholder name="dev/Processes" /> },
      { path: "dev/metrics",           element: <Placeholder name="dev/Metrics" /> },
      { path: "dev/errors",            element: <Placeholder name="dev/Errors" /> },
      { path: "dev/prompts",           element: <Placeholder name="dev/Prompts" /> },

      // catch-all
      { path: "*", element: <Navigate to="/forge/functions" replace /> },
    ],
  },
]);
