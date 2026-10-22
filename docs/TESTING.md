# Device acceptance

## Planetarium Chance checks

Use a disposable, non-challenge Normal run with Planetariums unlocked. Enable Found HUD in the game's options. These commands change the test run; the HUD itself is read-only with respect to game state and RNG.

1. On Basement I, the Planetarium icon and `1.0%` should appear below the deal-chance rows. Compare with the original Planetarium Chance mod on Windows. Check font, 50% opacity, spacing, hard/normal mode and HUD offset 0 / 1.
2. Skip the Basement I treasure room and reach Basement II (`stage 2` may be used for a disposable console test). Expect `21.0%` and a temporary green `+20.0%`. Enter the treasure room: the current floor snapshot must not change. On the next floor it should reflect visits and modifiers.
3. In a fresh run, enter the Basement I treasure room before advancing. Expect `1.0%` next floor, without a change popup. For item modifiers, give Magic 8 Ball (`giveitem c194`), Sausage (`giveitem c669`) or Crystal Ball (`giveitem c158`); check on the next floor, not immediately. Crystal Ball also has skipped-treasure-room behavior, so do not assume it is always just +15%.
4. Exit to menu and Continue; repeat after a full app restart. The observed floor percentage should be retained, without a new delta popup. Test a new run, held-R restart, R Key (`giveitem c636`) and Forget Me Now (`giveitem c127`) separately; the last two preserve other run state and need same-stage regeneration coverage.
5. Pause with the native pause button and with Esc: the icon, percentage and delta popup must disappear. Open Options and EID Items while paused; the row must remain hidden. Resume: the same percentage should return, with any unfinished popup continuing, not restarting. Repeat several times. Toggle Found HUD off/on. Check Greed (0%), an account without Planetariums unlocked (0%), Ascent (0%), and the NO HUD seed (hidden). Check Bethany/Tainted Bethany, Jacob & Esau, true co-op and Duality (`giveitem c498`) for overlap. Character changes must move the row without changing this floor's chance.
6. Confirm hiding during transitions, loss of native HUD visibility and the Beast arena. Compare the end of Dogma's death animation against the original: the row should disappear after animation frame 80 and stay hidden over the flash. Report any remaining visible row over it.
7. Check Mini HUD, EID, Steam Sync, Console, Drop, R, Esc, Enter and F still work. A successful compile/ABI log is not visual acceptance. Expected log: `Planetarium native getter/HUD ABI validation passed`, followed by one `Planetarium floor snapshot` per floor, not per room/item.

Restart Isaac after replacing/installing the mod. Use a disposable run: console
commands and the native Drop action change gameplay. Installation itself does
not change saves. The control is intentionally invisible.

1. Start/Continue a run. Tap the 72 x 64 points in the bottom-left corner.
2. `giveitem c489`: D Infinity. Each distinct tap should advance one die, not
   cycle continuously. Repeated fast taps should still have released frames.
   Check the full order: D1 → D4 → D6 → Eternal D6 → D7 → D8 → D10 → D12 → D20
   → D100 → D1. Charges, pickups and the room should not change just by tapping.
   With Schoolbag and a second active item, wrapping from D100 should perform
   the native active-slot swap, without using either item.
3. Without equipped trinkets, `spawncard 1`, pick it up, then hold the zone for
   about three seconds. The card should drop, not activate or disappear.
4. Repeat with `spawncard 32` (a rune) and `spawnpill 1`. The normal game rules
   decide the result; there is no direct pocket-item mutation.
5. `spawntrinket t1`, pick it up with a card held, then hold the zone. Check the
   game's normal trinket/pocket dropping behavior and immediate release afterward.
6. With D Infinity, hold without lifting: the first edge should switch at most
   once; holding must not produce a new synthetic trigger every frame.
   Repeat with physical Ctrl in PlayCover: hold for at least five seconds,
   then release and press again. Expect exactly one switch for each press,
   including the D100 wrap with Schoolbag. With a card held, long Ctrl must
   still drop it. Also check release/repress after pause and switching apps.
7. Keep moving/shooting with the other finger while tapping the corner. Existing
   game sticks must remain usable, with no stuck stick on cold launch.
8. Drag out, pause, background, and reopen while holding. Input must release;
   no queued press should occur on Continue or in a menu. Check EID/console pause
   buttons and settings remain usable.
9. Repeat in LiveContainer with only its app-specific framework loaded. Device
   testing on a jailbreak is not proof of every non-jailbroken runtime policy.

## Restart checks

Use a disposable run: these checks intentionally replace the current run.

1. Tap R or the top-center 72 x 64 point zone for less than one second. Nothing
   should restart. Hold either for one second: a fresh run should begin with
   the same character and difficulty, without acquired items.
2. Keep R held across at least three restarts. Repeat with one held finger in
   the top-center zone. The interval should be one second, or longer when a
   native load has not finished. Release and confirm the loop stops immediately.
