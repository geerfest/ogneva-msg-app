# Productized Messenger Client Tasks

This file tracks Flutter client work for the productized messenger backend
contract described in:

```text
/Users/geerfest/projects/ogneva-msg/docs/PRODUCT_REQUIREMENTS.md
/Users/geerfest/projects/ogneva-msg/docs/tasks/post-mvp-productization.md
/Users/geerfest/projects/ogneva-msg/docs/API.md
/Users/geerfest/projects/ogneva-msg/docs/REALTIME_EVENTS.md
/Users/geerfest/projects/ogneva-msg/api/openapi.yaml
```

Backend PM-1 through PM-6 are treated as complete handoff work. This file is
the client execution tracker, not a duplicate product specification.

Status values:

- `pending` - not started.
- `in_progress` - actively being implemented.
- `done` - implemented, verified, and documented.
- `blocked` - cannot continue without a product or technical decision.

Completion rule:

- update the task status;
- check completed acceptance items;
- add a dated verification note with commands, simulator checks, or live backend
  checks that passed;
- keep completed tasks in the file for history.

## CL-0 - Client Workflow Setup

Status: `done`

Scope:

- create the client-side task tracker;
- document cross-repo contract rules in `AGENTS.md`;
- keep product rules in the backend repo and client execution state here;
- use subagent/review passes for broad contract, UI, realtime, and verification
  checks when available;
- use the iOS Build app / XcodeBuildMCP plugin for live simulator verification
  when UI behavior changes.

Acceptance:

- [x] feature branch is created for productized messenger client work;
- [x] `AGENTS.md` explains the cross-repo source-of-truth model;
- [x] this task file lists the client implementation stages;
- [x] final verification note is added after the setup commit or handoff.

Verification notes:

- 2026-06-26: Created branch `codex/productized-messenger-client`, added this
  tracker, updated `AGENTS.md` with cross-repo workflow, subagent/review
  guidance, and iOS Build app / XcodeBuildMCP verification expectations. Reviewed
  the resulting diff and left implementation tasks pending from CL-1 onward.

## CL-1 - Backend Contract Parity in Data Layer

Status: `done`

Scope:

- add DTOs/domain models for contacts, member updates, personal archive state,
  `last_activity_at`, and new realtime data;
- add repository methods for `GET /contacts`, `POST /conversations`,
  add/update/remove members, archive/unarchive, `PATCH /topics`, message
  edit/delete, and cursor pagination;
- keep widgets free of direct HTTP calls;
- update unit tests for DTO parsing and API client/repository behavior.

Acceptance:

- [x] contacts parse `id`, `role`, `display_name`, `email`,
  `allowed_conversation_types`, and `reason`;
- [x] conversations parse `last_activity_at`, `archived_at`, members, topics,
  and `next_cursor`;
- [x] topic/thread message lists use backend opaque `cursor` values;
- [x] repository exposes create conversation, member add/update/remove,
  archive/unarchive, topic update, message edit/delete;
- [x] unauthorized refresh behavior remains intact;
- [x] focused data tests pass.

Verification notes:

- 2026-06-26: Started implementation after checking backend source-of-truth
  docs/API/OpenAPI for contacts, conversation pagination, personal archive,
  member/topic/message management, and realtime event payloads.
- 2026-06-26: Added contact/member/archive/message-delete domain models, DTO
  parsing, repository methods for CL-1 endpoints, cursor passthrough for topic
  and thread message lists, and focused API/repository tests. Ran
  `dart format .`, `flutter analyze`, and `flutter test`; analyze was clean and
  all 26 tests passed.

## CL-2 - Chats List Filters, Archive, and Pagination

Status: `done`

Scope:

- make `Все`, `Непрочитанные`, and `Архив` real filters backed by
  `filter=all|unread|archived`;
- support `next_cursor` loading for conversation pages;
- add personal archive/unarchive actions;
- reflect `archived_at`, `last_activity_at`, unread counts, empty, loading,
  error, and retry states.

Acceptance:

- [x] filter chips change the backend query and selected UI state;
- [x] archived conversations move to/from the archive filter for the current
  user only;
- [x] pagination can load another page without duplicate rows;
- [x] realtime archive/unarchive/unread changes trigger an appropriate reload;
- [x] widget tests cover filter switching and archive/unarchive state.

Verification notes:

- 2026-06-26: Started implementation after checking backend API/product/realtime
  docs for `filter=all|unread|archived`, personal archive behavior,
  `next_cursor`, and `conversation.archived` / `conversation.unarchived` /
  `unread.changed` reload expectations.
- 2026-06-26: Implemented real chats filters, `next_cursor` load-more with
  duplicate protection, personal archive/unarchive row actions, archived state
  labels, filter-specific empty states, and list reloads for archive/unarchive,
  membership/status, and unread realtime events. Added widget tests for filter
  switching, pagination merge behavior, archive/unarchive state, and realtime
  unread reload. Ran `dart format .`, `flutter analyze`, and `flutter test`;
  analyze was clean and all 30 tests passed. XcodeBuildMCP `build_run_sim`
  succeeded for `ios/Runner.xcworkspace` / `Runner` on booted `iPhone 17`, and
  screenshot verification showed the launched login UI.

