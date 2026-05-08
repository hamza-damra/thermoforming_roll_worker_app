# Roll Worker App — Backend Handoff for Frontend AI Agent

> **You are building the Flutter Roll Worker App** (تطبيق عامل الرولات). This document is the single source of truth for the backend contract. Do not infer behaviour from the existing Thermoforming or Palletizing app code — the Roll Worker App is a third device-app sibling on a new namespace with new endpoints. Where existing-app UI conventions are useful, see §2 and §7.
>
> **Backend version this doc reflects:** the `feature/thermoforming-backend-module` branch after Tasks 35–41 of the Roll Worker App amendment are committed (commits `f73b47c`, `11c3abe`, `0a81401`, `6a8b6c1`, `7b0eca8`, `c0bc54a`). All endpoints and error codes listed here are implemented and unit-tested under H2; the V67 migration verification runs on Docker-equipped CI.

---

## 1. App Purpose

The Roll Worker App is the Flutter app for the **roll worker** (عامل الرولات) — the worker who **physically handles plastic-film rolls** at the thermoforming machine. The Roll Worker logs in **after** the Thermoforming Operator has already started a shift and added at least one shift-line; the app is meaningless without an active `ThermoformingShiftLine`.

**The Roll Worker App does, end-to-end:**

- Authenticates the worker with their employee PIN against an **active** `ThermoformingShiftLine`.
- Scans a roll's barcode (12-digit `generatedRollId`) and mounts it on the line.
- Closes the previously mounted roll one of three ways: full-consume / return remaining weight / send remaining weight to grinding.
- Reprints a roll label after a partial close (return or grinding).
- Performs a product switch with **current-roll-weight entry** — the new product takes over the line; the still-mounted roll's segment is closed and a new segment opens.

**The Roll Worker App does NOT:**

- Start or end a Thermoforming shift (Thermoforming App only).
- Open or close a shift-line (Thermoforming App only).
- Stack pallets (Palletizing App only).
- Hold operator-level notes or production-summary screens (Thermoforming App).
- Manage the palletizer-employee session (Palletizing App).
- Hold supervisor / approval responsibilities.

The three roles coexist on the factory floor:

| Role | Arabic | App | Identity stamped on |
|---|---|---|---|
| Thermoforming Operator | المشغّل | Thermoforming App | shift, shift-line, line authorization, `RollConsumptionEvent.operator` |
| Roll Worker | عامل الرولات | **Roll Worker App (this doc)** | `RollConsumptionItem.rollWorker*` + `RollConsumptionEvent.rollWorker*` |
| Palletizer Employee | المُشَتِّح / موظف الطبليات | Palletizing App | each pallet (`palletizer_*` columns) |

---

## 2. UI Style

Follow the same **RTL Arabic** conventions used by the Thermoforming and Palletizing apps. **No new visual patterns.** Reuse the existing Flutter design tokens — typography, color palette, button styles, list patterns, error toasts, and dialogs — from those apps. The Roll Worker App is a third device-app sibling, not a re-skin.

The waiting/empty states should match the Palletizing App's "no active shift" experience: a centred RTL message + a single primary action ("جرّب مجددًا" / refresh).

---

## 3. Backend Module

> The Roll Worker App is backed by a **new top-level backend module**: `ps.taleeb.taleebbackend.thermoformingrollapp`.
>
> This module is **app-facing only**. It owns:
> - `RollWorkerSession` entity + `RollWorkerSessionStatus` enum + `RollWorkerSessionRepository`
> - `RollWorkerSessionService` (auth / current / logout / `requireActiveSession` / `requireAnyActiveSession` / `endSessionsForShiftLine`)
> - `RollWorkerSessionController` and `RollWorkerShiftLineController` and `RollWorkerRollController`
> - Roll-worker-facing DTOs (`RollWorkerAuthRequest`, `RollWorkerAuthResponse`, `RollWorkerSessionResponse`, `RollWorkerLogoutRequest`)
> - The `/api/v1/thermoforming-roll-app/**` API surface
> - Roll-worker session-token handling (`X-Session-Token` header, SHA-256 hashed at rest)
>
> Every roll-operation endpoint **delegates** core business logic to the existing thermoforming domain services (`RollScanService`, `PreviousRollResolutionService`, `RollLabelReprintService`, `ThermoformingProductSwitchService`) under `ps.taleeb.taleebbackend.thermoforming`. **It does not duplicate business logic.** Attribution stamping uses the domain-side `ps.taleeb.taleebbackend.thermoforming.dto.RollWorkerActorContext` record, passed from the controller to the domain service.

