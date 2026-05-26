// ForgePage — owns its own list ↔ detail router. focusEntity from ui
// store can pre-open a specific entity (used by EntityLink + cmdk).
//
// ForgePage —— 自管 list ↔ detail；focusEntity/onConsumeFocusEntity 由
// AppShell 经 props 传入，pages 层零 app 依赖。

import { useEffect, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { useFunction } from "@entities/function";
import { useHandler } from "@entities/handler";
import { useWorkflow } from "@entities/workflow";
import { ForgeList } from "./ui/ForgeList.tsx";
import { FunctionDetail } from "./ui/FunctionDetail.tsx";
import { HandlerDetail } from "./ui/HandlerDetail.tsx";
import { WorkflowDetail } from "./ui/WorkflowDetail.tsx";
import { slideUp, fadeIn } from "@shared/lib/motion";
import type { MotionProps } from "framer-motion";

interface ForgePageProps {
  focusEntity?: { forge?: string; [key: string]: unknown };
  onConsumeFocusEntity: (pane: string) => unknown;
  onOpenExecute?: (id: string) => void;
}

interface OpenEntity { kind: "function" | "handler" | "workflow"; id: string; [key: string]: unknown }

export function ForgePage({ focusEntity, onConsumeFocusEntity, onOpenExecute }: ForgePageProps) {
  const [open, setOpen] = useState<OpenEntity | null>(null);
  const focusId = focusEntity?.forge;

  // Probe each detail endpoint when focusId is set; whichever returns
  // first determines the kind. (Backend has separate /functions /handlers
  // /workflows endpoints, no unified /forges lookup.)
  const probeFn = useFunction(focusId && !open ? focusId : "");
  const probeHd = useHandler(focusId && !open ? focusId : "");
  const probeWf = useWorkflow(focusId && !open ? focusId : "");

  useEffect(() => {
    if (!focusId || open) return;
    let entity: object | null = null;
    let kind: "function" | "handler" | "workflow" | null = null;
    if (probeFn.data) { entity = probeFn.data; kind = "function"; }
    else if (probeHd.data) { entity = probeHd.data; kind = "handler"; }
    else if (probeWf.data) { entity = probeWf.data; kind = "workflow"; }
    if (entity && kind) {
      setOpen({ ...(entity as OpenEntity), kind });
      onConsumeFocusEntity("forge");
    }
  }, [focusId, open, probeFn.data, probeHd.data, probeWf.data, onConsumeFocusEntity]);

  const close = () => setOpen(null);

  return (
    <AnimatePresence mode="wait" initial={false}>
      {open ? (
        <motion.div key={`detail-${open.kind}-${open.id}`} {...(slideUp as MotionProps)} style={{ height: "100%" }}>
          {open.kind === "function" && <FunctionDetail forge={open} onBack={close} />}
          {open.kind === "handler"  && <HandlerDetail forge={open} onBack={close} />}
          {open.kind === "workflow" && <WorkflowDetail forge={open} onBack={close} onOpenExecute={onOpenExecute} />}
        </motion.div>
      ) : (
        <motion.div key="list" {...(fadeIn as MotionProps)} style={{ height: "100%" }}>
          <ForgeList onOpen={(e) => setOpen(e as unknown as OpenEntity)} onOpenExecute={onOpenExecute} />
        </motion.div>
      )}
    </AnimatePresence>
  );
}
