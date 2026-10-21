# Device acceptance

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

Log checkpoints: `native Drop instance adapter installed`, `IsaacDrop 0.1.2 ready`,
`live player vector validated`, `D Infinity touch-switch code validation passed`,
`native fresh-run restart code validation passed`, and
`native fresh-run restart queued; 1-second repeat while held`. With D Infinity
equipped, look for `D Infinity touch switch <old> -> <new>`.
Build/source checks and loading logs alone do not prove gameplay acceptance.