This mirrors the way `palletizing/palletizer/` is the app-facing module for the Palletizer Employee while the core palletizing domain stays separate.

---

## 4. Auth & Session Lifecycle

The Roll Worker App follows a **three-endpoint session pattern** that mirrors the Palletizing App's palletizer-employee auth (see [`PALLETIZING_APP_AUTH_AND_PRODUCT_SWITCH_HANDOFF.md`](PALLETIZING_APP_AUTH_AND_PRODUCT_SWITCH_HANDOFF.md) §3–§4).

### 4.1 Transport headers

Every request carries:

| Header | Meaning |
|---|---|
| `X-Device-Key` | Same shared device API key used by the Thermoforming and Palletizing apps. Required on **every** call (transport auth). |
| `X-Session-Token` | Issued ONCE at auth time. Required on every call **except** auth itself. Identifies which roll worker is acting. |

Backend security: the `/api/v1/thermoforming-roll-app/**` namespace is mounted under a dedicated `@Order(1)` `SecurityFilterChain` that requires `ROLE_DEVICE` (set by `DeviceApiKeyFilter` when `X-Device-Key` matches). The session token is enforced inside controllers via `RollWorkerSessionService.requireActiveSession(...)` — Spring Security never sees it.

### 4.2 Authenticate

```
POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-auth
Headers: X-Device-Key
Body: { "pin": "1234" }
```

Validations the backend enforces:

| # | Check | Error code | HTTP |
|---|---|---|---|
| 1 | Shift-line exists | `THERMOFORMING_SHIFT_LINE_NOT_FOUND` | 404 |
| 2 | Shift-line is `ACTIVE` | `THERMOFORMING_SHIFT_LINE_NOT_ACTIVE` | 409 |
| 3 | PIN matches an active operator | `OPERATOR_PIN_INVALID` | 401 |
| 4 | Operator has `rollWorkerEnabled = true` | `ROLL_WORKER_NOT_ALLOWED` | 403 |

**Replace-existing pattern:** if a different operator already has an ACTIVE roll-worker session on the same shift-line, the existing session transitions to `REPLACED` with reason `REPLACED_BY_NEW_AUTH` before the new session is persisted.

**Response (201/200):**
```json
{
  "success": true,
  "data": {
    "sessionId": 999,
    "sessionToken": "raw-uuid-token-shown-once",
    "rollWorkerOperatorId": 42,
    "rollWorkerName": "Ahmad",
    "thermoformingShiftId": 700,
    "thermoformingShiftLineId": 800,
    "thermoformingLineId": 200,
    "palletizingLineId": 10,
    "startedAt": "2026-05-07T13:00:00.000+03:00",
    "startedAtDisplay": "2026-05-07، 1:00 مساءً"
  }
}
```

`sessionToken` is the **only** time the raw token is returned — only its SHA-256 hash is stored server-side. The Flutter app must store the token locally (encrypted shared-prefs) and send it on every subsequent call.

### 4.3 Get current session

```
GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-session/current
Headers: X-Device-Key
```

> Note: the *current* endpoint does NOT require `X-Session-Token` — it's how the device discovers whether it has an active session at all. (The token-bound `requireActiveSession` gate is enforced on the roll-operation endpoints only, since they're the ones that mutate state on the worker's behalf.)

