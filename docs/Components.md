---
title: Справочник компонентов
type: reference
created: 2026-09-13
updated: 2026-09-23
tags: [components, actor, architecture]
---

# Справочник компонентов

Справочник помогает выбрать поведение для объекта и найти его настройки.
Описан текущий код; неактивные заготовки отмечены отдельно.

Для проектирования и расширения статов используйте общий
[список характеристик Actor](Actor_Stats.md): базовые атрибуты, атака,
скорость атаки, защита и DOT с состоянием реализации.

## Быстрый выбор

| Хочу сделать | С чего начать |
| --- | --- |
| Настроить бег и прыжки игрока | [MovementComponent](#movementcomponent), [CharacterBodyComponent](#characterbodycomponent) |
| Добавить уклонение или лестницу | [DodgeComponent](#dodgecomponent), [ClimbingComponent](#climbingcomponent) |
| Сделать объект, который можно ударить | [HealthComponent](#healthcomponent), [HurtboxComponent](#hurtboxcomponent) |
| Добавить ближнюю атаку | [AttackComponent](#attackcomponent), [HitboxComponent](#hitboxcomponent) |
| Добавить DOT и сопротивления ему | [StatusEffectComponent](#statuseffectcomponent), [инструкция по DOT](DOT.md) |
| Добавить блок или защиту брони | [GuardComponent](#guardcomponent), [EquipmentDefenseComponent](#equipmentdefensecomponent) |
| Сделать нового врага | [Компоненты врагов](#enemies), копия GroundDummy или FlyDummy |
| Дать врагу награду и лут | [ExperienceRewardComponent](#experiencerewardcomponent), [LootDropComponent](#lootdropcomponent) |
| Добавить предметы и экипировку | [InventoryComponent](#inventorycomponent), [EquipmentComponent](#equipmentcomponent) |
| Сделать использование зелий | [ItemUseComponent](#itemusecomponent), для фляг — [FlaskChargesComponent](#flaskchargescomponent) |
| Показать инвентарь и быстрые слоты | [InventoryMenuComponent](#inventorymenucomponent), [QuickAccessHUDComponent](#quickaccesshudcomponent) |
| Сделать сундук, рычаг или точку отдыха | [Взаимодействие](#interaction), [объекты мира](#world-objects) |
| Добавить смерть и возрождение | [DeathComponent](#deathcomponent), [PlayerRespawnComponent](#playerrespawncomponent) |
| Добавить анимацию, звук и отдачу от удара | [Отображение](#presentation) |
| Понять, почему персонаж занят | [ActorStateComponent](#actorstatecomponent), [правила совместимости](#coordination) |

## Как читать карточки

- **Делает** — за какое поведение отвечает компонент.
- **Когда применять** — пример использования в игре.
- **Что требуется** — соседи, ресурсы и узлы. «Дополнительно» означает условную или необязательную связь.
- **Настройки и ограничения** — где менять поведение и что пока не реализовано.
- **Файлы** — реализация, готовая сцена и конфигурация, если они есть.

Обязательные соседи должны быть включены. Требования к соседям не заменяют
требования к узлам: например, HitboxComponent нужен собственный Area2D с
формой, а AnimationComponent — узлы в `_Visual`.

## Как добавить компонент

1. Откройте готовую сцену объекта. Для игрока — `game/player/Player.tscn`,
   для нового врага — независимую копию шаблона по [Enemy_Copy.md](Enemy_Copy.md).
2. Добавьте готовую сцену компонента непосредственным ребёнком `_Components`.
   Если `.tscn` нет, добавьте подходящий узел со скриптом и создайте требуемые
   дочерние узлы. Ориентируйтесь на существующую сборку.
3. Добавьте требуемых соседей, назначьте Config/Profile и пути к узлам.
   Ресурс, который должен отличаться только у этого объекта, сделайте **Make Unique**.
4. Запустите сцену и проверьте действие. Сообщение `requires ...` обычно указывает
   на отсутствующий ресурс, компонент или неправильный путь.
5. Для проверки кода используйте группы из [Testing.md](Testing.md).

Actor собирает только непосредственных детей `_Components`, наследующих Component.
Сначала он собирает всех соседей, затем инициализирует их. Это позволяет найти
соседа независимо от порядка узлов, но не гарантирует, что тот уже завершил
собственную инициализацию. Не добавляйте два компонента одного типа: поиск
`get_component()` возвращает первое совпадение, включая наследников.

Пути к рисунку обычно отсчитываются от Actor, к собственному Area2D — от
компонента. Масштаб персонажа задаётся одинаково по обеим осям на корне;
спрайты и коллизионные узлы сохраняют масштаб 1. Размеры форм редактируются в
Shape2D. После изменения масштаба проверяйте также сенсоры и лучи.

<a id="coordination"></a>

## Кто чем управляет

| Часто путают | Разница |
| --- | --- |
| Health / Hurtbox / Death | Health хранит здоровье; Hurtbox обрабатывает боевой удар с защитой; Death завершает жизнь объекта и отключает поведение |
| Attack / Hitbox / EnemyAttack | Attack ведёт действие удара; Hitbox находит поражённые цели; EnemyAttack решает, когда врагу начать удар |
| Movement / CharacterBody | Movement задаёт движение игрока; CharacterBody предоставляет физическое тело и переносит его движение на Actor |
| HitReaction / HitStun / Knockback / HitStop | Рисунок реагирует / персонаж временно недееспособен / тело отбрасывается / игровое время кратко замедляется |
| Inventory / Equipment / QuickAccess | Владение предметами / надетые предметы и доступные действия / привязки быстрых слотов |
| Interaction / Interactable | Компонент действующего персонажа / компонент объекта, с которым взаимодействуют |
| ActorState / игровые способности | Сводка для отображения / реальные владельцы действия и его таймеров |

Компонент действия сам проверяет возможность старта и сообщает о начале и
завершении сигналами. `ExclusiveBehaviorGate` не даёт начать несовместимое
действие, пока другое занимает персонажа. `LocomotionConstraint` позволяет
способности запретить бег, прыжок или уклонение. ActorStateComponent собирает
состояние для отображения; менять его вместо запуска способности не нужно.
Подробности: [Actor_States.md](Actor_States.md) и [Architecture_Rules.md](Architecture_Rules.md).

Обычный боевой удар проходит через Hitbox/ThrownProjectile → Hurtbox →
проверку неуязвимости и модификаторов → Health → реакции и события.
Прямой вызов `HealthComponent.take_damage()` обходит защиту Hurtbox;
он подходит, например, для гарантированной смерти от падения.

## Разделы каталога

- [Основа и движение игрока](#foundation)
- [Здоровье и бой](#combat)
- [Компоненты врагов](#enemies)
- [Предметы и экипировка](#items)
- [Взаимодействие, развитие и возрождение](#interaction)
- [Отображение, звук и отладка](#presentation)
- [Готовые объекты мира](#world-objects)
- [Вспомогательные классы и ресурсы](#helpers)
- [Примеры сборок](#recipes)
- [Ограничения и поиск проблем](#troubleshooting)

<a id="foundation"></a>

## Основа и движение игрока

<a id="component"></a>

### Component — База всех компонентов

- **Делает:** Хранит ссылку на Actor, включение/выключение и общий контракт восстановления состояния.
- **Когда применять:** При написании новой способности: наследуйте этот класс.
- **Что требуется:** Actor с контейнером `_Components`; сам по себе Component не даёт игровой способности.
- **Настройки и ограничения:** Зависимости разрешайте в `on_initialize()`. В `disable()` отменяйте свои действия и восстанавливайте занятое состояние. Capture/restore сохраняют выбранные данные в памяти, не на диск.
- **Файлы:** [Код](../framework/core/Component.gd).

<a id="inputcomponent"></a>

### InputComponent — Команды игрока

- **Делает:** Читает InputMap и выдаёт оси движения, удержания и одноразовые команды.
- **Когда применять:** На управляемом игроком Actor, когда способности читают клавиатуру/контроллер.
- **Что требуется:** Отдельных соседей не требует; нужны действия InputMap проекта.
- **Настройки и ограничения:** Клавиши меняются в Project Settings → Input Map. Методы `consume_*` забирают событие: после чтения оно недоступно второму потребителю в том же цикле.
- **Файлы:** [Код](../framework/components/InputComponent.gd) · [Сцена](../framework/components/InputComponent.tscn).

<a id="characterbodycomponent"></a>

### CharacterBodyComponent — Физическое тело

- **Делает:** Предоставляет скорость, столкновения, пол/стены и `move_and_slide()`, согласуя тело с позицией Actor.
- **Когда применять:** Для движущегося персонажа, наземного или летающего врага.
- **Что требуется:** Дочерний CharacterBody2D; для столкновений — его формы.
- **Настройки и ограничения:** Collision Layer/Mask на компоненте, формы на теле. Направление выбирает MovementComponent или один из компонентов движения врага.
- **Файлы:** [Код](../framework/components/CharacterBodyComponent.gd) · [Сцена](../framework/components/CharacterBodyComponent.tscn).

<a id="facingcomponent"></a>

### FacingComponent — Направление игрока

- **Делает:** Определяет взгляд вправо/влево по вводу и сообщает `facing_changed`.
- **Когда применять:** Для игрока, чьи атаки и рисунок должны следовать направлению ввода.
- **Что требуется:** InputComponent.
- **Настройки и ограничения:** Враг получает направление из своего движения. Исходная графика смотрит вправо, левое направление отображается через flip_h.
- **Файлы:** [Код](../framework/components/FacingComponent.gd).

<a id="movementcomponent"></a>

### MovementComponent — Бег и прыжки игрока

- **Делает:** Ведёт движение, ускорение, гравитацию, обычные и настенные прыжки; применяет ограничения способностей.
- **Когда применять:** Для платформенного управления игроком.
- **Что требуется:** CharacterBodyComponent, InputComponent, MovementConfig. Дополнительно: DodgeComponent и ClimbingComponent.
- **Настройки и ограничения:** Config: Ground movement, Jumping, Acceleration. Передаёт расчёт скорости уклонению/лазанию, если они активны. Не устанавливайте параллельно компоненты движения врага на то же тело.
- **Файлы:** [Код](../features/movement/MovementComponent.gd) · [Сцена](../features/movement/MovementComponent.tscn) · [MovementConfig](../features/movement/MovementConfig.gd).

<a id="dodgecomponent"></a>

### DodgeComponent — Уклонение

- **Делает:** Запускает уклонение, фиксирует направление и вид уклонения (воздушное или кувырок на земле), ведёт длительность и ограничивает повторный старт.
- **Когда применять:** Когда игроку нужен рывок/уклонение с отдельным действием.
- **Что требуется:** InputComponent, CharacterBodyComponent, FacingComponent, DodgeConfig. MovementComponent вызывает применение скорости; InvulnerabilityComponent необязателен.
- **Настройки и ограничения:** Config задаёт движение, задержки и неуязвимость. `duration` — воздушное уклонение, `roll_duration` — кувырок на земле; вид выбирается в момент старта по `is_on_floor()` и читается через `is_air_dodge()`. Без InvulnerabilityComponent нет его защиты. Расход выносливости пока не подключён.
- **Файлы:** [Код](../features/movement/DodgeComponent.gd) · [Сцена](../features/movement/DodgeComponent.tscn) · [DodgeConfig](../features/movement/DodgeConfig.gd).

<a id="climbingcomponent"></a>

### ClimbingComponent — Лазание

- **Делает:** Ведёт вход в лазание, движение по вертикали, выход и прыжок с лестницы.
- **Когда применять:** Для лестниц и других размеченных ClimbableArea.
- **Что требуется:** InputComponent, CharacterBodyComponent, FacingComponent, ClimbingConfig; зона ClimbableArea в мире. MovementComponent применяет скорость лазания.
- **Настройки и ограничения:** Config задаёт скорость и выход. Обычной коллизии платформы недостаточно: нужна зона, регистрирующая персонажа. Уклонение учитывается при наличии.
- **Файлы:** [Код](../features/movement/ClimbingComponent.gd) · [Сцена](../features/movement/ClimbingComponent.tscn) · [ClimbingConfig](../features/movement/ClimbingConfig.gd).

<a id="combat"></a>

## Здоровье и бой

<a id="healthcomponent"></a>

### HealthComponent — Запас здоровья

- **Делает:** Хранит текущее/максимальное здоровье, лечит, принимает прямой урон и сообщает о смерти.
- **Когда применять:** Для персонажа или разрушаемого объекта со здоровьем.
- **Что требуется:** HealthConfig. Дополнительно: CharacterAttributesComponent для прибавки к максимуму от Endurance.
- **Настройки и ограничения:** Config → Max Health; итоговый максимум может отличаться от базового. Боевые попадания проводите через Hurtbox; для удаления погибшего объекта добавьте DeathComponent.
- **Файлы:** [Код](../features/health/HealthComponent.gd) · [Сцена](../features/health/HealthComponent.tscn) · [HealthConfig](../features/health/HealthConfig.gd).

<a id="hurtboxcomponent"></a>

### HurtboxComponent — Получение боевого удара

- **Делает:** Принимает HitData, проверяет неуязвимость, применяет модификаторы урона, уменьшает здоровье и запускает реакции.
- **Когда применять:** На цели ближнего удара или снаряда.
- **Что требуется:** HealthComponent. Для обнаружения попаданий — сцена с Area2D и формой. Дополнительно: DamageModifier-наследники, Invulnerability, Knockback, HitStun.
- **Настройки и ограничения:** Форма и физические слои задаются в сцене. `receive_hit()` возвращает фактически нанесённый урон. После успешного попадания передаёт `HitData.status_effects` в StatusEffectComponent цели, если он есть и цель жива. Сам Hurtbox не рисует полоску здоровья или эффект попадания.
- **Файлы:** [Код](../features/combat/HurtboxComponent.gd) · [Сцена](../features/combat/HurtboxComponent.tscn).

<a id="hitboxcomponent"></a>

### HitboxComponent — Зона нанесения урона

- **Делает:** В активной зоне находит Hurtbox цели, формирует удар, ограничивает повторные попадания по цели в одном окне.
- **Когда применять:** Для ближней атаки или управляемой опасной зоны.
- **Что требуется:** Собственный Area2D с формой; у цели — HurtboxComponent. Дополнительно: CombatFactionComponent для фильтрации сторон.
- **Настройки и ограничения:** Damage, Horizontal/Vertical Knockback, Critical Damage Multiplier и форма. Массив Status Effects задаёт эффекты при успешном попадании; см. [наложение DOT](DOT.md#наложение). Обычно включается AttackComponent; наличие узла не запускает атаку. Дальность оружия меняет рабочую геометрию ближнего хитбокса.
- **Файлы:** [Код](../features/combat/HitboxComponent.gd) · [Сцена](../features/combat/HitboxComponent.tscn).

<a id="attackcomponent"></a>

### AttackComponent — Действие ближней атаки

- **Делает:** Управляет обычной/тяжёлой атакой, зарядкой, окнами урона и восстановлением.
- **Когда применять:** Для игрока или врага; ИИ может вызвать `attack()` без ввода.
- **Что требуется:** HitboxComponent, AttackConfig. Для окон из анимации — AnimationEventComponent. Input, тело, Facing и Equipment используются при наличии.
- **Настройки и ограничения:** Config задаёт фазы; Timing Player Path/Timing Clip позволяют брать длительность из клипа. У врагов используйте [Enemy_Timing.md](Enemy_Timing.md). Урон оружия добавляется к базовому урону хитбокса.
- **Файлы:** [Код](../features/combat/AttackComponent.gd) · [Сцена](../features/combat/AttackComponent.tscn) · [AttackConfig](../features/combat/AttackConfig.gd).

<a id="damagemodifiercomponent"></a>

### DamageModifierComponent — Основа модификатора урона

- **Делает:** Задаёт контракт изменения входящего урона и разрешения реакций на удар.
- **Когда применять:** При разработке нового правила защиты; наследники уже есть у блока и защиты экипировки.
- **Что требуется:** Обрабатывается HurtboxComponent на том же Actor.
- **Настройки и ограничения:** База оставляет урон как есть; пустой компонент не даёт защиту. Порядок применения модификаторов соответствует порядку компонентов в Actor.
- **Файлы:** [Код](../features/combat/DamageModifierComponent.gd).

<a id="guardcomponent"></a>

### GuardComponent — Блок и парирование

- **Делает:** Уменьшает фронтальный урон, ведёт окно парирования и удерживает персонажа на месте.
- **Когда применять:** Для управляемого игроком персонажа с защитными действиями.
- **Что требуется:** InputComponent, FacingComponent, GuardConfig; для боевого эффекта — HurtboxComponent. Тело, Attack и Equipment учитываются при наличии.
- **Настройки и ограничения:** Config: снижение урона, окно/перезарядка парирования. С Equipment действия разрешаются экипировкой; блок начинается на земле. Guard Stability и расход выносливости пока не работают.
- **Файлы:** [Код](../features/combat/GuardComponent.gd) · [Сцена](../features/combat/GuardComponent.tscn) · [GuardConfig](../features/combat/GuardConfig.gd).

<a id="equipmentdefensecomponent"></a>

### EquipmentDefenseComponent — Защита от экипировки

- **Делает:** Переводит суммарную защиту надетых предметов в уменьшение входящего урона.
- **Когда применять:** Если броня и другие предметы должны снижать урон.
- **Что требуется:** EquipmentComponent; HurtboxComponent должен применять модификаторы.
- **Настройки и ограничения:** Defense Scale: формула `урон × scale / (scale + защита)`, по умолчанию scale = 100. Значения защиты задаются в профилях предметов.
- **Файлы:** [Код](../features/equipment/EquipmentDefenseComponent.gd) · [Сцена](../features/equipment/EquipmentDefenseComponent.tscn).

<a id="invulnerabilitycomponent"></a>

### InvulnerabilityComponent — Временная неуязвимость

- **Делает:** Хранит защитное окно и мигание; Hurtbox не пропускает урон, пока окно активно.
- **Когда применять:** Для защиты после попадания и кадров неуязвимости уклонения.
- **Что требуется:** InvulnerabilityConfig; CanvasItem по Visual Path нужен при включённом Blink Visual. Для фильтрации боевого урона — HurtboxComponent.
- **Настройки и ограничения:** Длительность/мигание в Config. `activate(duration)` задаёт отдельное окно. Не защищает от прямого вызова Health.take_damage().
- **Файлы:** [Код](../features/combat/InvulnerabilityComponent.gd) · [Сцена](../features/combat/InvulnerabilityComponent.tscn) · [InvulnerabilityConfig](../features/combat/InvulnerabilityConfig.gd).

<a id="knockbackcomponent"></a>

### KnockbackComponent — Физическое отбрасывание

- **Делает:** Задаёт скорость отбрасывания, временно приостанавливает обычное движение и затем возвращает управление.
- **Когда применять:** Когда попадание должно сдвигать тело цели.
- **Что требуется:** CharacterBodyComponent, KnockbackConfig; обычно вызывается HurtboxComponent.
- **Настройки и ограничения:** Config: длительность, гравитация, торможение. Сила/направление приходят в HitData. Не меняет масштаб физического тела.
- **Файлы:** [Код](../features/combat/KnockbackComponent.gd) · [Сцена](../features/combat/KnockbackComponent.tscn) · [KnockbackConfig](../features/combat/KnockbackConfig.gd).

<a id="hitstuncomponent"></a>

### HitStunComponent — Оглушение и сбивание с ног

- **Делает:** Прерывает действия и временно отключает несовместимые способности; сильный толчок выбирает более долгую фазу.
- **Когда применять:** Когда цель должна потерять возможность действовать после попадания.
- **Что требуется:** HitStunConfig; применяется через HurtboxComponent или `apply_hit()`, учитывает присутствующие способности.
- **Настройки и ограничения:** Config: Duration, Knockdown Duration, Knockdown Velocity Threshold. Текущий порог связан с отбрасыванием; Stagger Power оружия и Poise брони не участвуют.
- **Файлы:** [Код](../features/combat/HitStunComponent.gd) · [Сцена](../features/combat/HitStunComponent.tscn) · [HitStunConfig](../features/combat/HitStunConfig.gd).

<a id="deathcomponent"></a>

### DeathComponent — Завершение жизни объекта

- **Делает:** После Health.died отключает способности/коллизии, ведёт задержку смерти, выдаёт death_finished и при настройке удаляет Actor.
- **Когда применять:** Для погибающих врагов, игрока и разрушаемых объектов.
- **Что требуется:** HealthComponent, DeathConfig; CanvasItem по Visual Path требуется при Fade Visual.
- **Настройки и ограничения:** Duration, Fade Visual, Remove Actor On Finish. Нужные после смерти компоненты используют `should_disable_on_actor_death()`. Сам компонент не выбирает клип и не возрождает игрока.
- **Файлы:** [Код](../features/health/DeathComponent.gd) · [Сцена](../features/health/DeathComponent.tscn) · [DeathConfig](../features/health/DeathConfig.gd).

<a id="combatfactioncomponent"></a>

### CombatFactionComponent — Сторона в бою

- **Делает:** Задаёт Neutral/Player/Enemy и проверяет враждебность сторон.
- **Когда применять:** Чтобы удары и выбор целей различали игрока и врагов.
- **Что требуется:** Обязательных соседей нет; читается боевым поиском целей и Hitbox.
- **Настройки и ограничения:** Faction в Inspector. Устанавливайте на участниках боя, а не только на одном из них; учитывайте также физические слои зон.
- **Файлы:** [Код](../features/combat/CombatFactionComponent.gd) · [Сцена](../features/combat/CombatFactionComponent.tscn).

<a id="enemies"></a>

## Компоненты врагов

<a id="enemymovementcomponent"></a>

### EnemyMovementComponent — Наземное движение врага

- **Делает:** Ведёт горизонтальное движение и гравитацию; позволяет остановить, развернуть и выполнить заданный прыжок.
- **Когда применять:** На наземном враге вместо управления игрока.
- **Что требуется:** CharacterBodyComponent, EnemyMovementConfig.
- **Настройки и ограничения:** Config: скорость, гравитация, начальное направление. Сам не выбирает цель и не избегает обрывов: для этого добавляют Chase, GroundSensor и Patrol.
- **Файлы:** [Код](../features/enemy/EnemyMovementComponent.gd) · [EnemyMovementConfig](../features/enemy/EnemyMovementConfig.gd).

<a id="enemyflightcomponent"></a>

### EnemyFlightComponent — Полёт врага

- **Делает:** Летает около исходной позиции или к заданной цели, плавно меняет скорость.
- **Когда применять:** На летающем враге вместо EnemyMovementComponent.
- **Что требуется:** CharacterBodyComponent, EnemyFlightConfig.
- **Настройки и ограничения:** Config: скорость, разгон, расстояние патруля, вертикальное колебание и остановка у цели. Патруль полёта уже внутри; наземный EnemyPatrolComponent не нужен.
- **Файлы:** [Код](../features/enemy/EnemyFlightComponent.gd) · [EnemyFlightConfig](../features/enemy/EnemyFlightConfig.gd).

<a id="enemygroundsensorcomponent"></a>

### EnemyGroundSensorComponent — Проверка земли и препятствий

- **Делает:** Проверяет пол, стены, край платформы и наличие опоры впереди.
- **Когда применять:** Для наземного патруля, безопасного преследования и прыжков.
- **Что требуется:** CharacterBodyComponent, EnemyGroundSensorConfig.
- **Настройки и ограничения:** Config: длины проверок, глубина поиска пола, маски. Не двигает врага. Проверяйте лучи относительно тела и масштаба корня.
- **Файлы:** [Код](../features/enemy/EnemyGroundSensorComponent.gd) · [Сцена](../features/enemy/EnemyGroundSensorComponent.tscn) · [EnemyGroundSensorConfig](../features/enemy/EnemyGroundSensorConfig.gd).

<a id="enemypatrolcomponent"></a>

### EnemyPatrolComponent — Разворот наземного патруля

- **Делает:** Разворачивает врага у стены/края; учитывает занятость преследованием и атакой.
- **Когда применять:** Чтобы наземный враг ходил по платформе и не падал с края.
- **Что требуется:** EnemyMovementComponent, EnemyGroundSensorComponent, EnemyPatrolConfig. Chase и EnemyAttack необязательны.
- **Настройки и ограничения:** Config: Turn At Ledges / Turn At Walls; хотя бы один вариант должен быть включён. Скорость хранится в EnemyMovementConfig.
- **Файлы:** [Код](../features/enemy/EnemyPatrolComponent.gd) · [Сцена](../features/enemy/EnemyPatrolComponent.tscn) · [EnemyPatrolConfig](../features/enemy/EnemyPatrolConfig.gd).

<a id="enemychasecomponent"></a>

### EnemyChaseComponent — Обнаружение и преследование

- **Делает:** Выбирает обнаруженную цель и передаёт её позицию движению врага, учитывает остановку на атаку.
- **Когда применять:** Чтобы наземный или летающий враг замечал игрока и приближался.
- **Что требуется:** EnemyMovementComponent или EnemyFlightComponent, EnemyChaseConfig, DetectionArea2D с RectangleShape2D. GroundSensor обязателен при Avoid Unsafe Ground.
- **Настройки и ограничения:** Config: область и правила подхода. У летающего врага проверка безопасной земли обычно выключена. Сам урон не наносит.
- **Файлы:** [Код](../features/enemy/EnemyChaseComponent.gd) · [Сцена](../features/enemy/EnemyChaseComponent.tscn) · [EnemyChaseConfig](../features/enemy/EnemyChaseConfig.gd).

<a id="enemyjumpcomponent"></a>

### EnemyJumpComponent — Прыжок к цели

- **Делает:** Оценивает достижимость, опору приземления, скорость прыжка и задержку между попытками.
- **Когда применять:** Для наземного врага, который должен добираться на соседние платформы.
- **Что требуется:** CharacterBodyComponent, EnemyMovementComponent, EnemyChaseComponent, EnemyGroundSensorComponent, EnemyJumpConfig.
- **Настройки и ограничения:** Config: сила прыжка, cooldown и проверка приземления. Это локальный расчёт прыжка, а не поиск маршрута через весь уровень.
- **Файлы:** [Код](../features/enemy/EnemyJumpComponent.gd) · [Сцена](../features/enemy/EnemyJumpComponent.tscn) · [EnemyJumpConfig](../features/enemy/EnemyJumpConfig.gd).

<a id="enemyattackcomponent"></a>

### EnemyAttackComponent — Решение ИИ атаковать

- **Делает:** Находит цель в зоне атаки, показывает подготовку и запускает AttackComponent, при необходимости останавливает движение.
- **Когда применять:** Для читаемой атаки врага с паузой перед ударом.
- **Что требуется:** AttackComponent, EnemyAttackConfig, DetectionArea2D с RectangleShape2D, CanvasItem по Visual Path. Движение врага необязательно.
- **Настройки и ограничения:** Config: Engagement и Windup. Дистанция обнаружения атаки не равна зоне поражения Hitbox. Длительность удара задаётся через Attack/клип.
- **Файлы:** [Код](../features/enemy/EnemyAttackComponent.gd) · [Сцена](../features/enemy/EnemyAttackComponent.tscn) · [EnemyAttackConfig](../features/enemy/EnemyAttackConfig.gd).

<a id="items"></a>

## Предметы и экипировка

<a id="inventorycomponent"></a>

### InventoryComponent — Хранилище предметов

- **Делает:** Владеет стопками и количеством, добавляет/удаляет вещи, разделяет стопки, считает ячейки и вес.
- **Когда применять:** На персонаже или контейнере, которому нужно хранить предметы.
- **Что требуется:** InventoryConfig; предметы представлены ресурсами ItemData.
- **Настройки и ограничения:** Config: Capacity, Starting Items и соответствующие Starting Quantities. Подбор ограничен ячейками, не килограммами. `add_item()` возвращает принятое количество: остаток нужно сохранить у источника.
- **Файлы:** [Код](../features/inventory/InventoryComponent.gd) · [Сцена](../features/inventory/InventoryComponent.tscn) · [InventoryConfig](../features/inventory/InventoryConfig.gd).

<a id="equipmentcomponent"></a>

### EquipmentComponent — Надетые вещи и режим оружия

- **Делает:** Управляет двумя наборами рук и носимыми слотами, обменом, боеприпасами и разрешёнными действиями.
- **Когда применять:** Когда предметы должны давать урон, защиту и доступные действия.
- **Что требуется:** Для операций с вещами — InventoryComponent; CharacterAttributes добавляет расчёт нагрузки. Ввод не обязателен.
- **Настройки и ограничения:** Starting Main/Off Hand Ids задают начальные руки; вещи должны быть в инвентаре. Default Slot — режим, не выдача оружия. `operation_rejected` объясняет отказ. Восстановление принимает только словарь состояния.
- **Файлы:** [Код](../features/equipment/EquipmentComponent.gd) · [Сцена](../features/equipment/EquipmentComponent.tscn).

<a id="equipmentinputcomponent"></a>

### EquipmentInputComponent — Переключение наборов по вводу

- **Делает:** Переводит команду игрока в смену активного набора оружия.
- **Когда применять:** На игроке с переключением наборов клавишей Tab.
- **Что требуется:** InputComponent, EquipmentComponent.
- **Настройки и ограничения:** Отдельного Config нет; назначение клавиши — InputMap. Для экипировки, управляемой скриптом, не нужен.
- **Файлы:** [Код](../features/equipment/EquipmentInputComponent.gd) · [Сцена](../features/equipment/EquipmentInputComponent.tscn).

<a id="equipmentswapcomponent"></a>

### EquipmentSwapComponent — Переодевание между наборами оружия

- **Делает:** Ведёт состояние EquipmentSwap и таймер, применяет целевой набор только после завершения.
- **Когда применять:** Для уязвимой смены двух наборов оружия игрока; подключён в Player.tscn.
- **Что требуется:** EquipmentComponent и CharacterBodyComponent. Input проверяет отсутствие команды бега; HitStun отменяет смену при ударе, Health — при смерти. CharacterAttributes задаёт множитель скорости.
- **Настройки и ограничения:** Base Duration = 2 секунды; итоговое время делится на Attack Speed Multiplier Actor и фиксируется при старте. Начать можно только стоя на земле. Во время действия заблокированы движение, прыжок и другие эксклюзивные действия; повторная кнопка не сбрасывает таймер. Полоска EquipmentSwapView над головой показывает прогресс и секунды. Потеря земли, смерть, оглушение или отключение отменяют процесс с сохранением старого набора. Доступный додж отменяет переодевание и сразу запускает уклонение: полоска скрывается, старый набор сохраняется. Если додж недоступен (например, на перезарядке), смена продолжается без сброса таймера. Отдельное надевание вещей в инвентаре не входит в эту механику.
- **Файлы:** [Код](../features/equipment/EquipmentSwapComponent.gd) · [Сцена](../features/equipment/EquipmentSwapComponent.tscn) · [Полоска](../features/equipment/ui/EquipmentSwapView.tscn) · [Правила и скорость](Actor_Stats.md#смена-комплекта-экипировки).

<a id="inventorydropcomponent"></a>

### InventoryDropComponent — Выбрасывание предметов

- **Делает:** Удаляет разрешённое количество вещей из инвентаря и создаёт LootBag в мире.
- **Когда применять:** Для действия «выбросить» в меню или сценарии.
- **Что требуется:** InventoryComponent и Loot Bag Scene.
- **Настройки и ограничения:** Назначьте сцену мешка. Ограничения ключей/фляг учитываются игровыми правилами; интерфейс не должен самостоятельно удалять вещь до создания мешка.
- **Файлы:** [Код](../features/inventory/InventoryDropComponent.gd) · [Сцена](../features/inventory/InventoryDropComponent.tscn).

<a id="quickaccesscomponent"></a>

### QuickAccessComponent — Привязки быстрых слотов

- **Делает:** Хранит восемь слотов, активный выбор, назначение/очистку и переключение с пропуском пустых.
- **Когда применять:** Для быстрого доступа к предметам.
- **Что требуется:** InputComponent, InventoryComponent, EquipmentComponent, QuickAccessConfig; FlaskCharges учитывается при наличии.
- **Настройки и ограничения:** Ровно восемь слотов; первый закреплён за лечением, остальные настраиваются. Индексы в коде начинаются с 0. Выбор предмета не равен его расходованию и не переключает набор оружия.
- **Файлы:** [Код](../features/inventory/QuickAccessComponent.gd) · [Сцена](../features/inventory/QuickAccessComponent.tscn) · [QuickAccessConfig](../features/inventory/QuickAccessConfig.gd).

<a id="itemusecomponent"></a>

### ItemUseComponent — Использование расходников

- **Делает:** Ведёт действие, применяет лечение/ману/статус в конце и только тогда расходует предмет или заряд. Умеет и эффект `GRANT_EXPERIENCE`, но ни один предмет его не использует: опыт в игре даётся только янтарными осколками — см. [экономику](Amber_Economy.md).
- **Когда применять:** Для зелий и фляг из инвентаря/быстрого слота.
- **Что требуется:** InputComponent, CharacterBodyComponent, EquipmentComponent, HealthComponent, InventoryComponent, QuickAccessComponent, ItemUseConfig. По эффекту нужны Magic, Progression, StatusEffect или FlaskCharges.
- **Настройки и ограничения:** Config задаёт время, результат берётся из ItemData. Старт на земле, движение ограничено; прерывание отменяет применение без расхода. Рисунок эффекта принадлежит визуальному компоненту.
- **Файлы:** [Код](../features/items/ItemUseComponent.gd) · [Сцена](../features/items/ItemUseComponent.tscn) · [ItemUseConfig](../features/items/ItemUseConfig.gd).

<a id="flaskchargescomponent"></a>

### FlaskChargesComponent — Заряды постоянных фляг

- **Делает:** Хранит текущие заряды принадлежащих Actor фляг, расходует и пополняет их.
- **Когда применять:** Для многоразовых фляг здоровья, маны и ярости.
- **Что требуется:** InventoryComponent; предмету нужен профиль фляги.
- **Настройки и ограничения:** Максимум задаётся в ItemFlaskProfile. Текущий запас не пишется в общий ItemData. Нулевые заряды не удаляют флягу/привязку; RestComponent пополняет их.
- **Файлы:** [Код](../features/items/FlaskChargesComponent.gd) · [Сцена](../features/items/FlaskChargesComponent.tscn).

<a id="rangedweaponcomponent"></a>

### RangedWeaponComponent — Лук и арбалет

- **Делает:** Ведёт прицеливание, выпуск снаряда и восстановление, учитывает действия оружия и боеприпасы.
- **Когда применять:** Для текущей стрельбы игрока.
- **Что требуется:** InputComponent, EquipmentComponent, FacingComponent, InventoryComponent, AimingComponent, RangedWeaponConfig. Equipment определяет разрешённые действия оружия.
- **Настройки и ограничения:** Config: длительности, скорость, гравитация, урон и жизнь снаряда. Лук и арбалет выпускают снаряд при отпускании J, расходуя совместимые боеприпасы из OFF_HAND в инвентаре. K отменяет прицеливание. Отдельной перезарядки нет.
- **Файлы:** [Код](../features/ranged/RangedWeaponComponent.gd) · [Сцена](../features/ranged/RangedWeaponComponent.tscn) · [RangedWeaponConfig](../features/ranged/RangedWeaponConfig.gd).

<a id="magiccomponent"></a>

### MagicComponent — Мана и магическое действие

- **Делает:** Хранит ману, ведёт подготовку, применение и поддержание магии, создаёт снаряд. Подготовка направленного заклинания использует общий прицел и завершается отпусканием кнопки.
- **Когда применять:** Для нынешнего магического режима игрока и восстановления маны.
- **Что требуется:** InputComponent, EquipmentComponent, FacingComponent, MagicConfig; AimingComponent для направленного выстрела; CharacterAttributes добавляет максимум маны от Wisdom.
- **Настройки и ограничения:** Config: стоимость, длительности, снаряд и базовый максимум. Итоговый максимум читайте через `get_max_mana()`. Это текущая магическая способность, не универсальный каталог независимых заклинаний.
- **Файлы:** [Код](../features/magic/MagicComponent.gd) · [Сцена](../features/magic/MagicComponent.tscn) · [MagicConfig](../features/magic/MagicConfig.gd).

<a id="throwingcomponent"></a>

### ThrowingComponent — Бросок снаряда

- **Делает:** Ведёт прицеливание, бросок и восстановление; расходует один выбранный метательный предмет из инвентаря.
- **Когда применять:** Для предметов THROWABLE в быстром слоте, одновременно с оружием в руках.
- **Что требуется:** InputComponent, EquipmentComponent, InventoryComponent, QuickAccessComponent, AimingComponent, ThrowingConfig.
- **Настройки и ограничения:** ThrowingConfig задаёт длительности. ItemData.projectile_profile задаёт скорость, гравитацию, урон, отбрасывание, время жизни и текстуру. Пустой/некорректный профиль не разрешает бросок. При смене быстрого слота подготовка отменяется.
- **Файлы:** [Код](../features/throwing/ThrowingComponent.gd) · [Сцена](../features/throwing/ThrowingComponent.tscn) · [ThrowingConfig](../features/throwing/ThrowingConfig.gd).

<a id="interaction"></a>

## Взаимодействие, развитие и возрождение

<a id="interactioncomponent"></a>

### InteractionComponent — Действие взаимодействия

- **Делает:** Ищет ближайший доступный объект, ведёт фазы и вызывает его InteractableComponent.
- **Когда применять:** На персонаже, который подбирает лут, открывает сундуки или использует точки мира.
- **Что требуется:** InputComponent; у цели должен быть InteractableComponent.
- **Настройки и ограничения:** Interaction Distance, Cooldown и длительности прямо на компоненте. Ближайшая точка может учитываться по форме цели. Текущая кнопка — R.
- **Файлы:** [Код](../framework/components/InteractionComponent.gd).

<a id="interactablecomponent"></a>

### InteractableComponent — Возможность взаимодействовать

- **Делает:** Объявляет объект доступным, даёт название действия, сообщает `interacted`/`interacted_by`.
- **Когда применять:** На мешке, сундуке, рычаге, точке отдыха или выходе.
- **Что требуется:** Actor с `_Components`; InteractionComponent нужен действующему персонажу. Форма взаимодействия необязательна.
- **Настройки и ограничения:** Interaction Name и Interaction Shape Path. Сам не знает, как открыть сундук: действие выполняет подписчик сигнала.
- **Файлы:** [Код](../framework/components/InteractableComponent.gd).

<a id="restcomponent"></a>

### RestComponent — Отдых и восстановление

- **Делает:** Начинает отдых, сразу лечит, снимает дебаффы, восстанавливает ману и выносливость и пополняет фляги; на время отдыха занимает персонажа.
- **Когда применять:** На персонаже, который восстанавливается у RestPoint.
- **Что требуется:** HealthComponent и RestConfig. StatusEffectComponent, MagicComponent, StaminaComponent и FlaskChargesComponent используются при наличии.
- **Настройки и ограничения:** Config → Duration. Восстановление применяется мгновенно в момент старта; Duration только удерживает персонажа в состоянии отдыха и не растягивает восстановление. Сам не задаёт контрольную точку: её устанавливает RestPoint через PlayerRespawnComponent.
- **Файлы:** [Код](../features/rest/RestComponent.gd) · [Сцена](../features/rest/RestComponent.tscn) · [RestConfig](../features/rest/RestConfig.gd).

<a id="playerrespawncomponent"></a>

### PlayerRespawnComponent — Возрождение игрока

- **Делает:** После смерти ждёт задержку, заменяет Actor свежим экземпляром у контрольной точки и восстанавливает выбранные данные компонентов.
- **Когда применять:** Для возрождения без сброса всего уровня.
- **Что требуется:** HealthComponent, PlayerRespawnConfig; для замены нужна сохранённая сцена Actor и родитель.
- **Настройки и ограничения:** Restart Delay; позиция задаётся через RestPoint или `set_checkpoint_position()`. Если замена невозможна, перезагружается сцена. Снимки связаны с именами узлов компонентов; это не дисковое сохранение.
- **Файлы:** [Код](../features/player/PlayerRespawnComponent.gd) · [Сцена](../features/player/PlayerRespawnComponent.tscn) · [PlayerRespawnConfig](../features/player/PlayerRespawnConfig.gd).

<a id="viewportfalldeathcomponent"></a>

### ViewportFallDeathComponent — Смерть ниже экрана

- **Делает:** Наносит смертельный прямой урон, когда начало координат Actor оказывается ниже экрана с отступом.
- **Когда применять:** Для нынешнего правила смерти за нижним краем экрана в песочнице.
- **Что требуется:** HealthComponent, ViewportFallDeathConfig.
- **Настройки и ограничения:** Config → Bottom Margin. Проверяется текущий экран, не фиксированная нижняя координата уровня; камера влияет на условие.
- **Файлы:** [Код](../features/player/ViewportFallDeathComponent.gd) · [Сцена](../features/player/ViewportFallDeathComponent.tscn) · [ViewportFallDeathConfig](../features/player/ViewportFallDeathConfig.gd).

<a id="characterattributescomponent"></a>

### CharacterAttributesComponent — Базовые характеристики

- **Делает:** Хранит силу, ловкость, интеллект, выносливость и мудрость; считает производные значения.
- **Когда применять:** Для максимума здоровья, маны и нагрузки.
- **Что требуется:** Отдельных соседей не требует; CharacterDerivedStatsConfig хранит формулы.
- **Настройки и ограничения:** Base Attributes и Derived Values. Endurance влияет на здоровье/нагрузку, Wisdom — ману. Scaling урона от STR/DEX/INT пока не подключён.
- **Файлы:** [Код](../features/stats/CharacterAttributesComponent.gd) · [Сцена](../features/stats/CharacterAttributesComponent.tscn).

<a id="progressioncomponent"></a>

### ProgressionComponent — Опыт и уровень

- **Делает:** Начисляет опыт, повышает уровень, считает следующий порог и сообщает о повышении.
- **Когда применять:** На персонаже, чей уровень покупается за янтарные осколки в убежище. За убийство врагов опыт не начисляется.
- **Что требуется:** ProgressionConfig.
- **Настройки и ограничения:** Config: начальный порог, рост требования, потолок уровня и длительность состояния повышения. Сам не распределяет очки и не увеличивает базовые характеристики. Уровень продаёт `RestPoint` по курсу 1 осколок = 1 опыт, двумя строками: до следующего уровня и «обменять все» — см. [янтарные осколки](Amber_Economy.md). Кривая порогов, таблица 100 уровней и поведение на потолке — в [уровнях персонажа](Level_Progression.md).
- **Файлы:** [Код](../features/progression/ProgressionComponent.gd) · [Сцена](../features/progression/ProgressionComponent.tscn) · [ProgressionConfig](../features/progression/ProgressionConfig.gd).

<a id="experiencerewardcomponent"></a>

### ExperienceRewardComponent — Осколки за убийство

- **Делает:** После смерти врага один раз создаёт кучку янтарных осколков в месте гибели.
- **Когда применять:** На враге, дающем валюту. Имя компонента историческое и сохранено ради совместимости готовых сцен; опыт он не начисляет.
- **Что требуется:** HealthComponent и ExperienceRewardConfig с наградой больше нуля.
- **Настройки и ограничения:** `Config/Amount` задаёт количество осколков, по умолчанию 25. Источник удара не важен: награда привязана к смерти врага, включая смерть от окружения. Подбор выполняет [кучка осколков](../features/loot/AmberShardPickup.tscn) и кладёт валюту в `InventoryComponent`. Это отдельная награда от предметов в луте.
- **Файлы:** [Код](../features/progression/ExperienceRewardComponent.gd) · [Сцена](../features/progression/ExperienceRewardComponent.tscn) · [ExperienceRewardConfig](../features/progression/ExperienceRewardConfig.gd).

<a id="lootdropcomponent"></a>

### LootDropComponent — Лут после смерти

- **Делает:** После смерти создаёт мешок с результатом таблицы дропа.
- **Когда применять:** На враге или разрушаемом объекте с лутом.
- **Что требуется:** HealthComponent, Loot Bag Scene и допустимые Loot Entries.
- **Настройки и ограничения:** ItemData, количество и шанс в LootEntry. Проверки записей независимы, это не выбор ровно одного предмета. Подбор выполняет LootBag.
- **Файлы:** [Код](../features/loot/LootDropComponent.gd) · [Сцена](../features/loot/LootDropComponent.tscn).

<a id="staminacomponent"></a>

### StaminaComponent — Запас выносливости

- **Делает:** Хранит запас, расход, задержку и скорость восстановления, позволяет восстановить состояние.
- **Когда применять:** Как ресурс персонажа для будущих затрат действий.
- **Что требуется:** StaminaConfig.
- **Настройки и ограничения:** Config: максимум, скорость, задержка восстановления. Сейчас боевые действия не вызывают расход; добавление компонента не ограничивает атаки и уклонения.
- **Файлы:** [Код](../features/stamina/StaminaComponent.gd) · [Сцена](../features/stamina/StaminaComponent.tscn) · [StaminaConfig](../features/stamina/StaminaConfig.gd).

<a id="statuseffectcomponent"></a>

### StatusEffectComponent — Временные статусы, DOT и сопротивления

- **Делает:** Хранит баффы/дебаффы по ID, обновляет и удаляет их; наносит периодический урон с учётом сопротивления соответствующему типу DOT.
- **Когда применять:** Для горения, кровотечения, яда, новых именованных DOT и обычных временных состояний.
- **Что требуется:** StatusEffect с ID, Polarity и Duration. Для DOT нужен включённый HealthComponent; для статусов без урона он необязателен.
- **Настройки и ограничения:** Damage Per Tick и Tick Interval находятся в ресурсе эффекта; сопротивления 0–100% — в Dot Resistances → Resistance на компоненте цели. Список типов берётся из общего DotCatalog и расширяется генератором. Первый тик — через интервал, не сразу. Для одного ID сильнейший по DPS (Damage Per Tick / Tick Interval) DOT заменяет слабый с новой длительностью и отсчётом тика; слабый не заменяет и не продлевает сильный. Равный по DPS обновляет только длительность, сохраняя текущие урон, интервал и ближайший тик. Стаков нет. При 100% сопротивления эффект остаётся, но урона нет. Компонент не умножает характеристики; Damage Per Tick = 0 оставляет обычный временный статус.
- **Файлы:** [Код](../features/status/StatusEffectComponent.gd) · [Сцена](../features/status/StatusEffectComponent.tscn) · [Генератор](../features/status/DotEffectGenerator.tscn) · [Каталог](../game/status/DotCatalog.tres) · [Применение, тики и сопротивления](DOT.md).

<a id="presentation"></a>

## Отображение, звук и отладка

<a id="actorstatecomponent"></a>

### ActorStateComponent — Сводное состояние персонажа

- **Делает:** Собирает поведение и флаги статусов из способностей, сообщает об изменении.
- **Когда применять:** Для общей анимации игрока, HUD и отладки.
- **Что требуется:** Наблюдает за присутствующими компонентами движения, боя, здоровья, предметов и статусов; обязательного полного набора нет.
- **Настройки и ограничения:** Отдельного Config нет; приоритеты — в Actor_States.md. Не запускает действия и не разрешает их вместо владельцев. Враг использует свой EnemyVisualComponent.
- **Файлы:** [Код](../features/state/ActorStateComponent.gd) · [Сцена](../features/state/ActorStateComponent.tscn).

<a id="animationcomponent"></a>

### AnimationComponent — Общая анимация персонажа

- **Делает:** Переводит поведение и направление взгляда в клипы AnimationPlayer и flip_h.
- **Когда применять:** Для персонажа с ActorState; служит базой DarklightVisualComponent основного героя.
- **Что требуется:** ActorStateComponent, FacingComponent; `_Visual/AnimatedSprite2D` со SpriteFrames и `_Visual/AnimationPlayer` с нужными клипами.
- **Настройки и ограничения:** Кадры/библиотеки назначаются в сцене. Обязательные клипы описаны в коде и Animation_Workflow.md. Не добавляйте параллельно другой компонент, управляющий тем же рисунком.
- **Файлы:** [Код](../framework/components/AnimationComponent.gd) · [Сцена](../framework/components/AnimationComponent.tscn).

Для покадровых сцен используются указанные выше SpriteFrames. Основной герой
переопределяет отображение через Skeleton2D в следующем компоненте.

<a id="darklightvisualcomponent"></a>

### DarklightVisualComponent — Риг основного героя

- **Делает:** Отображает состояние ActorStateComponent клипами Darklight, отражает визуальный риг по направлению взгляда и обновляет экипировку активного набора.
- **Когда применять:** Для основного героя в game/player/Player.tscn; новые анимации создаются в DarklightRig.tscn.
- **Что требуется:** Skeleton2D/SoupIK, AnimationPlayer, крепления MainHand / OffHand и спрайт Arrows; игровые компоненты готовой сцены Player.
- **Настройки и ограничения:** Equipped Texture подменяет картинку руки; Equipped Visual задаёт необязательную сцену. Display Slot выбирает визуальную руку независимо от слота инвентаря. Колчан виден при экипированных стрелах/болтах. Анимация не определяет урон, расход предметов или длительность действий.
- **Файлы:** [Код](../game/player/darklight/DarklightVisualComponent.gd) · [Сцена](../game/player/darklight/DarklightVisualComponent.tscn) · [Риг](../game/player/darklight/DarklightRig.tscn) · [Работа с ригом и ограничения](../game/player/darklight/README.md).

<a id="enemyvisualcomponent"></a>

### EnemyVisualComponent — Анимация врага

- **Делает:** Показывает покой, движение, воздух, атаку и смерть по данным движения, Attack и Health.
- **Когда применять:** На наземном/летающем враге из шаблонов.
- **Что требуется:** Спрайт со SpriteFrames и AnimationPlayer по экспортируемым путям; тело, движение, Attack и Health наблюдаются при наличии.
- **Настройки и ограничения:** Sprite Path / Animation Player Path, кадры и клипы. Input и Facing не нужны; направление берётся из движения врага. Продолжает отображать смерть после отключения боевых способностей.
- **Файлы:** [Код](../features/enemy/EnemyVisualComponent.gd).

<a id="animationeventcomponent"></a>

### AnimationEventComponent — События из кадров

- **Делает:** Передаёт именованные события дорожек AnimationPlayer подписчикам.
- **Когда применять:** Для открытия/закрытия хитбокса, шагов и взмахов в заданном кадре.
- **Что требуется:** Обязательных соседей нет; нужны дорожки вызова `emit_event()` и потребители.
- **Настройки и ограничения:** Настройка в клипах. Событие окна урона проверяет AttackComponent; дорожка не должна напрямую уменьшать здоровье цели.
- **Файлы:** [Код](../framework/animation/AnimationEventComponent.gd) · [Сцена](../framework/animation/AnimationEventComponent.tscn).

<a id="actoraudiocomponent"></a>

### ActorAudioComponent — Звук персонажа

- **Делает:** Проигрывает шаги/взмахи по событиям анимации и звуки попадания, ранения, смерти по игровым сигналам.
- **Когда применять:** Для озвучивания игрока/врага.
- **Что требуется:** ActorAudioProfile и два плеера эффектов/голоса из сцены. AnimationEvent, Hitbox и Health подключаются при наличии.
- **Настройки и ограничения:** Profile: массивы AudioStream, громкость, вариация тона, дистанция. Пустые массивы не дают звука; одних событий в клипе недостаточно.
- **Файлы:** [Код](../features/audio/ActorAudioComponent.gd) · [Сцена](../features/audio/ActorAudioComponent.tscn) · [ActorAudioProfile](../features/audio/ActorAudioProfile.gd).

<a id="cameracomponent"></a>

### CameraComponent — Камера игрока

- **Делает:** Настраивает Camera2D и её следование за Actor, масштаб, сглаживание и границы.
- **Когда применять:** На персонаже, за которым должна следовать камера.
- **Что требуется:** CameraConfig и собственная Camera2D.
- **Настройки и ограничения:** Настройки в Config. При изменении масштаба персонажа проверьте кадрирование. CameraShake работает через этот компонент.
- **Файлы:** [Код](../framework/components/CameraComponent.gd) · [Сцена](../framework/components/CameraComponent.tscn) · [CameraConfig](../framework/camera/CameraConfig.gd).

<a id="interactionpromptcomponent"></a>

### InteractionPromptComponent — Подсказка действия

- **Делает:** Показывает подпись у доступной цели с учётом камеры и экранных координат.
- **Когда применять:** Чтобы игрок видел, с чем можно взаимодействовать.
- **Что требуется:** CameraComponent с Camera2D, InteractionComponent; Label из группы `interaction_prompt` в интерфейсе сцены.
- **Настройки и ограничения:** Offset задаёт сдвиг. Не ищет цели вместо InteractionComponent и не выполняет действие вместо него.
- **Файлы:** [Код](../framework/components/InteractionPromptComponent.gd).

<a id="hitreactioncomponent"></a>

### HitReactionComponent — Визуальная реакция на попадание

- **Делает:** Кратко меняет цвет/прозрачность и масштаб рисунка после удара.
- **Когда применять:** Чтобы сделать попадание заметным без изменения физики.
- **Что требуется:** HurtboxComponent, HitReactionConfig, CanvasItem по Visual Path.
- **Настройки и ограничения:** Config: длительность, цвет, множитель масштаба. Только визуал; для потери управления нужен HitStun, для перемещения — Knockback.
- **Файлы:** [Код](../features/combat/HitReactionComponent.gd) · [Сцена](../features/combat/HitReactionComponent.tscn) · [HitReactionConfig](../features/combat/HitReactionConfig.gd).

<a id="blockreactioncomponent"></a>

### BlockReactionComponent — Визуальная реакция блока

- **Делает:** Кратко сжимает/растягивает рисунок при заблокированном ударе.
- **Когда применять:** Для обратной связи успешного блока.
- **Что требуется:** GuardComponent, BlockReactionConfig, Node2D по Visual Path.
- **Настройки и ограничения:** Config: длительность и Scale Multiplier. Не рассчитывает защиту; Visual Path не должен указывать на физический корень Actor.
- **Файлы:** [Код](../features/combat/BlockReactionComponent.gd) · [Сцена](../features/combat/BlockReactionComponent.tscn) · [BlockReactionConfig](../features/combat/BlockReactionConfig.gd).

<a id="hitstopcomponent"></a>

### HitStopComponent — Краткое замедление при попадании

- **Делает:** Временно уменьшает Engine.time_scale, затем восстанавливает его.
- **Когда применять:** Для ощущения тяжести нанесённого/полученного удара.
- **Что требуется:** HitStopConfig; Hitbox при On Hit Landed, Hurtbox при On Hit Received.
- **Настройки и ограничения:** Config: Duration, Time Scale, источники события. Влияет на игровое время целиком; это не оглушение одной цели и не пауза меню.
- **Файлы:** [Код](../features/combat/HitStopComponent.gd) · [Сцена](../features/combat/HitStopComponent.tscn) · [HitStopConfig](../features/combat/HitStopConfig.gd).

<a id="camerashakecomponent"></a>

### CameraShakeComponent — Тряска камеры

- **Делает:** Добавляет краткое смещение камеры после удара.
- **Когда применять:** Для отдачи от боя на Actor с камерой.
- **Что требуется:** CameraComponent, CameraShakeConfig; Hitbox/Hurtbox по выбранным источникам.
- **Настройки и ограничения:** Config: длительность, сила, On Hit Landed / On Hit Received. Не перемещает физическое тело и не наносит урон.
- **Файлы:** [Код](../features/combat/CameraShakeComponent.gd) · [Сцена](../features/combat/CameraShakeComponent.tscn) · [CameraShakeConfig](../features/combat/CameraShakeConfig.gd).

<a id="damagenumbercomponent"></a>

### DamageNumberComponent — Всплывающие числа урона

- **Делает:** По сигналу повреждения Health создаёт DamageNumberView над объектом.
- **Когда применять:** Если над целью нужно видеть потерянное здоровье.
- **Что требуется:** HealthComponent, DamageNumberConfig.
- **Настройки и ограничения:** Оформление/движение числа в Config. Это визуальный подписчик, не система расчёта урона.
- **Файлы:** [Код](../features/combat/DamageNumberComponent.gd) · [Сцена](../features/combat/DamageNumberComponent.tscn) · [DamageNumberConfig](../features/combat/DamageNumberConfig.gd).

<a id="inventorymenucomponent"></a>

### InventoryMenuComponent — Экран инвентаря

- **Делает:** Открывает меню с паузой, ведёт выбор, карточку, фильтры, перетаскивание и команды предметов.
- **Когда применять:** Для управления вещами игрока.
- **Что требуется:** InputComponent, InventoryComponent, EquipmentComponent, QuickAccessComponent, InventoryDropComponent и UI готовой сцены. ItemUse, FlaskCharges, Attributes дополняют действия/данные.
- **Настройки и ограничения:** Оформление в InventoryMenuComponent.tscn, ItemCell, ItemDetailsView и InventoryTheme. Правила надевания принадлежат Equipment; меню показывает отказ. Пауза удерживается через PauseLease.
- **Файлы:** [Код](../features/inventory/InventoryMenuComponent.gd) · [Сцена](../features/inventory/InventoryMenuComponent.tscn).

<a id="quickaccesshudcomponent"></a>

### QuickAccessHUDComponent — Панель быстрых слотов

- **Делает:** Отображает привязки, активный слот и количество/заряды; при открытом меню позволяет редактировать привязки.
- **Когда применять:** Для экранной панели быстрых предметов.
- **Что требуется:** QuickAccessComponent, InventoryComponent и UI готовой сцены. InventoryMenu и FlaskCharges используются при наличии.
- **Настройки и ограничения:** Оформление в сцене HUD. Это отображение тех же слотов, не второе хранилище. В игре пустые ячейки скрываются, при открытом меню показываются.
- **Файлы:** [Код](../features/inventory/QuickAccessHUDComponent.gd) · [Сцена](../features/inventory/QuickAccessHUDComponent.tscn).

<a id="debugoverlaycomponent"></a>

### DebugOverlayComponent — Отладочная панель

- **Делает:** Показывает состояние, движение, здоровье, экипировку и другие доступные данные.
- **Когда применять:** Во время настройки/проверки механик.
- **Что требуется:** Panel и Label готовой сцены; читает присутствующие игровые компоненты.
- **Настройки и ограничения:** Visible On Start, Update Interval. Можно убрать из обычной игровой сборки; к правилам боя/инвентаря отношения не имеет.
- **Файлы:** [Код](../framework/debug/DebugOverlayComponent.gd) · [Сцена](../framework/debug/DebugOverlayComponent.tscn).

<a id="world-objects"></a>

## Готовые объекты мира

Это целые объекты или зоны, а не компоненты для `_Components`.

| Объект | Что делает и когда применять | Что настроить |
| --- | --- | --- |
| [Actor](../framework/core/Actor.gd) | Корень составного объекта: собирает и инициализирует компоненты. Используйте для новых персонажей и интерактивных объектов | Контейнер `_Components`, рисунок и геометрия в сцене |
| [LootBag](../features/loot/LootBag.tscn) | Мешок с несколькими стопками; падает на землю, передаёт доступное количество в инвентарь, сохраняет непоместившийся остаток | Гравитация, предельная скорость, тело/форма; содержимое через `add_item()` |
| [RestPoint](../features/rest/RestPoint.tscn) | По взаимодействию запускает отдых персонажа и устанавливает точку возрождения | Spawn Offset; персонажу нужны RestComponent и PlayerRespawnComponent для обеих возможностей |
| [LevelExit](../features/level/LevelExit.tscn) | По взаимодействию завершает уровень; может ждать смерти всех Actor группы `enemies` и переключить сцену | Require Enemy Clear, Next Scene; без Next Scene остаётся отметка завершения |
| [ClimbableArea](../features/movement/ClimbableArea.tscn) | Зона лестницы: сообщает ClimbingComponent о входе/выходе физического тела | Форму Area2D и маски столкновений; не добавляйте её как Component |
| [ThrownProjectile](../features/throwing/ThrownProjectile.tscn) | Общий снаряд для броска, стрелы и магии; движется, обрабатывает попадания и время жизни | Параметры передаются через `setup()` из способности; сам объект не выбирает оружие и не расходует боеприпасы |

<a id="helpers"></a>

## Вспомогательные классы, отображения и данные

Их не нужно добавлять в `_Components` как способности. Сцены отображений
размещаются в UI или визуальной части объекта, ресурсы назначаются через Inspector.

### Элементы интерфейса

| Класс / сцена | Назначение и настройка |
| --- | --- |
| [HealthBarView](../features/health/ui/HealthBarView.tscn) | Экранная шкала здоровья. Actor Path указывает на владельца Health; умеет переподключаться после возрождения |
| [WorldHealthBarView](../features/health/ui/WorldHealthBarView.tscn) | Шкала здоровья над объектом в мире. Actor Path задаётся относительно узла отображения |
| [PlayerResourceBarsView](../features/progression/ui/PlayerResourceBarsView.tscn) | Временные шкалы маны, выносливости, опыта и длительности rage. Читает компоненты по Actor Path, не меняет ресурсы |
| [DamageNumberView](../features/combat/DamageNumberView.tscn) | Одно всплывающее число; создаётся DamageNumberComponent и удаляется после показа |
| [ItemDetailsView](../features/inventory/ui/ItemDetailsView.tscn) | Формирует карточку и сравнение предмета; рабочие данные получает из предмета/экипировки |
| [ItemCell](../features/inventory/ui/ItemCell.tscn), [InventoryDragButton](../features/inventory/InventoryDragButton.gd) | Ячейка предмета и кнопка с передачей данных перетаскивания. Правила операции остаются в компонентах инвентаря/экипировки |
| [InventoryTheme](../features/inventory/ui/InventoryTheme.tres) | Оформление инвентаря: цвета, состояния и стили элементов |
| [CharacterAnimationPlayer](../framework/animation/CharacterAnimationPlayer.tscn) | Заготовка AnimationPlayer с клипами; используется внутри визуальной части персонажа |

### Помощники разработки

| Класс | Когда нужен |
| --- | --- |
| [EnemyAuthoringChecks](../features/enemy/EnemyAuthoringChecks.gd) | Предупреждения в редакторе о зависимостях, кадрах, клипах и событиях врага; кнопка независимого копирования |
| [EnemyTemplateCopy](../features/enemy/EnemyTemplateCopy.gd) | Реализация копирования сцены и принадлежащих врагу ресурсов. Обычный путь использования — кнопка в EnemyAuthoringChecks |
| [JumpReachPreview](../features/movement/JumpReachPreview.gd) | Рисует расчётные траектории игрока в редакторе; Movement Component Path указывает источник настроек |
| [EnemyJumpReachPreview](../features/enemy/EnemyJumpReachPreview.gd) | Такой же редакторский предпросмотр, но берёт настройки EnemyMovement/EnemyJump |
| [PlatformReachMarker](../features/movement/PlatformReachMarker.gd) | Отмечает достижимость платформы выбранным персонажем; задайте Source Actor Path и Jump Profile |
| [JumpTrajectoryCalculator](../features/movement/JumpTrajectoryCalculator.gd), [WallJumpCalculator](../features/movement/WallJumpCalculator.gd) | Расчёт траекторий и настенных прыжков для движения, предпросмотра и проверок; не создают физическое тело |
| [EnemyLocomotion](../features/enemy/EnemyLocomotion.gd) | Ищет у Actor движение, поддерживающее команды преследования и остановки; позволяет Chase/Attack работать и с полётом, и с ходьбой |
| [CombatTargeting](../features/combat/CombatTargeting.gd) | Общие проверки подходящей боевой цели; используйте при добавлении поведения ИИ |
| [ExclusiveBehaviorGate](../features/state/ExclusiveBehaviorGate.gd) | Проверяет занятость Actor другим исключающим действием перед началом способности |
| [LocomotionConstraint](../features/movement/LocomotionConstraint.gd) | Флаги ограничений движения, которыми обмениваются способности и движение |
| [PauseLease](../framework/core/PauseLease.gd) | Владение паузой для экрана/сценария. Закрытие одного владельца не отменяет паузу остальных |
| [ActorState](../framework/state/ActorState.gd), [MovementState](../features/movement/MovementState.gd) | Имена состояний и флагов. Это данные для компонентов, а не самостоятельное управление поведением |
| [InputProvider](../framework/input/InputProvider.gd) | Заготовка интерфейса ввода с нейтральными ответами. Текущие способности используют InputComponent; замена его этим классом сама по себе не подключает новый источник ввода |

### Ресурсы данных

| Ресурс | За что отвечает |
| --- | --- |
| `*Config` | Числа и варианты поведения соответствующего компонента. Ссылки на конфигурации есть в карточках выше |
| [CharacterDerivedStatsConfig](../features/stats/CharacterDerivedStatsConfig.gd) | Формулы максимума здоровья, маны и нагрузки от базовых характеристик |
| [ActorAudioProfile](../features/audio/ActorAudioProfile.gd) | Звуки по типу события, громкость и параметры воспроизведения |
| [ItemData](../features/inventory/ItemData.gd) | ID, название, описание, иконка, категория, цена, вес, стопка и ссылки на профили |
| [ItemStats](../features/inventory/ItemStats.gd) | Урон, защита и поля баффов; наличие дополнительных полей не означает готовую механику |
| [ItemEquipmentProfile](../features/inventory/profiles/ItemEquipmentProfile.gd) | Допустимые слоты, отдельный слот отображения и характеристики экипируемого предмета |
| [ItemWeaponProfile](../features/inventory/profiles/ItemWeaponProfile.gd) | Тип оружия, действия, руки, визуальный профиль, критический урон и дальность; неактивные поля помечены Planned |
| [ItemOffhandProfile](../features/inventory/profiles/ItemOffhandProfile.gd) | Семейство вспомогательного предмета, действия, блок и парирование |
| [ItemArmorProfile](../features/inventory/profiles/ItemArmorProfile.gd) | Класс/набор брони и заготовка устойчивости Poise |
| [ItemConsumableProfile](../features/inventory/profiles/ItemConsumableProfile.gd) | Эффект использования, величина, статус и визуальный эффект |
| [ItemFlaskProfile](../features/inventory/profiles/ItemFlaskProfile.gd) | Максимум зарядов постоянной фляги |
| [ItemProjectileProfile](../features/inventory/profiles/ItemProjectileProfile.gd) | Полёт, урон, отбрасывание и текстура метательного предмета |
| [ItemAmmunitionProfile](../features/inventory/profiles/ItemAmmunitionProfile.gd) | Тип боеприпаса для совместимости с оружием |
| [InventoryStack](../features/inventory/InventoryStack.gd), [QuickAccessSlot](../features/inventory/QuickAccessSlot.gd) | Данные одной стопки и одного быстрого слота; владельцы состояния — Inventory/QuickAccess |
| [LootEntry](../features/loot/LootEntry.gd) | Предмет, диапазон количества и шанс одной записи дропа |
| [HitData](../features/combat/HitData.gd) | Данные конкретного попадания: урон, источник и параметры реакции |
| [StatusEffect](../features/status/StatusEffect.gd) | ID, положительный/отрицательный характер и длительность статуса |

Создание предметов: [game/items/README.md](../game/items/README.md).
Рабочие и запланированные поля: [Item_Parameters.md](Item_Parameters.md).

<a id="recipes"></a>

## Примеры сборок

### Добавить разрушаемый объект

Возьмите Actor с `_Components`, добавьте HealthComponent, HurtboxComponent
и DeathComponent с их конфигурациями. Настройте форму уязвимой зоны и слои.
Рисунок разместите в `_Visual`; при Fade Visual путь должен вести на CanvasItem.
Установите Health → Max Health и Death → Remove Actor On Finish.
Для всплывающих чисел добавьте DamageNumberComponent, для дропа — LootDropComponent.

Проверка: удар снимает здоровье один раз за окно, смерть отключает коллизии,
лут появляется один раз. Не добавляйте Input и Movement неподвижному ящику.

### Создать наземного или летающего врага

Используйте [независимую копию](Enemy_Copy.md) GroundDummy/FlyDummy.
Они уже содержат согласованные тело, зоны, боевые компоненты и события.
Наземное движение собирается из EnemyMovement + GroundSensor + Patrol;
Chase добавляет преследование, Jump — прыжки к цели. Полёт использует
EnemyFlight с собственным патрулём и EnemyChase для преследования.
В обоих случаях EnemyAttack запускает Attack, а EnemyVisual отображает действие.

После копирования назначьте правонаправленную графику и собственные библиотеки,
подгоните формы под видимое тело, задайте равномерный масштаб корня.
Шаблоны остаются пустыми при масштабе 1; уровни ссылаются на готового монстра.
Проверяйте редакторские предупреждения, подход к краю, подготовку атаки,
окно урона, смерть и дроп. Пустые аудиопрофили нужно заполнить звуками отдельно.

### Добавить предмет без новой способности

Для нового меча или лечебной фляги обычно достаточно копии подходящего
ItemData из `game/items/templates`. Задайте уникальный ID и профиль,
добавьте предмет в InventoryConfig или LootEntry. Меч использует уже имеющийся
AttackComponent, фляга — ItemUseComponent и FlaskChargesComponent.
Новый компонент нужен для нового поведения, а не для каждого экземпляра меча.

### Добавить точку отдыха

Разместите RestPoint в уровне. На игроке нужны InteractionComponent,
RestComponent и PlayerRespawnComponent; для пополнения фляг — FlaskCharges,
для очистки дебаффов — StatusEffect. Настройте Spawn Offset над опорой.
Проверяйте отдельно восстановление, активацию точки и последующее возрождение:
это разные операции. Отдых сейчас не означает автоматическое восстановление маны.

### Добавить обратную связь от попадания

Начните с уже работающих Attack/Hitbox и Health/Hurtbox.
Добавьте только нужное: HitReaction для рисунка, Knockback для перемещения,
HitStun для потери управления, ActorAudio для звука, DamageNumber для числа.
HitStop замедляет игровое время, CameraShake смещает камеру.
При отключении каждого эффекта урон должен продолжать рассчитываться корректно.

### Написать новую способность

Наследуйте Component, разрешайте зависимости в `on_initialize()`, храните
таймер и результат действия в одном владельце. Выдавайте сигналы фактов;
представление подписывается на них. Если действие занимает персонажа,
используйте существующий контракт исключающего поведения. Если блокирует
движение — предоставляйте `get_locomotion_blocks()`. При disable отменяйте
собственные таймеры и освобождайте управление. Не изменяйте общий ItemData
для хранения состояния одного персонажа.

<a id="troubleshooting"></a>

## Ограничения и поиск проблем

| Симптом | Что проверить сначала |
| --- | --- |
| Компонент «не виден» другим | Он наследует Component и находится непосредственно под `_Components`; нет второго экземпляра того же типа |
| Компонент отключается при запуске | Сообщение `requires ...`, Config, обязательных соседей, пути и дочерние узлы |
| Персонаж не двигается | CharacterBody/формы, InputMap, включение Movement и занятость другой способностью |
| Атака есть, урона нет | Hitbox/Hurtbox, слои/маски, стороны, неуязвимость и открытие окна событиями AnimationEvent |
| Оружие не надевается | Оно есть в Inventory, совместимо со слотом и другой рукой, хватает характеристик; причина в `operation_rejected` |
| Фляга видна, но не используется | Заряды, наличие ItemUse и нужного получателя эффекта, положение на земле, занятость персонажа |
| Враг не преследует или падает с края | DetectionArea, EnemyChaseConfig, стороны, GroundSensor и Avoid Unsafe Ground |
| Враг не играет анимацию | Пути к спрайту/AnimationPlayer, SpriteFrames, обязательные клипы и события |
| При масштабировании уезжают зоны | Масштаб корня, формы без собственного масштаба, локальные размеры/смещения сенсоров и лучей |
| Меню закрыто, но игра на паузе | Остался другой владелец PauseLease или пауза была включена до открытия меню |
| После смерти пропали нужные данные | Компонент реализует capture/restore; имя узла сохранено; фазы боя и временные статусы намеренно сбрасываются |

Подготовленные поля оружия не делают готовыми скорость атаки, moveset,
типовой урон, scaling, stagger и poise. Stamina пока не связана с затратами
действий. Статусы требуют отдельного потребителя эффекта, а уровни — отдельного
решения о росте характеристик. Основной герой — Darklight; недостающие клипы
перечислены в [документации рига](../game/player/darklight/README.md). Шкалы ресурсов временные.
Общее прицеливание подключено к дальним атакам; дисковое сохранение описано в Save_System.md.

## Общее прицеливание

`features/aiming/AimingComponent.tscn` подключён к Player. Зависимости:
InputComponent, FacingComponent; настройки — AimingConfig. Владелец действия
вызывает begin_aim/end_aim и читает get_direction/get_launch_position.
Стартовый угол владелец может передать в begin_aim; при завершении он сообщает
флагом выстрела, нужно ли запомнить угол.
Компонент хранит угол возвышения, память угла последнего выстрела на 2 секунды
(`angle_memory_duration`, обнуляется перемещением по `angle_memory_move_tolerance`),
ограничивает перемещение при подготовке
и отменяет сессию при паузе, потере фокуса или отключении. AimingView рисует
указатель; бросок, лук, арбалет и направленная магия используют один прицел.
См. [Aiming.md](Aiming.md) для управления и ограничений прототипа.

## Как поддерживать справочник

При добавлении или удалении Component обновляйте его карточку и быстрый выбор,
если появилась новая задача пользователя. При изменении зависимости или Config
обновляйте соответствующую строку. Подключённую механику переносите из ограничений
в рабочее описание и сверяйте [Item_Parameters.md](Item_Parameters.md).
Не называйте поле работающим, пока в игровом коде нет его потребителя.
