# Actor Animation Workflow

Actor animation uses Godot's standard scene resources:

```text
gameplay component -> ActorStateComponent -> visual component -> AnimationPlayer
                                                          -> AnimatedSprite2D
```

The gameplay layer decides what the Actor is doing and when an action succeeds.
The visual layer only selects and presents the matching animation.

## Editing an enemy

1. Open `game/enemy/Enemy.tscn` or `game/enemy/FlyingEnemy.tscn`.
2. Select `_Visual/AnimatedSprite2D`.
3. Open its `Sprite Frames` resource in the bottom SpriteFrames panel to replace,
   reorder, or retime frame-by-frame art.
4. Select `_Visual/AnimationPlayer` and use the Animation panel when a clip must
   also coordinate sound, effects, or another presentation node.

Ground-enemy frames live in
`game/enemy/animations/GroundEnemySpriteFrames.tres`; flying-enemy frames live in
`game/enemy/animations/FlyingEnemySpriteFrames.tres`.

Both enemy scenes expose the same semantic clips: `idle`, `move`, `airborne`,
`attack`, and `death`. Different enemies may use completely different art while
their gameplay components keep using those names.

## Editing the player

1. Open `game/player/Player.tscn`.
2. Select `_Components/AnimationComponent` to assign the temporary Warrior,
   Archer, Lancer, and overlay-effect `SpriteFrames` resources.
3. Select `_Visual/AnimatedSprite2D` to inspect the currently configured base
   renderer.
4. Select `_Visual/AnimationPlayer` to edit the semantic player clips.

Player clips are `idle`, `run`, `jump`, `fall`, `attack`, and `guard`. The
temporary visual component switches the renderer's serialized frame resource
when the equipped weapon changes; it does not build frames at runtime.

## When to add AnimationTree

Do not add `AnimationTree` merely to duplicate the gameplay FSM. Add it when the
art actually needs blending, blend spaces, or sufficiently complex visual-only
transitions. Even then, `ActorStateComponent` remains the behavior authority.
