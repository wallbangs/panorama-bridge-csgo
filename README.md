<div align="center">

# Panorama Bridge

### The classic CS:GO HUD, with a guided setup and a simple launcher.

**Windows x86 · Legacy CS:GO · Offline / local play**

Panorama Bridge loads a locally built, Scaleform-style Panorama UI archive into legacy 32-bit CS:GO. It replaces one Panorama ZIP load; it does not provide HLAE's camera or recording features.

</div>

> [!IMPORTANT]
> This is for a compatible **legacy 32-bit CS:GO** build, not CS2. Launch with `-insecure` and use local games or demos. Do not use this on VAC-protected servers. It was tested with one legacy build; other versions or addon variants may need changes.

**The short version:** Run `Setup.cmd`, initialize MIGI if prompted, click **Build / Update Build** in MIGI, then run `Launch.cmd`. If your first launch shows the normal HUD, close the game and run `Launch.cmd` once more. After that, use `Launch.cmd` for everyday play. **HLAE is not required.**

This repository contains the Bridge, injector, and a patch for the tested UI. It does not contain game assets, MIGI, the full Scaleform addon, ReShade, or a ready-made Panorama ZIP. Setup downloads the needed third-party files from pinned upstream versions and verifies their hashes. The Panorama ZIP is created locally from your own game.

## What you need

