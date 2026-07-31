#!/usr/bin/env python3
"""Spawn one rig component in its own process session and print the leader PID."""
import argparse
import os
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cwd", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("command required after --")
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "ab", buffering=0) as log:
        proc = subprocess.Popen(
            command,
            cwd=args.cwd,
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
    print(proc.pid)


if __name__ == "__main__":
    main()
