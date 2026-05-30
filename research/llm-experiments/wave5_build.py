"""Wave-5 split-tools A/B: build the SAME complex workflows via incremental split tools
(create_workflow_shell + add_workflow_node + connect_workflow_nodes + set_case_branches)
instead of one monolithic create_workflow(ops=[...]).

Hypothesis (G8/G1): incremental building reduces case-routing errors (dangling branches,
redundant edges) + brace-undercount, vs the 55% monolithic rate. Reuses wave-1 user msgs + rubrics.

Writes /tmp/w5_specs/<id>.json = {id, system, user, tools, rubric, intent, max_turns}
"""

from __future__ import annotations

import json
from pathlib import Path

import catalog_v2 as cat
from wave1_gen import SCENARIOS as W1, SYSTEM as W1_SYSTEM

OUT = Path("/tmp/w5_specs"); OUT.mkdir(exist_ok=True)

SHELL = cat.tool(
    "create_workflow_shell",
    "Create an empty workflow (just a name); returns its id. Then build it up with add_workflow_node / connect_workflow_nodes / set_case_branches.",
    ["name"], {"name": {"type": "string"}},
)
SPLIT_TOOLS = [SHELL] + cat.workflow_split_tools()  # add_workflow_node, connect_workflow_nodes, set_case_branches

SYSTEM = W1_SYSTEM + """

You build workflows INCREMENTALLY with split tools: create_workflow_shell(name) → returns wf id;
then add_workflow_node(id, node) one node at a time; connect_workflow_nodes(id, from, to) for plain
tool/agent edges; set_case_branches(id, nodeId, expression, branches) for case nodes (case/approval
route via branches, NOT connect). Build the whole graph, then say you're done."""

# reuse the 3 complex workflow scenarios from wave-1
WANT = {"wf_clear_triage", "wf_branch_signup", "wf_retry_loop"}


def build():
    for sc in W1:
        if sc["id"] not in WANT:
            continue
        spec = {
            "id": sc["id"], "system": SYSTEM, "user": sc["user"],
            "tools": SPLIT_TOOLS, "rubric": sc["rubric"], "intent": sc["intent"], "max_turns": 12,
        }
        (OUT / f"{sc['id']}.json").write_text(json.dumps(spec, ensure_ascii=False, indent=2))
    print(f"built {len(WANT)} split-build specs in {OUT}/ ; tools:", [t["function"]["name"] for t in SPLIT_TOOLS])


if __name__ == "__main__":
    build()
