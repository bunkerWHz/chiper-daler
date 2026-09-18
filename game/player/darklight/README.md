# Darklight

`game/player/Player.tscn` uses Darklight as its playable visual. The existing
Actor components still own movement, FSM, inventory, equipment, damage, stamina,
item use, saving and respawning. No gameplay scripts or UI from dark-sanctum are
loaded.

## Editing animations

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

Assign an optional `ItemData.equipped_visual` PackedScene. Its root must be
Node2D; put the grip at `(0, 0)` and keep sprites at native scale. The adapter
instances it under the front/back hand attachment and updates both hands when
the active loadout changes, including unequip and weapon-set changes.

The starting katana and bow have scenes using the imported source weapon art.
The starting buckler has a simple scene-authored polygon placeholder. For other
items, an explicitly assigned inventory icon is an aspect-preserving fallback;
items without either scene or icon have no hand visual. Armor/accessory stats
continue to work, but replacing body-part artwork is not implemented here.

Consumable and buff overlays remain connected to the current item/status signals.

## Size and facing

Player root scale is `(0.04, 0.04)`. Body, hurtbox and hitbox shapes are authored
as 500×500 native units, preserving their previous 20×20 world dimensions.
The hitbox's 500-unit offset preserves its original 20-world-unit reach before
weapon modifiers. `_Visual.position.y = -250` aligns the feet with the existing
floor contact. Movement, gravity, jump velocities and world-space interaction
distances are unchanged. HUD/effect scaling is a visual-only exception.

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
