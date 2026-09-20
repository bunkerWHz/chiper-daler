---
title: План по предметам
type: plan
created: 2026-09-20
updated: 2026-09-20
tags: [items, workflow]
---

# План по предметам

Что предстоит доделать в каталоге предметов. Страница заведена после сплошной
проверки 45 ресурсов и 13 шаблонов; список задач и таблица предметов
обновляются по мере работы.

Правила, по которым предметы проверяются, живут в
[[Item_Creation_Design|устройстве оружия и брони]] и
[[Item_Parameters|параметрах предметов]]. Состояние полей и их потребителей —
там же; эта страница отвечает за то, чего ещё не хватает.

Список собирается повторным прогоном аудитора:

```sh
godot --headless --path . --script tests/item_audit.gd
```

Аудитор только читает ресурсы и печатает JSON: `error` — нарушение правила,
`pending` — известный пробел с этой страницы, `note` — осознанная схема,
похожая на пропуск.

## Состояние на 2026-09-20

| Показатель | Значение |
| --- | ---: |
| Реальных предметов в каталоге | 45 |
| Шаблонов в `game/items/templates` | 13 |
| Нарушений правил: вес и цена, `is_valid()`, уникальность `id`, профили, стопки | 0 |
| Предметов без иконки | 38 |
| Предметов без мирового арта — скрыты при экипировке | 14 |
| Файлов графики, не подключённых ни к чему | 9 |

Ни один предмет не нарушает установленных правил. Пробелы ниже — это
отсутствующий арт и незакрытые решения, а не ошибки в данных.

## Задачи

- [ ] **T1. Иконки для 38 предметов.** Арта нет вовсе: `assets/items/Weapons/` и
  `assets/items/Armors/` пусты, единственная картинка брони — `Odin Shiled.png`
  для младшего щита. Пока иконка не назначена, интерфейс показывает
  `icon_placeholder.png` — это документированное стартовое значение, а не
  поломка. Нужны иконки: 21 доспех, `Training Greatshield`, 13 единиц оружия,
  `Training Arrows`, `Training Bolts`, `Training Stone`.
- [ ] **T2. Мировой арт для 14 предметов.** Без `equipped_texture` или
  `equipped_visual` предмет при экипировке скрыт — так описано в
  [[Inventory_System|системе инвентаря]]. Не хватает 13 единицам оружия
  (есть только у лука и катаны) и `Training Greatshield`. Причина та же, что в
  T1, но последствие заметнее: предмет не виден в руке героя.
- [ ] **T3. Решить судьбу 9 неиспользованных файлов графики.** `Flasks/Darkness`,
  `Flasks/Poison`, `Flasks/Spirit`, `Jewerly/Ring`, `Jewerly/Brooch`,
  `Jewerly/Necklace`, `Bone Bow_bw_ready`, `Throwables/Destiny Axes` (два файла).
  Либо под них создаются предметы — тогда нужны эффекты, урон и цены от
  дизайнера, — либо файлы остаются заготовками. Иконки трёх существующих флясок
  взяты из той же папки `Flasks`, так что место для них уже готово.
- [ ] **T4. Зафиксировать схему щитов.** `Training Buckler` и
  `Training Greatshield` идут категорией `ARMOR` с `offhand_profile` и без
  `armor_profile`; `templates/Shield` устроен так же. Отдельной категории
  `SHIELD` в `ItemData.Category` нет. Это осознанная схема, но она выглядит
  пропуском — описать её в [[Item_Parameters|параметрах предметов]].
- [ ] **T5. Мелочи в данных.** У `training_longspear` название предмета —
  «Training Spear», то есть имя ресурса и имя в интерфейсе расходятся. В имени
  файла `Axe of Destiny.png` есть пробел — учесть при подключении.
- [ ] **T6. Перепроверить после появления арта.** Прогон аудитора должен
  показать ноль в строках «без иконки» и «без мирового арта»; тогда задачи T1 и
  T2 закрываются.

## Список предметов

`Иконка`: **нет** — ресурс без картинки, показывается общая заглушка.
`Арт в руке`: **нет** — предмет не виден при экипировке; прочерк означает, что
предмет в руках не держится и арт ему не нужен.