**Response when active session exists (200):**
```json
{
  "success": true,
  "data": {
    "sessionId": 999,
    "rollWorkerOperatorId": 42,
    "rollWorkerName": "Ahmad",
    "thermoformingShiftId": 700,
    "thermoformingShiftLineId": 800,
    "thermoformingLineId": 200,
    "palletizingLineId": 10,
    "status": "ACTIVE",
    "startedAt": "2026-05-07T13:00:00.000+03:00",
    "startedAtDisplay": "2026-05-07، 1:00 مساءً",
    "lastUsedAt": "2026-05-07T13:42:18.512+03:00",
    "lastUsedAtDisplay": "2026-05-07، 1:42 مساءً"
  }
}
```

No `sessionToken` field — the token is shown only at auth time.

**Response when no active session (404):**
```json
{ "success": false, "error": { "code": "ROLL_WORKER_SESSION_REQUIRED", "message": "..." } }
```

App behaviour on 404: navigate back to the PIN screen.

### 4.4 Logout

```
POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-logout
Headers: X-Device-Key
Body: { "sessionToken": "raw-uuid-token" }
```

Idempotent: logging out an already-ended session is a no-op (200, no error). Wrong shift-line for the token → 403 `ROLL_WORKER_SESSION_REQUIRED`. Unknown token → 404 `ROLL_WORKER_SESSION_REQUIRED`.

After logout: clear the locally-stored token and navigate to the PIN screen.

### 4.5 Cascading end (no client action required)

When the Thermoforming Operator ends the shift-line via the Thermoforming App, the backend automatically transitions every ACTIVE `RollWorkerSession` on that shift-line to `ENDED` with reason `SHIFT_LINE_ENDED`. The next call from the device will return 401/404 on the roll-operation endpoints; the app should treat any `ROLL_WORKER_SESSION_REQUIRED` response as "session lost — return to PIN screen".

---

## 5. Active Shift-Line Requirement

Roll-worker authentication **rejects** if there is no `ACTIVE` `ThermoformingShiftLine` for the target id. The Thermoforming Operator must have started a shift and added the line before the Roll Worker App is usable.

The session is also bound to the shift-line: every roll-operation endpoint (§6) verifies the token belongs to **this** shift-line via `RollWorkerSessionService.requireActiveSession(shiftLineId, token)`. Mismatch → 403 `ROLL_WORKER_SESSION_REQUIRED`. The looser `requireAnyActiveSession(token)` variant is used only for the read-only label-reprint endpoint, which is keyed by `generatedRollId` (not shift-line).

The operator must have `rollWorkerEnabled = true` on the `Operator` entity. Default is `false`; admins opt operators in via the user management page.

---

## 6. Roll Operations

All endpoints below require:
- `X-Device-Key` header
- `X-Session-Token` header (must resolve to ACTIVE session bound to `{shiftLineId}` for shift-line-scoped endpoints; any ACTIVE session for `/rolls/{generatedRollId}/reprint-label`)

Every mutation through this app stamps three V67 attribution columns on the affected `roll_consumption_items` and/or `roll_consumption_events` rows:
- `roll_worker_operator_id` — the authenticated roll worker
- `roll_worker_session_id` — the session that performed the action
- `roll_worker_name_snapshot` — the operator's name at action time

### 6.1 Mount a roll (scan / manual entry)

```
POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/scan-roll
Headers: X-Device-Key, X-Session-Token
Body: { "generatedRollId": "777000000001" }
       // OR
Body: { "scannedValue": "777000000001" }
```

Both `generatedRollId` and `scannedValue` are accepted — the backend prefers `generatedRollId` if both are present.

**Returns 201 Created** on success.

**Validation rules (in order):**