## CL-3 - Conversation Creation from Contact Discovery

Status: `done`

Scope:

- use `GET /contacts?purpose=direct` and
  `GET /contacts?purpose=group_member`;
- implement create direct/support/group flows without guessing product policy;
- use `allowed_conversation_types` from contacts to decide available actions;
- navigate to the created or existing returned conversation.

Acceptance:

- [x] FAB opens a create-chat flow instead of a no-op;
- [x] direct/support recipient choices come from `purpose=direct`;
- [x] group member choices come from `purpose=group_member`;
- [x] group title is required only when needed by backend contract;
- [x] duplicate direct conversation response opens the existing chat;
- [x] errors from product policy are shown cleanly;
- [x] widget tests cover at least one direct flow and one group flow.

Verification notes:

- 2026-06-26: Started implementation after checking backend
  PRODUCT_REQUIREMENTS/API/OpenAPI for contact discovery purposes,
  `allowed_conversation_types`, `POST /conversations`, duplicate direct
  behavior, and group/support policy boundaries.
- 2026-06-26: Implemented `/chats/new` create-chat flow with backend contact
  discovery for direct/support and group-member purposes, direct/support/group
  create actions, optional group title, returned-conversation navigation, and
  policy-error display. Added widget tests for returned direct conversation
  navigation, policy errors, and group creation from group-member discovery. Ran
  `dart format .`, `flutter analyze`, and `flutter test`; analyze was clean and
  all 33 tests passed. XcodeBuildMCP `build_run_sim` succeeded for
  `ios/Runner.xcworkspace` / `Runner` on booted `iPhone 17` (iOS 26.5), then
  live simulator verification passed `login -> chats -> create chat -> select
  Dev Teacher -> open Dev Teacher / Student`; screenshot:
  `/var/folders/c0/5zsz0jvx3ys0qdp7qjc07wnm0000gn/T/screenshot_optimized_d18f8315-10d4-4355-ad30-35b45db0b26f.jpg`.
  The simulator app process was stopped after verification.

## CL-4 - Chat Management: Members and Topics

Status: `pending`

Scope:

- show conversation participants with roles and write permission;
- add member management actions where backend allows them;
- support member role/can_write update and soft removal;
- support topic rename/archive;
- keep composer and topic actions aligned with backend errors and archived or
  closed states.

Acceptance:

- [ ] conversation detail exposes members in a usable UI;
- [ ] add/update/remove member calls the correct endpoints;
- [ ] topic rename/archive calls `PATCH /topics/{topic_id}`;
- [ ] archived topics cannot be used for new sends from the UI;
- [ ] policy failures show clear messages without corrupting local state;
- [ ] realtime member/topic/status events refresh chat detail.

Verification notes:

- Pending.

## CL-5 - Message Actions and History Pagination

Status: `pending`

Scope:

- add edit/delete actions for messages;
- preserve soft-delete/tombstone display;
- use cursor pagination for older topic and thread messages;
- keep optimistic send reconciliation by `client_message_id`.

Acceptance:

- [ ] own message edit uses `PATCH /messages/{message_id}`;
- [ ] delete uses `DELETE /messages/{message_id}`;
- [ ] realtime `message.edited` and `message.deleted` update visible topic and
  thread messages;
- [ ] older topic messages can be loaded through `next_cursor`;
- [ ] older thread replies can be loaded through `next_cursor`;
- [ ] widget tests cover edit/delete and older-page merge behavior.

Verification notes:

- Pending.

## CL-6 - Realtime Invalidation and Contact Refresh

Status: `pending`

Scope:

- handle productization events:
  `conversation.member_updated`, `conversation.member_removed`,
  `conversation.archived`, `conversation.unarchived`,
  `conversation.status_updated`, `student_teacher_link.created`, and
  `student_teacher_link.revoked`;
- refresh contact discovery after student-teacher link changes;
- avoid showing the current user's own typing event.

Acceptance:

- [ ] list-level events refresh chats without duplicate subscriptions;
- [ ] chat-level member/status events refresh conversation detail;
- [ ] link events invalidate contact caches or reload active contact screens;
- [ ] realtime deduplication remains based on `event_id`;
- [ ] tests cover new event routing decisions.

Verification notes:

- Pending.

## CL-7 - Live iOS Simulator Verification

Status: `pending`

Scope:

- run the local backend stack with current seed data;
- verify live flows on iOS Simulator through the iOS Build app /
  XcodeBuildMCP plugin when available;
- keep command-line checks as the baseline gate.

Acceptance:

- [ ] `dart format .` completed;
- [ ] `flutter analyze` passed;
- [ ] `flutter test` passed;
- [ ] iOS simulator launches the app against live backend;
- [ ] live scenario passes:
  `login -> contacts -> create chat -> chats filters/archive -> chat management
  -> edit/delete -> pagination -> realtime refresh`;
- [ ] any skipped live check is documented with the reason.

Verification notes:

- Pending.
