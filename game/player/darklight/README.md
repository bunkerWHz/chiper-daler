# Darklight

Darklight is the project's main playable hero, not an alternate or temporary skin.
`game/player/Player.tscn` is its gameplay scene. The existing
Actor components still own movement, FSM, inventory, equipment, damage, stamina,
item use, saving and respawning. No gameplay scripts or UI from dark-sanctum are
loaded.

## Editing animations

Author all future player rig and animation changes in this repository's
`game/player/darklight/DarklightRig.tscn`, not the external source project.
The legacy Warrior/Archer/Lancer character art and `TemporaryPlayerVisualComponent`
have been removed. Their history remains in Git; new player work uses this rig.

Open `DarklightRig.tscn` directly. Select `AnimationPlayer` and edit the clips by
moving `CharacterContainer/Anim Targets`. The original Skeleton2D, Bone2D rest
poses, skinned polygons, RemoteTransform2D attachments and SoupIK solvers are
preserved. The rig is authored at native size; its standalone root is unit scale.

`DarklightVisualComponent` listens to `ActorStateComponent.state_changed` and
`FacingComponent.facing_changed`. Run, jump, fall, wall jump, dodge, block, light
and heavy ground/air attacks use the corresponding source clips. Attack and
dodge playback speeds follow the existing gameplay action durations. Animation
does not activate hitboxes, spend stamina or change FSM state.

Before switching clips the adapter applies RESET, because the source's attack
clips key only the arms. RESET no longer targets the old character controller,
camera, gameplay components, root transform or equipment visibility.

Aim clips are `throw_aim`, `bow_aim`, `crossbow_aim` and `magic_aim`, stored as
independent Animation resources in `animations/` and exposed in the rig's
AnimationPlayer. They play during the corresponding aim/charge states. Throw
starts from a separate copy of the bow pose with MainHand and OffHand hidden; crossbow and
magic start from copies of idle, ready for authoring without changing
idle itself. The source has no dedicated release, climbing, item-use, hit, death or
equipment-swap animation. Those states currently use the idle pose; death and
respawn freeze it while the existing fade/respawn components handle the result.
`equipment_swap` retains a two-second empty placeholder clip whose playback rate
follows the swap duration. Add new authored clips and map them in
`_get_animation_name()` to replace these fallbacks.

## Shoulder, elbow and wrist controls

### Bow and throw aiming in gameplay

Edit `bow_aim` or `throw_aim` in AnimationPlayer with the neutral aim pointing right. Their
BackArmFK mode is FK; key Shoulder, Elbow and Wrist rotations to change the pose.
The authored values are sampled throughout playback, including animated keys.
DarklightVisualComponent adds the shared aim angle to the authored shoulder
pose, preserving elbow and wrist edits. The default extended arm pivots at the shoulder,
so its wrist follows a circle. Wrist rotation accounts for the local direction
from the wrist pivot to its authored OffHand grip. That wrist-to-grip line follows
the aim, rather than the bone's +X axis. The look-at target follows the corrected
bone direction; the weapon attachment and idle grip remain unchanged.
The arm uses FK while its wrist look-at remains active; head look-at is temporarily
evaluated from the authored Head_AT target before adding one quarter of the aim angle.

On AnimationComponent, **Bow Aiming Pose → Bow Head Follow** controls this ratio
(default 0.25); **Bow Shoulder Offset Degrees** adjusts the arm's angle relative
to the aim. Both facings are supported. Releasing/cancelling aim, switching clips
or disabling the visual restores the saved controls and look-at target. Throwing
uses the same arm/head follow and grip launch point, including quick taps. Its
MainHand and OffHand equipment visuals are hidden while aiming and restored
on release/cancel; equipment itself is unchanged. Both hands are currently empty;
displaying the thrown item's texture in MainHand is not implemented yet. Crossbow and magic use their
authored clips without this angle overlay.
Gameplay still owns aiming limits, firing and ammo.

To edit: open `DarklightRig.tscn`, select AnimationPlayer, choose the desired
`*_aim` clip and enable animation preview. Move/key controls under
`CharacterContainer/Anim Targets`. For crossbow/magic the arms start in IK:
edit FrontArmIK/BackArmIK and their look targets, or key the desired arm's mode
to FK before animating its Shoulder/Elbow/Wrist. Keep a key at time zero for
each edited property. The clips loop while aiming; release/cancel leaves the
clip through the existing gameplay state machine. Bow/throw's angle overlay only runs
in gameplay, so the editor shows its neutral authored pose.

Bow arrows, thrown projectiles and the aiming indicator share the world position of the wrist's
OffHand attachment (the authored grip). Querying it synchronizes the bow pose,
including quick taps. Firing captures this point before ending aim or consuming
the last arrow or throwable. Other weapons keep the configured launch offset.

### Manual controls

`CharacterContainer/Anim Targets/Hip` controls the pelvis: animate its Rotation
or Position directly, without switching modes. Keep its Scale at (1, 1).
Its BoneTransform child transfers the full transform for correct mirrored facing. Existing Hip tracks,
including RESET, target this control. FK arms follow the pelvis; IK limbs still
reach their separate targets. Do not animate the Hip bone or BoneTransform directly.

Under `CharacterContainer/Anim Targets`, both `BackArmFK` (bow arm) and
`FrontArmFK` contain `Shoulder → Elbow → Wrist` Marker2D controls.
Select the arm's FK node and set **Mode = FK** in the Inspector, then animate
the markers' **Rotation**. Shoulder rotation moves the whole chain; elbow
rotation moves the forearm, wrist and equipped item; wrist rotation adjusts
the hand. Marker positions follow the bone pivots and are not animation inputs.

