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
defaults.

If replacing the Player scene is impossible, respawn safely falls back to the
previous full-scene reload behavior.

The main sandbox contains a `RestPoint` near the initial Player position. Press
`E` beside its blue marker to activate it.
