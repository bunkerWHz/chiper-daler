# Enemy authoring

Enemies are Actors assembled from independent combat, locomotion, targeting,
audio, animation-event, and presentation components. A content author should be
able to create a normal enemy without editing GDScript.

## Creating an enemy

Each enemy is a standalone composition scene. Enemy scenes must not inherit
from a Dummy scene or from another concrete enemy.

1. Copy the blank composition template in `game/enemy`: `GroundDummy.tscn` for
   grounded movement or `FlyDummy.tscn` for flight. Save the copy and its
   art under a directory owned by that enemy. The copied root scene is now the
   complete, independent assembly for this enemy.
2. Add or remove component scene instances under `_Components` to define the
   enemy's abilities. Shared component scenes remain referenced, so fixes to a
   component are received by every enemy that uses it without creating an
   inheritance relationship between enemy scenes.
3. The copy button creates owned `SpriteFrames.tres` and `AnimationLibrary.tres`
   in `game/enemy/monsters/<name>/`. Dummy sprites have no assigned frames;
   their copies get empty named animations to fill. The new root scale is
   always reset to (1, 1), without modifying the source. Never edit another
   enemy's animation resources in place.
4. Replace, reorder, and retime the frames for the semantic clips `idle`,
   `move`, `airborne`, `attack`, and `death`.
5. Match every `AnimationPlayer` clip length to the corresponding
   `SpriteFrames` cycle. Loop `idle`, `move`, and `airborne`; keep `attack` and
   `death` one-shot.
6. Select the editable collision children in the enemy scene and fit the
   body, hurtbox, and attack hitbox over the new art. Their Shape2D resources
   are local to the scene, so editing one enemy does not change another.
7. Tune chase and attack range through `EnemyChaseConfig` and
   `EnemyAttackConfig`. Those sensor shapes are generated from the config at
   runtime.
8. Tune health, movement, damage, knockback, rewards, and loot through their
   component properties and config resources.

## Sizing

Keep AnimatedSprite2D at unit scale. Set overall size with equal positive X/Y
Scale on the Actor root. Blank templates and new copies start at (1, 1).
The collection's StoneMaw and AmberWasp retain scales 0.24 and 0.22.
Author sprite Position, body/hurtbox/hitbox shapes, hitbox offsets, attack/chase
sensor ranges and ground-ray distances in native, actor-local pixels. These
grow together with root scale. Do not resize collision nodes independently;
edit their Shape2D dimensions. Prepare all source sprites facing right;
left-facing movement uses flip_h. There is no per-enemy artwork-facing config.

Movement speed, gravity, jump velocity and navigation distances are world units
and remain independent of visual size. Health bars use a UI scale correction;
jump previews draw in world pixels to keep the displayed trajectory accurate.

## Authoring animation events

Each enemy owns its AnimationLibrary timeline. Add Call Method Track keys that
target `../_Components/AnimationEventComponent` and call `emit_event`.

Supported event names currently include:

- `footstep` for a grounded foot contact;
- `wing_flap` for a flying movement beat;
- `attack_swing` for a bite or weapon-swing sound;
- `hitbox_on` and `hitbox_off` for the damaging part of an attack;
- `body_impact` for a body hitting the ground during death.

Place `hitbox_on` on the first dangerous frame and `hitbox_off` immediately
after the last dangerous frame. `AttackComponent.active_duration` is the total
attack lifetime and must match the `attack` AnimationPlayer clip length. The
component closes the hitbox automatically when the attack ends, is cancelled,
or is interrupted, even if an animation key is missing.

The ground and flying composition templates contain example event keys. Move the
keys to fit the replacement art instead of assuming the example timing is
correct.

For an attack whose reach changes during the swing, add property tracks for
the local position, rotation, scale, or shape of
`../_Components/HitboxComponent/Area2D`. `HitboxComponent` mirrors this local
motion with the Actor's facing direction. Keep `hitbox_on` and `hitbox_off` as
the only keys that enable or disable damage.

## Authoring audio

Assign streams to the enemy's `ActorAudioComponent.profile`. The profile owns
sound choices and playback variation, while the animation timeline owns the
frame on which an authored cue occurs.

Footsteps, wing flaps, swings, and body impacts come from animation events.
Actual hit-confirmation audio comes from `HitboxComponent.hit_landed`; hurt and
death voices come from `HealthComponent`. A missed attack therefore plays its
swing but not a hit sound.

`EnemyChaseComponent` and `EnemyAttackComponent` discover locomotion through
the shared enemy-locomotion capability. New locomotion styles only need to
implement `set_chase_target`, `clear_chase_target`, `stop`,
`capture_move_intent`, `restore_move_intent`, and `get_facing_direction`.

Enemy physical bodies use physics layer 5 (`16`) and collide only with world
layer 1. Player bodies use layer 4 (`8`) with the same world-only mask. Combat
continues to use separate hitbox and hurtbox layers.
