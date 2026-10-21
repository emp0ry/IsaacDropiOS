## Added

- **Esc** pauses the active run and resumes from the normal pause menu.
- UIKit hardware-keyboard and PlayCover support, with one toggle per press;
  autorepeat does not repeatedly pause/unpause.
- Accepting Esc cancels the held-R restart loop. Text input, presented dialogs,
  menus and modified shortcuts are left to their existing handlers.

The adapter calls verified native pause-menu entry and animated-exit functions,
including the native manager audio-resume path. It does not overwrite the pause
state directly. Unsupported builds and transitions fail closed. Bottom-left
Drop, top-center Restart and one-second held-R repetition are unchanged.

The iPhone library, rootless package, LiveContainer framework, embedded archive
and separate PlayCover library are included, with SHA-256 checksums. Use one
copy per game installation and restart Isaac after updating.

Host checks cover Escape routing, autorepeat, modifiers, ignored presses and
existing-handler chaining. Native signatures were checked against the supported
iOS executable; Escape gameplay verification is pending. No game app, assets
or saves are distributed.
