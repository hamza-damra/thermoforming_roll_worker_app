# Roll Worker App — Multi-Line Selection (Backend Handoff)

> **Audience.** The Roll Worker Flutter agent. This document supersedes any prior assumption that the line picker is single-select. It also refines (it does **not** replace) [`THERMOFORMING_ROLL_WORKER_APP_FRONTEND_REQUIREMENTS.md`](frontend-handoff/THERMOFORMING_ROLL_WORKER_APP_FRONTEND_REQUIREMENTS.md) — that doc's per-shift-line storage rules, role separation, scan/mount flow, etc. all stand. The only change is the auth shape.

> **Scope.** Backend only in this slice. No Flutter source code is touched here. Operator App and Palletizing App are out of scope.

---

## 1. Summary

### 1.1 Why the old single-select UX is wrong

A roll worker is operationally responsible for **every** active thermoforming shift-line their parent operator is supervising — usually two (e.g. `TH-01` and `TH-02`), occasionally more. Forcing the worker to authenticate against exactly one line per device meant:

- They had to log out / re-enter PIN to switch lines, wasting time during scan-heavy moments.
- The other line's roll-consumption events were attributed to "no roll worker" or, worse, miscredited if a teammate signed in.
- The factory's "this line lost a roll worker" warning fired spuriously every time the worker was working the *other* line.

### 1.2 New expected behaviour

- The line picker (`GET /shift-lines/active-options`) is a **multi-select** (1..N).
- After the worker selects 1 or more lines and enters their PIN once, the device calls **one** new endpoint: `POST /sessions/start-batch`.
- The backend validates the PIN exactly once, then atomically opens (or replaces) one ACTIVE session per selected shift-line.
- The response carries one `sessionToken` per selected `shiftLineId`. Flutter stores the tokens locally, **keyed by `shiftLineId`**.
- All roll-operation endpoints stay shift-line-scoped — Flutter just picks the right token for the line the worker is currently acting on.

### 1.3 Backend status: did it change?

**Yes.** This slice added:

- **NEW** endpoint: `POST /api/v1/thermoforming-roll-app/sessions/start-batch` — atomic batch session-start.
- **CHANGED (additive)**: `GET /api/v1/thermoforming-roll-app/shift-lines/active-options` response now carries two new nullable fields — `existingSessionOperatorId` and `existingSessionOperatorName` — used by the multi-select picker to render a "used by X" badge.
- **NEW** error codes (4) + Arabic/English message keys (6 — also fills two pre-existing-but-unmessaged codes).
- **No Flyway migration.** The existing `RollWorkerSession` table already supports one operator on multiple shift-lines; the per-shift-line uniqueness constraint (`uk_roll_worker_sessions_one_active_per_shift_line` on the generated `active_lock` column from `V67`) stays intact.
- **No domain-service changes.** The Roll Worker module continues to delegate to the same `RollScanService`, `PreviousRollResolutionService`, `ThermoformingProductSwitchService`, `RollLabelReprintService`.

The legacy single-line endpoint (`POST /shift-lines/{shiftLineId}/roll-worker-auth`) **is retained** for backward-compatibility with anything already wired against it. New Flutter flow should use **batch-start exclusively** — even when only one line is selected. There is no behavioural difference for the `count == 1` case.

---

## 2. Backend endpoints (full reference)

### 2.1 `GET /api/v1/thermoforming-roll-app/shift-lines/active-options`

| | |
|---|---|
| **Method** | `GET` |
| **Auth** | `X-Device-Key: <device key>` only. **No** roll-worker session token — this endpoint is the entry point that runs **before** PIN authentication. |
| **Body** | none |
| **Status** | 200 OK on success (empty list when no active shift-lines exist) |

**Response shape** (single row of the `data` array):

```json
{
  "shiftLineId": 101,
  "thermoformingShiftId": 9001,

  "thermoformingLineId": 11,
  "thermoformingLineCode": "TH-01",
  "thermoformingLineName": "خط التشكيل 1",

  "palletizingLineId": 21,
  "palletizingLineCode": "LINE_1",
  "palletizingLineName": "خط الرص 1",

  "currentProductTypeId": 50,
  "currentProductTypeName": "TBS-13 C1500 Black / Black / 32 كرتونة",

  "currentRollId": 900,
  "currentRollGeneratedRollId": "001000000123",
  "currentRollTypeCode": "RT-A",
  "currentRollTypeName": "Regular Black",
  "currentRollLastKnownWeightKg": 180.500,

  "operatorId": 7,
  "operatorName": "محمد",

  "shiftLineStatus": "ACTIVE",
  "selectable": true,
  "blockingReason": null,

  "existingSessionOperatorId": 77,
  "existingSessionOperatorName": "يوسف"
}
```

