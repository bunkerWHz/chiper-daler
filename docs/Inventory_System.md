# Inventory System

## Working decisions for version 0.1

The inventory has two connected layers:

- a paused main inventory for item management and equipment;
- eight fixed quick-access slots for real-time use.

The hotbar contains items only. Slot one is the fixed Health Potion slot, while
slots two through eight are configurable for consumables, throwables, spells,
and future combat-ready item types. Weapon sets are not hotbar entries.

All eight number keys address real quick-access slots. `Q` and `E` cycle
backward and forward through available slots, wrapping around and skipping
empty ones. `R` is contextual: a nearby world target has priority; otherwise it
uses the active hotbar item. Consumables activate on press, while throwables aim
until `R` is released. `Tab` cycles the two weapon sets separately, like
changing combat stance, and activates the combat mode of the new main-hand
weapon. `J` and `K` remain the primary and secondary weapon actions.
The fixed Health Potion slot is active and usable immediately after the Player
spawns; selecting a consumable never changes the active weapon mode.
Consumables can be used only while grounded. Using one holds the Player in
place and blocks jumping and dodging until the action completes; leaving the
ground cancels the action without spending the item.

Paper-doll equipment currently supports two independent main/off-hand weapon
sets; head, shoulder, chest, hands, belt, legs, and feet armor; four rings; two
earrings; an amulet, artifact, and brooch; and three runes. The menu presents the
active weapon set and wearable slots as a three-column, seven-row paper doll;
the compact `Set 1` and `Set 2` buttons switch which hand slots are shown. The
active set uses an amber background and border instead of an extra text label,
keeping the equipment column and its scrollbar tight to the item grid. Equipped
copies appear only in the equipment area and are excluded
from the main bag grid and its visible weight/slot summary. The inventory
component remains the single owner of item data while equipment reserves the
equipped quantity. Unequipping returns that copy to the main grid; removing the
last owned copy automatically clears its equipment slot.
Light and heavy melee attacks, guard, and parry require a melee weapon in the
active set's main hand. Dropping or otherwise removing that weapon immediately
cancels any attack, guard, or parry already in progress and blocks new ones
until another melee weapon is equipped in the active set.
Guard can begin only on the ground. Its parry window and sustained block both
hold the Actor in place while still allowing facing changes.

Weapons define a family, one- or two-handed grip, primary damage type, moveset,
available actions, attack speed, reach, stagger, attribute scaling, and optional
ammunition type in `ItemWeaponProfile`. Offhand tools use a separate
`ItemOffhandProfile` for shield/catalyst family, actions, block reduction, guard
stability, and parry timing. Equipping a two-handed main weapon automatically
clears the offhand of that weapon set, and an offhand cannot be equipped while
that main weapon remains active. The other weapon set is independent. Moveset
execution and final scaling formulas will consume this metadata in later tasks;
they are intentionally not hard-coded into item resources.
Light/heavy attacks, guard, and parry now consult those action flags. Defensive
actions may come from either the main-hand weapon or the equipped offhand tool;
legacy items without a specialized profile retain their previous behavior while
the remaining item resources are migrated.
Bow and crossbow aiming/firing and magic casting/channeling use the same action
gate. `Reload` is already represented in weapon data but will become mandatory
only when a real crossbow reload phase exists.
The inventory item card exposes weapon family, grip, damage type, moveset,
actions, scaling, timing/reach values, ammunition, and shield/offhand defense
data. The bag and equipped paper doll continue to show icons only.

Endurance increases maximum health and equipment load through a configurable
derived-stat resource. At the reference value of 5 Endurance, base health is
unchanged and maximum equipment load is 25; each Endurance point changes health
by 10 and load by 3. Inventory weight remains informational and item pickup is
limited by bag cells, not kilograms. Equipment load counts armor, accessories,
and weapons in both weapon sets. Its ratio is exposed for later movement and
dodge tiers but does not affect locomotion yet.
Wisdom increases maximum mana through the same derived-stat resource. At the
reference value of 5 Wisdom, base mana is unchanged; each Wisdom point changes
maximum mana by 10. Mana restoration and the HUD use the derived maximum.

The first one-handed content batch adds training rapier, katana, and dagger
resources without adding them to the starting inventory. They share the
temporary warrior visual but have distinct thrust/slash profiles, moveset IDs,
actions, speed, reach, stagger, requirements, weight, and scaling. Critical
damage is weapon data and is applied to the active melee hitbox; the dagger has
the strongest critical multiplier in this batch.
The first strength-focused batch adds training battle axe, war hammer, and
greatsword resources. All are two-handed and therefore reserve their weapon
set's offhand, while their slash/strike type, speed, reach, stagger, weight,
requirements, and scaling remain independent data.
The remaining two-handed batch adds training great hammer, staff, halberd, and
scythe. The staff exposes cast/channel actions and intelligence scaling; the
great hammer leads stagger and weight; the halberd leads reach; the scythe
leans toward dexterity and critical damage.
The current offhand catalog contains buckler and greatshield. Daggers are
main-hand-only for now; the former parrying-dagger resource is retained as a
legacy main-hand dagger but is excluded from the starting inventory. Shield
block reduction and parry-window multipliers affect `GuardComponent`; stability
remains reserved for the future stamina/poise system.

