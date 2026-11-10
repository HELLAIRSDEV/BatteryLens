# BatteryLens

**Реальное состояние аккумулятора Mac — в меню-баре.**

macOS в настройках показывает «Максимальная ёмкость: 85%», даже когда батарея физически потеряла четверть ёмкости. BatteryLens читает сырые данные контроллера и показывает правду: `FullChargeCapacity / DesignCapacity`, циклы и текущий расход.

```
┌──────────────────────┐
│        77%           │
│  реальная ёмкость    │
│  Пора планировать    │
│      замену          │
│                      │
│  Заряд        84%    │
│  Ёмкость  4725/6075  │
│  Циклы        369    │
│  Расход     8.4 Вт   │
│  Осталось   1 ч 48   │
└──────────────────────┘
```

## Возможности

- **Реальная ёмкость** в процентах от проектной, с цветовой индикацией.
- Заряд, ёмкость в мА·ч, циклы, текущая мощность, остаток времени.
- Иконка в меню-баре: заряд и `⚡` при зарядке.
- Обновление каждые 10 секунд, окно по клику.
- **Универсальный бинарник**: Apple Silicon и Intel.
- Работает без root, без сети и без сторонних библиотек.
- Есть CLI-режим для скриптов и диагностики.

## Установка

Скачай последний релиз: **[Releases](../../releases/latest)**

- `BatteryLens-x.y.z.dmg` — открой, перетащи `BatteryLens` в `Applications`.
- `BatteryLens-x.y.z.zip` — распакуй и перемести приложение в `Applications`.

Приложение подписано ad-hoc (без Apple Developer ID), поэтому при первом запуске macOS может предупредить. Разреши запуск:

```bash
xattr -dr com.apple.quarantine /Applications/BatteryLens.app
```

или: правый клик по приложению → **Открыть** → **Открыть**.

Автозапуск: **Системные настройки → Основные → Элементы входа → +** → `BatteryLens.app`.

## CLI

```bash
/Applications/BatteryLens.app/Contents/MacOS/BatteryLens --print
```

```
charge      84%
health      77.4%
capacity    4725 / 6075 mAh
cycles      369
power       8.4 W  (12.12 V, -1.14 A)
plugged     no
charging    no
```

## Сборка из исходников

Нужны только Command Line Tools (`xcode-select --install`), Xcode не требуется.

```bash
git clone <repo-url> && cd BatteryLens
./scripts/build.sh          # универсальный .app
./scripts/package.sh        # zip + dmg в dist/
```

Иконка уже в репозитории. Перегенерировать:

```bash
swift tools/make-icon.swift /tmp/AppIcon.iconset
iconutil -c icns /tmp/AppIcon.iconset -o Resources/AppIcon.icns
```

## Структура проекта

```
BatteryLens/
├── Sources/main.swift          # приложение целиком
├── Resources/AppIcon.icns      # иконка
├── tools/make-icon.swift       # генератор иконки
├── scripts/build.sh            # универсальная сборка
├── scripts/package.sh          # zip + dmg
├── .github/workflows/
│   ├── ci.yml                  # сборка на каждый push
│   └── release.yml             # релиз по тегу v*
├── Info.plist
├── VERSION
├── LICENSE
└── README.md
```

## Релизы

Релиз собирается автоматически по тегу:

```bash
git tag v0.1.0
git push origin v0.1.0
```

GitHub Actions соберёт универсальное приложение, упакует `.zip` и `.dmg` и опубликует в **Releases**.

Текущая версия: **0.1.0**

## Как это работает

Данные читаются напрямую из IORegistry:

- `AppleSmartBattery` → словарь `BatteryData` (`FullChargeCapacity`, `DesignCapacity`, `CycleCount`);
- на Intel-маках те же значения лежат в корне сервиса, а `CurrentCapacity`/`MaxCapacity` означают мА·ч — приложение определяет это автоматически.

Ничего не изменяется и не требует привилегий: только чтение.

Почему цифра «прыгает» на 1%: контроллер пересчитывает ёмкость каждые несколько секунд, разброс ±0.8% — норма. В интерфейсе включён гистерезис, чтобы шум не дёргал цифру.

## Ограничения

- Температура батареи на Apple Silicon недоступна через IOKit без root/SMC.
- Требуется macOS 13+.
- Приложение не подписано Apple Developer ID, поэтому Gatekeeper требует ручного подтверждения.

## Roadmap

- [ ] Иконка-батарейка с заполнением в меню-баре
- [ ] История измерений и график деградации
- [ ] Экспорт PDF-отчёта для продажи/покупки б/у Mac
- [ ] Оценка рыночной цены с учётом износа

## Лицензия

[MIT](LICENSE)
