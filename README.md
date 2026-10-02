<div align="center">

# Panorama Bridge

### The classic CS:GO HUD. Your legacy build. No HLAE at launch.

**Windows x86 · Legacy CS:GO · Offline / local play**

Panorama Bridge loads a locally built, Scaleform-style Panorama UI archive into legacy 32-bit CS:GO. It replaces one Panorama ZIP load; it does not provide HLAE's camera or recording features.

</div>

> [!IMPORTANT]
> This is for a compatible **legacy 32-bit CS:GO** build, not CS2. Launch with `-insecure` and use local games or demos. Do not use this on VAC-protected servers. It was tested with one legacy build; other versions or addon variants may need changes.

## How the pieces fit

```text
Your CS:GO installation ──► original Panorama ZIP ─┐
                                                   ├── build_archive.py ──► panorama.my.zip
Scaleform addon's panorama folder ─────────────────┘                       │
                                                                           ▼
MIGI + p_scaleform ──► rebuilt game folder       Panorama Bridge injector + DLL
                       │                                   │
                       └────────► launch legacy CS:GO ◄───┘
```

This repository contains the Bridge, injector, source code, and local archive builder. It does **not** contain Valve assets, HLAE, MIGI, the Scaleform addon, ReShade, or a ready-made `panorama.my.zip`.

## What you need

