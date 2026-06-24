# Ogneva Messenger App

Flutter-клиент мессенджера для учебного центра Ogneva. Приложение будет работать с backend-репозиторием
[geerfest/ogneva-msg](https://github.com/geerfest/ogneva-msg).

Сейчас это первый экранный MVP: навигация, дизайн-система, моковые данные и базовые пользовательские сценарии уже собраны. Подключение к реальному API вынесено следующим этапом: `MessengerApiClient` и конфигурация base URL уже есть, но auth/chats пока используют mock-репозитории.

## Что Уже Есть

- Экран входа с теплым фирменным визуалом и голубыми action-акцентами.
- Список чатов с unread-счетчиками, топиками, статусами и профилем.
- Экран чата с топиками, сообщениями, unread-разделителем, typing indicator и composer.
- Экран ветки ответов.
- Экран профиля и настроек пользователя.
- Декларативная навигация через `go_router`.
- Простая архитектура `ui / domain / data`.
- Widget-тесты для входа и перехода в тред.
- Подготовленный HTTP-клиент для backend API.

## Стек

- Flutter / Dart
- Material 3
- `go_router` для навигации
- `provider` для простого DI и session state
- `http` для REST API
- `flutter_secure_storage` для будущего хранения токенов

## Требования

- Flutter SDK, совместимый с Dart `^3.11.5`
- Xcode и iOS Simulator для запуска на iOS
- Android Studio / Android SDK для запуска на Android
- Локальный backend `ogneva-msg`, когда понадобится проверять реальный API

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
    repositories/      # mock/live repositories and data access contracts
    services/          # HTTP/API clients
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
- `lib/data/repositories/` - текущие mock-репозитории.
- `lib/data/services/messenger_api_client.dart` - заготовка API-клиента.

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

Пока данные моковые. Следующий большой этап - заменить `MockAuthRepository` и `MockChatRepository` на реализации поверх backend API `ogneva-msg`, добавить хранение токенов и обработку реальных ошибок сети.

## Ближайшие Задачи

- Подключить реальный auth: login, refresh, me.
- Подключить список чатов и сообщений из API.
- Добавить хранение access/refresh token через `flutter_secure_storage`.
- Добавить состояние загрузки, empty/error states и retry.
- Добавить отправку сообщений.
- Добавить интеграционные тесты ключевого сценария.