For an FK animation, key `BackArmFK:mode` (or `FrontArmFK:mode`) to FK at time
zero using a discrete track, then key the three marker rotations as needed.
Each arm switches independently. IK mode keeps the original wrist targets and
SoupIK solvers; FK disables both that arm's two-bone solver and wrist look-at.
The controls follow the hip and the rig's facing. RESET returns both arms to IK
and clears the FK angles, so existing clips retain their original behavior.
Switching modes is immediate; it does not automatically match or blend poses.

## Cloak wind

`Cloak.tscn` contains a native-size skinned cloth mesh and four Bone2D nodes.
The existing hip attachment still positions the cloak. Anchor holds the neckline;
Upper, Middle and Hem bend the lower fabric with a delayed, subtle four-second
wind loop. Its independent WindAnimation player keeps running across body clips
and inherits gameplay pause and visual facing. Physics and IK are unchanged.
The `jump` clip tucks the fabric toward the back during ascent; `fall` curves it
outward into an inflated canopy during descent. DarklightVisualComponent selects
these from airborne vertical velocity, including during attacks and aiming, with
a 0.22-second blend. The apex retains the previous air pose; landing restores wind.
Death/respawning freeze cloth playback. These are visual poses only.
Open Cloak.tscn and preview/edit `wind`, `jump`, or `fall` on WindAnimation to adjust
the three bone rotation tracks (or playback Speed Scale to change wind speed).
The texture placement matches the original centered sprite and (-264, 0) offset.
Run `tests/darklight_cloak_check.gd` for weights, loop, anchoring and facing checks.

## Equipment

The rig's `MainHand` and `OffHand` are Sprite2D nodes driven by the existing
bone RemoteTransform2D attachments and animation targets. Their transforms,
`centered` and `offset` are authored in the rig and are never changed by equipment.
Assign `ItemData.equipped_texture` to replace only the native-size image.
Inventory `icon` is separate and is not automatically used as weapon artwork.

For a multipart visual, use the optional `ItemData.equipped_visual` Node2D scene
instead. Its grip is at the scene origin; use its own Sprite2D offset/rotation for
item-specific alignment. `equipped_texture` takes precedence when both are set.
The adapter replaces only its own instance, preserving any authored children.

`Equipment Profile → Display Slot` offers `Same As Equipment` (default),
`Main Hand`, and `Off Hand`. This changes only the visual destination. The katana
uses its main-hand slot; bow and crossbow resources/templates explicitly select
Off Hand while still equipping to MAIN_HAND in inventory. If both equipped items
claim the same visual destination, MAIN_HAND equipment wins. The inactive weapon
set never changes visible equipment. Items without texture or visual scene are
hidden; the training crossbow still needs its own artwork assigned.

The `Arrows` sprite contains the quiver artwork. It is visible only while arrows
or bolts are equipped in the active set. Ammunition is not displayed in the hand
sprites. Unequipping ammunition, exhausting its stack, and switching sets update
visibility through the existing equipment signals. Both ammunition types currently
use the same quiver image. Armor/accessory stats work without replacing body art.

Consumable and buff overlays remain connected to the current item/status signals.

## Size and facing

Player root scale is `(0.1, 0.1)`. Body collision and hurtbox are 412×970
native units, offset by `(0, -250)` to match the rig's body from head to feet
without including cloak, quiver or weapons (41.2×97 world units at this scale).
The melee hitbox remains 500×500 native units with offset `(500, -250)`:
its reach is unchanged, but its center is now at hand/torso height.
Collision nodes retain unit local scale. `_Visual.position.y = -250` matches
the body/hurtbox offset. Movement, gravity, jump velocities and world-space
interaction distances are unchanged. HUD/effect scaling is a visual-only exception.

The equipment-swap view anchors at native Y = -750, just above the head.
Its 600-native-unit width follows the player size (60 world pixels at 0.1),
while its height, text size and 4-world-pixel head gap stay constant.
The view cancels inherited scale for its controls in both editor and gameplay.

Unlike Sprite2D, Skeleton2D and skinned Polygon2D do not expose `flip_h`.
The visual rig is reflected as a whole, including its IK targets and attachments;
the actor and physics are never reflected. RemoteTransform2D must transfer the
complete bone transform to preserve correct reflection. Source art faces right.

Skinned Polygon2D attachments are the exception: their RemoteTransform2D nodes
must not copy rotation or scale, which are already supplied by skeletal skinning
and the shared rig parent. Copying global scale without rotation can retain a
negative local Y scale after repeated facing changes and make the thighs vanish.
Keep the authored polygon basis unchanged; ordinary sprite attachments still
copy the complete transform. `tests/darklight_facing_check.gd` exercises 48 turns
across idle/run and checks every skinned polygon's basis each frame.

## Provenance and checks

Imported from the user's `dark-sanctum/Scenes/Characters/dark_light.tscn`, its
DarkLight body textures and sword/bow assets. Source files were left untouched.
Only SoupIK's required runtime scripts/resources/icons are vendored in
`addons/soupik`, with its original license. The process-mode setter/initialization
in SoupMod is corrected to avoid running each solver in both update loops.

Run `tests/run_tests.gd -- darklight_visual animation_pipeline equipment_swap`
and `tests/darklight_runtime_check.gd` with Godot. The runtime check verifies
floor contact, native sprite scale, walking, facing, jumping, equipped bow and
inventory pause/resume; graphical runs save right/left/bow previews in `.godot`.
