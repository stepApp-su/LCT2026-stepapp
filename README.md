# Питомец Финни

Детское просветительское приложение по финансовой грамотности для детей 7–11 лет.
Полностью офлайн, без единого разрешения в AndroidManifest.

## Запуск

```bash
flutter pub get
flutter run
```

## Тесты и линт

```bash
flutter test
dart run import_lint
flutter analyze
```

## Структура

- `lib/domain` — чистая бизнес-логика (без `package:flutter`)
- `lib/data` — персистентность прогресса
- `lib/content` — загрузка JSON-контента из `assets/content`
- `lib/ui` — экраны и виджеты
- `assets/content` — задания, товары, цели, звания, реплики Финни
- `assets/images` — SVG-графика
- `test` — юнит-тесты
