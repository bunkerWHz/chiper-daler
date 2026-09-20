---
title: Game Loop
type: architecture
created: 2026-08-28
updated: 2026-09-20
tags: [progression, saves, levels]
---

# Game Loop

## Checkpoint and respawn

`RestPoint` combines recovery and checkpoint activation. Interacting with it:

- restores the player's health, mana and stamina in full;
- clears active debuffs while preserving buffs;
- refills every owned flask;
- stores a respawn position above the marker.

When the player dies, `PlayerRespawnComponent` replaces only the dead Player
instance after its configured delay. The level scene is not reloaded, so its
current state remains intact. The replacement Player is a fresh instance with
all components, collisions, resources, and visuals reset to their scene
defaults. Stateful components restore earned progression, the equipped slot,
flask charges, remaining consumables and ammunition, and current mana.
Temporary combat and status phases are intentionally cleared by death.

If replacing the Player scene is impossible, respawn safely falls back to the
previous full-scene reload behavior.

For platforming tests, `ViewportFallDeathComponent` kills the Player after its
origin passes 32 pixels below the visible viewport. It uses the regular health,
death, and respawn chain, so the replacement appears at the latest RestPoint
checkpoint without reloading the level.

The main sandbox contains a `RestPoint` near the initial Player position. Press
`E` beside its blue marker to activate it.

## Enemy rewards

Enemies own an `ExperienceRewardComponent`. The name is historical: it is kept
so that authored enemy scenes stay valid, and the component no longer awards
experience. When the enemy dies, the component drops
`features/loot/AmberShardPickup.tscn` with its configured amount — 25 by
default — and the player collects the shards by touching them. The reward
belongs to the death rather than to the killing blow, so environmental deaths
still drop shards, and one enemy can drop them only once.

Experience is never a kill reward. Amber shards are the only source of it: the
sanctuary spends them on levels at a rate of 1 shard = 1 experience toward the
next level, and only when the player chooses to buy one. See
[Amber shards](Amber_Economy.md).

## Loot drops

`LootDropComponent` creates an interactable `LootBag` at the enemy position when
its loot table rolls at least one item. Collecting the bag with `E` transfers
its contents to the player's real inventory; a full inventory leaves the
unaccepted remainder in the bag. An empty loot table disables the component
entirely, so no bag appears — that is the case for the default enemy, whose only
reward is amber shards.

`LootDropComponent`, `LootBag`, inventory, equipment, and quick-access slots
reference the same reusable `ItemData` assets.

## Temporary player resource HUD

The sandbox HUD keeps the green health bar at the top left and places the
provisional bars directly below it: mana, stamina, experience toward the next
level, and the remaining duration of the provisional `rage` buff. The experience
bar shows progress toward the level the sanctuary sells for amber shards; it is
not a kill reward. The view observes the owning gameplay components and contains
no resource or combat logic. It is intentionally replaceable when the final
interface is designed.

## Level completion

`LevelExit` counts living Actors in the `enemies` group. Its interaction stays
locked while any enemy is alive. After the level is cleared, interacting with
the exit emits `level_completed` and optionally changes to its configured next
scene. Without a next scene, the marker turns green and remains as a visible
completion result.

The main sandbox places the orange `EXIT` marker on the right platform.