**The two NEW fields**:
- `existingSessionOperatorId` (Long, nullable) — id of the roll worker currently holding an ACTIVE session on this shift-line, or `null` if no roll worker is logged in.
- `existingSessionOperatorName` (String, nullable) — display name from the session's snapshot column.

**UX rule for these fields**: advisory only. `selectable` stays `true` even when a session exists. The worker may still tick a line that's "used by Yusuf" — the backend will resolve the conflict at batch-start time (idempotent reuse if it's the same worker, hard reject if it's someone else). Use the values to render a "مستخدم من: <name>" / "in use by <name>" badge so the worker can make an informed choice before committing to PIN entry.

### 2.2 `POST /api/v1/thermoforming-roll-app/sessions/start-batch` (NEW)

| | |
|---|---|
| **Method** | `POST` |
| **Auth** | `X-Device-Key: <device key>` only. **No** session token — this call IS the session-creation step. |
| **Body** | `application/json`, see below |
| **Status** | 201 CREATED on success |

**Request**:

```json
{
  "pin": "1234",
  "shiftLineIds": [101, 102]
}
```

- `pin`: required, the raw PIN from the input field. The backend validates it once, never logs it. Flutter must send it over TLS only and **never** persist it on disk.
- `shiftLineIds`: required, non-empty. Order is preserved in the response (after duplicate-id rejection).

**Response (201 CREATED)**:

```json
{
  "success": true,
  "data": {
    "rollWorkerOperatorId": 77,
    "rollWorkerName": "يوسف",
    "sessions": [
      {
        "shiftLineId": 101,
        "sessionId": 501,
        "sessionToken": "5b2e…uuid…",
        "thermoformingShiftId": 9001,
        "thermoformingLineId": 11,
        "palletizingLineId": 21,
        "startedAt": "2026-05-10T10:00:12.123+03:00",
        "startedAtDisplay": "2026-05-10، 10:00 صباحاً"
      },
      {
        "shiftLineId": 102,
        "sessionId": 502,
        "sessionToken": "9c4f…uuid…",
        "thermoformingShiftId": 9001,
        "thermoformingLineId": 12,
        "palletizingLineId": 22,
        "startedAt": "2026-05-10T10:00:12.140+03:00",
        "startedAtDisplay": "2026-05-10، 10:00 صباحاً"
      }
    ]
  },
  "error": null
}
```

- The raw `sessionToken` is returned **once** per shift-line. The backend persists only its SHA-256 hash. If you lose it, you must re-authenticate (call batch-start again) — there is no "fetch my token" endpoint.
- The list is in input order after de-duplication.
- `rollWorkerOperatorId` / `rollWorkerName` are the same across every entry (PIN was validated once).

**Error responses** (envelope shape `{success: false, data: null, error: { code, message, details? }}`):

| code | HTTP | when | details? | UX action |
|---|---|---|---|---|
| `OPERATOR_PIN_INVALID` | 401 | wrong PIN | — | shake PIN field, allow retry; counter increments toward lockout |
| `OPERATOR_LOCKED` | 423 | 5 failed PIN attempts | — | show "locked, try in 5 min" |
| `ROLL_WORKER_NOT_ALLOWED` | 403 | PIN matched but `roll_worker_enabled=false` | — | "هذا المشغّل غير مخوّل للعمل كعامل رولات." → block, route to admin |
| `ROLL_WORKER_SESSION_BATCH_EMPTY` | 400 | empty / null `shiftLineIds` | — | bug — disable the CTA when 0 selected |
| `ROLL_WORKER_SESSION_LINE_DUPLICATE` | 400 | same id appears twice in payload | `{shiftLineId}` | bug — picker should de-dup client-side too |
| `THERMOFORMING_SHIFT_LINE_NOT_FOUND` | 404 | one of the ids doesn't exist | `{shiftLineId}` | refresh active-options and re-pick |
| `ROLL_WORKER_SESSION_LINE_INACTIVE` | 409 | one of the lines isn't `ACTIVE` (e.g. ended between picker-load and submit) | `{shiftLineId}` | refresh active-options; tell the worker that line ended |
| `ROLL_WORKER_SESSION_LINE_USED_BY_OTHER_WORKER` | 409 | one of the lines has an ACTIVE session owned by a different operator | `{shiftLineId, ownerOperatorId, ownerOperatorName}` | show "هذا الخط مستخدم من <name>"; offer to drop it from selection and retry |