The Player now owns a minimal stamina resource with spending, delayed
regeneration, restoration, save-state support, and a temporary green HUD bar.
Combat actions do not consume stamina yet. The starting inventory replaces the
old sword, shield, focus, and spear with the new weapon/offhand batches; the
legacy bow and crossbow remain only until their replacement resources exist.

Armor uses a dedicated profile with light, heavy, and robe classes, set ID, and
poise. The first comparison batch contains one chest item per class and is
included in the starting inventory. Defense and weight remain shared equipment
data; total equipped poise is exposed for the later stagger-resistance system.
Each armor class now also has a head item in the same set: scout leather hood,
knight plate helm, and scholar hood.
The same three sets include shoulder items: scout leather mantle, knight plate
pauldrons, and scholar mantle.
Hands and belt slots now follow the same three-class comparison: scout leather
gloves and utility belt, knight plate gauntlets and war belt, scholar handwraps
and sash. The test player's inventory scene has 60 cells so the growing item
catalog fits during development; the reusable inventory default remains 40.
The same comparison sets are complete for the core armor slots with scout
leather pants and boots, knight plate leggings and greaves, and scholar trousers
and shoes. Chest resources are explicitly covered by slot tests alongside every
other core armor piece.

The starting inventory contains the complete training weapon/offhand catalog,
the growing light/heavy/robe armor sets, training bow and crossbow,
permanent health, mana, and rage flasks with three charges each, and two
Experience Tonics. These are functional test items for equipment, quick-access,
item-use, and visual-profile checks. Weapon set one starts with a katana and
buckler; set two starts with the bow.

The training weapon catalog now covers sword, rapier, katana, dagger, axe,
mace, greatsword, great hammer, spear, halberd, scythe, wand, staff, bow, and
crossbow. The original Rusty Sword, Training Spear, Apprentice Focus, Short Bow,
and Light Crossbow resources remain loadable for save compatibility but are no
longer included in the starting inventory or weapon sets.

Inventory icons support double-click equipment. The action fills the first free
compatible slot and replaces slot zero when every compatible slot is occupied.
Double-clicking an occupied equipment slot unequips its item back to the bag.
Equipping a two-handed weapon replaces both hands. Bows and crossbows then put
the first compatible ammunition stack into the active set's offhand: arrows for
bows and bolts for crossbows. Without compatible ammunition, the ranged weapon
still equips and offhand remains empty. Non-ammunition offhands remain invalid
while a two-handed weapon is active.

Equipped main-hand damage is added to melee, bow, crossbow, and magic base
damage. Heavy melee attacks multiply the combined value. Defense from the
active weapon set, armor, and accessories reduces incoming damage with
`damage * 100 / (100 + defense)`. Strength, dexterity, intelligence, endurance,
and wisdom requirements prevent equipping an item until the Actor has the
required attributes. The inventory
details panel shows these values and compares an item with the active equipped
item in the same slot.

The functional menu can begin consumable use while paused, then closes and
resumes the game so the full use action must complete. Health, mana, and rage
are applied only at the end of that action. Taking damage, leaving the ground,
or changing action context cancels it without consuming the item. The menu also
supports equip/unequip toggling, manual quick-slot assignment and clearing, stack
splitting when a free cell exists, and quantity-confirmed dropping. Key items
cannot be dropped. A confirmed multi-item drop creates one loot bag containing
the selected quantity. Dropping the only copy of an item skips the quantity
dialog and creates the loot bag immediately.

The single player hotbar sits to the right of the health bar. During gameplay it
shows only available quick-access slots, so empty cells do not occupy space.
Opening the inventory expands this same hotbar to all eight cells and enables
drag-and-drop into configurable slots two through eight; the inventory panel
does not create a second hotbar. It follows the active slot, item assignments,
icons and stack quantities in real time. Hotbar icons render
at a fixed 64 by 64 pixels. Items without final art use the shared
`assets/icon_placeholder.png` texture, scaled down where smaller menu icons are
required.

While the inventory is open, hovering a hotbar slot uses the same item card as
the inventory grid. Assigned slots show full item details, and empty configurable
slots explain that a combat item can be dropped there. Leaving the slot restores
any card previously pinned by clicking an inventory item.

