# Inventory System

## Working decisions for version 0.1

The inventory has two connected layers:

- a paused main inventory for item management and equipment;
- eight fixed quick-access slots for real-time use.

The first two quick slots represent weapon sets, the third starts as the health
consumable slot, and slots four through eight are configurable. These rules are
data-driven and may change after playtesting.

Every item occupies one inventory cell. Stackable items share a cell up to
their configured maximum. Non-stackable items always occupy separate cells.

## Implementation stages

1. `ItemData`, stacks, and inventory storage.
2. Paper-doll equipment with two weapon sets.
3. Eight quick-access slots and runtime switching.
4. Pickup and loot integration.
5. Paused inventory UI, item details, and management actions.

Weight is recorded in `ItemData` and exposed by `InventoryComponent`, but no
weight limit is enforced until the design decides how encumbrance should work.
