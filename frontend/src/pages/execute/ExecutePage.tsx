// ExecutePage — list↔detail router for flowruns. focusEntity.execute can
// pre-open a specific run.
//
// ExecutePage —— flowrun list↔detail router；focusEntity/onConsumeFocusEntity
// 由 AppShell 经 props 传入，pages 层零 app 依赖。

import { useEffect, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { useFlowRun } from "@entities/flowrun";
import { ExecuteOverview } from "./ui/ExecuteOverview.tsx";
import { FlowRunDetail } from "./ui/FlowRunDetail.tsx";
import { slideUp, fadeIn } from "@shared/lib/motion";
import type { MotionProps } from "framer-motion";

interface ExecutePageProps {
  focusEntity?: { execute?: string; [key: string]: unknown };
  onConsumeFocusEntity: (pane: string) => unknown;
  onOpenChat?: (convId: string) => void;
}

export function ExecutePage({ focusEntity, onConsumeFocusEntity, onOpenChat }: ExecutePageProps) {
  const [openRunId, setOpenRunId] = useState<string | null>(null);
  const focusId = focusEntity?.execute;

  // Probe and consume incoming focusId
  const { data: probe } = useFlowRun(focusId && !openRunId ? focusId : "");
  useEffect(() => {
    if (focusId && !openRunId && probe) {
      setOpenRunId(focusId);
      onConsumeFocusEntity("execute");
    }
  }, [focusId, openRunId, probe, onConsumeFocusEntity]);

  return (
    <AnimatePresence mode="wait" initial={false}>
      {openRunId ? (
        <motion.div key={`run-${openRunId}`} {...(slideUp as MotionProps)} style={{ height: "100%" }}>
          <FlowRunDetail runId={openRunId} onBack={() => setOpenRunId(null)} onOpenChat={onOpenChat} />
        </motion.div>
      ) : (
        <motion.div key="list" {...(fadeIn as MotionProps)} style={{ height: "100%" }}>
          <ExecuteOverview onOpen={(fr) => setOpenRunId(fr.id)} />
        </motion.div>
      )}
    </AnimatePresence>
  );
}
