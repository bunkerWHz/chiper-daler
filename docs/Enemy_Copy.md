# Создать самостоятельного врага

1. Откройте `game/enemy/Enemy.tscn` для наземного врага или
   `game/enemy/FlyingEnemy.tscn` для летающего.
2. Выберите узел `EnemyAuthoringChecks` в дереве сцены.
3. В Inspector укажите `New Enemy Name`, например `ForestBat`.
4. Нажмите **Create independent copy**.
5. Откройте созданную сцену `game/enemy/forest_bat/ForestBat.tscn`.

Кнопка сохраняет текущую сборку сцены, включая несохранённые настройки,
в новую папку. В ней будут сцена, собственные `SpriteFrames.tres` и
`AnimationLibrary.tres`. Конфигурации компонентов копируются внутрь новой
сцены. Общие компоненты остаются экземплярами своих сцен, а новая сцена врага
не наследуется от исходного врага. Исходные текстуры могут использоваться
повторно; для нового рисунка замените кадры в собственном SpriteFrames.

Имя должно быть допустимым идентификатором без пробелов и разделителей пути.
Существующая папка никогда не перезаписывается. Открывать нужно саму сцену
врага: кнопка не создаёт копии из экземпляров, размещённых внутри уровня.

После копирования:

- Рисунок: `_Visual/AnimatedSprite2D` → Sprite Frames.
- События и длительность удара: `_Visual/AnimationPlayer` → `attack`.
  Подробности в [Enemy_Timing.md](Enemy_Timing.md).
- Здоровье: `_Components/HealthComponent` → Config.
- Урон и зона удара: `_Components/HitboxComponent` и его CollisionShape2D.
- Движение: EnemyMovementComponent или EnemyFlightComponent → Config.
- Обнаружение и подготовка удара: EnemyChaseComponent и EnemyAttackComponent → Config.

Перед запуском проверьте предупреждения EnemyAuthoringChecks. Для смены
кадров, длины атаки и перечисленных параметров редактировать GDScript не нужно.
