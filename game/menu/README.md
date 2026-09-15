# Menus and playthrough saves

The project starts at `MainMenu.tscn`. New Game opens the existing
`MovementSandbox.tscn`; change `GameFlow.FIRST_LEVEL` when the first level is ready.
Escape opens the pause menu during gameplay. Progress saves automatically and
before returning or quitting. The pause menu also offers an immediate manual save.

One slot stores the full character and persistent world flags in
`user://checkpoint.cfg`, with a previous valid snapshot in `.bak`. Loading returns
to the last successful restpoint, refills health/mana/flasks and respawns ordinary
enemies. New Game replaces the slot after starting the level. Corrupt primaries
fall back to the backup. The old version-1 checkpoint format remains readable.
Save failures appear in-game and prevent exiting until a write succeeds.
Death permanently removes 20% of carried amber (recoverable amount rounded down)
and leaves the remainder at the death position. Approaching it recovers it;
dying again destroys the previous unclaimed stash, even with an empty wallet.
The marker and balance persist together in version-3 saves; versions 1 and 2 migrate.
See [Save_System.md](../../docs/Save_System.md) for the schema, rules and TODO list.

Master volume, fullscreen and VSync apply immediately and persist in
`user://settings.cfg`. Buttons support Godot's standard keyboard/gamepad UI actions.
Window resolution also persists. The list includes preset sizes that fit the current
monitor's usable area, allowing space for window decorations. Fullscreen uses the
monitor resolution; the window-size picker is disabled until windowed mode returns.
The logical 1280×720 viewport stays unchanged so resolution does not alter gameplay.

Audio has three persistent controls: Master, SFX and Music. SFX and Music feed
Master in `default_bus_layout.tres`; zero mutes that bus. Existing actor effects
and voices use SFX. Route future jump, pickup and other effect players to SFX too.
For background music, instance `features/audio/BackgroundMusic.tscn` in a level
and assign its Stream (enable looping on the audio resource as appropriate).
It autoplays on Music. No soundtrack is assigned yet. Old settings files default
both category gains to 100%, preserving the previous overall listening level.

Replace the `Background/Color` node with a full-rect TextureRect, or add an animated
scene beneath `Background`. Keep decorative Controls at `mouse_filter = Ignore`.
The foreground menu and behavior do not depend on the background. Pause-menu
background animations must process while paused if animation is desired there.

Validation: run `tests/menu_runtime_check.gd` with `--script` and an isolated
APPDATA/LOCALAPPDATA directory, e.g. `.godot/test-user`. The test writes and removes
saves/settings in that isolated profile. It checks disk persistence, malformed saves,
scene transitions, pause release and resetting checkpoints for a new game.