1. A working legacy **32-bit** CS:GO installation containing `csgo.exe`.
2. [MIGI](https://github.com/ZooLSmith/MIGI3) for that game build.
3. A compatible `p_scaleform` UI addon, obtained separately. The [original addon](https://github.com/abandonedpools/scaleform) documents the older MIGI/HLAE method; other variants may differ.
4. [HLAE](https://github.com/advancedfx/advancedfx) **once**, to generate your own original `panorama.org.zip`. It is not used for normal Bridge launches.
5. Python 3. In Command Prompt, check `py -3 --version`.

Test the unmodified game first. Keep backups of any working addon and original ZIP. Download external tools from their own projects rather than game-file repacks.

## First-time setup

### 1. Install MIGI beside CS:GO

Follow [MIGI's installation guide](https://github.com/ZooLSmith/MIGI3). On Windows, `migi.exe` belongs beside `csgo.exe`. Start MIGI and let it create its `migi/csgo` structure:

```text
Counter-Strike Global Offensive/
├── csgo.exe
├── migi.exe
└── migi/csgo/addons/
```

### 2. Install the UI addon into MIGI

Extract your separately obtained addon so the folder is exactly:

```text
Counter-Strike Global Offensive/migi/csgo/addons/p_scaleform/panorama/
```

The `panorama` folder should contain `layout`, `scripts`, and `styles`. Avoid an extra wrapper folder such as `addons/Scaleform-UI-CSGO-main/p_scaleform/`. Click **Build / Update Build** in MIGI. Rebuild after every addon change. MIGI's [addon guide](https://zoolsmith.github.io/MIGI3/0_Using_MIGI/1_Installing_addons/) explains the `p_` format.

### 3. Get your original Panorama archive

If `%APPDATA%\HLAE\panorama.org.zip` already exists from **your own game**, keep it and skip the one-time HLAE launch.

Otherwise, follow [HLAE's Panorama guide](https://github.com/advancedfx/advancedfx/wiki/How-to-change-Panorama-UI) to run legacy CS:GO once with `-panorama -afxDetourPanorama` in windowed mode. Exit the game and confirm that `%APPDATA%\HLAE\panorama.org.zip` exists. The windowed launch is only for this extraction step. Do not download somebody else's ZIP.

### 4. Build `panorama.my.zip` locally

Open **Command Prompt** in the Panorama Bridge folder. Replace the addon path below with your installation path:

```bat
py -3 build_archive.py --original "%APPDATA%\HLAE\panorama.org.zip" --addon "C:\path\to\Counter-Strike Global Offensive\migi\csgo\addons\p_scaleform\panorama"
```

Success prints `Created ...\panorama.my.zip with ... stored file entries`. Keep `panorama.my.zip`, `PanoramaBridge32.dll`, `panorama-inject32.exe`, and `enable-replacement.flag` together in this folder.

The builder merges the original UI with the addon and fixes a few old team-menu mismatches. It writes a STORE-only ZIP with no directory entries. **Do not repack it with another archiver**: additional ZIP metadata has caused Panorama initialization failures.

### 5. Start the Bridge before CS:GO

Exit CS:GO completely. In Command Prompt, run:

```bat
cd /d "C:\path\to\panorama-bridge-public"
panorama-inject32.exe csgo.exe
```

Leave that window waiting for the game process.

### 6. Launch CS:GO through MIGI

Use MIGI's **Launch MIGI** button, making sure `-insecure` is set. Alternatively, for the legacy CS:GO executable, use these Steam launch options:

```text
-insecure -game migi/csgo -console
```

Do **not** add `-afxDetourPanorama` and do not start HLAE for this launch. Open a local map or demo and check that the classic HUD appears. For a local-map console test:

```text
map de_mirage
```

`PanoramaBridge.log` appears beside the DLL. An injector success message confirms the DLL loaded, not that the UI works; verify the menu and HUD in-game.

## Everyday launch

1. Leave your generated ZIP, the DLL, EXE, and flag together.
2. Start `panorama-inject32.exe csgo.exe` **before** CS:GO.
3. Launch legacy CS:GO through MIGI with `-insecure -game migi/csgo`.

Rebuild the ZIP if the original archive or the addon's `panorama` files change. If you edit a MIGI addon, click **Build / Update Build** in MIGI again too.

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
| Game starts but classic UI is missing | Check that `panorama.my.zip` and `enable-replacement.flag` are beside the DLL and that the injector ran **before** CS:GO. Read the log. |
| Injector succeeds but UI is unchanged | Confirm this is legacy 32-bit `csgo.exe`, not CS2. Confirm MIGI's build is current. |
| Builder says addon is incomplete | Point `--addon` to the inner `p_scaleform/panorama` directory, not the outer download folder or archive. |
| Builder cannot find expected UI text | The addon variant differs from the tested one. Do not force a mismatched archive; adapt the compatibility patch in `build_archive.py`. |
| Game works only without the replacement ZIP | Remove `enable-replacement.flag` for Bridge pass-through mode; this isolates archive problems from hook problems. |
| MIGI edits do not appear | Rebuild MIGI and confirm `-game migi/csgo` is active. |

Old addons can also print localization, sound, or map warnings unrelated to the Bridge.

## Optional: rebuild the binaries

The included EXE and DLL are the tested x86 binaries. To compile from source, open an **x86 MSVC Developer Command Prompt** in this folder and run:

```bat
build_x86.cmd
```

The repository includes `PanoramaBridge.cpp`, an adapted `injector.cpp`, and `minhook/`. ReShade is neither required nor bundled for the Panorama Bridge. Install and configure it separately if you want shaders.

## Sharing and credits

**Do not upload** `panorama.my.zip`, `panorama.org.zip`, extracted Panorama files, game assets, logs, or personal presets. The generated ZIP contains game-owned content. `.gitignore` excludes ZIPs and logs, but inspect your upload anyway.

- Injector: adapted from [ReShade's injector](https://github.com/crosire/reshade/blob/main/tools/injector.cpp), copyright Patrick Mours, BSD-3-Clause; see `LICENSE-ReShade.txt`.
- Hooking: [MinHook](https://github.com/TsudaKageyu/minhook); see `minhook/LICENSE.txt`.
- Panorama approach: informed by [HLAE's public implementation](https://github.com/advancedfx/advancedfx); no HLAE code or assets are bundled.
- UI addon: obtained separately. Credit the creators of the variant you use, including the [original Scaleform addon](https://github.com/abandonedpools/scaleform) where applicable.

Bridge-specific source is under `LICENSE-Bridge.txt`. Third-party components retain their own licenses.
