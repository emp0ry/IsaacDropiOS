Adds native fresh-run restart controls alongside the existing invisible Drop
control. EID, Steam Sync and Debug Console remain independent.

## Added

- Hold **R for 1 second** to restart. Keep holding for repeated restarts at
  **1-second intervals**; release to stop.
- An invisible **top-center 72 x 64 screen-point** touch zone with the same
  hold-to-restart behavior. The bottom-left Drop zone stays in place.
- Physical R-key support in PlayCover, including non-English keyboard layouts,
  plus UIKit hardware-keyboard support.
- A separately signed **Mac Catalyst library for PlayCover**.

## Behavior and safety

- Uses the game's native fresh-run queue. Character, difficulty, seed rules
  and Eden-token restrictions follow the native restart path. This is not the
  R Key collectible: acquired items are not kept.
- Short presses do nothing. Sliding out, pausing, opening text entry or dialogs,
  backgrounding and focus loss cancel the held restart.
- Repetition survives its own native loading transition. It waits for the
  previous restart to finish, so slow loads can lengthen the interval without
  queuing a burst of restarts.
- Native executable UUID and restart-function checks fail closed on unsupported
  builds. No executable-page patching or direct save-file editing is used.
- Keyboard handling chains existing input handlers, preserving the Debug Console
  grave shortcut and unrelated game input.

## Downloads

- `IsaacDrop-rootless.deb`: rootless iPhone jailbreak with ElleKit.
- `IsaacDrop-LiveContainer.framework.zip`: Isaac-specific LiveContainer tweak.
- `IsaacDrop-Embedded.zip`: iPhone library, license and installation notes.
- `IsaacDrop.dylib`: standalone iPhone ARM64 library.
- `IsaacDrop-PlayCover.dylib`: Mac Catalyst ARM64 library for the iOS game in PlayCover.
- `SHA256SUMS`: checksums for all five distribution files.

Use only one copy per game installation and fully restart Isaac after updating.
Existing PlayCover installations must use the PlayCover library, not the iPhone
one. No game app, extracted assets, accounts or saves are distributed.

## Verification

The initial native restart was gameplay-confirmed in PlayCover. Continuous
one-second repetition has host coverage for timing, transitions, cancellation,
unchanged seeded-run identities and preventing duplicate requests; gameplay
confirmation of the repeated-hold behavior and the full loading-mode matrix
is still pending. Drop, keyboard routing, source/site checks, distribution
builds, signatures and checksums are verified by the release workflow.
