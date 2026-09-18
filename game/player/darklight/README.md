# Darklight

Darklight is the project's main playable hero, not an alternate or temporary skin.
`game/player/Player.tscn` is its gameplay scene. The existing
Actor components still own movement, FSM, inventory, equipment, damage, stamina,
item use, saving and respawning. No gameplay scripts or UI from dark-sanctum are
loaded.

## Editing animations

Author all future player rig and animation changes in this repository's
`game/player/darklight/DarklightRig.tscn`, not the external source project.
The legacy Warrior/Archer/Lancer art and `TemporaryPlayerVisualComponent` are
reference assets only and are not the basis for new player work.

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

The source has no dedicated ranged, magic, climbing, item-use, hit, death or
equipment-swap animation. Those states currently use the idle pose; death and
respawn freeze it while the existing fade/respawn components handle the result.
`equipment_swap` retains a two-second empty placeholder clip whose playback rate
follows the swap duration. Add new authored clips and map them in
`_get_animation_name()` to replace these fallbacks.

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
