# Isaac Drop (Ctrl) for iOS v0.1.1

First public release: an independent, invisible Drop control for native iOS
Repentance. It can be installed alongside EID, Steam Sync and Debug Console;
none of them is required.

## Controls

- **Bottom-left corner:** a clear 72 × 64 screen-point touch zone at the actual
  screen edge. Nothing is drawn over the game.
- **Tap with D Infinity:** advance exactly one die without using it or spending
  charge. Includes the native D100-to-D1 wrap and Schoolbag slot-swap behavior.
- **Hold:** supply native Drop input for the normal drop threshold, around three
  seconds, to drop eligible pocket items and trinkets. No trinket is required.
- Sliding out, pausing, backgrounding or losing the game host cancels the input.

The D Infinity adapter fixes a difference in the native touch-controller path:
the iOS game skips the keyboard/controller mode-switch branch. Holding Drop
continues to use the native input path.

## Packages

| File | Setup |
| --- | --- |
| `IsaacDrop-rootless.deb` | Rootless jailbreak with ElleKit |
| `IsaacDrop-LiveContainer.framework.zip` | Isaac-specific LiveContainer tweak |
| `IsaacDrop-Embedded.zip` | Dylib, license and installation notes for embedding |
| `IsaacDrop.dylib` | Standalone ARM64 library |
| `SHA256SUMS` | Checksums for the four distribution files |

Use one loading method, then fully restart Isaac. For directly embedded builds,
sign the dylib and complete application bundle. The dylib has no jailbreak-only
dependencies and does not request JIT or writable executable memory.

## Website and documentation

[isaacfixesios.emp0ry.com](https://isaacfixesios.emp0ry.com/) includes a touch-zone
diagram, D Infinity sequence demonstration, downloads and installation steps.
The site source lives in `docs/`, with a single build/release workflow for every
distribution format.

## Compatibility and verification

- Native Isaac **iOS 1.4 / Repentance 1.7.9b.J754**, ARM64, iOS 15 or later.
- Executable UUID, method table, object layout and D Infinity branch validation;
  unknown builds are left untouched.
- Local C++ input-policy tests, source/site checks, ARM64 build, code-signature
  verification and dependency audit passed before publication. CI repeats the
  build for published release files.
- Native hold-to-drop was confirmed on the development iPhone. The D Infinity
  fix is included; gameplay confirmation of the new switching adapter and the
  complete loading-mode matrix is still pending.

This is not a full Ctrl/keyboard replacement: other short-press Ctrl behaviors
are not yet fully supported. The mod does not directly edit save files. No game
IPA, extracted game assets, accounts, credentials or user saves are distributed.

Report reproducible problems on [GitHub](https://github.com/emp0ry/IsaacFixesiOS/issues)
with the game version, loading method and steps to reproduce.