3. Repeat in a seeded run, where the native seed can remain unchanged. Repeating
   must still work, without issuing multiple requests into a single transition.
4. Cancel a hold by sliding out, pausing, opening a dialog/text field, switching
   apps or losing focus. Returning to the run must not resume the cancelled hold.
5. In PlayCover, test physical R in English and another keyboard layout. Shift,
   Ctrl, Option and Command combinations must not start a restart. The Debug
   Console grave shortcut and typing R in a text field must still work.
6. Check the native Eden-token restriction and unsupported-game fail-closed
   behavior. Repeating must never bypass native restart restrictions.

Press Esc in an active run to pause, hold it to confirm it does not toggle again,
then release and press once to resume. Check the native pause animation, music,
R-loop cancellation, and typing in Console/Steam fields without changing pause.

Log checkpoints: `native Drop instance adapter installed`, `IsaacFixes 0.3.3 ready`,
`live player vector validated`, `D Infinity touch-switch code validation passed`,
`native fresh-run restart code validation passed`, and
`native fresh-run restart queued; 1-second repeat while held`. With D Infinity
equipped, look for `D Infinity touch switch <old> -> <new>`.
Build/source checks and loading logs alone do not prove gameplay acceptance.

## PlayCover Enter and fullscreen

1. Fully restart after replacing the library. Load only the combined Isaac Fixes copy, not the old standalone Enter mod.
2. Pause, select Continue, and press Enter: resume. Pause again, select Options, and press Enter: open Options instead of forcing a resume. Repeat with keypad Enter.
3. Check Enter against physical Space with a charged active item in a disposable run. Hold both keys in each order and release them; input must not stick.
4. Open Debug Console, type `help`, and press Enter. It must execute the command, not activate a game item. Check Steam text fields too.
5. In a menu, run, and pause menu, press F to enter macOS fullscreen. Release and press F to leave. Holding F must not loop; extra presses during the animation must not queue toggles.
6. Try F with a Russian keyboard layout, then Command/Control/Option/Shift+F and F in text fields. Only the unmodified physical F shortcut should toggle fullscreen in the game window.
7. Confirm Drop, D Infinity, R, Esc, EID, Steam Sync, and Debug Console still work. The log should include `native Enter/Space alias installed` and `R, Escape and F input installed`.

Host checks include fullscreen transition/failure handling and the actual native Enter adapter with a simulated pause selection. These are not a substitute for the in-game checks above.

## PlayCover cursor auto-hide

1. During an unpaused run, leave the mouse inside the game content without moving or clicking. After 3 seconds the cursor should disappear, including while playing with the keyboard. Move or click: it should return immediately.
2. Pause with Esc or the game's button, open Options, EID settings/items, Console and Steam dialogs. Leave the pointer still for more than 3 seconds: it must remain visible. Resume: start a new 3-second idle interval.
3. Move to the title bar or outside the window, switch apps, minimize and restore, and enter/leave fullscreen with F. The cursor must remain usable outside the game and restart its idle delay on return.
4. Hold a mouse button or drag a control: it must not hide during the drag. Close/reopen the run and test another app window gaining focus. Existing mouse events, Ctrl, R, Esc, Enter and F must remain unchanged. Physical iPhone pointer behavior is intentionally unchanged.

## Extra HUD: Mini quality

The first experiment used linear minification and was rejected in gameplay because it blurred the icons. It must not be enabled again or described as a confirmed quality fix.

1. Fully restart after installing the test build. Switch normal Extra HUD to Mini, wait several seconds, then switch Off and back to Mini. There must be no delayed smoothing, doubled icons or stale overlays.
2. Compare the same existing items in normal and Mini HUD. For a disposable run, fine-detail examples are `giveitem c118`, `giveitem c182`, `giveitem c331`, and `giveitem c395`. The source remains 32x32 rather than being reduced to 16 game pixels first.
3. Resize the PlayCover window and enter/exit fullscreen. Icons must retain the native compact cells, order, right-edge alignment and translucency. At fewer than 32 physical pixels per cell, keep the native renderer instead of claiming recovered detail.
4. Pause, open Options/EID/Console, resume, leave the run, and Continue. No icon must remain over menus. Normal HUD and all unrelated native draws retain the original renderer. Procedural art, special native shaders and missing PNGs fall back rather than disappearing.
5. Verify Drop, R, Esc, Enter, F, and other mods still work. No saves, options, assets, samplers, GL bindings or executable pages are changed. Image references are retained while an individual-image vptr adapter is active, restored before release, with all other methods and RTTI preserved.
6. Logs should contain `Mini HUD display-density adapter validation passed` and, after a matching draw, `Mini HUD full-source draw active` with virtual screen, view and physical icon dimensions. A screenshot or short recording is still needed for visual acceptance; passing build checks alone are insufficient.
