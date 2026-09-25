# Scene sizing convention

- Author world objects, including players and enemies, in the sprite's native pixel
  dimensions: keep Sprite2D/AnimatedSprite2D scale at (1, 1), keep collision nodes at unit
  local scale and edit the Shape2D resources, fit their dimensions and offsets to the
  visible artwork (excluding transparent padding), and set the overall size with a uniform
  scale on the scene root. LootBag and all monsters follow this: root Scale equal on both
  axes, sprites at unit scale, collision shapes in native dimensions.
- Apply this to new objects and safe updates to existing scenes: preserve user-authored
  sizes and offsets unless a size change is requested, and verify physics and visual
  alignment after changing the root scale.
- When migrating characters, recalculate local collision dimensions, offsets, attack/chase
  sensor ranges and ground rays to preserve existing world geometry. The root scale is the
  only character size knob; item visuals keep their authored `visual_scale`/`equipped_scale`.
  Movement speed, gravity, jump velocity and world-space navigation distances stay in world
  units.
- Exceptions: visual-only animation effects (hit reactions, squash/stretch) and UI layout do
  not resize physical collision shapes.
- Prefer setting physics object scale during scene authoring, before spawning; runtime
  resizing needs separate validation of physics behavior.
- `EnemyAuthoringChecks` reports violations of these rules as editor warnings; fix them
  instead of re-deriving the convention.

# Characters and enemies

- Prepare all character sprites facing right in the source art. Movement uses flip_h; there
  is no artwork-direction detection and no per-character facing configuration
  (`FacingComponent` is the single generic implementation), and scene properties beat
  one-off direction config resources. Skeleton2D/Polygon2D are the exception: reflect only
  the visual rig with its IK targets and attachments, never the physics root.
- Start new enemies from `game/enemy/GroundDummy.tscn` or `FlyDummy.tscn` and follow
  `docs/Enemy_Copy.md`. Name enemy asset folders after the monster:
  `assets/Enemies/<MonsterName>/PNG Sequences`.

# Main playable hero

- Darklight is the canonical main hero: `game/player/Player.tscn` for gameplay,
  `game/player/darklight/DarklightRig.tscn` for rig and animation authoring. Read
  `game/player/darklight/README.md` before changing either — it owns the rig, attachments,
  hand visuals and the generated `DarklightRig2.tscn` (rebuild with
  `node tests/regenerate_darklight_rig2.mjs`, never hand-edit it). Work on this repository's
  rig, not the external dark-sanctum source project.
- Preserve Skeleton2D, bone targets and bone attachments, and add future player animations
  to the canonical rig. DarklightVisualComponent presents ActorStateComponent behavior;
  gameplay components keep ownership of action timing, damage and item consumption.
- Equipment slots and visual hands are independent: `display_slot` defaults to the equipment
  slot, and bow/crossbow equip in MAIN_HAND while displaying in OffHand. Preserve authored
  hand transforms; equipped arrows/bolts control the quiver. See `docs/Item_Parameters.md`.

# Documentation

`docs/` is the project's Obsidian vault and its compiled wiki layer: the durable memory of
this project, so read it before you reason about gameplay.

- Before changing or explaining a mechanic, read its owning page. Start at `docs/index.md`;
  read `docs/concepts.md` for terminology. Follow the links on those pages before concluding
  that the wiki lacks the answer.
- Treat the wiki as a map, not as truth: verify concrete values, node paths and field names
  against the code, scenes and resources.
- When a change alters documented behaviour, update the owning page, its `updated` date and
  `docs/index.md` in the same commit, and mark a superseded rule next to the new one instead
  of deleting the history.
- After documentation changes, run `node docs/tools/wiki_lint.mjs` and fix what it reports.
  Leave the repository's README files where they are; `docs/sources.md` points to them.
- The full protocol — page types, frontmatter, links, ingest/query/lint — is in
  `docs/AGENTS.md`, which applies to work under `docs/`. Read it before restructuring
  documentation.

# Commit workflow

- After completing and verifying a fix, always create a Git commit before reporting
  completion; the user has authorized this, so do not ask again unless they request leaving
  the changes uncommitted.
- Include the fix with its tests and documentation. Stage only files or hunks belonging to
  the current work; leave unrelated user changes untouched.
- Use a concise commit message and report the commit hash. This authorization covers local
  commits, not pushing to a remote.
