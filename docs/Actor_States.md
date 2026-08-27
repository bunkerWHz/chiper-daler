# Actor States

## Model

Actor state is a layered read model, not one global mutually exclusive enum.
An Actor can have one locomotion state, one primary action, and any number of
conditions at the same time.

Example:

```text
Falling + LightAttack + Debuffed
```

The layers are:

- `ActorState.Locomotion`: physical traversal mode;
- `ActorState.Action`: the primary action currently occupying the Actor;
- `ActorState.Condition`: overlapping status flags.

`ActorStateComponent` derives the snapshot from capability components. It does
not implement abilities and must not duplicate their gameplay logic.

## Implemented states

| Layer | Actor state | Source of truth |
| --- | --- | --- |
| Locomotion | `Idle` | `MovementComponent` or body velocity |
| Locomotion | `Walking` | `MovementComponent.RUN` or grounded velocity |
| Locomotion | `Jumping` | `MovementComponent.JUMP` or upward body velocity |
| Locomotion | `DoubleJumping` | `MovementComponent.DOUBLE_JUMP` |
| Locomotion | `WallJumping` | `MovementState.WALL_JUMP` |
| Locomotion | `Dodging` | `DodgeComponent` through `MovementState.DODGE` |
| Locomotion | `ClimbingIdle` | `ClimbingComponent` with no vertical input |
| Locomotion | `ClimbingUp` | `ClimbingComponent` with upward input |
| Locomotion | `ClimbingDown` | `ClimbingComponent` with downward input |
| Locomotion | `Falling` | `MovementComponent.FALL` or downward body velocity |
| Action | `LightAttack` | `AttackComponent.is_attacking()` |
| Action | `Blocking` | `GuardComponent.is_guarding()` |
| Condition | `Hit` | `HitReactionComponent.is_reacting()` |
| Condition | `Stunned` | `HitStunComponent.is_stunned()` |
| Condition | `Dead` | `HealthComponent.is_dead()` |
| Condition | `Respawning` | `PlayerRespawnComponent.is_restart_scheduled()` |

## Reserved states without mechanics

These names are stable and available to future components, but they must not
be reported as active until the corresponding ability exists.

### Locomotion

### Actions

- `HeavyAttack`
- `UsingItem`
- `ThrowingAim`, `ThrowingAction`, `ThrowingRecovery`
- `AimBow`, `LooseArrow`
- `AimCrossbow`, `FireCrossbow`
- `MagicCharge`, `MagicCast`, `MagicRecovery`, `MagicChanneling`
- `Parrying`
- `CriticalAttack`
- `InteractingStart`, `InteractingProgress`, `InteractingEnd`

### Conditions

- `KnockedDown`
- `LevelUp`
- `Resting`
- `Debuffed`
- `Buffed`

Specific effects such as poison, bleed, slow, increased attack, or increased
defence belong to future effect components. `Debuffed` and `Buffed` are summary
condition flags, not containers for effect logic.

## Extension rule

When adding a state:

1. Implement the ability or condition in its own component.
2. Keep that component as the source of truth.
3. Add a read-only mapping in `ActorStateComponent`.
4. Add a transition test and a debug-overlay check.
5. Never make unrelated components write directly into Actor state.

## Planned implementation order

1. Heavy attack and parry.
2. Timed interaction states.
3. Items, throwing, ranged weapons, and magic as separate ability families.
4. Knockdown, rest, level-up, buffs, and debuffs as condition components.