1. Legacy **32-bit** CS:GO with a working `csgo.exe` (not CS2).
2. [Python 3 for Windows](https://www.python.org/downloads/windows/) (`py -3` or `python` must work in Command Prompt).
3. Internet access during setup and Steam running when you launch the game.

## First-time setup

1. **Download and extract this repository** anywhere on your PC. Double-click `Setup.cmd` and select the folder containing your legacy `csgo.exe`.
2. **Set up MIGI if prompted.** Setup downloads [MIGI3](https://github.com/ZooLSmith/MIGI3) if it is missing. Run `migi.exe` as administrator once to initialize it, then run it normally. Return to this folder and run `Setup.cmd` again. Setup also downloads the tested Scaleform UI and resources automatically; you do not need to find a separate addon. Accept the suggested paths.
3. **Build the addon.** In MIGI, click **Build / Update Build**.
4. **Start Steam, then double-click `Launch.cmd`.** If you see the normal HUD, that is expected: this launch captures the original Panorama files from *your* game. Close CS:GO completely.
5. **Double-click `Launch.cmd` again.** It builds the local replacement ZIP and launches the classic UI. Open a local map or demo to check the HUD. If Setup found an original ZIP from your own game already, the classic UI may work on the first launch.

The generated `panorama.org.zip` and `panorama.my.zip` stay on your PC. Do not manually re-compress them or upload them.

## Everyday launch

Start Steam, close any running CS:GO, and double-click `Launch.cmd`. It starts the injector and launches legacy CS:GO with `-insecure -game migi/csgo -console`. You do not need to run Setup again unless your game or addon files change. After addon edits, click **Build / Update Build** in MIGI and rerun `Setup.cmd`.

### If `Launch.cmd` does not start the game

Close CS:GO. Open Command Prompt in the extracted Bridge folder and run:

```bat
panorama-inject32.exe csgo.exe
```

Leave that window waiting. Then launch the game using MIGI's **Launch MIGI** button with `-insecure`, or launch the legacy executable with these Steam options:

```text
-insecure -game migi/csgo -console
```

Do not use HLAE or `-afxDetourPanorama` for the normal Bridge launch. An injector success message only confirms that the DLL loaded; check the HUD in a local map. `PanoramaBridge.log` appears beside the DLL.

## Optional: GameSense / Skeet launch order

This is the order reported working with a separately obtained GameSense loader in an **offline/local, `-insecure`** setup. GameSense is not included, supported, or required by this repository. Do not use this sequence on VAC-protected servers.

1. Close CS:GO completely. Keep HLAE closed; do not add `-afxDetourPanorama`.
2. Start your GameSense loader and put it in its waiting/injecting state **before opening CS:GO**. Do not start the game yet.
3. Open a separate Command Prompt in the Panorama Bridge folder and run:

   ```bat
   panorama-inject32.exe csgo.exe
   ```

   Leave this window waiting too.
4. Now launch legacy CS:GO through MIGI with `-insecure -game migi/csgo` (or use MIGI's launch button with equivalent options).
5. Once the game has loaded, check the classic HUD in a local map. The two loaders may finish at different times; a success line in one window does not by itself confirm both components are active.

If the game crashes, first test the normal Bridge-only launch above. Keep the tests offline and add components back one at a time; avoid stacking HLAE or additional injectors while diagnosing.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `Failed to initialize panorama engine` | Exit CS:GO. Rebuild the ZIP from your matching original and addon. Never manually re-compress it. |
| First launch has the normal UI | Expected when there was no original ZIP. Close the game completely, then run `Launch.cmd` again. |
| No `panorama.org.zip` after the first launch | Check `PanoramaBridge.log`. Confirm the x86 injector ran before legacy `csgo.exe` and that `CZip archive-load function hooked` appears. |
| Game starts but classic UI is missing | Check that `panorama.my.zip` and `enable-replacement.flag` are beside the DLL and that the injector ran **before** CS:GO. Read the log. |
| Injector succeeds but UI is unchanged | Confirm this is legacy 32-bit `csgo.exe`, not CS2. Confirm MIGI's build is current. |
| Builder says addon is incomplete | Point `--addon` to the inner `p_scaleform/panorama` directory, not the outer download folder or archive. |
| Builder cannot find expected UI text | The addon variant differs from the tested one. Do not force a mismatched archive; adapt the compatibility patch in `build_archive.py`. |
| Game works only without the replacement ZIP | Remove `enable-replacement.flag` for Bridge pass-through mode; this isolates archive problems from hook problems. |
| MIGI edits do not appear | Rebuild MIGI and confirm `-game migi/csgo` is active. |
| `Launch.cmd` does not start CS:GO | Start Steam and use the manual launch fallback above. The Bridge injector must be waiting before game launch. |
| `Setup.cmd` says Python is missing | Install Python 3, then rerun setup. It accepts either the `py` launcher or `python.exe`. |
| Addon or MIGI download fails or reports a hash mismatch | Retry when GitHub is reachable. Setup refuses to install unexpected revisions; do not bypass the checksums. |
| Existing `p_scaleform` is incomplete | Back up that folder and repair it, or remove it yourself before rerunning setup. Setup never overwrites it. |

Old addons can also print localization, sound, or map warnings unrelated to the Bridge.

## Optional: rebuild the binaries

The included EXE and DLL are the tested x86 binaries. To compile from source, open an **x86 MSVC Developer Command Prompt** in this folder and run:

```bat
build_x86.cmd
```

The repository includes `PanoramaBridge.cpp`, an adapted `injector.cpp`, and `minhook/`. ReShade is neither required nor bundled for the Panorama Bridge. Install and configure it separately if you want shaders.

## Sharing and credits

**Do not upload** `panorama.my.zip`, `panorama.org.zip`, `local-settings.json`, extracted Panorama files, game assets, logs, or personal presets. The generated ZIP contains game-owned content. `.gitignore` excludes ZIPs, logs, and local settings, but inspect your upload anyway.

- Injector: adapted from [ReShade's injector](https://github.com/crosire/reshade/blob/main/tools/injector.cpp), copyright Patrick Mours, BSD-3-Clause; see `LICENSE-ReShade.txt`.
- Hooking: [MinHook](https://github.com/TsudaKageyu/minhook); see `minhook/LICENSE.txt`.
- Panorama approach: informed by [HLAE's public implementation](https://github.com/advancedfx/advancedfx); no HLAE code or assets are bundled.
- UI addon: fetched directly from [awfeel7/Scaleform-UI-CSGO](https://github.com/awfeel7/Scaleform-UI-CSGO), with resources fetched from [abandonedpools/scaleform](https://github.com/abandonedpools/scaleform). The seven-file patch contains only local UI changes, not the full addon.

Bridge-specific source is under `LICENSE-Bridge.txt`. Third-party components retain their own licenses.
