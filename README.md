# BatteryLens

Показывает реальную ёмкость аккумулятора Mac в меню-баре.

## Возможности

- Реальная ёмкость: `FullChargeCapacity / DesignCapacity`, а не сглаженная цифра macOS.
- Заряд, ёмкость в мА·ч, циклы, текущий расход, остаток времени.
- Универсальный бинарник: Apple Silicon и Intel, macOS 13+.
- Без root, без сети, без зависимостей.
- CLI-режим для скриптов.

## Установка

Скачай последний релиз: **[Releases](../../releases/latest)**

- `BatteryLens-x.y.z.dmg` — открой и перетащи `BatteryLens` в `Applications`.
- `BatteryLens-x.y.z.zip` — распакуй и перемести приложение в `Applications`.

Подпись ad-hoc, поэтому при первом запуске macOS может предупредить:

```bash
xattr -dr com.apple.quarantine /Applications/BatteryLens.app
```

Автозапуск: **Системные настройки → Основные → Элементы входа → +** → `BatteryLens.app`.

## CLI

```bash
/Applications/BatteryLens.app/Contents/MacOS/BatteryLens --print
```

```
charge      100%
health      100.0%
capacity    6075 / 6075 mAh
cycles      0
power       6.4 W  (12.30 V, -0.52 A)
plugged     yes
charging    no
```

## Сборка

```bash
./scripts/build.sh      # универсальный .app
./scripts/package.sh    # zip + dmg в dist/
```

Нужны только Command Line Tools (`xcode-select --install`).

Релиз публикуется автоматически по тегу:

```bash
git tag v0.1.0
git push origin v0.1.0
```

## Лицензия

[MIT](LICENSE)
