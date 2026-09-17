# Drow rig — first modeled version

`Drow_Rig.blend` is the editable T-pose source; `Drow_Rig.glb` contains only the
character and skeleton, with no animation clips, cameras or lights.

Created locally in Blender from the user-supplied front/side reference
`C:/Users/bunkerWHz/Desktop/Blender drow/t-pose drow full.png`.
This is a stylized interpretation, not an exact reconstruction. Back details
are inferred. No paid generation service or third-party mesh was used.
Rights to the supplied reference remain with its owner; no license is assigned
to that reference by this project.

## Posing

Select `Drow_Rig`, enter Pose Mode and rotate the named bones. This is an FK
rig (no IK controls). `root` moves the whole character; `pelvis`, `spine`,
`chest`, `neck`, and `head` form the central chain. Arms, legs, individual
fingers and thumbs have left/right bones. `tabard` and `skirt.L/R` adjust
front clothing to accommodate poses. Finger controls have one segment each.
There is no facial rig. Clear pose transforms to restore T-pose.

Height is approximately 2.18 Blender meters, Z-up, facing -Y in Blender;
glTF applies its standard axis conversion. Mesh and armature scales are 1.
Materials use solid colors and UVs are available for later texture painting.
Meshes remain separate for editing. UV islands are generated per mesh, not
packed into a shared atlas.

## Verification and limits

`validation.json` records topology counts, normalized skin weights and measured
vertex motion during forearm, shin and head rotations. `pose_check.png` is a
temporary pose preview; the saved source and export remain in T-pose.
The GLB is reimported into Blender and checked by `verify_export.py`.
No runtime engine import, animation retargeting or exhaustive extreme-pose
collision testing has been done. Clothing may need manual auxiliary-bone
adjustments in deep crouches. This is a first model/rig for review, with
material colors rather than finished painted textures.

Rebuild with Blender background mode and `build_drow.py` in an isolated process.
The builder resets its own process to an empty scene. It does not edit the
currently open Blender session. The original reference is not required to
rebuild the procedural geometry.
