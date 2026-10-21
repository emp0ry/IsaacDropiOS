# Isaac Drop (Ctrl) for iOS

A separate native input mod for The Binding of Isaac: Repentance on iOS.
It does not require or modify External Item Descriptions, Steam Sync, or Debug
Console. They can remain installed independently.

[Website](https://isaacctrlios.emp0ry.com/) ·
[Downloads](https://github.com/emp0ry/IsaacDropiOS/releases/latest) ·
[Report a bug](https://github.com/emp0ry/IsaacDropiOS/issues)

## Downloads

| Your setup | Release file |
| --- | --- |
| Rootless jailbreak / ElleKit | [IsaacDrop-rootless.deb](https://github.com/emp0ry/IsaacDropiOS/releases/latest/download/IsaacDrop-rootless.deb) |
| LiveContainer app-specific tweaks | [IsaacDrop-LiveContainer.framework.zip](https://github.com/emp0ry/IsaacDropiOS/releases/latest/download/IsaacDrop-LiveContainer.framework.zip) |
| Direct embedding | [IsaacDrop-Embedded.zip](https://github.com/emp0ry/IsaacDropiOS/releases/latest/download/IsaacDrop-Embedded.zip) |
| Standalone ARM64 library | [IsaacDrop.dylib](https://github.com/emp0ry/IsaacDropiOS/releases/latest/download/IsaacDrop.dylib) |
| PlayCover on Apple silicon | [IsaacDrop-PlayCover.dylib](https://github.com/emp0ry/IsaacDropiOS/releases/latest/download/IsaacDrop-PlayCover.dylib) |

Use one loading method, then fully restart Isaac. Check release files against
[SHA256SUMS](https://github.com/emp0ry/IsaacDropiOS/releases/latest/download/SHA256SUMS).

## Controls

The **bottom-left 72 x 64 screen points** are an invisible Drop control during
an unpaused run. The zone ends at the actual screen edge, not the game HUD edge.

- **Tap:** advance D Infinity by one die. Holding starts with the same single
  switch; it does not repeatedly cycle. Other short-press Ctrl behaviors are
  not yet fully supported by the iOS touch-control path.
- **Hold:** keep native Drop pressed for the game's normal drop threshold,
  usually a few seconds, to drop eligible trinkets and pocket items. A trinket
  is not required to press the control.
- Sliding out cancels. Pause, menus, backgrounding and loss of the game host
  release input. A ten-second watchdog prevents a lost touch-end from sticking.

No text, icon, outline, highlight, or extra window is drawn. Only the two small
control zones receive touches; the game retains the rest of the screen. The Drop
control uses the shared native action, not a separate delete-card command:
native rules and restrictions still apply.

### Restart (R)

- Hold **R** on a hardware keyboard, or hold the invisible **top-center
  72 x 64 point** zone, for **1 second** to start a fresh run. Keep holding to
  restart repeatedly at **1-second intervals**; release to stop.
- A short press does nothing. Releasing, sliding out, pausing, opening text
  entry, losing focus or suspending the game cancels an unfinished hold.
- The native restart queue retains the character, difficulty and native seed
  rules. This is not the R Key collectible: acquired items are not retained.
- Repeats wait for the previous native restart to finish; a slow load can make
  an interval longer, but requests never pile up. The keyboard shortcut uses the
  physical R key in PlayCover, including with a non-English keyboard layout.
- Native restrictions still apply, including Eden token checks. Menus, paused
  runs, transitions and text fields do not accept the shortcut.

The initial native restart was confirmed in PlayCover. The repeating-hold
update has host tests and still needs gameplay confirmation. It does not replace
or disable the bottom-left Drop control or the other installed mods.

## Installation

- **Rootless jailbreak:** install `packages/IsaacDrop-rootless.deb` with ElleKit.
- **LiveContainer:** import `packages/IsaacDrop-LiveContainer.framework.zip` into
  Isaac's app-specific tweak folder, then fully restart Isaac.
- **Embedded app:** normally sign and embed `IsaacDrop.dylib` inside the app,
  for example using `@executable_path/Frameworks/IsaacDrop.dylib` as its load path.
  The embedded archive contains no game or resource database.
- **PlayCover:** use `IsaacDrop-PlayCover.dylib`, the Mac Catalyst build, instead
  of the iPhone library. Embed it using your existing signed-app workflow and
  preserve the app's entitlements and other mods. To replace an existing Drop
  installation, keep its load path and replace just its library. Fully restart
  Isaac afterward. This is for the iOS game in PlayCover, not native macOS Isaac.

Use one loading method per installation. The dylib has no jailbreak dependency.
ElleKit is needed only for the optional jailbreak loader package. No JIT or
writable executable memory is requested.

## Compatibility

Targets native Isaac iOS **1.4 / Repentance 1.7.9b.J754**, ARM64 UUID
`F4357753-A25F-30EE-BACF-63709F902895`. Unknown binaries fail closed.

The native touch device's Drop pressed/triggered/value queries use a private
copy of its complete method table and RTTI. Only that validated writable input
object's table pointer changes. Protected original tables remain untouched.
No page-protection changes, instruction patching, native
item removal, active-item invocation, save editing, or injected UITouch is used.
Except for an accepted R shortcut, physical input and other actions pass through
unchanged. A foreign hook in these exact slots is rejected rather than overwritten. The mod disables
itself if table, object, or executable validation fails.

Tap edge state follows the existing native display link timestamp, keeping
multiple queries in one game frame consistent. Short taps are retained until
sampled. Startup waits for the real guest render view and advancing native
frames, including LiveContainer; it does not force controller/view loading.
One bounded, read-only background scan locates the randomized native touch
object. The main thread revalidates it before attaching the private method table;
no full-process scan runs in the game render loop.

### D Infinity on touch controls

The iOS controller has a separate native input branch which skips the keyboard's
D Infinity switch logic. Version 0.1.1 therefore applies that verified mode
transition once per touch-down to the touch-controlled player's main active
slot. It validates the executable UUID, native instructions, player/controller,
input restrictions, writable state and the current mode (0–9), then changes only
the 16-bit mode and calls the game's native HUD refresh. It neither uses the die
nor spends charge. On D100 → D1 it also preserves the native Schoolbag slot swap.
Keyboard/gamepad players are excluded to avoid double switching. The hold-to-drop
input adapter is unchanged; unsupported binaries never receive this state write.

## Build and tests

On macOS with Xcode and an iPhoneOS SDK, Python 3, Node.js, ripgrep and dpkg:

```sh
make release
```

Outputs: iPhone and PlayCover ARM64 dylibs, rootless deb, LiveContainer framework,
embedded zip, and checksums in `dist/`. Host checks cover Drop, repeating restart
timing, loading transitions, cancellation and keyboard-hook chaining. See
[device checks](docs/TESTING.md) for gameplay acceptance.
Diagnostic log: `Library/Application Support/IsaacDrop/drop.log` inside Isaac's
own sandbox. No account credentials or saves are logged.

Native hold-to-drop was confirmed on the development iPhone. The D Infinity
switching fix has build and policy-test coverage; gameplay confirmation of that
new adapter and the full loading-mode matrix is still pending.

## Website and releases

`docs/` is a buildless HTML/CSS/JavaScript site published with GitHub Pages from
`main:/docs`. Its custom domain is declared in `docs/CNAME`. There are no site
dependencies, analytics or account requirements. The small die-sequence demo is
an illustration, not remote game control. Download links work without JavaScript;
when available, GitHub's public API adds current release metadata.

One workflow, `.github/workflows/release.yml`, runs the tests, builds all package
formats and audits signatures/dependencies. A matching `v*` tag also publishes the
verified files with `docs/RELEASE_NOTES_v<version>.md` and SHA-256 checksums.

This is an independent, unofficial mod. No Isaac IPA, extracted game assets or
purchase bypass is included. Source: MIT license, copyright emp0ry.