| id | Название | Категория | Слот | Вес | Цена | Иконка | Арт в руке | Что требуется |
| --- | --- | --- | --- | ---: | ---: | --- | --- | --- |
| `training_arrows` | Training Arrows | AMMUNITION | OFF_HAND | 0,05 | 1 | **нет** | — | иконка |
| `training_bolts` | Training Bolts | AMMUNITION | OFF_HAND | 0,08 | 1 | **нет** | — | иконка |
| `knight_plate_armor` | Knight Plate Armor | ARMOR | CHEST | 12 | 70 | **нет** | — | иконка |
| `knight_plate_gauntlets` | Knight Plate Gauntlets | ARMOR | HANDS | 3 | 30 | **нет** | — | иконка |
| `knight_plate_greaves` | Knight Plate Greaves | ARMOR | FEET | 4 | 36 | **нет** | — | иконка |
| `knight_plate_helm` | Knight Plate Helm | ARMOR | HEAD | 4 | 35 | **нет** | — | иконка |
| `knight_plate_leggings` | Knight Plate Leggings | ARMOR | LEGS | 6,5 | 48 | **нет** | — | иконка |
| `knight_plate_pauldrons` | Knight Plate Pauldrons | ARMOR | SHOULDER | 3,5 | 32 | **нет** | — | иконка |
| `knight_war_belt` | Knight War Belt | ARMOR | BELT | 2 | 26 | **нет** | — | иконка |
| `scholar_handwraps` | Scholar Handwraps | ARMOR | HANDS | 0,4 | 22 | **нет** | — | иконка |
| `scholar_hood` | Scholar Hood | ARMOR | HEAD | 0,7 | 27 | **нет** | — | иконка |
| `scholar_mantle` | Scholar Mantle | ARMOR | SHOULDER | 0,5 | 24 | **нет** | — | иконка |
| `scholar_robe` | Scholar Robe | ARMOR | CHEST | 3 | 55 | **нет** | — | иконка |
| `scholar_sash` | Scholar Sash | ARMOR | BELT | 0,3 | 20 | **нет** | — | иконка |
| `scholar_shoes` | Scholar Shoes | ARMOR | FEET | 0,7 | 24 | **нет** | — | иконка |
| `scholar_trousers` | Scholar Trousers | ARMOR | LEGS | 1,4 | 32 | **нет** | — | иконка |
| `scout_leather_armor` | Scout Leather Armor | ARMOR | CHEST | 5 | 35 | **нет** | — | иконка |
| `scout_leather_boots` | Scout Leather Boots | ARMOR | FEET | 1,2 | 18 | **нет** | — | иконка |
| `scout_leather_gloves` | Scout Leather Gloves | ARMOR | HANDS | 0,8 | 15 | **нет** | — | иконка |
| `scout_leather_hood` | Scout Leather Hood | ARMOR | HEAD | 1,2 | 18 | **нет** | — | иконка |
| `scout_leather_mantle` | Scout Leather Mantle | ARMOR | SHOULDER | 1 | 16 | **нет** | — | иконка |
| `scout_leather_pants` | Scout Leather Pants | ARMOR | LEGS | 2,5 | 24 | **нет** | — | иконка |
| `scout_utility_belt` | Scout Utility Belt | ARMOR | BELT | 0,7 | 14 | **нет** | — | иконка |
| `training_buckler` | Training Buckler | ARMOR | OFF_HAND | 1,5 | 22 | есть | есть | — |
| `training_greatshield` | Training Greatshield | ARMOR | OFF_HAND | 10 | 48 | **нет** | **нет** | иконка, арт в руке |
| `health_potion` | Health Potion | CONSUMABLE | — | 0 | 0 | есть | — | — |
| `mana_potion` | Mana Potion | CONSUMABLE | — | 0 | 0 | есть | — | — |
| `rage_potion` | Rage Potion | CONSUMABLE | — | 0 | 0 | есть | — | — |
| `gothic_swords` | Gothic Swords | THROWABLE | — | 1 | 1 | есть | есть | — |
| `training_stone` | Training Stone | THROWABLE | — | 1 | 1 | **нет** | — | иконка |
| `training_battle_axe` | Training Battle Axe | WEAPON | MAIN_HAND | 6 | 34 | **нет** | **нет** | иконка, арт в руке |
| `training_bow` | Training Bow | WEAPON | MAIN_HAND | 2,2 | 34 | есть | есть | — |
| `training_crossbow` | Training Crossbow | WEAPON | MAIN_HAND | 3,8 | 44 | **нет** | **нет** | иконка, арт в руке |
| `training_dagger` | Training Dagger | WEAPON | MAIN_HAND | 1 | 18 | **нет** | **нет** | иконка, арт в руке |
| `training_great_hammer` | Training Great Hammer | WEAPON | MAIN_HAND | 11 | 50 | **нет** | **нет** | иконка, арт в руке |
| `training_greatsword` | Training Greatsword | WEAPON | MAIN_HAND | 8 | 42 | **нет** | **нет** | иконка, арт в руке |
| `training_halberd` | Training Halberd | WEAPON | MAIN_HAND | 7,5 | 44 | **нет** | **нет** | иконка, арт в руке |
| `training_katana` | Training Katana | WEAPON | MAIN_HAND | 3 | 28 | есть | есть | — |
| `training_longspear` | Training Spear | WEAPON | MAIN_HAND | 4,5 | 34 | **нет** | **нет** | иконка, арт в руке |
| `training_rapier` | Training Rapier | WEAPON | MAIN_HAND | 2 | 24 | **нет** | **нет** | иконка, арт в руке |
| `training_scythe` | Training Scythe | WEAPON | MAIN_HAND | 6 | 45 | **нет** | **нет** | иконка, арт в руке |
| `training_staff` | Training Staff | WEAPON | MAIN_HAND | 4 | 46 | **нет** | **нет** | иконка, арт в руке |
| `training_sword` | Training Sword | WEAPON | MAIN_HAND | 3,5 | 30 | **нет** | **нет** | иконка, арт в руке |
| `training_wand` | Training Wand | WEAPON | MAIN_HAND | 1,2 | 38 | **нет** | **нет** | иконка, арт в руке |
| `training_war_hammer` | Training War Hammer | WEAPON | MAIN_HAND | 7 | 36 | **нет** | **нет** | иконка, арт в руке |

