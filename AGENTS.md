# Scene sizing convention

- Prefer authoring simple world objects in the sprite's native pixel dimensions:
  keep Sprite2D/AnimatedSprite2D scale at (1, 1), fit collision shape dimensions
  and offsets to the visible artwork (excluding transparent padding), and set
  the object's overall size with a uniform scale on its scene root.
- Keep collision nodes at unit local scale; edit the Shape2D resource dimensions.
- Apply this convention to new objects and safe updates to existing scenes.
  Preserve user-authored sizes and offsets unless a size change is requested.
  Verify physics and visual alignment after changing the root scale.
- Do not blindly migrate characters with independently tuned movement sensors,
  attack ranges, hurtboxes, UI, or differently sized animation assets. Preserve
  intentional visual-only normalization when changing it would alter gameplay.
- Visual-only animation effects (hit reactions, squash/stretch) and UI layout
  are exceptions: they should not resize physical collision shapes.
- Prefer setting physics object scale during scene authoring, before spawning;
  runtime resizing needs separate validation of physics behavior.

LootBag follows this convention: adjust its root Scale equally on both axes.
Its Visual stays at unit scale and its collision shape is authored at native size.
