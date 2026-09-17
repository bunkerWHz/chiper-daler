# Hero unarmed idle — first animation pass

Source: the user's `CutOutAnim.blend`, supplied with six painted PNG body parts and an existing 19-bone weighted armature. Original source file was not overwritten. All six source images are packed into `Hero_Idle.blend`.

## Playback

Open `Hero_Idle.blend` and play frames **1–48 at 24 fps**. The action is `Hero_Idle_Unarmed`; frame 49 is the matching closing key, excluded from playback. Duration: 2 seconds. Small torso rise and tilt, delayed head/arm movement, fixed lower body. No weapon and no root travel. Existing bone names and skin weights are retained.

The sprite camera is orthographic, facing the YZ artwork plane from +X. The character faces screen-right. Original camera and original material datablocks are retained; assigned sprite materials use unlit painted colour and texture alpha. No Godot scene or physical sizing was changed.

The near arm (`arm_right`) is at X = -0.42: in front of the torso (X ≈ -0.572), behind the head (X = -0.3). This depth order is shared with the movement scene and exported sprites.

## Outputs

- `frames/idle_00.png` through `idle_23.png`: 24 RGBA frames, 512 × 512, play at **12 fps**, looping. These sample Blender frames 1, 3, …, 47 without duplicating the closing pose.
- `idle_sheet.png`: 6 columns × 4 rows, row-major order, each cell 512 × 512; total 3072 × 2048.
- `idle_preview.webp` / `idle_preview.gif`: animated review copies on a dark background.
- `idle_contact.png`: four phase samples and enlarged joint regions for visual review.

Keep the identical frame canvas when importing. This is an animation/art review pass, not a wired-in game animation. Weapon sockets, front/back weapon layering, and weapon-specific hand poses are not part of this pass.

## Validation and reproduction

`validation.json` records exact loop closure, maximum evaluated leg-vertex drift across all 49 keyed frames (< 0.000001 Blender units), and PNG count/alpha/frame-boundary checks. Four representative rendered phases were visually inspected for joint gaps and clipping. Physics/gameplay integration was not tested because no game scenes changed.

`create_idle.py` records the construction procedure for the original source scene (its output directory is explicitly configured). `render_frames.py` rerenders the sequence from the saved animation file. `build_preview.py` creates review media and the sheet using Pillow.

Artwork is user-provided. No external assets were generated or downloaded, and no additional license or redistribution rights are asserted. The game-dev CLI was unavailable on this host; creation and inspection used the connected Blender MCP directly. This directory is a local Blender/PNG deliverable, not a game-dev canonical registry package.
