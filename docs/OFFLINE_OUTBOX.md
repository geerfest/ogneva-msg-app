# Offline Cache And Outbox

This client should keep network, persistence, and UI concerns separated. Widgets
talk to view models, view models talk to repositories, and repositories own the
choice between remote API, local cache, and pending outbox work.

## Target Data Flow

```text
ui/features/*/views
  -> ui/features/*/view_models
    -> data/repositories/ChatRepository
      -> data/services/MessengerApiClient
      -> data/services/LocalChatStore
      -> data/services/MessageOutboxStore
      -> data/services/ConnectivityService
```

## Responsibilities

- `LocalChatStore` persists conversations, topics, root messages, thread replies,
  read positions, and enough member display data to render cached screens while
  offline.
- `MessageOutboxStore` persists unsent topic messages and thread replies with
  their `clientMessageId`, parent id, body, created timestamp, retry count,
  last error, and status.
- `ChatRepository` is the single source of truth for UI state. It should return
  cached data immediately, merge remote refreshes when available, and expose
  pending outbox messages as normal `ChatMessage` domain objects with
  `isPending` or `isFailed`.
- A sync worker drains the outbox when connectivity returns or when the app is
  resumed. It retries with exponential backoff and jitter, keeps the same
  `clientMessageId`, and reconciles the server response into the local cache.
- `MessengerApiClient` remains a low-level HTTP wrapper. It should not know about
  widgets, view models, local databases, retry scheduling, or UI error strings.

## Message Send Contract

1. Generate a durable `clientMessageId` before writing anything to the UI.
2. Insert the pending message into `LocalChatStore`.
3. Insert an outbox record with status `queued`.
4. Render the pending message from repository state.
5. The sync worker sends the request with the same `clientMessageId`.
6. On success, replace the pending local row with the server `MessageDTO`.
7. On duplicate/idempotent success, treat the returned existing message as
   success and reconcile it.
8. On offline or transient failures, keep the record queued and retry.
9. On validation or permission failures, mark the outbox row failed and show the
   failed state in the message bubble.

The backend already deduplicates sends by `topic_id + sender_id +
client_message_id`, including thread replies through their parent topic. Client
IDs therefore need to be unique per sender across a topic, not only inside a
single thread.

## Storage Choice

Use a real on-device database for this layer, not secure storage and not ad hoc
JSON files. Recommended Flutter options:

- `drift` plus `sqlite3_flutter_libs` for typed queries, migrations, and tests.
- `sqflite` if we want a smaller, lower-level dependency surface.

`flutter_secure_storage` stays only for auth tokens. Message bodies, topics,
and outbox metadata should live in the local chat database.

## Minimum First Slice

The first offline implementation should be deliberately narrow:

- cache the conversation list, conversation details, topic messages, and thread
  replies after successful loads;
- queue topic and thread sends when HTTP fails because of connectivity or a
  transient server error;
- expose pending, retrying, and failed states through existing `ChatMessage`
  fields;
- retry on app resume and after a successful realtime reconnect;
- keep `dart format .`, `flutter analyze`, and `flutter test` clean.
