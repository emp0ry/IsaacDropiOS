# Changelog

## 0.3.1

- Hide Planetarium Chance and the display-density Mini HUD overlay during native floor transitions, fades, boss introductions, death screens and cinematics. Both remain hidden on pause.
- Validate the supported executable's presentation-state signatures before reading these states. This is read-only and does not alter native scene rendering, RNG, saves or assets.
- Cover the separate boss/large-sprite screen, fullscreen ANM2 playback, post-HUD screen counters and white fades that were missing from the first transition check. Wait for a continuously clear scene for 100 ms after loading/cinematics instead of showing an intermediate loading frame.
- Keep overlays visible through ordinary WALK door slides in all four directions, without restarting the visibility delay when the room descriptor changes. Fullscreen/fade transitions still hide overlays; console mutations retain the stricter transition guard.
- Give an open Debug Console priority over the normal Esc pause action, regardless of key-monitor installation order. Held/released Escape cannot close the console and then toggle pause again.
- Host checks cover presentation capture/failure states, scene re-entry and both UIKit/Mac key-monitor orders. The separate supported-binary presentation ABI check is read-only; these checks do not replace in-game verification of every cutscene.

## 0.3.0

- Add a native Planetarium Chance HUD row following the original Repentance mod: game-owned icon/font, 50% alpha, per-floor native chance snapshots, HUD offset and character/Duality positioning, and green/red change popups.
- Read unlock/run eligibility and the game's actual chance without advancing RNG, spawning a probe entity or editing saves. Keep observed floor snapshots in a bounded mod-only preferences cache for Continue.
- Hide the entire Planetarium row, including its change popup, while paused. Resume the same floor percentage and popup afterward without recalculating the chance.
- Hide with Found HUD disabled, native HUD invisibility, NO HUD seeds, transitions, the Beast arena and Dogma's death flash after frame 80. Greed keeps a 0% row.
- The user confirmed Planetarium Chance working in PlayCover. Host checks cover pause visibility, layout, chance gating, popup animation and the bounded bitmap-font parser; supported-binary getter/availability/HUD ABI checks and package/signature audits passed. Separate physical iPhone, unusual co-op and cutscene timing coverage remains pending.

## 0.2.1

- Withdraw the experimental Mini HUD linear minification change after in-game feedback: it blurred icons shortly after switching to Mini. No native sampler or GL state is changed by the replacement build.
- Improve Extra HUD: Mini icon clarity. Use full 32x32 PNGs from the user's game in the native compact layout, bypassing the low-resolution scene downsample without linear filtering. Native coordinates, ordering and alpha are preserved. Protected code, global samplers, saves and assets are unchanged.
- Validate the native Mini caller, all image-vtable methods/RTTI, and image-reference ABI before attaching to individual image objects. Other draws, normal HUD, paused menus, unknown/procedural art, and missing PNGs retain the original renderer.
- The user confirmed the sharper Mini HUD in PlayCover. Host checks, the supported binary's draw/ref ABI verification, and package/signature audits passed. Separate physical iPhone coverage is still needed.

## 0.2.0

Isaac Drop (Ctrl) is now **Isaac Fixes**: one native mod for the small controls missing from Isaac iOS and PlayCover.

- Keep invisible bottom-left Drop/Ctrl and D Infinity switching.
- Keep the top-center restart zone and hold-R fresh-run restart, repeating at one-second intervals until released.
- Keep Esc native pause/resume.
- Include the Enter / keypad Enter to Space alias in the same mod. Confirm the selected pause-menu entry or use the ordinary Space binding in gameplay. Physical Space and Debug Console text entry remain available.
- Add F to enter and leave native macOS fullscreen in PlayCover. Holding F toggles once; additional presses during the native animation do not queue more transitions.
- Fix the typing guard so the game's render view is not mistaken for a text editor.
- Replace the experimental desktop-event approach with the verified native keyboard callback path, avoiding the earlier Catalyst event-conversion crash.
- Rename downloads, website content, and project links to Isaac Fixes. The website moves to `isaacfixesios.emp0ry.com`; Cloudflare DNS must be updated separately.
- Retain the jailbreak package identity for upgrades. Replace old embedded Drop/Enter copies instead of loading duplicates.

Build, host checks, native key-table verification, package/signature audits, and website checks are run before publishing. F and the combined package still need full in-game/device coverage; host checks do not imply exhaustive gameplay testing.

## 0.1.3

- Add Esc native pause/resume for hardware keyboards and PlayCover.
- Preserve existing Drop, D Infinity, and repeating restart controls.

## 0.1.2

- Repeat native fresh-run restart every second while R or the restart touch zone is held.
- Wait for each native restart transition before queuing another request.

## 0.1.1

- Add verified D Infinity touch switching and native fresh-run restart controls.

## 0.1.0

- Initial invisible native Drop control for Isaac iOS.