## Шаблоны

Шаблоны не попадают в каталог и намеренно не имеют `id`; копия шаблона получает
стартовые значения, включая вес 1 и цену 1.

| Файл | Категория | Слот | Стопка | Вес | Цена |
| --- | --- | --- | ---: | ---: | ---: |
| `Accessory.tres` | RING | RING | — | 1 | 1 |
| `Ammunition.tres` | AMMUNITION | OFF_HAND | 999 | 1 | 1 |
| `Armor.tres` | ARMOR | CHEST | — | 1 | 1 |
| `Bow.tres` | WEAPON | MAIN_HAND | — | 2,2 | 34 |
| `Consumable.tres` | CONSUMABLE | — | 10 | 1 | 1 |
| `Crossbow.tres` | WEAPON | MAIN_HAND | — | 3,8 | 44 |
| `Key.tres` | KEY | — | — | 1 | 1 |
| `Lore.tres` | LORE | — | — | 1 | 1 |
| `Material.tres` | MATERIAL | — | 99 | 1 | 1 |
| `Scroll.tres` | SCROLL | — | 10 | 1 | 1 |
| `Shield.tres` | ARMOR | OFF_HAND | — | 1 | 1 |
| `Throwable.tres` | THROWABLE | — | 20 | 1 | 1 |
| `Weapon.tres` | WEAPON | MAIN_HAND | — | 1 | 1 |

## Как закрывать задачи

Изменение данных или арта проходит через тот же порядок, что и любая правка
проекта: обновить страницу-владельца темы, отметить пункт здесь и прогнать
проверки — `tests/run_tests.gd` для поведения и
`node docs/tools/wiki_lint.mjs` для документации.