Each item type may be assigned to only one quick-access slot, including the
fixed health-potion slot. A configurable assignment can be removed by dragging
it back into the inventory grid or releasing it outside the hotbar while the
inventory is open.

Every item occupies one inventory cell. Stackable items share a cell up to
their configured maximum. Non-stackable items always occupy separate cells.

## Item data model

`ItemData` contains identity, presentation, category, economy, and stacking
rules. Optional focused resources contain behavior for a particular item
family:

- `ItemEquipmentProfile` declares every compatible equipment slot and stat
  requirements/modifiers;
- `ItemWeaponProfile` declares combat mode and the temporary visual archetype;
- `ItemConsumableProfile` declares the current use effect, value, status, and
  presentation effect.

Gameplay systems use the `ItemData` query methods, so a profile can replace the
legacy flat fields without changing every consumer at once. The flat fields
remain serialized fallbacks during migration of older resources and saves.
Production test items already use profiles. Durability is not part of the game
and is not stored in item stats.

Equipment enhancement will be runtime state on a unique item instance, never a
mutation of shared `ItemData`. A failed enhancement attempt spends the required
currency and materials, but does not reduce the enhancement level and cannot
damage or destroy the item.

Health, mana, and rage flasks use persistent charges instead of disappearing
inventory stacks. `FlaskChargesComponent` owns current charges for each Actor.
At zero charges the item and hotbar binding remain visible and selectable, but
use is disabled. Flasks cannot be stacked, removed, dropped, or transferred;
sanctuary rest refills every owned flask. Their runtime charge state is saved
independently from inventory ownership.
Persistent flasks are also rejected by enemy loot tables and loot bags. The
default test enemy drops an ordinary Experience Tonic instead, so every item in
its bag can be collected normally.

## Implementation stages

1. `ItemData`, stacks, and inventory storage.
2. Paper-doll equipment with two weapon sets. *(implemented)*
3. Eight quick-access slots and runtime switching. *(implemented)*
4. Loot-bag and enemy-drop integration. *(implemented)*
5. Paused inventory UI, item details, equipment, filtering, sorting, and quick
   assignment. *(implemented)*
6. Reactive eight-slot quick-access HUD. *(implemented)*
7. Drag-and-drop between inventory, equipment, and configurable quick slots.
   *(implemented)*

Press `I` to open or close the inventory. Opening it pauses the scene tree. The
panel keeps its centered half-screen width, begins below the health and hotbar
HUD, and extends to 95 percent of the viewport height so five percent remains
visible beneath it. It has no fullscreen overlay. The separate HUD hotbar
reveals all eight quick-access cells, including empty cells
available for assignment. The inventory grid uses five columns of icon-only
64-pixel items. The equipment column reserves enough fixed width for its three
paper-doll cells and vertical scrollbar without adding scrollable padding. This
keeps both scrollbars adjacent to their grids without covering an item. A
temporary item card appears on hover; clicking an item selects it and pins the
card with its description, quantity, weight, value, requirements, stats, and
equipment comparison. The panel also shows both weapon sets, armor and accessory
slots as icon-only cells. Hovering, focusing with the keyboard, or selecting an
equipped icon uses the same item card as the main grid. Compatible items can be
dragged from the bag into equipment, while dragging an equipped item back to the
bag unequips it. Equipment cells also accept compatible equipped items for moving
or swapping between slots. The panel includes actions for using, equipping,
splitting, quick-slot assignment, and quantity-confirmed dropping. The same
multi-stack bag is used by enemy drop tables; collecting it transfers everything
that fits and leaves any remainder on the ground. The item grid can be filtered
by category and sorted by name, category, weight, or value. Drag-and-drop
supports equipping compatible slots, returning equipment to inventory, assigning
or clearing quick slots, and rearranging quick-slot assignments. Manual item-grid
ordering and selling remain later interaction work.

Weight is recorded in `ItemData` and exposed by `InventoryComponent`, but no
weight limit is enforced until the design decides how encumbrance should work.

## Temporary player visuals

`TemporaryPlayerVisualComponent` isolates the current test art from the generic
animation architecture. A main-hand item's `visual_archetype` selects warrior,
archer, or lancer sprite sheets; the bow and crossbow also fall back to archer.
Switching the active weapon set refreshes the profile immediately.

Item effects use an `AnimatedSprite2D` overlay above the character. Health,
mana, and rage play their own animation for exactly the configured item-use
duration. Successful rage use applies the provisional `rage` buff status. A
second overlay plays the shared buff animation whenever any buff is applied,
allowing both layers to coexist. These profiles and assets are deliberately
temporary and can be replaced without changing equipment or item-use rules.
