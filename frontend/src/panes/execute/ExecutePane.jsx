// ExecutePane — list↔detail router for flowruns. focusEntity.execute can
// pre-open a specific run.
//
// ExecutePane —— flowrun list↔detail router；focusEntity 可预打开。

import { useEffect, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { useUIStore } from "../../store/ui.js";
import { useFlowRun } from "../../api/flowruns.js";
import { ExecuteOverview } from "./ExecuteOverview.jsx";
import { FlowRunDetail } from "./FlowRunDetail.jsx";
import { slideUp, fadeIn } from "../../motion/tokens.js";

export function ExecutePane() {
  const [openRunId, setOpenRunId] = useState(null);
  const consumeFocusEntity = useUIStore((s) => s.consumeFocusEntity);
  const focusId = useUIStore((s) => s.focusEntity.execute);

  // Probe and consume incoming focusId
  const { data: probe } = useFlowRun(focusId && !openRunId ? focusId : null);
  useEffect(() => {
    if (focusId && !openRunId && probe) {
      setOpenRunId(focusId);
      consumeFocusEntity("execute");
    }
  }, [focusId, openRunId, probe, consumeFocusEntity]);

  return (
    <AnimatePresence mode="wait" initial={false}>
      {openRunId ? (
        <motion.div key={`run-${openRunId}`} {...slideUp} style={{ height: "100%" }}>
          <FlowRunDetail runId={openRunId} onBack={() => setOpenRunId(null)} />
        </motion.div>
      ) : (
        <motion.div key="list" {...fadeIn} style={{ height: "100%" }}>
          <ExecuteOverview onOpen={(fr) => setOpenRunId(fr.id)} />
        </motion.div>
      )}
    </AnimatePresence>
  );
}
