#!/usr/bin/env python3
"""Seed the durable, read-only sources used by SURF-022's sidestage run.

The fixture does not synthesize UI state: it writes the same SQLite projections that
the production HTTP handlers serve, then the real backend and App re-hydrate them.
The active stage is deliberately produced by a real chat turn in the formal run.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
from datetime import datetime, timedelta, timezone


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", required=True, help="path to anselm.db")
    parser.add_argument("--workspace", required=True)
    parser.add_argument("--conversation", required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    now = datetime.now(timezone.utc)
    rows: list[tuple[object, ...]] = []

    # 6 + 18 + 30 = 54 aggregate rows: the first page leaves four rows for load-more.
    ages = [
        *(timedelta(seconds=30 * (i + 1)) for i in range(6)),
        *(timedelta(hours=1, minutes=3 * i) for i in range(18)),
        *(timedelta(days=2, minutes=3 * i) for i in range(30)),
    ]
    for i, age in enumerate(ages):
        at = (now - age).isoformat(sep=" ")
        rows.append(
            (
                f"tp_surf022_{i:02d}",
                args.workspace,
                args.conversation,
                "function",
                f"fn_surf022_{i:02d}",
                f"SURF-022 Cast {i + 1:02d}",
                "viewed",
                "assistant",
                1,
                at,
                at,
                "",
            )
        )

    todos = [
        {
            "content": "核对三档 Cast 的分组与顺序",
            "activeForm": "正在核对三档 Cast 的分组与顺序…",
            "status": "in_progress",
        },
        {
            "content": "确认历史触点可通过载更多完整取回",
            "activeForm": "确认历史触点可通过载更多完整取回",
            "status": "pending",
        },
        {
            "content": "记录右岛的最终视觉证据",
            "activeForm": "记录右岛的最终视觉证据",
            "status": "completed",
        },
    ]
    created = now.isoformat(sep=" ")

    with sqlite3.connect(args.db) as db:
        db.executemany(
            """
            INSERT OR REPLACE INTO conversation_touchpoints
              (id, workspace_id, conversation_id, item_kind, item_id, item_name,
               verb, last_actor, count, first_at, last_at, last_message_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            rows,
        )
        db.execute(
            """
            INSERT OR REPLACE INTO todos
              (scope_id, workspace_id, conversation_id, subagent_id, items,
               created_at, updated_at, deleted_at)
            VALUES (?, ?, ?, NULL, ?, ?, ?, NULL)
            """,
            (
                args.conversation,
                args.workspace,
                args.conversation,
                json.dumps(todos, ensure_ascii=False),
                created,
                created,
            ),
        )
        db.commit()

    print(
        json.dumps(
            {
                "workspace": args.workspace,
                "conversation": args.conversation,
                "touchpoints": len(rows),
                "todoItems": len(todos),
                "tiers": {"just": 6, "today": 18, "earlier": 30},
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
