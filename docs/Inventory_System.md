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

Paper-doll equipment currently supports two independent main/off-hand weapon
sets, head, chest, hands, legs, two rings, two earrings, one amulet, and one
back slot. Equipped entries reference items that remain visible in the main
inventory. Removing the last copy of an item automatically unequips it.
Light and heavy melee attacks, guard, and parry require a melee weapon in the
active set's main hand. Dropping or otherwise removing that weapon immediately
cancels any attack, guard, or parry already in progress and blocks new ones
until another melee weapon is equipped in the active set.
Guard can begin only on the ground. Its parry window and sustained block both
hold the Actor in place while still allowing facing changes.

The starting inventory contains a Rusty Sword, Wooden Shield, Short Bow, Light
Crossbow, Apprentice Focus, three Health Potions, three Mana Potions, and two
Experience Tonics. The last two are temporary functional items for testing
quick-access assignment and item use. Weapon set one starts as sword and shield;
set two starts with the bow. Crossbow and focus remain in the inventory and can
replace a main-hand weapon through the equipment menu.

Equipped main-hand damage is added to melee, bow, crossbow, and magic base
damage. Heavy melee attacks multiply the combined value. Defense from the
active weapon set, armor, and accessories reduces incoming damage with
`damage * 100 / (100 + defense)`. Strength and dexterity requirements prevent
equipping an item until the Actor has the required attributes. The inventory
details panel shows these values and compares an item with the active equipped
item in the same slot.

The functional menu supports immediate consumable use while paused,
equip/unequip toggling, manual quick-slot assignment and clearing, stack
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
centered panel occupies half of the viewport without a fullscreen overlay. The
separate HUD hotbar reveals all eight quick-access cells, including empty cells
available for assignment. The inventory grid uses icon-only 64-pixel cells. A
temporary item card appears on hover; clicking an item selects it and pins the
card with its description, quantity, weight, value, requirements, stats, and
equipment comparison. The panel also shows both weapon sets, armor and accessory
slots, and actions for using, equipping,
splitting, quick-slot assignment, and quantity-confirmed dropping. The same
multi-stack bag is used by enemy drop tables; collecting it transfers everything
that fits and leaves any remainder on the ground. The item grid can be filtered
by category and sorted by name, category, weight, or value. Drag-and-drop
supports equipping compatible slots, returning equipment to inventory, assigning
or clearing quick slots, and rearranging quick-slot assignments. Manual item-grid
ordering and selling remain later interaction work.

Weight is recorded in `ItemData` and exposed by `InventoryComponent`, but no
weight limit is enforced until the design decides how encumbrance should work.
