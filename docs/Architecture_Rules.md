Architecture Rules

Core Principles

1.  Composition over inheritance.
2.  Single Responsibility: one component = one responsibility.
3.  Component dependencies are resolved explicitly through the owning Actor.
4.  Prefer events over direct calls.
5.  Keep global managers to an absolute minimum.
6.  New mechanics should primarily be added by composing components. Existing
    capability owners may gain small integration points, but the new mechanic's
    state and rules stay in its own component.
7.  Separate data from logic.
8.  Every Actor is assembled from reusable components.
9.  Prefer capabilities (interfaces) over concrete types.
10. Every component should be independently testable.
11. Optimize only after profiling.
12. Follow Godot’s scene/node model; do not fight the engine.

Terminology

Actor: Any object placed in the world. Component: Reusable behavior
attached to an Actor. System: Coordinates interactions across
Actors/components. State: Current behavior mode (Idle, Run, Jump…).
Command: Intent from input (Jump, Attack…). Event: Notification that
something happened. Data: Tunable configuration without gameplay logic.

Component Rules

-   One responsibility only.
-   Resolve sibling dependencies through `actor.get_component(Type)`.
-   Validate required dependencies once during initialization.
-   Avoid circular component dependencies.
-   Communicate through events or the owning Actor.
-   No gameplay constants embedded in code.
-   Components must be optional and removable.

Component Lifecycle

-   Actor uses two-pass setup: it first collects every direct Component under
    `_Components`, then initializes them. Sibling lookup is therefore safe in
    `on_initialize()` regardless of scene order.
-   `Component.initialize()` owns the base lifecycle and is not overridden.
-   Resolve and validate sibling dependencies in `on_initialize()`.
-   Use `_ready()` only for owned nodes, SceneTree state, and external UI.
-   A missing required dependency produces one initialization error, calls
    `disable()`, and returns. Optional dependencies degrade gracefully.
-   Disabled components do not process or physics-process until enabled again.

Capability Gates and Action Coordination

-   The component that owns an action remains its single source of truth and
    exposes read-only queries plus fact signals.
-   Consumers check capability gates when an action starts and react to source
    signals when an ongoing action must be cancelled. They do not copy the
    source state into a second flag.
-   Dependencies remain directed. If component A already observes component B,
    B must not add a dependency back to A; use a signal or a focused capability
    contract instead.
-   Locomotion restrictions use the `get_locomotion_blocks()` capability and
    `LocomotionConstraint` flags. `MovementComponent` and `DodgeComponent`
    consume those flags without knowing which ability produced them.
-   During normal player control, `MovementComponent` owns input-driven body
    velocity. Ability components expose constraints instead of writing movement
    directly. Physical effects such as knockback may take explicit temporary
    ownership while normal movement is suspended.

Actor Rules

-   Actor is a container for components.
-   Actor owns lifecycle.
-   Actor contains almost no gameplay logic.

Actor Signals

-   A signal is owned by the object that produces the event.
-   Component events stay on their component; Actor does not relay them.
-   Add an Actor signal only for an event that belongs to the whole Actor
    and already has a real consumer.
-   Do not add generic `changed`, `event`, or message-bus signals.
-   Signal names describe facts in the past tense.

Camera Follow

-   CameraComponent owns its Camera2D node.
-   CameraComponent is a child of Actor and follows through scene hierarchy.
-   CharacterBodyComponent synchronizes the Actor position after movement.
-   Camera follow does not poll a target and does not depend on movement logic.

Actor Scene Structure

-   `_Components` is Node2D when it contains spatial components that must
    inherit the Actor transform.
-   Components use Node unless they own spatial children or transforms.
-   `_Visual` and `_Sockets` are Node2D branches owned by the Actor scene.
-   Gameplay behavior stays in components; the Player script stays minimal.
-   New world actors start from `framework/core/Actor.tscn`.
-   The Actor template contains no gameplay or test components by default.

Systems

-   Systems coordinate gameplay across Actors.
-   Systems never become God Objects.
-   Keep systems focused on one domain.

Data

-   Store balancing/configuration in resources.
-   Never hardcode gameplay values unless truly constant.

State Machine

-   State controls behavior.
-   Components provide abilities.
-   Avoid large if/else chains.
-   Actor state is layered into locomotion, primary action, and overlapping
    conditions; see `docs/Actor_States.md`.
-   `ActorStateComponent` is a read model. Ability components remain the source
    of truth and state names do not imply an implemented mechanic.

Commands

-   Input -> Command -> Actor.
-   Gameplay must not depend on keyboard/gamepad directly.

Events

-   Broadcast facts, not requests.
-   Event names use past tense (Jumped, Damaged, Died).

Forbidden

-   Deep inheritance trees.
-   God managers.
-   Circular dependencies.
-   Components modifying unrelated systems directly.
-   Duplicate gameplay logic.

Goal

Build a modular, extensible 2D platformer architecture where new
mechanics are added through composition instead of rewriting existing
code.
