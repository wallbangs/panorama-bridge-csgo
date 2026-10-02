"""Apply the tested addon deltas to the pinned upstream addon, never to an unknown version."""

import argparse
import base64
import hashlib
import json
from pathlib import Path


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def apply(root: Path, patch_file: Path) -> None:
    patch = json.loads(patch_file.read_text(encoding="utf-8"))
    if patch.get("format") != 1:
        raise ValueError("Unsupported addon patch format")
    pending = []
    for relative, spec in patch["files"].items():
        parts = Path(relative).parts
        if not parts or any(part in (".", "..") for part in parts) or Path(relative).is_absolute():
            raise ValueError(f"Unsafe addon patch path: {relative}")
        path = root / relative
        old = path.read_bytes()
        if digest(old) == spec["result_sha256"]:
            continue
        if digest(old) != spec["base_sha256"]:
            raise ValueError(f"Addon version mismatch: {relative}")
        lines = old.splitlines(keepends=True)
        result = []
        position = 0
        for edit in spec["edits"]:
            start, deleted = edit["start"], edit["delete"]
            if start < position or start + deleted > len(lines):
                raise ValueError(f"Invalid patch offsets: {relative}")
            result.extend(lines[position:start])
            result.append(base64.b64decode(edit["insert_b64"], validate=True))
            position = start + deleted
        result.extend(lines[position:])
        new = b"".join(result)
        if digest(new) != spec["result_sha256"]:
            raise ValueError(f"Addon patch verification failed: {relative}")
        pending.append((path, new))
    for path, data in pending:
        path.write_bytes(data)
    print(f"Applied {len(pending)} verified addon file patches")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--addon", type=Path, required=True)
    parser.add_argument("--patch", type=Path, default=Path(__file__).parent / "addon-patch.json")
    args = parser.parse_args()
    apply(args.addon, args.patch)
