"""Round-2 self-consistency: from the n=50 robustness reps (/tmp/r2), measure how CONSISTENT the
model's output STRUCTURE is across reps of the SAME request (determinism proxy → UX trust).
Modal-signature fraction = (# reps matching the most-common structural signature) / n. No new gen."""
from __future__ import annotations
import json, glob
from collections import Counter


def sig(surface, args):
    """Coarse structural signature per surface (semantics-agnostic, just shape)."""
    if not isinstance(args, dict) or "_unparseable" in args:
        return ("MALFORMED",)
    if surface == "create_workflow":
        ops = args.get("ops", [])
        nts = tuple(sorted(o.get("node", {}).get("type", "") for o in ops if isinstance(o, dict) and o.get("op") == "add_node"))
        ncase = sum(1 for o in ops if isinstance(o, dict) and o.get("node", {}).get("type") == "case")
        return (len(ops), nts, ncase)
    if surface == "create_agent":
        ops = args.get("ops", [])
        kinds = tuple(sorted(o.get("op", "") for o in ops if isinstance(o, dict)))
        return (kinds,)
    if surface == "cel_when":
        br = args.get("branches", {})
        return (tuple(sorted(br.keys())),)
    if surface in ("create_function", "create_handler"):
        return (args.get("kind", "?"), bool(args.get("code")))
    return ("other",)


def main():
    rows = []
    for f in sorted(glob.glob("/tmp/r2/*.json")):
        d = json.load(open(f))
        surface = d.get("surface", "?")
        sigs = []
        for r in d.get("reps", []):
            tcs = r.get("tool_calls", [])
            if not tcs:
                sigs.append(("NOCALL",))
                continue
            sigs.append(sig(surface, tcs[0].get("args", {})))
        n = len(sigs)
        if not n:
            continue
        c = Counter(map(str, sigs))
        modal = c.most_common(1)[0][1]
        rows.append((d["id"], surface, modal / n, n, len(c)))
    print("self-consistency (modal structural signature fraction; higher = more deterministic):")
    for id_, surf, frac, n, nuniq in sorted(rows, key=lambda x: x[2]):
        print(f"  {id_:20s} {surf:16s} {frac*100:5.0f}%  (n={n}, {nuniq} distinct shapes)")
    if rows:
        mean = sum(r[2] for r in rows) / len(rows)
        print(f"\n  MEAN self-consistency: {mean*100:.0f}%")


if __name__ == "__main__":
    main()
