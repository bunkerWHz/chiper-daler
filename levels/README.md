# Уровни

`LevelTemplate.tscn` — пустой шаблон для сборки новых уровней.
Скопируйте его в `levels/<level_name>/<LevelName>.tscn` и переименуйте корень.
Например: `levels/forest_entry/ForestEntry.tscn`.

Единые правила и порядок работы: [Создание уровней](../docs/Level_Authoring.md).
Шаблон хранит структуру и настройки слоёв, но не содержит игрового контента
и не подключает механики автоматически.

`workshops/TileSetWorkshop.tscn` — стенд настройки GreenForest TileSet с визуальными
образцами. [Инструкция мастерской](workshops/README.md).

`workshops/BWForestTileSetWorkshop.tscn` — такой же стенд для чёрно-белого
набора BWForest, с собственными ресурсами земли и односторонних платформ.

`workshops/CaveTileSetWorkshop.tscn` — каталог модульных деталей пещеры:
сплошные блоки, односторонние платформы и декор. [Инструкция Cave](workshops/Cave.md).
