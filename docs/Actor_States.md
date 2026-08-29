# Actor States

## Model

Every Actor exposes exactly one active `ActorState.Behavior`. Movement and an
action are never reported as simultaneous states. For example, pressing attack
while falling changes `Fall` into `AirLightAttack`; when the attack ends, the
Actor returns to `Jump` or `Fall` from its current vertical velocity.

`ActorStateComponent` is the transition coordinator and the single public
source for the active behavior. Ability components still own their mechanics,
timers, hitboxes, and fact signals. The coordinator resolves those facts by
priority instead of duplicating their gameplay logic.

Buffs and debuffs are not behavior states. They are independent
`ActorState.Status` flags and may coexist with any behavior.

## Behavior groups

- Grounded locomotion: `Idle`, `Run`.
- Airborne locomotion: `Jump`, `DoubleJump`, `WallJump`, `Fall`.
- Traversal: `Dodge`, `ClimbIdle`, `ClimbUp`, `ClimbDown`.
- Ground melee: `GroundAttackWindup`, `GroundLightAttack`,
  `GroundHeavyAttack`, `GroundAttackRecovery`.
- Air melee: `AirAttackWindup`, `AirLightAttack`, `AirHeavyAttack`.
- Other actions: item use, throwing, ranged weapons, magic, guard, parry,
  critical attacks, and interaction phases.
- Interrupting behaviors: hit, stun, knockdown, death, respawn, level up, and
  rest.

## Melee transitions

```text
Idle / Run
    -> GroundAttackWindup
    -> GroundLightAttack or GroundHeavyAttack
    -> Idle / Run

Jump / Fall
    -> AirAttackWindup
    -> AirLightAttack or AirHeavyAttack
    -> Jump / Fall

AirAttackWindup / AirLightAttack / AirHeavyAttack
    -> land before completion
    -> GroundAttackRecovery
    -> Idle / Run
```

A ground windup or attack immediately claims the exclusive behavior, stops
horizontal locomotion, and blocks jump and dodge. An air windup or attack keeps
normal horizontal air control and gravity, but blocks another jump and dodge.
Landing recovery blocks horizontal movement, jump, and dodge for the configured
recovery duration.

The input press starts a windup. Releasing it before the heavy threshold starts
a light attack; holding it through the threshold starts a heavy attack. This
keeps the state accurate even while the final attack type is not known yet.

## Exclusive behavior gate

Components that can occupy the Actor expose
`is_exclusive_behavior_active()`. Before beginning, they query
`ExclusiveBehaviorGate` while excluding themselves. An already active behavior
therefore rejects a conflicting command instead of creating combinations such
as `Run + Attack`, `Guard + Attack`, or `Interact + ItemUse`.

Movement restrictions are exposed separately through
`get_locomotion_blocks()`. `MovementComponent` applies those generic flags and
does not depend on concrete combat or interaction components.

## Contextual equipment controls

`EquipmentComponent` owns the active weapon set and derives its combat mode
from the active main-hand item. `Tab` switches between the two weapon sets.
Number keys `1` through `8` address item hotbar slots; `Q` and `E` cycle through
non-empty hotbar slots. Hotbar selection does not change weapon stance.
The default Health Potion slot is usable immediately without first reselecting
it through a number key or hotbar cycling.

`J` is the primary weapon action and `K` is its secondary action. `R` interacts
with a nearby world target when one is available; otherwise it uses the active
hotbar item. Melee attack, parry, and block are available only while the melee
slot is active and the active weapon set has a melee weapon in its main hand.
Removing that weapon cancels any of those actions already in progress. Every
future equipment ability must follow the same ownership rule.

Equipment-driven actions also observe changes inside their active context.
Changing the active ranged or magic main-hand item, or switching weapon sets,
cancels an aim, charge, cast, or release phase that started from the previous
context. Changing only an unrelated armour or inactive-set item does not cancel
the action.

Interaction is lower priority than combat actions. Pressing `R` during another
exclusive behavior does nothing; interaction becomes available after that
behavior finishes and never cancels it.

Guard and its opening parry window form a grounded defensive behavior. It can
start only on the floor, stops horizontal motion, and blocks running, jumping,
and dodging until released. Horizontal input may still update facing so the
Actor can turn toward an incoming attack. Losing floor contact ends guard.

Consumable use is also grounded. `UsingItem` stops horizontal motion and blocks
jump and dodge until the use completes. If the Actor loses floor contact from
an external effect, the use is cancelled without consuming the item. Facing
may still change while the Actor is using it.

## Implemented behavior mapping

| Actor behavior | Source of truth |
| --- | --- |
| `Idle`, `Run` | `MovementComponent` or grounded body velocity |
| `Jump`, `DoubleJump`, `WallJump`, `Fall` | `MovementComponent` or airborne body velocity |
| `Dodge` | `DodgeComponent` through `MovementState.DODGE` |
| `ClimbIdle`, `ClimbUp`, `ClimbDown` | `ClimbingComponent` through movement state |
| Ground and air windup/light/heavy/recovery | `AttackComponent` phase and attack origin |
| `UsingItem` | `ItemUseComponent` |
| `ThrowingAim`, `ThrowingAction`, `ThrowingRecovery` | `ThrowingComponent` phase |
| `AimBow`, `LooseArrow`, `AimCrossbow`, `FireCrossbow` | `RangedWeaponComponent` phase |
| `MagicCharge`, `MagicCast`, `MagicRecovery`, `MagicChanneling` | `MagicComponent` phase |
| `Blocking`, `Parrying` | `GuardComponent` |
| `CriticalAttack` | successful backstab from `HitboxComponent` |
| `InteractingStart`, `InteractingProgress`, `InteractingEnd` | `InteractionComponent` phase |
| `Hit` | `HitReactionComponent` |
| `Stunned`, `KnockedDown` | `HitStunComponent` |
| `Dead` | `HealthComponent` |
| `Respawning` | `PlayerRespawnComponent` |
| `Resting` | `RestComponent` |
| `LevelUp` | `ProgressionComponent` |

## Status effects

`ActorState.Status.DEBUFFED` and `ActorState.Status.BUFFED` are summary flags
reported by `StatusEffectComponent`. Specific poison, bleeding, slow, attack,
or defence effects remain in their own implementations and do not create a
second behavior FSM.

## Extension rule

When adding a behavior:

1. Implement its mechanic in a focused component.
2. Expose `is_exclusive_behavior_active()` while it occupies the Actor.
3. Check `ExclusiveBehaviorGate` before starting the behavior.
4. Expose locomotion blocks when the behavior restricts movement.
5. Add its priority mapping to `ActorStateComponent`.
6. Map its temporary animation in `AnimationComponent`.
7. Add transition, conflict, and debug-state tests.

Unrelated components never write directly into Actor state.
