#!/usr/bin/env python3
"""Check the managed gateway's explicit image-to-video contract before TOOL-123."""

import argparse
import gzip
import json
import sys
from pathlib import Path


def read_models(path: Path):
    raw = path.read_bytes()
    if raw.startswith(b"\x1f\x8b"):
        raw = gzip.decompress(raw)
    return json.loads(raw.decode("utf-8"))


def check(payload) -> tuple[bool, str]:
    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, list):
        return False, "models response has no data array"
    for model in data:
        caps = model.get("anselm_capabilities") if isinstance(model, dict) else None
        video = caps.get("video_generation") if isinstance(caps, dict) else None
        if (
            isinstance(caps, dict)
            and caps.get("version", 0) >= 1
            and caps.get("routing") == "content"
            and isinstance(video, dict)
            and video.get("available") is True
            and video.get("image_to_video") is True
        ):
            return True, f"model {model.get('id', '<unnamed>')} explicitly advertises image_to_video"
    return False, "no model explicitly advertises video_generation.available=true and image_to_video=true"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Check a captured managed /models response before the TOOL-123 App run."
    )
    parser.add_argument("models", type=Path, help="raw or gzip-compressed /models response")
    args = parser.parse_args(argv)
    try:
        payload = read_models(args.models)
        available, reason = check(payload)
    except (OSError, UnicodeDecodeError, gzip.BadGzipFile, json.JSONDecodeError) as exc:
        print(f"i2v: invalid models response: {exc}", file=sys.stderr)
        return 2
    if not available:
        print(f"i2v: unavailable — {reason}", file=sys.stderr)
        return 2
    print(f"i2v: available — {reason}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
