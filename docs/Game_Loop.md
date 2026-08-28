# Game Loop

## Checkpoint and respawn

`RestPoint` combines recovery and checkpoint activation. Interacting with it:

- restores the player's health;
- clears active debuffs while preserving buffs;
- stores a respawn position above the marker.

When the player dies, `PlayerRespawnComponent` replaces only the dead Player
instance after its configured delay. The level scene is not reloaded, so its
current state remains intact. The replacement Player is a fresh instance with
all components, collisions, resources, and visuals reset to their scene
defaults. Stateful components restore earned progression, the equipped slot,
remaining consumables and ammunition, and current mana. Temporary combat and
status phases are intentionally cleared by death.

If replacing the Player scene is impossible, respawn safely falls back to the
previous full-scene reload behavior.

The main sandbox contains a `RestPoint` near the initial Player position. Press
`E` beside its blue marker to activate it.

## Enemy experience rewards

Enemies own an `ExperienceRewardComponent`. When a hit kills an enemy, the
component awards its configured experience amount to the attacking Actor's
`ProgressionComponent`. Damage without an Actor source gives no experience,
and one enemy can grant its reward only once.

## Loot drops

Enemy death creates a `Pickup` at the enemy position. The default enemy drops
a Health Essence that restores 25 health when collected with `E`. A full-health
player cannot consume it, so the pickup remains available.

`PickupData` also supports item charges, throwables, arrows, bolts, mana, and
experience. Designers can create another drop by changing only the resource
data used by `LootDropComponent`.

## Level completion

`LevelExit` counts living Actors in the `enemies` group. Its interaction stays
locked while any enemy is alive. After the level is cleared, interacting with
the exit emits `level_completed` and optionally changes to its configured next
scene. Without a next scene, the marker turns green and remains as a visible
completion result.

The main sandbox places the orange `EXIT` marker on the right platform.
