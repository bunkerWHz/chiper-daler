# Scene sizing convention

- Author world objects, including players and enemies, in the sprite's native pixel dimensions:
  keep Sprite2D/AnimatedSprite2D scale at (1, 1), fit collision shape dimensions
  and offsets to the visible artwork (excluding transparent padding), and set
  the object's overall size with a uniform scale on its scene root.
- Keep collision nodes at unit local scale; edit the Shape2D resource dimensions.
- Apply this convention to new objects and safe updates to existing scenes.
  Preserve user-authored sizes and offsets unless a size change is requested.
  Verify physics and visual alignment after changing the root scale.
- When migrating characters, recalculate local collision dimensions, offsets,
  attack/chase sensor ranges and ground rays to preserve existing world geometry.
  Do not keep a separate visual size setting. Movement speed, gravity, jump
  velocity and world-space navigation distances remain in world units.
- Visual-only animation effects (hit reactions, squash/stretch) and UI layout
  are exceptions: they should not resize physical collision shapes.
- Prefer setting physics object scale during scene authoring, before spawning;
  runtime resizing needs separate validation of physics behavior.

LootBag and all monsters follow this convention: adjust root Scale equally
on both axes. Sprites stay at unit scale; collision shapes use native dimensions.

Prepare all character sprites facing right in the source art. Use flip_h for
left-facing movement; do not add artwork-direction detection or per-character
facing configuration. Prefer scene/node properties over one-off config resources.

Start new enemies from game/enemy/GroundDummy.tscn or FlyDummy.tscn. Keep these
templates at unit scale with no assigned SpriteFrames. Store completed enemies
in game/enemy/monsters/<name>/ with owned animation resources. The copy tool
resets the new root scale to (1, 1); levels reference completed monsters.
Name enemy asset folders after the monster: assets/Enemies/<MonsterName>/PNG Sequences.

# Commit workflow

- After completing and verifying a fix, always create a Git commit before
  reporting completion. The user has authorized this; do not ask again unless
  they explicitly request leaving the changes uncommitted.
- Include the fix, its relevant tests and documentation. Stage only files or
  hunks belonging to the current work; leave unrelated user changes untouched.
- Use a concise commit message describing the change and report the commit hash.
  This authorization covers local commits, not pushing to a remote.