| # | Check | Error code |
|---|---|---|
| 1 | Token resolves to ACTIVE session bound to this shift-line | `ROLL_WORKER_SESSION_REQUIRED` (400/401/403/404) |
| 2 | Shift-line ACTIVE | `THERMOFORMING_SHIFT_LINE_NOT_FOUND` / `THERMOFORMING_SHIFT_LINE_NOT_ACTIVE` |
| 3 | Linked palletizing line has a `currentProductType` | `NO_CURRENT_PRODUCT_ON_LINE` |
| 4 | Roll exists by 12-digit `generatedRollId` | `ROLL_NOT_FOUND` |
| 5 | Roll's `RollType` is allowed for current product (strict, no override) | `ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT` |
| 6 | Roll is not BLOCKED | `ROLL_BLOCKED` |
| 7 | Roll is not already CONSUMED / PARTIALLY_RETURNED / SENT_TO_GRINDING | `ROLL_ALREADY_CONSUMED` |
| 8 | Roll is not already mounted on another shift-line | `ROLL_ACTIVE_ON_ANOTHER_LINE` |

**Response (201):**
```json
{
  "success": true,
  "data": {
    "rollId": 999,
    "generatedRollId": "777000000001",
    "rollTypeId": 70,
    "rollTypeRollCode": "TT-1S B250 White",
    "rollTypeDisplayName": "TT-1S B250",
    "colorName": "White",
    "productTypeId": 5,
    "productTypeName": "أحمر 20 كغ",
    "consumptionItemId": 5000,
    "activeSegmentId": 6000,
    "state": "IN_CONSUMPTION",
    "lastKnownWeightKg": 250.000
  }
}
```

The frontend should persist `consumptionItemId` and `activeSegmentId` on the active-line card. They're useful for displaying "current segment X of N" or for analytics, but **all** mutating endpoints take `shiftLineId` (not item/segment ids), so the frontend never needs to send them back.

### 6.2 Previous-roll resolution (close the mounted roll)

Three exclusive flows. All three return the same response shape; the frontend dispatches based on which button was tapped.

#### 6.2.1 Full consume (no remainder)

```
POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/previous-roll/full-consume
Headers: X-Device-Key, X-Session-Token
No body
```

UX: simple confirmation ("Roll fully consumed?"). No weight input.

#### 6.2.2 Return remaining

```
POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/previous-roll/return
Headers: X-Device-Key, X-Session-Token
Body: { "remainingWeightKg": 75.5 }
```

