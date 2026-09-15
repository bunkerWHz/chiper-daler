# Prototype menus

The project starts at `MainMenu.tscn`. New Game opens the existing
`MovementSandbox.tscn`; change `GameFlow.FIRST_LEVEL` when the first level is ready.
Escape opens the pause menu during gameplay. Save there before returning or quitting.

One manual slot stores the level path and the player's respawn checkpoint in
`user://checkpoint.cfg`. Loading recreates the level at that checkpoint: inventory,
experience, enemies and other world state are reset. This is a checkpoint prototype,
not a full playthrough save. New Game clears in-memory checkpoints but retains the
disk slot until the next manual save. Missing/invalid saves cannot be loaded.

Master volume, fullscreen and VSync apply immediately and persist in
`user://settings.cfg`. Buttons support Godot's standard keyboard/gamepad UI actions.
Window resolution also persists. The list includes preset sizes that fit the current
monitor's usable area, allowing space for window decorations. Fullscreen uses the
monitor resolution; the window-size picker is disabled until windowed mode returns.
The logical 1280×720 viewport stays unchanged so resolution does not alter gameplay.

Replace the `Background/Color` node with a full-rect TextureRect, or add an animated
scene beneath `Background`. Keep decorative Controls at `mouse_filter = Ignore`.
The foreground menu and behavior do not depend on the background. Pause-menu
background animations must process while paused if animation is desired there.

Validation: run `tests/menu_runtime_check.gd` with `--script` and an isolated
APPDATA/LOCALAPPDATA directory, e.g. `.godot/test-user`. The test writes and removes
saves/settings in that isolated profile. It checks disk persistence, malformed saves,
scene transitions, pause release and resetting checkpoints for a new game.
