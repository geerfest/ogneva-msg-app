# AGENTS.md

Инструкции для Codex и других coding agents, которые работают в этом репозитории.

## Контекст

Это Flutter-клиент мессенджера Ogneva. Backend живет отдельно:

```text
https://github.com/geerfest/ogneva-msg
```

Текущий клиент подключен к live MVP backend. Runtime mock-режима в приложении нет; тесты используют явно инжектированные fakes.

Если задача про продуктовую логику, роли, права, контакты, realtime, payload или API, сначала проверь backend-репозиторий:

```text
/Users/geerfest/projects/ogneva-msg/docs/PRODUCT_REQUIREMENTS.md
/Users/geerfest/projects/ogneva-msg/docs/tasks/post-mvp-productization.md
/Users/geerfest/projects/ogneva-msg/docs/API.md
/Users/geerfest/projects/ogneva-msg/docs/REALTIME_EVENTS.md
/Users/geerfest/projects/ogneva-msg/api/openapi.yaml
```

Backend product/API docs являются source of truth для межрепозиторного контракта. В этом репозитории веди клиентский execution tracker, UI/UX решения и проверочный статус.

## Главные Правила

- Пиши код в стиле существующего Flutter-проекта.
- Держи архитектуру простой: `ui`, `domain`, `data`.
- Не добавляй новые state-management или routing библиотеки без явной причины.
- Не смешивай сетевые вызовы с виджетами. Виджеты обращаются к view model / repository, а не к `http` напрямую.
- Не храни токены в памяти виджета; для persistent auth используй `flutter_secure_storage`.
- Не коммить build-артефакты, DerivedData, `.dart_tool`, `build/`, IDE-кэш и локальные env-файлы.
- Для UI-изменений проверяй, что элементы не переполняются на маленьком экране.
- Для кликабельных строк и компактных controls добавляй понятную tappable-зону и `Semantics`, если это помогает accessibility и тестам.
- Не собирай список пользователей для чата из "всех users". Для выбора получателей используй backend contact discovery.

## Task Flow

Новая продуктовая клиентская работа ведется через task-файлы в:

```text
docs/tasks/
```

Текущий tracker:

```text
docs/tasks/productized-messenger-client.md
```

Правила:

- перед началом этапа проверь backend docs, затем обнови статус задачи на `in_progress`;
- двигайся по task-файлу сверху вниз, если пользователь не меняет приоритет;
- после завершения этапа отметь acceptance items, добавь verification note и только потом переходи дальше;
- если контракт backend непонятен или противоречив, не додумывай silently: зафиксируй вопрос в task-файле или спроси пользователя;
- если меняется продуктовая логика, роли, права или API-контракт, источник правды должен быть обновлен на backend стороне; в этом репозитории можно добавить краткую клиентскую ссылку/заметку, но не дублировать весь продуктовый spec.

## Cross-Repo Workflow

Рабочая схема для одного продукта в двух репозиториях:

- `ogneva-msg` хранит продуктовые правила, API/realtime контракт, migrations, smoke-доказательства и backend task history.
- `ogneva-msg-app` хранит клиентские задачи, UI state, навигацию, view models, DTO parsing, widget/unit tests и simulator verification.
- Перед data-layer изменениями сверяй route/payload/response по backend docs и при необходимости по backend handler/dto.
- Перед UI flow изменениями проверь, какие роли и действия разрешены backend политикой; UI может скрывать недоступные действия, но backend остается authority.

## Subagent / Review Workflow

Для крупных или сквозных этапов полезны независимые проверки, если tooling доступен:

- contract pass: сравнить backend docs/OpenAPI с клиентскими DTO/repository методами;
- UI pass: проверить экранные состояния, overflow и доступность;
- realtime pass: проверить обработку событий и reload-инвалидацию;
- verification pass: составить live сценарии перед iOS simulator run.

