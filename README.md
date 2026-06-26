# Ogneva Messenger App

Flutter-клиент мессенджера для учебного центра Ogneva. Приложение работает с backend-репозиторием
[geerfest/ogneva-msg](https://github.com/geerfest/ogneva-msg).

Клиент подключен к live MVP backend: auth, secure token persistence, список чатов, темы, сообщения, треды, отправка сообщений и Centrifugo realtime-события идут через data-layer. Runtime mock-режима в приложении нет; тесты используют явно инжектированные fakes.

## Что Уже Есть

- Экран входа с теплым фирменным визуалом и голубыми action-акцентами.
- Список чатов с unread-счетчиками, топиками, статусами и профилем.
- Экран чата с топиками, сообщениями, unread-разделителем, typing indicator и composer.
- Экран ветки ответов.
- Экран профиля и настроек пользователя.
- Auto-restore сессии через refresh token.
- REST-интеграция с `ogneva-msg` для auth/chats/topics/messages/threads.
- Centrifugo realtime-подписки на user/conversation/topic/thread события.
- Декларативная навигация через `go_router`.
- Простая архитектура `ui / domain / data`.
- Widget- и unit-тесты для auth, API parsing, realtime reducer и ключевых экранов.

## Стек

- Flutter / Dart
- Material 3
- `go_router` для навигации
- `provider` для простого DI и session state
- `http` для REST API
- `flutter_secure_storage` для хранения access/refresh token
- `centrifuge` для Centrifugo realtime

## Требования

- Flutter SDK, совместимый с Dart `^3.11.5`
- Xcode и iOS Simulator для запуска на iOS
- Android Studio / Android SDK для запуска на Android
- Локальный backend `ogneva-msg` для live run/smoke

Проверить окружение:

```bash
flutter doctor -v
```

## Первый Запуск

Установить зависимости:

```bash
flutter pub get
```

Запустить на выбранном устройстве:

```bash
flutter devices
flutter run -d <device-id>
```

Пример для iOS Simulator:

```bash
flutter run -d "iPhone 17"
```

Если Xcode сообщает, что не установлен нужный iOS Simulator runtime, установи его через:

```text
Xcode -> Settings -> Components
```

## Backend URL

Base URL задается через Dart define:

```bash
flutter run \
  --dart-define=OGNEVA_API_BASE_URL=http://localhost:8080/api/v1
```

Для iOS Simulator `localhost` указывает на Mac, поэтому локальный backend обычно доступен так:

```bash
flutter run -d "iPhone 17" \
  --dart-define=OGNEVA_API_BASE_URL=http://localhost:8080/api/v1
```

Для Android Emulator локальный backend на Mac обычно нужен через `10.0.2.2`:

```bash
flutter run -d <android-emulator-id> \
  --dart-define=OGNEVA_API_BASE_URL=http://10.0.2.2:8080/api/v1
```

Значение по умолчанию в приложении:

```text
http://localhost:8080/api/v1
```

## Локальный Backend

Backend dev stack публикует API на `localhost:8080` и Centrifugo на `localhost:8000`.

В backend-репозитории:

```bash
cd /Users/geerfest/projects/ogneva-msg
docker compose -f deploy/docker-compose.yml up --build
```

Dev seed пользователи:

```text
admin@example.com / admin123
teacher@example.com / user123
student@example.com / user123
parent@example.com / user123
student2@example.com / user123
```

Для iOS Simulator backend `CENTRIFUGO_WS_URL` должен быть доступен как:

```text
ws://localhost:8000/connection/websocket
```

## Проверки

Форматирование:

```bash
dart format .
```

Статический анализ:

```bash
flutter analyze
```

Тесты:

```bash
flutter test
```

Перед коммитом желательно прогонять минимум:

```bash
dart format .
flutter analyze
flutter test
```

## Структура Проекта

```text
lib/
  data/
    models/            # backend DTO parsing
    repositories/      # live repositories and data access contracts
    services/          # HTTP, token storage, realtime
  domain/
    models/            # app domain models
  ui/
    core/              # routing, theme, session, shared widgets
    features/          # feature screens and view models
```

Основные точки входа:

- `lib/main.dart` - DI, тема, router и старт приложения.
- `lib/ui/core/routing/app_router.dart` - карта маршрутов и auth redirect.
- `lib/ui/core/theme/` - цветовые токены и Material theme.
- `lib/data/repositories/` - live auth/chat repositories.
- `lib/data/services/messenger_api_client.dart` - REST API-клиент.
- `lib/data/services/realtime_service.dart` - Centrifugo connection/subscriptions.
- `docs/OFFLINE_OUTBOX.md` - целевая архитектура локального кеша, outbox и retry.

## Дизайн

Принятое направление:

- Теплый светлый фон: peach / pale orange.
- Голубой - функциональный акцент: аватарки, unread badges, иконки, кнопки, focus states.
- Без зеленого/teal в основной палитре.
- Интерфейс должен ощущаться спокойным, дружелюбным и рабочим, без тяжелого декоративного слоя.
- Элементы управления должны быть удобны для пальца: маленькие интерактивные чипы лучше расширять до понятной tappable-зоны.

Цветовые токены лежат в:

```text
lib/ui/core/theme/app_colors.dart
```

## Текущий Статус

Приложение запускается на iOS Simulator и проходит базовый сценарий:

```text
login -> chats -> chat -> thread
```

Данные берутся из live backend. При старте приложение пытается восстановить сессию через `/auth/refresh`; при logout очищает secure storage и отключает realtime.

## Ближайшие Задачи

- Productized messenger client work ведется по `docs/tasks/productized-messenger-client.md`.
- Ближайший этап: data-layer parity с backend contract, затем chats filters/archive, create-chat flow, chat management, message edit/delete, pagination и realtime invalidation.
- Offline queue остается отдельным будущим этапом по `docs/OFFLINE_OUTBOX.md`.
