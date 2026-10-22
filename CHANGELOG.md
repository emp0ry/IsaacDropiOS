# Changelog

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
