---
title: Каталог источников
type: index
created: 2026-09-20
updated: 2026-09-25
tags: [meta, workflow]
---

# Каталог источников

Raw-слой проекта — это то, что wiki читает, но никогда не переписывает и не
копирует: сцены, скрипты, ресурсы и настройки. Код и сцены остаются ground
truth: если страница wiki расходится с проектом, права страница-владелец темы, а
расхождение фиксируется как lint-находка, а не замалчивается.

Ссылки на raw-файлы из wiki идут обычными относительными markdown-ссылками: они
работают на GitHub и не разрешаются в Obsidian — это ожидаемо, потому что цели
лежат вне vault.

## Разделы проекта

| Раздел | Что содержит | Ведущие страницы |
| --- | --- | --- |
| `framework/` | Каркас: `core` (Actor, Component, PauseLease), `components`, `state` и `states`, `animation`, `events`, `input`, `resources`, `services`, `systems`, `camera`, `debug` | [[Architecture_Rules]], [[Components]] |
| `features/` | Механики по папкам: `movement`, `combat`, `health`, `state`, `status`, `stats`, `stamina`, `inventory`, `equipment`, `items`, `ranged`, `magic`, `throwing`, `aiming`, `enemy`, `boss`, `loot`, `progression`, `rest`, `save`, `level`, `player`, `audio` | [[Components]], [[DOT]], [[Aiming]] |
| `game/` | Игровой контент: `player/` (Darklight), `enemy/` (шаблоны и `monsters/`), `items/`, `status/` (эффекты и `DotCatalog.tres`), `menu/`, `level/` | [[Project_Guide]], [[Monster_Collection]] |
| `levels/` | Шаблон `LevelTemplate.tscn`, игровые уровни и `workshops/` с мастерскими TileSet | [[Level_Authoring]] |
| `tests/` | Автоматические проверки, песочницы (`MovementSandbox.tscn`, `AimingSandbox.tscn`) и фикстуры | [[Testing]], [[Development_Sandbox]] |
| `assets/` | Графика, звук, шрифты, тайлсеты и шейдеры | [[Level_Authoring]], [[Animation_Workflow]] |
| `art/` | Исходники анимаций и ригов (Blender) с пояснениями в README | [[Animation_Workflow]] |
| `project.godot` | Имя проекта, главная сцена, автолоады, разрешение и раскладка ввода | [[Architecture_Rules]], [[Testing]] |
| `default_bus_layout.tres` | Аудиошины проекта | [[Animation_Workflow]] |
| `addons/` | Сторонние аддоны редактора; не документация проекта | — |
| `AGENTS.md` (корень) | Инструкции агенту по репозиторию: конвенция размеров сцен, персонажи и враги, главный герой, документация, порядок коммитов | [[AGENTS]] |

Пустые и генерируемые каталоги в документации не описываются: `.godot/`
создаёт редактор, а `export_templates/`, `feature_profiles/`, `script_templates/`,
`text_editor_themes/` и `ui/` сейчас пусты.

## README вне vault

Эти файлы остаются на своих местах и не переносятся в wiki. Здесь они собраны
как указатели; открываются на GitHub.

| Файл | О чём | Связанные страницы |
| --- | --- | --- |
| [game/player/darklight/README.md](../game/player/darklight/README.md) | Риг Darklight: крепления, масштаб, анимации и ограничения | [[Animation_Workflow]], [[Project_Guide]] |
| [game/items/README.md](../game/items/README.md) | Предметы: `ItemData`, шаблоны, требования и порядок создания | [[Item_Creation_Design]], [[Item_Parameters]] |
| [game/menu/README.md](../game/menu/README.md) | Меню, создание персонажа, слот прохождения и сохранения | [[Save_System]] |
| [game/enemy/monsters/stone_golem/README.md](../game/enemy/monsters/stone_golem/README.md) | Первый босс: сцена, анимации и что отключено до подключения боя | [[Boss_Encounters]], [[Monster_Collection]] |
| [levels/README.md](../levels/README.md) | Папка уровней и шаблон | [[Level_Authoring]] |
| [levels/workshops/README.md](../levels/workshops/README.md) | Мастерские TileSet: выбор набора и папки ресурсов | [[Level_Authoring]] |
| [levels/workshops/Cave.md](../levels/workshops/Cave.md) | Набор Cave: основа, облицовка и готовые конструкции | [[Level_Authoring]] |
| [art/hero_idle/README.md](../art/hero_idle/README.md) | Исходник idle героя: кадры, fps, что сохранено | [[Animation_Workflow]] |
| [art/hero_movement/README.md](../art/hero_movement/README.md) | Бег, прыжок и падение без оружия, порядок глубины рук | [[Animation_Workflow]] |
| [art/drow_rig/README.md](../art/drow_rig/README.md) | Риг Drow: T-pose источник и состав экспорта | [[Animation_Workflow]] |

## Что делать при изменении раскладки

Если раздел проекта переименован, появился или исчез, обновите таблицы этой
страницы и проверьте ссылки на raw-файлы:

```sh
node tools/wiki_lint.mjs
```

Линтер сообщает о ссылках, чьи цели больше не существуют.