**Atomicity**: every error rejects the whole batch. No session is opened on any line in the request. This is a hard guarantee from the backend's `@Transactional` boundary — Flutter does not need any "rollback" logic.

**Same-worker collision** is handled silently: if a selected line already has an ACTIVE session owned by the same worker who's authenticating now, that session is moved to `REPLACED` (reason `REPLACED_BY_NEW_AUTH`) and a fresh ACTIVE session with a new token is returned. From Flutter's POV, every successful call returns a fresh token per line — always overwrite local storage with the new value.

### 2.3 `GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-session/current`

Unchanged. Use to **restore** a single line's session at app launch.

| | |
|---|---|
| **Method** | `GET` |
| **Auth** | `X-Device-Key` only |
| **Status** | 200 OK if an ACTIVE session exists; 404 (`ROLL_WORKER_SESSION_REQUIRED`) otherwise |

To restore N lines after relaunch: call this endpoint N times, once per stored token's `shiftLineId`. There is **no batch-restore endpoint** — per-line failure (404 / 401) just means the worker no longer has an ACTIVE session on that line; drop the local token and either show "this line ended" or re-route to the picker. Other lines keep working.

### 2.4 `POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-logout`

Unchanged. Per-line only.

| | |
|---|---|
| **Method** | `POST` |
| **Auth** | `X-Device-Key` only |
| **Body** | `{"sessionToken": "<raw token for THIS shift-line>"}` |
| **Status** | 200 OK; idempotent on already-ended sessions (no error if you call twice) |

For "logout current line": call once. For "logout all lines": call once per active session (in parallel or sequentially — each call is independently idempotent). If one call fails, only that line's session stays open — retry independently. Drop the local token only on a successful (200) response. There is **no batch-logout endpoint**.

### 2.5 Roll-operation endpoints (unchanged contracts)

All require `X-Device-Key: <device key>` AND `X-Session-Token: <raw token for the shift-line>`. The session token must belong to the same `shiftLineId` in the path or the backend returns 403 `ROLL_WORKER_SESSION_REQUIRED`.

- `POST /shift-lines/{shiftLineId}/scan-roll`
- `POST /shift-lines/{shiftLineId}/previous-roll/full-consume`
- `POST /shift-lines/{shiftLineId}/previous-roll/return`
- `POST /shift-lines/{shiftLineId}/previous-roll/grinding`
- `POST /shift-lines/{shiftLineId}/product-switch`
- `GET /rolls/{generatedRollId}/reprint-label` — not shift-line-scoped; accepts any ACTIVE session token the worker holds.

---

## 3. Active-line option DTO field guide

Every field already documented in [§5 of THERMOFORMING_ROLL_WORKER_APP_FRONTEND_REQUIREMENTS.md](frontend-handoff/THERMOFORMING_ROLL_WORKER_APP_FRONTEND_REQUIREMENTS.md) is unchanged. New / clarified fields:

