# Inventory System

## Working decisions for version 0.1

The inventory has two connected layers:

- a paused main inventory for item management and equipment;
- eight fixed quick-access slots for real-time use.

The first two quick slots represent weapon sets, the third starts as the health
consumable slot, and slots four through eight are configurable. These rules are
data-driven and may change after playtesting.

Until inventory-backed starter weapons are introduced, empty quick slots four
through six retain the previous bow, crossbow, and magic shortcuts. Assigning a
combat item replaces that temporary fallback for the slot.

Paper-doll equipment currently supports two independent main/off-hand weapon
sets, head, chest, hands, legs, two rings, two earrings, one amulet, and one
back slot. Equipped entries reference items that remain visible in the main
inventory. Removing the last copy of an item automatically unequips it.

Every item occupies one inventory cell. Stackable items share a cell up to
their configured maximum. Non-stackable items always occupy separate cells.

## Implementation stages

1. `ItemData`, stacks, and inventory storage.
2. Paper-doll equipment with two weapon sets. *(implemented)*
3. Eight quick-access slots and runtime switching. *(implemented)*
4. Pickup and loot integration.
5. Paused inventory UI, item details, and management actions.

Weight is recorded in `ItemData` and exposed by `InventoryComponent`, but no
weight limit is enforced until the design decides how encumbrance should work.