Главный агент все равно сам читает инструкции, принимает финальные решения, запускает итоговые проверки и обновляет task-файл.

## Архитектура

Ожидаемая структура:

```text
lib/
  data/
    repositories/
    services/
  domain/
    models/
  ui/
    core/
      routing/
      session/
      theme/
      widgets/
    features/
      <feature>/
        view_models/
        views/
```

Правила по слоям:

- `domain/models` - чистые модели без Flutter UI.
- `data/services` - низкоуровневый API/HTTP.
- `data/repositories` - прикладной data contract для UI и view models.
- `ui/features/*/view_models` - состояние экрана и пользовательские действия.
- `ui/features/*/views` - композиция виджетов, без бизнес-логики и сетевых деталей.
- `ui/core/theme` - все общие цвета, typography и Material theme.
- `ui/core/widgets` - переиспользуемые UI-компоненты.

## Навигация

Навигация живет в:

```text
lib/ui/core/routing/app_router.dart
```

Используй `go_router`. Не размазывай route strings по приложению, если маршрут начинает использоваться больше одного раза: добавь helper/constant рядом с router.

## Дизайн-Система

Текущий визуальный язык:

- warm pale orange / peach для фона и поверхностей;
- blue для action-состояний, аватарок, unread badges, иконок и focus;
- graphite для основного текста;
- muted gray для вторичного текста;
- без зеленого/teal как основного акцента.

Основные токены:

```text
lib/ui/core/theme/app_colors.dart
lib/ui/core/theme/app_theme.dart
```

Если нужно добавить цвет, сначала проверь, нельзя ли выразить задачу существующим токеном. Не вставляй произвольные `Color(...)` внутрь feature views без причины.

## API И Backend

Base URL задается через:

```text
OGNEVA_API_BASE_URL
```

Пример:

```bash
flutter run --dart-define=OGNEVA_API_BASE_URL=http://localhost:8080/api/v1
```

Для Android Emulator используй `10.0.2.2` вместо `localhost`, если backend запущен на Mac.

При подключении backend:

- сначала посмотри реальные endpoints и payloads в `geerfest/ogneva-msg`;
- добавь DTO/parsing в data-layer;
- сохрани domain models удобными для UI;
- обработай loading, empty, unauthorized, offline/error states;
- не ломай mock-режим, пока live API не закрывает все нужные сценарии.

## Проверки Перед Завершением

Минимум для любых Dart/Flutter изменений:

```bash
dart format .
flutter analyze
flutter test
```

Для UI-изменений дополнительно желательно:

```bash
flutter run -d <simulator-or-device>
```

Когда доступен iOS Build app / XcodeBuildMCP plugin, используй его для simulator verification. Перед первым build/run/test в сессии проверь defaults, затем запускай приложение на iOS Simulator и проходи релевантный сценарий.

Проверяй как минимум сценарий:

```text
login -> chats -> chat -> thread
```

Для productized messenger работы расширяй live сценарий по мере готовности:

```text
login -> contacts -> create direct/support/group -> chats filters/archive -> chat management -> edit/delete -> pagination -> realtime refresh
```

## Тесты

Текущие widget-тесты лежат в:

```text
test/widget_test.dart
```

Добавляй widget-тесты, когда меняешь:

- auth flow;
- навигацию;
- chat/thread interactions;
- view model behavior, влияющий на экран.

Интеграционные тесты стоит добавить отдельным этапом, когда live API-контракт стабилизируется.

## Git

- Не переписывай чужие изменения.
- Перед коммитом смотри `git status --short`.
- Коммиты делай небольшими и осмысленными.
- Если задача не просит пушить, оставь изменения локально и сообщи статус.

## Definition Of Done

Работа считается готовой, когда:

- код отформатирован;
- `flutter analyze` чистый;
- релевантные тесты проходят;
- UI проверен на симуляторе, если менялся экран;
- README/AGENTS обновлены, если изменилась архитектура, запуск или workflow.