| Field | Type | UI usage |
|---|---|---|
| `shiftLineId` | Long | Primary key for the row. **Use as the storage key** for the session token after batch-start. **Never hardcode.** |
| `thermoformingLineCode` | String | Header chip in the picker tile, e.g. `TH-01`. |
| `thermoformingLineName` | String (Arabic) | Sub-title in the tile, e.g. `خط التشكيل 1`. |
| `palletizingLineCode/Name` | String / String (Arabic) | "Linked palletizing line" line in the tile (so the worker confirms they're picking the right line). |
| `currentProductTypeName` | String (Arabic) | "Currently producing" sub-line. |
| `currentRollGeneratedRollId` | String | Optional: render "Roll #001000000123 mounted" if non-null. |
| `currentRollLastKnownWeightKg` | BigDecimal | Optional: render the latest weight reading. Never substitute roll start-weight as a fallback. |
| `operatorId` / `operatorName` | Long / String | The Thermoforming **operator** running the parent shift-line (different concept from the Roll Worker). Display as "Shift operator: <name>". |
| `existingSessionOperatorId` | **Long, nullable** | **NEW.** The **roll worker** currently logged in here, if any. Use to compute "this line is mine" vs "this line is someone else's" *after* the worker authenticates. |
| `existingSessionOperatorName` | **String, nullable** | **NEW.** Display name for the badge. Render as "مستخدم من: <name>" when non-null. |
| `selectable` | Boolean | **Always `true`** in the current design. Do not disable rows on the client side based on this — conflicts are enforced authoritatively by `start-batch`. |
| `blockingReason` | String | Always `null`. Reserved for a future variant. |

---

## 4. Batch start / session flow

```
┌──────────────────┐    GET /shift-lines/active-options       (X-Device-Key)
│  Picker screen   │ ────────────────────────────────────────────────────►
│  multi-select    │ ◄────────────────────────────── 200 [ ...rows... ]
└────────┬─────────┘
         │  user ticks 1..N rows, taps "متابعة بـ {N} خطوط"
         ▼
┌──────────────────┐
│   PIN screen     │  user enters PIN once
└────────┬─────────┘
         │
         ▼
         POST /sessions/start-batch                              (X-Device-Key)
         body: { pin, shiftLineIds: [101, 102, ...] }
         ──────────────────────────────────────────────────────►
         ◄────────────────────────────── 201 { sessions: [ ... ] }
         │
         ▼
┌──────────────────┐
│   home / multi-  │  for each entry in response:
│   line switcher  │     secureStorage.write(
│                  │         "roll_worker_session_token_${shiftLineId}",
└──────────────────┘         entry.sessionToken)
```

**Storage key strategy** (matches §6.2 of the existing handoff):
- Per-shift-line key: `roll_worker_session_token_${shiftLineId}`.
- Optionally also keep an index: `roll_worker_active_shift_line_ids` → JSON list of ids the worker selected, so app launch knows which keys to look for.
- **Never** use a single global key. Two lines = two values.
- When the device removes a token (logout / 401 / 404 on the per-line current endpoint), remove just that key and update the index.

**One vs many lines**: there is no client-side branching. The "1 line selected" case is just the same request with a 1-element list. The picker CTA copy may still vary ("اختيار الخط" vs "متابعة بـ 2 خطوط") — see §5.

---

## 5. Multi-line home UX requirements (Arabic copy)

Use the strings below verbatim where possible. Do not invent new translations for these screens — keep the Arabic vocabulary consistent across screens.

### 5.1 Line picker

| Element | Arabic | Notes |
|---|---|---|
| Screen title | `اختر خطوط التشكيل` | header |
| Subtitle / helper | `يمكنك اختيار خط واحد أو أكثر` | small text under header |
| Selected count chip | `تم اختيار {count} خطوط` | live-update as user ticks rows |
| CTA — 0 selected | `اختر على الأقل خطاً واحداً` | disabled state |
| CTA — 1 selected | `متابعة` | enabled, primary button |
| CTA — 2+ selected | `متابعة بـ {count} خطوط` | enabled, primary button |
| Empty state (zero ACTIVE shift-lines globally) | `لا توجد خطوط نشطة حالياً` | with refresh affordance |
| Per-row "in-use by other worker" badge | `مستخدم من: {name}` | shown when `existingSessionOperatorName != null && existingSessionOperatorId != currentWorkerId`; until PIN is entered, just show the name |
| Per-row "in use by you" hint (only after PIN if returning to picker) | `الخط الحالي` | optional |

### 5.2 Home / multi-line switcher

| Element | Arabic | Notes |
|---|---|---|
| Top-bar tabs/chips | line code (e.g. `TH-01`, `TH-02`) | one chip per active session; tap to switch |
| Active line indicator | `الخط الحالي: {code}` | always visible above the scan/mount card so the worker knows which line they're acting on |
| Switch action | `تبديل الخط` | optional — long-press or menu item if tabs are too small on small screens |
| Per-line lost-session toast | `انتهت جلسة هذا الخط — يرجى إعادة الاختيار` | when a `current` poll returns 404/401 for a stored token |

### 5.3 Logout

Backend supports per-line logout only. Surface both options in the menu:

| Element | Arabic | Calls |
|---|---|---|
| `تسجيل خروج من الخط الحالي` | per-line logout for the currently active chip | `POST /shift-lines/{currentId}/roll-worker-logout` once |
| `تسجيل خروج من كل الخطوط` | per-line logout for every stored session | `POST /shift-lines/{id}/roll-worker-logout` for each id; handle each result independently |

Partial failure handling for "logout all":
- If a call returns 200 → drop just that line's token and remove its chip.
- If a call returns 4xx/5xx → keep the line's token, mark its chip with an error indicator, allow user-initiated retry.
- After all calls finish, if zero tokens remain → route back to picker / PIN screen.

---

## 6. State management guide for Flutter

> Every rule below is hard. The "no fake local state" rule is what makes the multi-line UX trustworthy in practice.

- **State container**: Riverpod `AsyncNotifier` / `Notifier`. **No** `setState` for business state.
- **Sessions** keyed by `shiftLineId` — typically a `Map<int, RollWorkerSessionState>` inside one notifier, or a notifier-per-line within a parent registry.
- **Mounted-roll state** keyed by `shiftLineId` — never global. Switching the active chip swaps which line's mounted-roll subtree is rendered; it does not refetch the others.
- **Errors** scoped per line — a 401 on `/scan-roll` for `TH-01` does **not** invalidate the `TH-02` session.
- **Token storage** keyed by `shiftLineId` (see §4). One row per active session in `flutter_secure_storage`.
- Forbidden:
  - hardcoded `shiftLineId` literals
  - manual `shiftLineId` text-entry fields anywhere in the UI
  - any static "list of lines" loaded from JSON / asset / hardcoded constant
  - a global "the current session token" variable shared between lines
  - any client-side fallback that forges a session if the backend says no

---

## 7. Product compatibility note

The Roll Worker product-switch picker MUST eventually consume:

```
GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/product-switch-options
```

Per [§8 of `THERMOFORMING_PRODUCT_ROLL_COMPATIBILITY_HANDOFF.md`](THERMOFORMING_PRODUCT_ROLL_COMPATIBILITY_HANDOFF.md), this endpoint is **still TODO on the backend**. Do **not**:
- Use any "all active products" fallback list.
- Send the product-switch request without first showing the worker the compatible-only options.
- Hard-code allowed product↔roll pairs in the app.

When the endpoint lands, wire it into the product-switch screen and ship.

---

## 8. Testing checklist for the Flutter agent

- [ ] Picker shows multiple ACTIVE shift-lines; can tick 1 line; can tick 2+ lines.
- [ ] CTA is disabled when 0 lines selected; copy switches between `متابعة` and `متابعة بـ N خطوط`.
- [ ] PIN entry happens **once** for the whole selection; backend log shows exactly one `verifyPin` per batch (verify via dev backend logs).
- [ ] On 201, `sessions[].sessionToken` is stored under `roll_worker_session_token_${shiftLineId}` for each entry.
- [ ] Home screen shows a switcher (chips/tabs) for each selected line; the active chip is visually distinct.
- [ ] Each scan/mount/return/grinding/product-switch call sends `X-Session-Token` for the **currently selected** line only.
- [ ] `existingSessionOperatorName` is rendered as a "مستخدم من" badge when non-null.
- [ ] If batch-start returns `ROLL_WORKER_SESSION_LINE_USED_BY_OTHER_WORKER`, the offending shift-line (from `error.details.shiftLineId`) is highlighted on the picker; the worker can drop it and retry.
- [ ] Per-line 404 on `/current` removes only that line's chip and token; other lines stay live.
- [ ] "Logout current line" calls per-line logout exactly once; chip is removed on 200.
- [ ] "Logout all lines" calls per-line logout once per stored session; partial failure leaves the failed line live with a retry indicator.
- [ ] App relaunch restores per-line sessions by calling `/current` once per stored token; stale tokens (4xx) are dropped silently.
- [ ] Forbidden grep clean across the Flutter source:
  - no `/api/v1/thermoforming-app/` (Operator App namespace)
  - no `/api/v1/palletizing-line/` (Palletizing App namespace)
  - no string literals matching `shiftLineId.*=.*[0-9]+` (hardcoded ids)
  - no manual `TextField` accepting a shift-line id

---

## 9. Open questions / limitations

- **Single-line endpoint retained.** `POST /shift-lines/{shiftLineId}/roll-worker-auth` still exists for back-compat. New Flutter code should not call it; use `start-batch` even when N=1.
- **No batch logout.** Per-line `roll-worker-logout` is the only logout path. Each call is idempotent so per-line retries are safe. If operational evidence later argues for an atomic batch-logout, raise it back to backend; do not invent a workaround.
- **No batch restore.** Restore at app launch is N parallel calls to `/current` (one per stored token). Per-line failure removes only that token.
- **`product-switch-options` still TODO.** See §7. Do not ship the product-switch picker until the backend lands it.
- **`selectable` field is always `true`.** It exists for forward-compatibility (a future variant might block selection — e.g. a parent shift in a draining state); for now Flutter should ignore it for disable-logic and rely on `existingSessionOperator*` for advisory rendering.
- **`existingSessionOperatorId` is a hint, not a guarantee.** Between picker load and PIN submit, ownership can flip. The batch-start endpoint is the source of truth — render the picker without disabling rows; let the conflict response drive the recovery UI.
