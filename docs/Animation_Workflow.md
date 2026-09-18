# Actor Animation Workflow

Actor animation uses Godot's standard scene resources:

```text
gameplay component -> ActorStateComponent -> visual component -> AnimationPlayer
                                                          -> AnimatedSprite2D
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

`game/player/Player.tscn` now renders the Skeleton2D-based Darklight character.
Open `game/player/darklight/DarklightRig.tscn`, select `AnimationPlayer`, and
animate `CharacterContainer/Anim Targets`. The original rig includes skinned
polygons, bone attachments and SoupIK controls.

`DarklightVisualComponent` maps the existing `ActorStateComponent` behavior to
clips. Gameplay components remain the authority for action durations and damage.
Equipment visuals are scene instances attached to the hand bones, assigned with
`ItemData.equipped_visual`; changes to the active inventory loadout update them.

See [Darklight authoring notes](../game/player/darklight/README.md) for size,
facing, attachment setup, source provenance and missing-animation fallbacks.
The old `TemporaryPlayerVisualComponent` and Warrior/Archer/Lancer resources
remain available as legacy assets, but are no longer used by the player scene.

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
