# Isaac Fixes for iOS

Small native control and HUD fixes for The Binding of Isaac: Repentance on iPhone and in PlayCover. Previously **Isaac Drop (Ctrl)**. One mod includes Drop, restart, pause, Enter/Space, Mac fullscreen, sharper Mini Extra HUD icons, and Planetarium Chance.

[Website](https://isaacfixesios.emp0ry.com/) · [Downloads](https://github.com/emp0ry/IsaacFixesiOS/releases/latest) · [Changelog](CHANGELOG.md) · [Report a bug](https://github.com/emp0ry/IsaacFixesiOS/issues)

## Controls

| Control | Action | Where |
| --- | --- | --- |
| Bottom-left invisible zone: tap | Switch D Infinity to the next die without using it or spending charge | iPhone / PlayCover |
| Bottom-left invisible zone: hold | Native Drop for eligible trinkets, cards, runes, and pills; no trinket required | iPhone / PlayCover |
| Ctrl with D Infinity | Switch once per press; holding does not cycle repeatedly and still allows native Drop | Hardware keyboard / PlayCover |
| Hold R, or hold the top-center invisible zone | Fresh run after 1 second; repeat every second until released | Hardware keyboard / touch |
| Esc | Native pause/resume, one toggle per press | Hardware keyboard / PlayCover |
| Enter / keypad Enter | Same native input as Space, including confirming the selected pause-menu entry | PlayCover |
| F | Toggle native macOS fullscreen on/off, one toggle per press | PlayCover |

The two touch zones are **72 x 64 screen points**, invisible, and enabled only during an unpaused run. Sliding out, pausing, backgrounding, or losing the game host cancels held input.

Restart follows the game's normal character, difficulty, seed, and Eden-token rules. This is not the R Key item and does not keep acquired items. Slow loading can lengthen the repeat interval; restart requests do not pile up.

Enter on **Continue** resumes; Enter on **Options** opens Options. It is not a forced pause toggle or a direct active-item call. The physical Space key still works. F uses macOS's native fullscreen transition and returns to windowed mode when pressed again.

In PlayCover, the mouse cursor hides after **3 seconds** without mouse activity during an unpaused run. Move or click to show it again. It stays visible in menus, on pause, over open mod panels, outside the game content and while another window/app is focused. No global mouse monitoring or extra system permissions are used.

Normal text fields, Debug Console input, dialogs, and modified keyboard shortcuts are left alone. D Infinity cycling and hold-to-drop are supported; other short-press Ctrl behaviors are not yet fully supported by the iOS touch path.

## Sharper Mini HUD

Enable **Extra HUD: Mini** in the game's own options. The mod displays the original 32x32 item art directly at screen resolution in the same compact cells, avoiding the game's intermediate reduction to 16x16. No smoothing or global filter is enabled. It reads icons from your installed game; no game art is included in the download.

Normal HUD, paused menus, procedural/special-shader icons, missing art, and cells smaller than 32 physical pixels keep the native renderer. Confirmed working in PlayCover; physical iPhone testing remains separate.

## Planetarium Chance

Adds a Planetarium percentage to Found HUD, following the Repentance behavior of [Planetarium Chance by Peachee/Sectimus](https://github.com/Sectimus/isaac-planetarium-chance). The original game icon and LuaMiniOutlined bitmap font are read from your own installation, at 50% opacity. The row follows HUD offset, difficulty, character counters and Duality. A changed floor percentage briefly shows a green increase or red decrease.

The percentage comes from Isaac's native chance getter and is captured per floor, not continuously recalculated after entering a treasure room or collecting an item. Unlock/run restrictions are checked without spawning entities or consuming RNG. Pause menus, Found HUD off, HUD-invisible states, NO HUD seeds, floor loading, boss introductions, cinematics and the Beast arena hide the row. Ordinary door slides keep it visible. Resuming restores the same percentage; any change popup is frozen while paused. Greed retains a 0% row. A bounded mod-only preferences cache preserves observed floor snapshots across Continue; it does not edit Isaac saves or Steam Cloud.

Dogma's death flash also hides the row after animation frame 80, like the original. Confirmed working in PlayCover. Host logic and supported-binary checks pass; separate physical iPhone coverage, unusual co-op setups and cutscene timing still need acceptance testing.

## Downloads

| Setup | File |
| --- | --- |
| Rootless jailbreak / ElleKit | [IsaacFixes-rootless.deb](https://github.com/emp0ry/IsaacFixesiOS/releases/latest/download/IsaacFixes-rootless.deb) |
| LiveContainer app-specific tweaks | [IsaacFixes-LiveContainer.framework.zip](https://github.com/emp0ry/IsaacFixesiOS/releases/latest/download/IsaacFixes-LiveContainer.framework.zip) |
| Direct iOS embedding | [IsaacFixes-Embedded.zip](https://github.com/emp0ry/IsaacFixesiOS/releases/latest/download/IsaacFixes-Embedded.zip) |
| Standalone iPhone ARM64 library | [IsaacFixes.dylib](https://github.com/emp0ry/IsaacFixesiOS/releases/latest/download/IsaacFixes.dylib) |
| PlayCover on Apple Silicon | [IsaacFixes-PlayCover.dylib](https://github.com/emp0ry/IsaacFixesiOS/releases/latest/download/IsaacFixes-PlayCover.dylib) |

Use one loading method and one copy only, then fully restart Isaac. Verify downloads with [SHA256SUMS](https://github.com/emp0ry/IsaacFixesiOS/releases/latest/download/SHA256SUMS).

## Install or update

- **Rootless jailbreak:** install the DEB with your package manager. Its package identity is retained so it upgrades the old Isaac Drop package.
- **LiveContainer:** replace the old Drop framework with the new app-specific framework. Do not keep both copies enabled.
- **Embedded iOS app:** embed `IsaacFixes.dylib`, normally at `@executable_path/Frameworks/IsaacFixes.dylib`, and sign the complete app.
- **PlayCover:** use `IsaacFixes-PlayCover.dylib`, not the iPhone dylib. Embed it as `IsaacFixes.dylib` and re-sign with the existing app entitlements. Keep EID, Steam Sync, Debug Console, and other independent mods intact.

When replacing an existing embedded Drop installation, you can keep its current `IsaacDrop.dylib` load path and replace that file with the new build. Alternatively, update the load path to `IsaacFixes.dylib`. **Do not load both old and new copies.** Remove the separate experimental `IsaacEnterSpace.dylib` load command if you installed it; Enter is now included here.

Back up your app before changing its embedded libraries. Fully restart Isaac after installation. No IPA, game executable, extracted game assets, or save files are distributed.

## Compatibility and limits

- Isaac iOS **1.4 / Repentance 1.7.9b.J754**, ARM64, iOS 15 or newer.
- PlayCover supports the iOS game, not the native Windows/macOS Isaac executable.
- Unknown game binaries and incompatible native handlers are rejected.
- Independent of EID, Steam Sync, and Debug Console; no configuration panel or account required.
- Apple system libraries only in the dylib. ElleKit is needed only for the optional jailbreak loader package. No JIT, writable executable memory, global key injection, or save editing.

The Drop adapter preserves the native input object's full method table and RTTI in a private writable copy. The Enter alias uses validated native keyboard handlers. R and Esc use verified native game paths; F uses the owning Mac window's public fullscreen API. Startup waits for the existing render view and advancing game frames, without forcing a view load or creating another game window.

## Build and check

With macOS, Xcode, an iPhoneOS SDK, Python 3, Node.js, ripgrep, and dpkg:

```sh
make release
```

Downloads and checksums are generated in `dist/`. Host checks cover Drop, restart timing, R/Esc/F routing, Enter/Space menu input, text-field guards, and fullscreen transitions. They do not replace gameplay/device testing. The release notes distinguish newly added functionality from device-confirmed behavior.

[Device checklist](docs/TESTING.md). Diagnostic log inside Isaac's sandbox: `Library/Application Support/IsaacFixes/fixes.log`.

## Website and releases

The [product website](https://isaacfixesios.emp0ry.com/) is also available at [emp0ry.com/IsaacFixesiOS/](https://emp0ry.com/IsaacFixesiOS/). Website sources and publication are maintained in the private emp0ry.com project. Completed application releases notify its central static build; this repository contains the application and its technical documentation.

Tagging the version from `package/control` builds the packages and publishes the matching section of [CHANGELOG.md](CHANGELOG.md), without repeating the release title in its body.

Independent, unofficial software by emp0ry. Not affiliated with Nicalis. MIT license.
