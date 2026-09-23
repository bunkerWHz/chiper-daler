---
title: Actor Animation Workflow
type: guide
created: 2026-09-03
updated: 2026-09-23
tags: [animation, actor, workflow]
---

# Actor Animation Workflow

Actor animation uses Godot's standard scene resources:

```text
gameplay component -> ActorStateComponent -> visual component -> AnimationPlayer
                                                          -> Skeleton2D / SoupIK (player)
                                                          -> AnimatedSprite2D (frame art)
```

The gameplay layer decides what the Actor is doing and when an action succeeds.
The visual layer only selects and presents the matching animation.

## Editing an enemy

1. Open the enemy's standalone scene. For a new enemy, first copy the grounded
   or flying composition template; do not create an inherited scene.
2. Select `_Visual/AnimatedSprite2D`.
3. Open its `Sprite Frames` resource in the bottom SpriteFrames panel to replace,
   reorder, or retime frame-by-frame art.
4. Select `_Visual/AnimationPlayer` and use the Animation panel when a clip must
   coordinate sounds, effects, or combat timing events.

The template resources live in `game/enemy/animations`. Every production enemy
must own copies of both its `SpriteFrames` and `AnimationLibrary`. This keeps
frame timing, sound cues, and attack events independent between enemy types.

Both enemy scenes expose the same semantic clips: `idle`, `move`, `airborne`,
`attack`, and `death`. Different enemies may use completely different art while
their gameplay components keep using those names.

For an event that belongs to a drawn frame, add a Call Method Track targeting
`../_Components/AnimationEventComponent`. Use `footstep`, `wing_flap`,
`attack_swing`, `hitbox_on`, `hitbox_off`, or `body_impact` as the event name.
Gameplay-result audio such as a successful hit is emitted by gameplay signals
instead of the animation timeline.

## Editing the player

Darklight is the main hero; `game/player/Player.tscn` is its gameplay scene.
All new player animations belong to this Skeleton2D-based rig.
Open `game/player/darklight/DarklightRig.tscn`, select `AnimationPlayer`, and
animate `CharacterContainer/Anim Targets`. The original rig includes skinned
polygons, bone attachments and SoupIK controls.

The rig's internals — the bone hierarchy and rest poses, skin weights,
`RemoteTransform2D` attachments, the IK solvers that turn those targets into bone
rotations, and the mirrored facing rule — are documented in
[Bones and rig solvers](Rig_Bones.md).

`DarklightVisualComponent` maps the existing `ActorStateComponent` behavior to
clips. Gameplay components remain the authority for action durations and damage.
The rig's `MainHand` and `OffHand` Sprite2D nodes follow the hand bones. Assign
`ItemData.equipped_texture` to swap artwork without changing animation tracks or
authored hand transforms. Optional `equipped_visual` scenes support multipart
artwork; the texture takes precedence. Inventory icons are separate.

`ItemEquipmentProfile.display_slot` defaults to the equipment slot. Bow and
crossbow equip in MAIN_HAND but display in OffHand. Only the active weapon set
updates visible equipment; its equipped arrows or bolts show the `Arrows` quiver
sprite. See [item authoring](../game/items/README.md) for resource setup.

See [Darklight authoring notes](../game/player/darklight/README.md) for size,
facing, attachment setup, source provenance and missing-animation fallbacks.
The old `TemporaryPlayerVisualComponent` and Warrior/Archer/Lancer character
resources have been removed; their history remains in Git.

### Generated clips

Most player clips are keyed by hand in `AnimationPlayer`. A clip whose whole
point is a rigid rotation of the body — the `dodge2` tucked roll — is generated
instead, because every target has to orbit the pelvis by the same angle and by
the same amount that keeps the artwork on the floor. `tests/dodge2_roll_author.gd`
owns that maths and writes `animations/dodge2.tres`; open the `.tres` in
`AnimationPlayer` for hand edits afterwards, and regenerate from the script when
the roll's timing or tuck has to change.

The generator needs a window: it renders the rig offscreen and reads the lowest
lit pixel of every key, so the pelvis sits exactly on the ground line measured
from `idle`. Reading the silhouette from node transforms is not enough — the
skinned limb pieces and the cloak are only placed correctly by the renderer, and
the rig's skin weights and polygon followers had to be repaired for that
measurement to be meaningful at all (see the Darklight notes).

```sh
godot --script tests/dodge2_roll_author.gd            # write the clip, verify floor contact
godot --script tests/dodge2_roll_author.gd -- sheet   # plus a review contact sheet
godot --headless --script tests/dodge2_roll_author.gd -- sweep   # rank tuck candidates
```

`-- frames` prints the roll as text and `-- measure` compares the shipped clips
before and after a rig edit. `-- probe` reports how far the drawn silhouette
moves when the pelvis moves, which is how the skinning defects above were found.
`dodge2` is not mapped to a state yet: `ActorStateComponent` behavior `Dodge`
still selects the older `dodge` clip, and switching that also means giving the
cloak a tucked pose.

## Stone Golem asset setup

`game/enemy/monsters/stone_golem/StoneGolem.tscn` is a passive boss composition
with owned character/effect SpriteFrames and frame-keyed AnimationPlayer clips.
Use `tests/StoneGolemPreview.tscn` to inspect every animation and effect.
The per-boss README documents source frame counts (block 8, armor buff 10),
the reversed appearance clip, native collision sizes and the future combat work.

## When to add AnimationTree

Do not add `AnimationTree` merely to duplicate the gameplay FSM. Add it when the
art actually needs blending, blend spaces, or sufficiently complex visual-only
transitions. Even then, `ActorStateComponent` remains the behavior authority.
