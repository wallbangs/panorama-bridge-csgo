"""Build a STORE-only Panorama archive from locally installed game/mod files."""

import argparse
from copy import copy
from uuid import uuid4
from pathlib import Path
from zipfile import ZIP_STORED, ZipFile, ZipInfo


def patch_ui(name: str, data: bytes) -> bytes:
    fixes = {
        "panorama/scripts/teamselectmenu.js": [
            (
                b"$('#TeamSelectCancel').visible = !bUnassigned;",
                b"var cancel = $('#TeamSelectCancel'); if (cancel) cancel.visible = !bUnassigned;",
            )
        ],
        "panorama/layout/teamselectmenu.xml": [
            (b'text="#CHOOSE TEAM"', b'text="CHOOSE TEAM"'),
            (b'text="#Auto pick in:"', b'text="Auto pick in:"'),
            (b'text="#Bots:"', b'text="Bots:"'),
        ],
        "panorama/layout/hud/hud.xml": [
            (
                b'blurrects="Scoreboard EndOfMatch BuyMenu sliding-panel--TERRORIST sliding-panel--CT"',
                b'blurrects="Scoreboard EndOfMatch BuyMenu"',
            )
        ],
    }
    for old, new in fixes.get(name.casefold(), []):
        if old not in data:
            raise ValueError(f"Expected UI text not found in {name}: {old!r}")
        data = data.replace(old, new)
    return data


def build(original: Path, addon: Path, output: Path) -> None:
    if not original.is_file() or not addon.is_dir():
        raise ValueError("Original ZIP or addon panorama directory not found")
    if original.resolve() == output.resolve():
        raise ValueError("Output cannot overwrite the source ZIP")
    overlays = {
        ("panorama/" + file.relative_to(addon).as_posix()).casefold(): file
        for file in addon.rglob("*") if file.is_file()
    }
    if len(overlays) < 700:
        raise ValueError("Addon directory appears incomplete; select its panorama subfolder")
    temporary = output.with_name(f".{output.stem}-{uuid4().hex}.zip")
    try:
        with ZipFile(original) as source:
            originals = source.infolist()
            if len(originals) < 700 or any(entry.is_dir() for entry in originals):
                raise ValueError("Original archive does not match the expected legacy format")
            with ZipFile(temporary, "w", compression=ZIP_STORED, allowZip64=False) as target:
                for entry in originals:
                    file = overlays.pop(entry.filename.casefold(), None)
                    data = file.read_bytes() if file else source.read(entry)
                    target.writestr(copy(entry), patch_ui(entry.filename, data), compress_type=ZIP_STORED)
                for name, file in sorted(overlays.items()):
                    entry = ZipInfo(name)
                    entry.create_system = 0
                    entry.external_attr = 0
                    target.writestr(entry, patch_ui(name, file.read_bytes()), compress_type=ZIP_STORED)
        with ZipFile(temporary) as check:
            entries = check.infolist()
            if len(entries) < 700 or any(
                entry.is_dir() or entry.compress_type != ZIP_STORED or entry.extra
                for entry in entries
            ):
                raise ValueError("Output ZIP verification failed")
        temporary.replace(output)
        print(f"Created {output} with {len(entries)} stored file entries")
    finally:
        temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--original", type=Path, required=True, help="HLAE panorama.org.zip")
    parser.add_argument("--addon", type=Path, required=True, help="p_scaleform/panorama directory")
    parser.add_argument("--output", type=Path, default=Path(__file__).parent / "panorama.my.zip")
    args = parser.parse_args()
    build(args.original, args.addon, args.output)
