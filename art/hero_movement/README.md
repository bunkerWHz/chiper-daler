# Unarmed hero: run, jump, fall

Separate animation source: `Hero_Movement.blend`. Contains the preserved `Hero_Idle_Unarmed` action plus three new actions. The original `art/hero_idle/Hero_Idle.blend` and original user artwork are unchanged. Textures remain packed. Uses the existing weights, bone names, sprite camera, unlit painted materials and screen-right facing artwork.

| Action | Frames | FPS | Duration | Loop |
| --- | --- | --- | --- | --- |
| Hero_Run_Unarmed | 1–16 | 24 | 0.667 seconds | Yes; closing key at 17 |
| Hero_Jump_Unarmed | 1–12 | 24 | 0.5 seconds | No; hold last pose if still ascending |
| Hero_Fall_Unarmed | 1–16 | 24 | 0.667 seconds | Yes; closing key at 17 |

The saved scene opens with Run selected and timeline 1–16. Choose another named action in Blender's Action Editor and set the corresponding playback range above. Idle retains its original 1–48 range and 24 fps.

## Motion

- Run: opposing legs and arm swings, bent elbows, forward body lean, body compression, stance and airborne phases. Planar two-bone leg solving is baked into ordinary pose keys; there are no runtime solver dependencies. Stance boot height is corrected using the evaluated mesh, without stretching leg bones.
- Jump: brief anticipation/crouch, extension, knee lift and settling into the airborne pose. It is a one-shot body animation, not a baked world-space flight path.
- Fall: restrained repeating airborne pose with slight upper-body and limb movement. The first pose exactly matches Jump's last pose.

The game's controller should handle horizontal movement, jump velocity and gravity. Set Run playback speed to match actual ground speed. Jump includes a short anticipation at the start: synchronize the gameplay impulse with extension or skip anticipation for an immediate jump response. Switch to Fall when vertical velocity becomes downward. Landing animation is not included. No game scenes, collisions or character sizes were modified, and game integration has not been tested.

## Sprite outputs

All frames are **512 × 512 RGBA PNG**, with the same orthographic camera, framing, scale and canvas as Idle. Keep the full canvas; independent trimming would change the pivot.

Each `run`, `jump`, `fall` folder contains:

- `frames/<name>_00.png` onward, in playback order;
- `<name>_sheet.png`: row-major sheet, **4 columns**, cell size 512 × 512. Run/Fall have 4 rows; Jump has 3 rows;
- `<name>_preview.webp`: lossless animation for review;
- `<name>_preview.gif`: smaller dark-background preview. The Jump GIF deliberately holds its final pose and replays for review; actual Jump playback is one-shot.

`movement_contact.png` shows four phases per animation. Weapon sockets and weapon layering remain separate future work.

## Verification and reproduction

`validation.json` records exact pose closure for Run/Fall, exact Jump-to-Fall pose and pixel equality, 44 validated RGBA exports, and canvas bounds for every frame. `validate_blender.py` checks finite transforms, unit bone scales within floating-point tolerance, and contact boot mesh height within one output pixel. This is a geometry check, not a gameplay physics test. Representative rendered poses were inspected for clipping and joint deformation; the larger swings remain constrained by the supplied cutout artwork and skin weights.

`create_movement.py` runs from the existing Idle source, adds the three actions and saves the separate movement scene. `render_frames.py` exports all three from the saved movement file; optional `JOB_START` and `JOB_END` select a bounded render batch. `build_preview.py` uses Pillow to validate images and build previews/sheets. `validate_blender.py` runs inside the saved movement scene.

Artwork provenance: user-supplied CutOutAnim artwork and rig, via the preceding Idle scene. No external assets, paid generation or new redistribution rights. Work used the connected Blender MCP directly; this is a local Blender/PNG deliverable, not a game-dev registry package.
