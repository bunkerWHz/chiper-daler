# Menus and playthrough saves

The project starts at `MainMenu.tscn`. New Game opens `CharacterCreation.tscn`,
then the existing `MovementSandbox.tscn`; change `GameFlow.FIRST_LEVEL` when the first level is ready.
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

## Character creation

Darklight remains the only playable rig. Creation sets a trimmed name (1–24
characters), five attributes with a minimum of 1, and exactly 10 points total:
5 are already assigned, 5 are freely distributed. Plus/minus buttons refund
points before starting; reset returns every attribute to 1. All points must be spent.
Validation and navigation buttons stay below the scrollable form so longer
equipment warnings cannot clip the Back or Start Adventure buttons.
Weapon, top (chest) and bottom (legs) choices are independent of stats/classes
and of one another. Starting armor contains only these two pieces; no head,
shoulder, hand, belt or foot items are granted.
`CharacterCreationData.gd` owns the budget, validation and starter catalogs.
Bow/crossbow include matching ammunition; every loadout includes health/mana flasks.
The selected loadout replaces the sandbox inventory and is equipped immediately.
The UI shows actual equipment weight against the existing END capacity formula.
It does not introduce new stat scaling or change the established combat balance.

The existing save codec restores starting data before the first autosave and
stores an optional `identity.name`; older saves default to Darklight. Cancel/Escape
returns to the menu without preparing a new session or replacing the existing save.
Direct `GameFlow.start_game()` remains available to sandbox checks with authored defaults.
Run `tests/character_creation_runtime_check.gd` with isolated APPDATA to check budget
boundaries, all gear combinations, actual equipment, disk round trips and cancellation.
Use a rendered run with `-- --capture` to save a UI screenshot in the temporary directory.
