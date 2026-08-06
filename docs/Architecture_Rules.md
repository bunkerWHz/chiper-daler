Architecture Rules

Core Principles

1.  Composition over inheritance.
2.  Single Responsibility: one component = one responsibility.
3.  Components must not directly depend on other components.
4.  Prefer events over direct calls.
5.  Keep global managers to an absolute minimum.
6.  New mechanics should be added by composing components, not modifying
    existing ones.
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
-   No hard references to sibling components.
-   Communicate through events or the owning Actor.
-   No gameplay constants embedded in code.
-   Components must be optional and removable.

Actor Rules

-   Actor is a container for components.
-   Actor owns lifecycle.
-   Actor contains almost no gameplay logic.

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