UX: number input + decimal keypad; client-side validation: `> 0` and `≤ activeSegmentStartWeight` (the active card's last-known weight).

#### 6.2.3 Send remaining to grinding

```
POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/previous-roll/grinding
Headers: X-Device-Key, X-Session-Token
Body: { "remainingWeightKg": 40.0 }
```

UX: same input pattern with a different button label and a confirmation dialog ("سيتم إرسال هذه البقايا إلى خط الجرش").

#### 6.2.4 Validation (server-side)

- Token resolves and binds to this shift-line → `ROLL_WORKER_SESSION_REQUIRED`
- An ACTIVE roll item must exist on the shift-line → `NO_ACTIVE_ROLL_ON_LINE`
- The active item must have an open segment → `NO_OPEN_SEGMENT_ON_ITEM` (HTTP 500; data-integrity → show generic "please contact support")
- `remainingWeightKg` non-null and ≥ 0 → `INVALID_REMAINING_ROLL_WEIGHT` (400)
- `remainingWeightKg` does not exceed open segment's start weight → `INVALID_REMAINING_ROLL_WEIGHT`

#### 6.2.5 Response payload (all three flows)

```json
{
  "success": true,
  "data": {
    "rollId": 999,
    "generatedRollId": "777000000001",
    "finalState": "PARTIALLY_RETURNED",
    "consumedWeightKg": 175.500,
    "remainingWeightKg": 75.500,
    "remainderAction": "RETURN",
    "eventType": "CLOSED_PARTIAL_RETURN",
    "reprintAvailable": true
  }
}
```

`finalState` ∈ `{CONSUMED, PARTIALLY_RETURNED, SENT_TO_GRINDING}`. `remainderAction` ∈ `{NONE, RETURN, GRINDING}`. **`reprintAvailable: true`** means the operator should immediately see a "إعادة طباعة الملصق" button — they're going to attach a sticker to the partial roll right now.

### 6.3 Roll label reprint

```
GET /api/v1/thermoforming-roll-app/rolls/{generatedRollId}/reprint-label
Headers: X-Device-Key, X-Session-Token
```

**Strict eligibility:** only served when the roll's current state is `PARTIALLY_RETURNED` or `SENT_TO_GRINDING`. Other states are rejected with `ROLL_LABEL_REPRINT_NOT_AVAILABLE` (HTTP 409). The frontend should **only show the reprint button** when the close-flow response said `reprintAvailable: true` — that's the safe gate.

**Response:**
```json
{
  "success": true,
  "data": {
    "generatedRollId": "777000000001",
    "prefixSnapshot": "777",
    "serialNumber": 1,
    "rollTypeId": 70,
    "rollTypeRollCode": "TT-1S B250 White",
    "rollTypeDisplayName": "TT-1S B250",
    "colorName": "White",
    "standardLengthM": 100.000,
    "standardWeightKg": 250.000,
    "actualLengthM": 99.500,
    "actualWeightKg": 248.000,
    "actualThicknessMm": 0.250,
    "productionKind": "NORMAL",
    "consumptionState": "PARTIALLY_RETURNED",
    "lastKnownWeightKg": 75.500
  }
}
```

**Critical UX rules:**
- **Same `generatedRollId`** — never show or generate a new roll number. The QR encodes this exact value.
- **No new serial.** This is a reprint, not a new roll.
- The `consumptionState` field drives a small badge on the sticker: "إعادة طباعة بعد الإرجاع" (PARTIALLY_RETURNED) or "إعادة طباعة قبل الجرش" (SENT_TO_GRINDING).
- `lastKnownWeightKg` is the declared remainder — show prominently.

### 6.4 Product switch (with current-roll-weight entry)

**Product changes happen ONLY on the device the roll worker is operating** (i.e. via this app, NOT the Thermoforming App, NOT the Palletizing App).

```
POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/product-switch
Headers: X-Device-Key, X-Session-Token
Body: {
  "newProductTypeId": 6,
  "currentRollWeightKg": 175.0
}
```

Both fields are required. The frontend's product-switch screen must collect a fresh weight reading (scale tare → weigh → enter) before sending.

**What the backend does:**

1. Resolve the roll-worker session and bind it to the shift-line (gate).
2. Lock the consumption-state row (pessimistic).
3. Validate `currentRollWeightKg` is non-null, ≥ 0, ≤ open segment's start weight → otherwise `CURRENT_ROLL_WEIGHT_REQUIRED` / `INVALID_CURRENT_ROLL_WEIGHT`.
4. Look up new product, validate it's active.
5. **Strict compatibility check:** still-mounted roll's `RollType` must be allowed for the new product → otherwise `ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT`. **No override.**
6. Close the open segment with reason `PRODUCT_SWITCHED` and compute `consumedWeight = openSegment.startWeight − currentRollWeightKg`.
7. Update the linked palletizing line's `currentProductType`.
8. Open a new segment for the new product on the same active item (roll stays mounted).
9. Update state's `lastKnownWeightKg`.
10. Append `PRODUCT_SWITCHED` event with V67 attribution stamped from the resolved roll-worker session.
11. Publish a `LineStateChangedEvent` so palletizing-side observers see the new product.

**Response:**
```json
{
  "success": true,
  "data": {
    "shiftLineId": 800,
    "closedSegmentId": 6000,
    "closedSegmentConsumedWeightKg": 75.000,
    "newSegmentId": 6001,
    "newProductTypeId": 6,
    "newProductTypeName": "أزرق 10 كغ",
    "currentRollWeightKg": 175.000
  }
}
```

After a successful switch the active-line card refreshes: the new product name + the new segment id, but the same mounted roll. The roll worker continues without re-mounting.

---

## 7. Session Token Handling

- Token is a UUID v4 string returned in `data.sessionToken` from the auth endpoint **once**.
- Server stores only `SHA-256(token)` (CHAR(64) hex).
- App stores token in encrypted local storage (Flutter `flutter_secure_storage` is the established convention).
- Add `X-Session-Token: <token>` to every roll-operation request.
- On any 401/403/404 with `ROLL_WORKER_SESSION_REQUIRED`: clear local token, navigate to PIN screen, show "انتهت الجلسة، يُرجى تسجيل الدخول مجددًا".
- On every successful roll-operation request, the backend updates `lastUsedAt` server-side (no inactivity timeout enforced today, but the column is there for a future inactivity policy).

---

## 8. Error Codes

| Code | HTTP | Arabic display message | Where |
|---|---|---|---|
| `THERMOFORMING_SHIFT_LINE_NOT_FOUND` | 404 | لم يتم العثور على خط التشكيل المُسند للوردية. | auth, all roll ops |
| `THERMOFORMING_SHIFT_LINE_NOT_ACTIVE` | 409 | خط التشكيل المُسند للوردية ليس نشطًا الآن. | auth, all roll ops |
| `OPERATOR_PIN_INVALID` | 401 | رقم تعريف غير صحيح. | auth |
| `OPERATOR_PIN_LOCKED` | 423 | تم قفل رقم التعريف بسبب محاولات خاطئة، حاول لاحقًا. | auth |
| `ROLL_WORKER_NOT_ALLOWED` | 403 | هذا المشغّل غير مفعّل لتطبيق عامل الرولات. | auth |
| `ROLL_WORKER_SESSION_REQUIRED` | 400 / 401 / 403 / 404 | انتهت الجلسة، يُرجى تسجيل الدخول مجددًا. | every roll-op endpoint |
| `NO_CURRENT_PRODUCT_ON_LINE` | 409 | لا يوجد منتج حالي على الخط، يجب اختياره من تطبيق التشكيل أولًا. | scan-roll |
| `ROLL_NOT_FOUND` | 404 | لم يتم العثور على الرول المطلوب. | scan-roll, reprint |
| `ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT` | 409 | هذا النوع من الرول غير مسموح للمنتج الحالي. | scan-roll, product-switch |
| `ROLL_BLOCKED` | 409 | الرول محجوب إداريًا. | scan-roll |
| `ROLL_ALREADY_CONSUMED` | 409 | الرول قد تم استهلاكه أو إغلاقه مسبقًا. | scan-roll |
| `ROLL_ACTIVE_ON_ANOTHER_LINE` | 409 | الرول مُركّب حاليًا على خط آخر. | scan-roll |
| `NO_ACTIVE_ROLL_ON_LINE` | 409 | لا يوجد رول مُركّب على هذا الخط. | previous-roll, product-switch |
| `NO_OPEN_SEGMENT_ON_ITEM` | 500 | حدث خطأ تقني، يُرجى التواصل مع الدعم. | previous-roll, product-switch |
| `INVALID_REMAINING_ROLL_WEIGHT` | 400 | الوزن المتبقي غير صالح. | previous-roll/return, /grinding |
| `CURRENT_ROLL_WEIGHT_REQUIRED` | 400 | يجب إدخال الوزن الحالي للرول قبل تبديل المنتج. | product-switch |
| `INVALID_CURRENT_ROLL_WEIGHT` | 400 | الوزن الحالي للرول غير صالح. | product-switch |
| `PRODUCT_TYPE_NOT_FOUND` | 404 | لم يتم العثور على المنتج المطلوب. | product-switch |
| `PRODUCT_TYPE_INACTIVE` | 400 | هذا المنتج غير نشط. | product-switch |
| `ROLL_LABEL_REPRINT_NOT_AVAILABLE` | 409 | إعادة طباعة الملصق غير متاحة لهذا الرول حاليًا. | reprint-label |

For any non-listed error code: show a generic "حدث خطأ، حاول مرة أخرى" with the raw code in a debug overlay.

---

## 9. State Management Recommendation

Use Riverpod (matches the Thermoforming App). Suggested providers:

| Provider | Type | Lifetime |
|---|---|---|
| `deviceKeyProvider` | string read from build config | app-lifetime |
| `shiftLineIdProvider` | nullable Long; populated from a "select shift-line" screen on first launch | persistent |
| `rollWorkerSessionProvider` | `AsyncValue<RollWorkerSessionResponse?>` driven by GET current; `null` = need PIN | reactive |
| `sessionTokenProvider` | secure-storage backed string | persistent until logout / 401 |
| `activeMountProvider` | `AsyncValue<ScanResponse?>` populated after scan-roll, cleared after close | session-lifetime |

Hard rules:

1. **Backend is the source of truth.** Never derive "session active" from the existence of a stored token alone — always re-verify via `GET .../current` on app foreground.
2. **No fake states.** Don't paint the success state of a roll close before the response arrives — wait for `reprintAvailable`.
3. **Clear local token on any `ROLL_WORKER_SESSION_REQUIRED`.** Navigate to PIN screen.
4. **Do not cache product/RollType compatibility client-side.** The backend evaluates strict compatibility on every scan and product-switch — frontend caching would create false-success paths.
5. **Do not re-implement validation business rules.** Render error codes from the table in §8; never block at the client what the backend would also block.

---

## 10. Acceptance Criteria

The Roll Worker App build is "done" when:

- [ ] On first launch (no token), the worker can authenticate via PIN against an active shift-line and receive a 201 with `sessionToken`.
- [ ] On subsequent launches (token present), `GET .../roll-worker-session/current` returns 200 → home screen renders mount card; 404 → PIN screen.
- [ ] Logging out clears the token, returns 200, and bounces to the PIN screen.
- [ ] When the operator ends the shift-line in the Thermoforming App, the next roll-operation call returns `ROLL_WORKER_SESSION_REQUIRED` and the app gracefully bounces to PIN screen.
- [ ] Scan a valid roll → 201 → mount card shows roll details + product + last-known weight.
- [ ] Scan an incompatible roll → 409 with `ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT` → Arabic error toast.
- [ ] Full-consume returns `reprintAvailable: false` → no reprint button.
- [ ] Return-remaining and grinding both return `reprintAvailable: true` → reprint button visible → reprint endpoint returns 200 with the partial sticker payload.
- [ ] Product switch with a valid weight + compatible new product succeeds; the line card refreshes with the new product name; the same `consumptionItemId` is preserved.
- [ ] Every authentication and every roll-op call sends both `X-Device-Key` and (where required) `X-Session-Token`.
- [ ] No hard-coded English strings in the auth/error UI; all messages match the §8 table.
- [ ] No client-side product/RollType compatibility table; trust the backend's strict response.

---

## Appendix — Things this app deliberately does NOT do

- **Does not start shifts.** Operator app only.
- **Does not open lines.** Operator app only (via shift-line creation, which programmatically opens the linked palletizing line authorization).
- **Does not create or stack pallets.** Palletizing App only.
- **Does not manage palletizer-employee sessions.** Palletizing App only.
- **Does not show production summary.** That's the Thermoforming Operator App's "My Production" screen.
- **Does not modify the current product on the line directly.** The product changes happen via the product-switch endpoint described in §6.4 — never via a "set product" action.

## Appendix — Backend version reference

Tracked in [`docs/backend/THERMOFORMING_BACKEND_MASTER_PLAN.md`](../backend/THERMOFORMING_BACKEND_MASTER_PLAN.md) under "Roll Worker App Amendment" (Tasks 35–44). Final implementation report: [`docs/backend/THERMOFORMING_BACKEND_IMPLEMENTATION_REPORT.md`](../backend/THERMOFORMING_BACKEND_IMPLEMENTATION_REPORT.md).
