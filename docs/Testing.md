---
title: Запуск игровых тестов
type: guide
created: 2026-09-05
updated: 2026-09-18
tags: [testing, workflow]
---

# Запуск игровых тестов

## Прицеливание

`tests/AimingSandbox.tscn` — отдельная площадка общего прицела. F1: бросок (R),
F2: лук (J), F3: арбалет (J), F4: заклинание (J). F1–F4 пополняют ресурсы
прототипа. Удерживайте кнопку действия, меняйте угол мышью или W/S,
разворачивайтесь A/D, отпускайте для выпуска; K отменяет подготовку.
Левый стик управляет углом и стороной, X стреляет, Y бросает, B отменяет,
LB/RB переключают быстрые слоты (названия кнопок Xbox).

Автоматические проверки: `--script tests/run_tests.gd -- aiming throwing ranged_weapon magic`.
Проверяются быстрый выпуск, угол, пределы, смешанный ввод, разворот, совпадение
вектора снаряда с прицелом, отмена, пауза, потеря фокуса и баллистика.
Геймпадные события можно проверить программно; ощущения от физического стика
и чувствительность мыши требуют ручной проверки.

## Проверка сохранений

Полная проверка сохранения и загрузки:

```powershell
$env:APPDATA = Join-Path $PWD '.godot/save-test-profile'
$env:LOCALAPPDATA = $env:APPDATA
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
godot --headless --path . --script tests/save_runtime_check.gd
godot --headless --path . --script tests/lost_amber_runtime_check.gd
```

Используйте отдельный сеанс терминала для этих переменных окружения.
В Windows вместо `godot` можно указать полный путь к консольному exe.
Скрипт откажется работать, если профиль не находится внутри `.godot/`.
Реальные сохранения не затрагиваются. Для `tests/menu_runtime_check.gd` используйте
другой **пустой** профиль: он проверяет в том числе отсутствие слота на старте.

Проверка сейвов охватывает автосохранение, раздельные стопки, развитие и экипировку,
постоянное открытие сундука, отдых, переход уровня, смерть, возврат по ID restpoint,
резервную копию, старый формат, некорректные данные и новую игру.
Правила и будущие интеграции описаны в [Save_System.md](Save_System.md).

## Все игровые тесты

Запускайте команды из корня проекта. Нужны Godot 4.6.1 и установленный
`addons/godot_ai`: существующие тесты используют его `McpTestSuite` и
`McpTestRunner`. Каталог addons исключён из Git.

Все игровые тесты:

```sh
godot --headless --path . --script tests/run_tests.gd
```

Только экипировка и меню инвентаря:

```sh
godot --headless --path . --script tests/run_tests.gd -- equipment inventory_menu
```

После `--` перечисляются имена из `suite_name()`, а не имена файлов.
Неизвестное имя считается ошибкой. В Windows используйте консольный файл
Godot (`Godot_v4.6.1-stable_win64_console.exe`); если его нет в PATH,
укажите полный путь к нему.

Последняя строка JSON содержит количество пройденных и проваленных тестов
и описание ошибок. Код завершения: 0 при успехе, 1 при ошибках тестов
или выборе несуществующей группы.

Сцену в редакторе для этого запуска открывать не нужно. Игровые тесты
с обычными сценами не следует запускать внутри редакторского MCP runner:
скрипты без `@tool` в таком окружении могут стать placeholder-экземплярами,
а состояние InputMap отличается от игрового запуска.

Для ручной проверки откройте `tests/MovementSandbox.tscn` и запустите сцену.

Смена наборов экипировки: группа `equipment_swap` проверяет таймер, состояния,
запреты и прерывание. Полная сцена игрока с физикой и переключением из меню:

```sh
godot --headless --path . --script tests/equipment_swap_runtime_check.gd
```

Без `--headless` проверка также сохраняет кадр с полоской над игроком в
`.godot/equipment_swap_preview.png` для визуальной проверки.
Размещение объектов в песочнице можно менять; автоматические тесты не должны
зависеть от их координат.

Появление монстров в EnemyPlatformSandbox проверяется отдельным игровым
тестом, поскольку основной McpTestRunner выполняет тесты синхронно:

```sh
godot --headless --path . --script tests/enemy_sandbox_spawn_check.gd
```

Проверка ждёт отложенного появления первого монстра у EnemySpawn, затем
посылает сигнал завершения смерти и проверяет появление следующего монстра
из очереди. Основной набор отдельно проверяет состав платформ, точку
появления и назначенные сцены монстров.

## Darklight integration

```sh
godot --headless --path . --script tests/run_tests.gd -- darklight_visual animation_pipeline equipment_swap
godot --headless --max-fps 60 --path . --script tests/darklight_runtime_check.gd
```

For visual QA run the second command without `--headless`. It writes
`.godot/darklight_right.png`, `darklight_left.png`, and `darklight_bow.png`.
Use `--max-fps 60` for runtime checks that wait physics frames while gameplay
components also advance timers in `_process`.
