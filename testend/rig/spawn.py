#!/usr/bin/env python3
"""Spawn one rig component in its own process session and print the leader PID."""
import argparse
import datetime
import json
import os
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cwd", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--lifecycle")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("command required after --")
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    requested_at = datetime.datetime.now(datetime.timezone.utc).isoformat(
        timespec="microseconds"
    ).replace("+00:00", "Z")
    with open(args.out, "ab", buffering=0) as log:
        proc = subprocess.Popen(
            command,
            cwd=args.cwd,
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
    returned_at = datetime.datetime.now(datetime.timezone.utc).isoformat(
        timespec="microseconds"
    ).replace("+00:00", "Z")
    if args.lifecycle:
        os.makedirs(os.path.dirname(args.lifecycle) or ".", exist_ok=True)
        with open(args.lifecycle, "w", encoding="utf-8") as lifecycle:
            json.dump(
                {
                    "pid": proc.pid,
                    "spawnRequestedAt": requested_at,
                    "spawnReturnedAt": returned_at,
                },
                lifecycle,
                indent=2,
            )
            lifecycle.write("\n")
    print(proc.pid)


if __name__ == "__main__":
    main()
