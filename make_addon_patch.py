"""Maintainer tool: create a delta between a pinned upstream addon and a tested local addon."""

import argparse
import base64
import difflib
import hashlib
import json
from pathlib import Path


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def make_patch(upstream: Path, modified: Path) -> dict:
    patches = {}
    for source in upstream.rglob("*"):
        if not source.is_file():
            continue
        relative = source.relative_to(upstream)
        target = modified / relative
        if not target.is_file():
            raise ValueError(f"Missing modified file: {relative}")
        old, new = source.read_bytes(), target.read_bytes()
        if old == new:
            continue
        old_lines = old.splitlines(keepends=True)
        new_lines = new.splitlines(keepends=True)
        edits = []
        matcher = difflib.SequenceMatcher(None, old_lines, new_lines, autojunk=False)
        for kind, i1, i2, j1, j2 in matcher.get_opcodes():
            if kind == "equal":
                continue
            edits.append({
                "start": i1,
                "delete": i2 - i1,
                "insert_b64": base64.b64encode(b"".join(new_lines[j1:j2])).decode("ascii"),
            })
        patches[relative.as_posix()] = {
            "base_sha256": digest(old),
            "result_sha256": digest(new),
            "edits": edits,
        }
    return {"format": 1, "files": patches}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream", type=Path, required=True)
    parser.add_argument("--modified", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    patch = make_patch(args.upstream, args.modified)
    args.output.write_text(json.dumps(patch, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {args.output} with {len(patch['files'])} changed files")
