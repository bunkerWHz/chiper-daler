# Enemy authoring

Enemies are Actors assembled from independent combat, locomotion, targeting,
and presentation components.

## Creating a variant

1. Duplicate the closest enemy scene in `game/enemy`.
2. Keep the shared combat components and tune their config resources.
3. Choose one locomotion component: `EnemyMovementComponent` for grounded
   movement or `EnemyFlightComponent` for flight.
4. Assign `EnemyVisualConfig.animation_root` to a directory containing the
   animation folders. Folder names are configurable, so art packs do not need
   to use a fixed naming convention.
5. Adjust only the scene's collision shapes, hitbox position, visual scale,
   and visual offset for the new creature.

`EnemyChaseComponent` and `EnemyAttackComponent` discover locomotion through
the shared enemy-locomotion capability. New locomotion styles only need to
implement `set_chase_target`, `clear_chase_target`, `stop`,
`capture_move_intent`, `restore_move_intent`, and `get_facing_direction`.

PNG sequences are loaded in filename order. The visual component automatically
selects idle, move/fly, airborne, attack, and death animations and flips the art
to match movement direction.

Enemy physical bodies use physics layer 5 (`16`) and collide only with world
layer 1. Player bodies use layer 4 (`8`) with the same world-only mask. Combat
continues to use the separate hitbox and hurtbox layers, preventing character
bodies from pushing, carrying, or riding each other.
