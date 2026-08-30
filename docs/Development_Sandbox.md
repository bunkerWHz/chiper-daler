# Development Sandbox

`res://tests/MovementSandbox.tscn` is the project's main manual testing scene
and the default scene launched from the editor.

It is an intentionally editable playground rather than an automated test
fixture. Platforms, actors, interactables, and other test objects may be moved,
added, or removed whenever a mechanic needs a practical in-game check. Useful
sandbox layout changes should be committed separately from feature code so the
current testing setup is shared by the project.

The sandbox currently provides:

- the complete Player scene and HUD;
- movable platform collision bodies;
- an Enemy for movement, combat, loot, and progression checks;
- interactable objects, a chest, and a lever;
- a sanctuary checkpoint;
- a climbable area;
- a level exit.

Automated tests must not depend on exact sandbox object positions. Mechanics
that require a stable layout should use a dedicated test scene, such as
`res://tests/EnemyPlatformSandbox.tscn`, or construct their own fixture in code.
