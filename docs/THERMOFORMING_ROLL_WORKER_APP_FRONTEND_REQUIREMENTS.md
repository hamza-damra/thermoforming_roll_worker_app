# Thermoforming Roll Worker App Frontend Requirements

> Backend reference: feature branch `feature/thermoforming-backend-module` at HEAD `ff0115f` (V67 + V68 applied).
> Authoritative backend handoffs this doc consolidates and supersedes for the Roll Worker App scope:
> - [docs/backend/THERMOFORMING_BACKEND_MASTER_PLAN.md](../backend/THERMOFORMING_BACKEND_MASTER_PLAN.md)
> - [docs/backend/THERMOFORMING_BACKEND_IMPLEMENTATION_REPORT.md](../backend/THERMOFORMING_BACKEND_IMPLEMENTATION_REPORT.md)
> - [docs/frontend-handoff/ROLL_WORKER_APP_BACKEND_HANDOFF.md](ROLL_WORKER_APP_BACKEND_HANDOFF.md) (older — full backend handoff this doc draws from)
> - [docs/frontend-handoff/THERMOFORMING_OPERATOR_APP_FRONTEND_REQUIREMENTS.md](THERMOFORMING_OPERATOR_APP_FRONTEND_REQUIREMENTS.md) (sibling app)
> - [docs/frontend-handoff/PALLETIZING_APP_AUTH_AND_PRODUCT_SWITCH_HANDOFF.md](PALLETIZING_APP_AUTH_AND_PRODUCT_SWITCH_HANDOFF.md) (forbidden surface — see §4)
> - [docs/frontend-handoff/PALLETIZING_APP_FRONTEND_UPDATE_REQUIREMENTS.md](PALLETIZING_APP_FRONTEND_UPDATE_REQUIREMENTS.md) (sibling app)

---

## 1. Purpose of this app

This app is the **Thermoforming Roll Worker App** / **تطبيق عامل الرولات**. It is used by the roll worker (عامل الرولات) — the worker who **physically handles plastic-film rolls** at the thermoforming machine.

What this app does, end-to-end:

- **Authenticates** the roll worker with their employee PIN against an active `ThermoformingShiftLine`.
- **Scans / mounts** a roll on the line using the 12-digit `generatedRollId` (QR or manual).
- **Resolves the previous roll** in one of three ways: full-consume / return remaining / send remaining to grinding.
- **Reprints** a roll label after a partial close (return or grinding only).
- **Product-switches** the line by entering the current-roll weight; the still-mounted roll's segment is closed and a new segment opens for the new product.

What this app does **not** do:

- It does NOT start or end Thermoforming shifts (Operator App, §4).
- It does NOT open or close shift-lines (Operator App, §4).
- It does NOT open Palletizing line authorizations (the Operator App's add-shift-line action does that as a backend side-effect).
- It does NOT create, stack, or convert pallets / FALETs (Palletizing App, §4).
- It does NOT manage palletizer-employee sessions (Palletizing App, §4).
- It does NOT show shift-level production summaries (Operator App).

This app is one of three Flutter apps that together cover the Thermoforming workflow:
- **Thermoforming Operator App** — orchestrates the shift
- **Thermoforming Roll Worker App** — this document
- **Palletizing App** — palletizer employee + pallet creation

The Roll Worker App is meaningless without an active `ThermoformingShiftLine`. If the operator hasn't opened a line, this app shows a waiting state and does nothing else (§7, §8).

---

## 2. What must NOT change visually

The Roll Worker App should feel like a sibling of the existing Taleeb factory apps (Operator App, Palletizing App). Production-floor operators expect the same visual rhythm.

- **Arabic, RTL** layout throughout.
- Production-floor-friendly: large clear cards, large tap targets, strong line colors, simple modal dialogs.
- Loading and error states are clear and inline; no spinner-on-spinner, no surprise full-screen blockers.
- Same spacing rhythm and general visual language as the Operator App and Palletizing App. Reuse the existing Flutter design tokens — typography, color palette, button styles, list patterns, error toasts, dialogs.
- Waiting / empty states should match the Palletizing App's "no active shift" experience: a centered RTL message + a single primary action ("جرّب مجددًا" / refresh).
- **Do not** introduce a new visual identity for this app.
- **Do not** over-design — fast and easy under factory pressure beats elegant.

---

## 3. Required state management and architecture

This is mandatory, not a recommendation:

> **Riverpod + AsyncNotifier / Notifier + Freezed states + Clean Architecture.**

Do **NOT** use:

- One giant `ChangeNotifier` for the whole app.
- One global `Provider` covering every feature.
- `GetX`.
- `setState` for any business state.

`setState` is allowed only for tiny, widget-only UI details (e.g. a local toggle that never crosses widget boundaries).

### Recommended Flutter folder structure

```
lib/
  core/
    api/           # API client, interceptors, dio/http config
    config/        # build-time config (API_BASE_URL, DEVICE_KEY)
    errors/        # ErrorCode mapping, BusinessException, network failure types
    storage/       # secure storage wrapper (token storage)
    theme/         # design tokens, RTL helpers
    widgets/       # shared production-floor widgets (cards, buttons, dialogs)
  features/
    roll_worker_auth/
      data/        # repository impl, dto mappers
      domain/      # entities, repository interface, use-cases
      presentation/  # screens, controllers (AsyncNotifier), Freezed states
    shift_line/
      data/
      domain/
      presentation/
    roll_scan/
      data/
      domain/
      presentation/
    previous_roll/
      data/
      domain/
      presentation/
    product_switch/
      data/
      domain/
      presentation/
    label_reprint/
      data/
      domain/
      presentation/
```

### Recommended controllers / notifiers

Each is its own `AsyncNotifier` (or `Notifier`) with a Freezed state:

| Controller | Owns |
|---|---|
| `RollWorkerAuthController` | PIN screen state + login + logout |
| `CurrentShiftLineController` | which shift-line is selected + its session status (driven by `GET /roll-worker-session/current`) |
| `RollScanController` | scan-roll flow + active mount card |
| `PreviousRollResolutionController` | full-consume / return / grinding |
| `ProductSwitchController` | product-switch flow |
| `RollLabelReprintController` | reprint flow |

### Hard rules

- **Backend is the source of truth.** Never derive "session active" from the existence of a stored token alone — always re-verify via `GET .../roll-worker-session/current` on app foreground.
- Do not fake the active shift-line locally. Do not fake the mounted roll locally. Do not paint the success state of a roll close before the response arrives.
- After every mutation, refresh from the backend if a refresh endpoint exists. Where no refresh endpoint exists today (see §24 gaps), the response payload itself is the new source of truth — store it and show it without retrying a phantom refresh.
- Prevent duplicate submits on every mutation (debounce or button-disabled until response).
- Handle app resume per §18.
- Store the roll-worker session token securely (§15).
- **Never** store or log the raw PIN. **Never** log the session token, not even in debug builds.

---

## 4. Role separation in the UI

Three operational roles, three apps. The Roll Worker App must surface ONLY the roll worker's responsibilities and must NOT expose actions belonging to the other two roles.

### المشغّل (Thermoforming operator) — Operator App, NOT this app
Owns:
- shift start / end
- line assignment / removal
- line supervision
- shift / line notes
- production summary

### عامل الرولات (Roll worker) — this app
Owns:
- roll-worker login per shift-line
- roll scan / mount
- previous-roll resolution (close, return, send to grinding)
- roll label reprint
- product switch with current-roll-weight entry

### المُشَتِّح / موظف الطبليات (Palletizer employee) — Palletizing App, NOT this app
Owns:
- palletizer-employee PIN login per palletizing line
- pallet creation / stacking
- FALET conversion / handover

Suggested Arabic chrome for this app's screens (use these consistently — most are already in `messages_ar.properties`):

| Concept | Arabic |
|---|---|
| Roll worker | عامل الرولات |
| Thermoforming line | خط التشكيل |
| Linked palletizing line | خط الطبليات المرتبط |
| Current product | المنتج الحالي |
| Current roll | الرول الحالي |
| Mount roll | تركيب رول |
| Close previous roll | إغلاق الرول السابق |
| Return remaining | إرجاع المتبقي |
| Send remaining to grinding | إرسال المتبقي للجرش |
| Product switch | تغيير المنتج |
| Reprint roll label | إعادة طباعة ليبل الرول |

Forbidden actions (mirrored from `THERMOFORMING_OPERATOR_APP_FRONTEND_REQUIREMENTS.md` §10–§11):

| Forbidden action | Lives in |
|---|---|
| `POST /api/v1/thermoforming-app/shifts/start` | Operator App |
| `GET  /api/v1/thermoforming-app/shifts/current` | Operator App |
| `POST /api/v1/thermoforming-app/shifts/{shiftId}/end` | Operator App |
| `POST /api/v1/thermoforming-app/shifts/{shiftId}/lines` | Operator App |
| `POST /api/v1/thermoforming-app/shift-lines/{shiftLineId}/end` | Operator App |
| `POST /api/v1/thermoforming-app/shifts/{shiftId}/notes` | Operator App |
| `POST /api/v1/thermoforming-app/auth/operator-pin` | Operator App |
| `POST /api/v1/palletizing-line/lines/{lineId}/palletizer-auth` | Palletizing App |
| `GET  /api/v1/palletizing-line/lines/{lineId}/palletizer-session/current` | Palletizing App |
| `POST /api/v1/palletizing-line/lines/{lineId}/palletizer-logout` | Palletizing App |
| `POST /api/v1/palletizing-line/lines/{lineId}/pallets` | Palletizing App |
| FALET conversion / pallet reprint endpoints | Palletizing App |

---

## 5. App configuration

The Roll Worker App is configured at **build time**, not at runtime. There is no operator-facing settings screen for the device key.

### Build-time variables

Pass via `--dart-define` at build / run time:

| Variable | Meaning | Example |
|---|---|---|
| `API_BASE_URL` | Backend root, e.g. `https://api.taleeb.ps` | `--dart-define=API_BASE_URL=https://api.taleeb.ps` |
| `DEVICE_KEY` | Shared device API key (transport secret) | `--dart-define=DEVICE_KEY=<provided-by-ops>` |

Read them from `String.fromEnvironment(...)` in a `core/config/AppConfig` class. Resolve once at app start; treat as immutable.

### Header policy

Every backend request from this app must include:

```
X-Device-Key: <DEVICE_KEY>
```

`DeviceApiKeyFilter` on the backend rejects (401) any request without it on the `/api/v1/thermoforming-roll-app/**` namespace.

### Storage / logging rules (non-negotiable)

- **Never** display `DEVICE_KEY` in any UI.
- **Never** log `DEVICE_KEY` (not in stdout, debug overlays, crash reports, or analytics).
- **Never** persist `DEVICE_KEY` to user-visible disk locations (it's already baked into the binary; don't copy it elsewhere).
- If `API_BASE_URL` or `DEVICE_KEY` is missing at runtime: show a fatal-state screen with:
  > إعدادات التطبيق غير مكتملة، يرجى التواصل مع المسؤول

  And refuse all backend calls.

---

## 6. Roll Worker authentication flow

### Endpoints

| Method | Path | Headers | Body |
|---|---|---|---|
| `POST` | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-auth` | `X-Device-Key` | `{pin}` |
| `GET` | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-session/current` | `X-Device-Key` | — |
| `POST` | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-logout` | `X-Device-Key` | `{sessionToken}` |

### Authenticate

```http
POST /api/v1/thermoforming-roll-app/shift-lines/800/roll-worker-auth
X-Device-Key: <device-key>
Content-Type: application/json

{ "pin": "1234" }
```

Backend validation order:

| # | Check | Error code | HTTP |
|---|---|---|---|
| 1 | Shift-line exists | `THERMOFORMING_SHIFT_LINE_NOT_FOUND` | 404 |
| 2 | Shift-line is `ACTIVE` | `THERMOFORMING_SHIFT_LINE_NOT_ACTIVE` | 409 |
| 3 | PIN matches an active operator | `OPERATOR_PIN_INVALID` | 401 |
| 4 | Operator has `rollWorkerEnabled = true` | `ROLL_WORKER_NOT_ALLOWED` | 403 |

**Replace-existing pattern**: if a different roll worker already has an `ACTIVE` session on the same shift-line, the existing session transitions to `REPLACED` with reason `REPLACED_BY_NEW_AUTH` before the new session is persisted. The previous device's token is invalidated.

Response (201 Created):

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
    "startedAt": "2026-05-08T13:00:00.000+03:00",
    "startedAtDisplay": "2026-05-08، 1:00 مساءً"
  }
}
```

The `sessionToken` is the **only time** the raw token is returned. Backend stores only its SHA-256 hash. The Flutter app must store the token securely (§15) and present it as `X-Session-Token` on every roll-operation call.

### Get current session

```http
GET /api/v1/thermoforming-roll-app/shift-lines/800/roll-worker-session/current
X-Device-Key: <device-key>
```

> **Note: this endpoint does NOT require `X-Session-Token`.** It's how the device discovers whether an active session exists for the shift-line at all. The token-bound `requireActiveSession` gate is enforced only on the roll-operation endpoints (which mutate state on the worker's behalf).

Response when an active session exists (200):

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
    "startedAt": "2026-05-08T13:00:00.000+03:00",
    "startedAtDisplay": "2026-05-08، 1:00 مساءً",
    "lastUsedAt": "2026-05-08T13:42:18.512+03:00",
    "lastUsedAtDisplay": "2026-05-08، 1:42 مساءً"
  }
}
```

No `sessionToken` field — the token is shown only at auth time.

When no active session exists, backend returns 404 with `ROLL_WORKER_SESSION_REQUIRED`. The app routes back to the PIN screen.

### Logout

```http
POST /api/v1/thermoforming-roll-app/shift-lines/800/roll-worker-logout
X-Device-Key: <device-key>
Content-Type: application/json

{ "sessionToken": "raw-uuid-token" }
```

Response: `{ "success": true, "data": null }`. Idempotent — logging out an already-ended session is a 200 no-op.

> The token is sent in the **body**, not as a header on this endpoint (mirroring the Palletizing app convention). After logout, clear the locally-stored token and route to the PIN screen.

### Per-shift-line, not global

Roll-worker sessions are scoped to a specific `shiftLineId`. The same operator on a different shift-line gets a different session and a different token. Token storage MUST be keyed by shift-line id:

> **Suggested storage key**: `roll_worker_session_token_{shiftLineId}`

Do not use a single global key for "the" roll-worker token — it would collide if the worker ever switched lines.

### Cascade-on-end

When the Operator ends the shift-line (via `POST /api/v1/thermoforming-app/shift-lines/{shiftLineId}/end`), the backend automatically transitions every ACTIVE `RollWorkerSession` on that shift-line to `ENDED` with reason `SHIFT_LINE_ENDED`. The next roll-operation call from the device will return `ROLL_WORKER_SESSION_REQUIRED`. The app must treat this gracefully:

- Clear the stored token for that shift-line.
- Snackbar: `تم إنهاء خط التشكيل، يُرجى تسجيل الدخول مجددًا عند فتح خط جديد.`
- Route back to the line picker / waiting screen (§7).

### UI

- Screen title: `تسجيل دخول عامل الرولات`
- PIN input (numeric, 4 digits)
- Button: `دخول`
- Inline error area below the PIN input — render the Arabic message of the returned error code.
- Do NOT show operator-app or palletizer auth here. This screen is single-purpose.

---

## 7. Shift-line selection / line picker

The app must know which `shiftLineId` the worker is working on **before** the PIN screen makes sense.

### BACKEND GAP — no list-active-shift-lines endpoint

> **Gap status**: confirmed by code inspection. There is **no** endpoint under `/api/v1/thermoforming-roll-app/**` (or anywhere else accessible to the Roll Worker App's `ROLE_DEVICE` namespace) that returns the list of currently-active Thermoforming shift-lines for a picker. The Operator App has shift-line listing endpoints, but those are gated by the operator's shift session token and are not appropriate for this app.
>
> **Why it matters**: production-floor roll workers cannot type 19-digit shift-line IDs. Manual ID entry is **not acceptable** as final production UX.

### Recommended backend follow-up

Add a new read-only endpoint:

```
GET /api/v1/thermoforming-roll-app/shift-lines/active-options
Headers: X-Device-Key
```

Suggested response shape:

```json
{
  "success": true,
  "data": [
    {
      "shiftLineId": 800,
      "thermoformingShiftId": 700,
      "thermoformingLineId": 200,
      "thermoformingLineCode": "TF-1",
      "thermoformingLineName": "Thermo Line 1",
      "palletizingLineId": 10,
      "palletizingLineCode": "PL1",
      "palletizingLineName": "Palletizing Line 1",
      "currentProductTypeId": 5,
      "currentProductTypeName": "أحمر 20 كغ",
      "currentRollGeneratedRollId": "777000000001",
      "supervisingOperatorName": "محمد",
      "status": "ACTIVE",
      "hasActiveRollWorkerSession": false
    }
  ]
}
```

The Roll Worker App's first screen would call this and show a card per active shift-line (factory floor — usually 1–3 lines). The worker taps the card for the line they're working on; the app stores `shiftLineId` and proceeds to the PIN screen.

See §24 for the formal backend follow-up entry.

### Frontend behavior until the gap is filled

Until the picker endpoint exists, the app needs a safe-but-temporary path. Pick **one** of these and ship it explicitly behind a build flag, not as production UX:

1. **Manual entry — debug/QA only.** A hidden long-press on the title bar (or a `--dart-define=ALLOW_MANUAL_SHIFT_LINE=true` flag) reveals a numeric input. The PIN screen then uses that id. Never ship this in a production-signed APK.
2. **Static config per device.** If a single device is permanently assigned to a single Thermoforming line, hard-code `STATIC_SHIFT_LINE_ID` via `--dart-define`. Acceptable as an interim measure for a known-stable line. Document this in operations runbook.

Neither is the correct production answer — both are workarounds while the backend ships the picker endpoint.

### UI states

The first-launch flow has these states; each maps to a distinct screen / banner:

1. **No active shift-line resolvable** — show:
   > لا يوجد خط تشكيل نشط حاليًا، انتظر بدء المناوبة من المشغّل
   With a single `إعادة المحاولة` button that re-fetches.
2. **Waiting for operator** — same UX as #1; refreshed automatically every 10s while the screen is foregrounded (§19).
3. **Line resolved, roll worker not authenticated** — go to PIN screen (§6).
4. **Line resolved, roll worker authenticated** — go to home (§8).

---

## 8. Main Roll Worker Home screen

After line resolution and roll-worker login, the home screen shows the active mount card:

| Field | Source |
|---|---|
| Roll worker name | `RollWorkerSessionResponse.rollWorkerName` |
| Thermoforming line | derived from session response (line name + code) |
| Linked Palletizing line | `RollWorkerSessionResponse.palletizingLineId` (name + code if available) |
| Current product on line | `ThermoformingRollScanResponse.productTypeName` (last scan) — or "no product" if none |
| Current roll | `ThermoformingRollScanResponse.generatedRollId` if mounted |
| Roll state | `ThermoformingRollScanResponse.state` (e.g. `IN_CONSUMPTION`) |
| Last known weight | `ThermoformingRollScanResponse.lastKnownWeightKg` |

### Possible states

The home screen drives off these states:

1. **Waiting for active shift-line** — same UX as §7 #1.
2. **Needs roll worker login** — route to PIN screen.
3. **No roll mounted** — show empty mount card, primary action: `تركيب رول جديد` (scan/manual entry).
4. **Roll mounted / IN_CONSUMPTION** — show full mount card with current roll details + actions: `إغلاق الرول السابق` (open dialog with 3 options), `تغيير المنتج`.
5. **Previous roll must be resolved first** — when the operator (via Operator App) ends the line in a way that leaves an ambiguous state. Force the close-flow before any new mount.
6. **Product switch flow active** — modal screen, see §11.
7. **Reprint available after partial close** — a small `إعادة طباعة الليبل` button next to the just-closed roll's row, visible only when `reprintAvailable: true` in the response.
8. **Error / blocked** — inline error on the affected card (e.g. session expired → snackbar + route to PIN).

### Layout discipline

- Use one large card for the active mount; don't split it into many rows.
- Primary actions are big buttons inside the card.
- Show the `lastKnownWeightKg` prominently — that's the operator's reference number for the close flow.
- Don't stack secondary metrics; the home screen is for **doing**, not **reading**.

---

## 9. Roll scan / mount flow

### Endpoint

```http
POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/scan-roll
X-Device-Key: <device-key>
X-Session-Token: <roll-worker session token>
Content-Type: application/json

{ "generatedRollId": "777000000001" }
```

Or alternatively:

```json
{ "scannedValue": "777000000001" }
```

Both fields are accepted; the backend prefers `generatedRollId` if both are present. The 12-digit format is `PPPSSSSSSSSS` — 3-digit product-type prefix + 9-digit serial.

### Backend validation (in order)

| # | Check | Error code |
|---|---|---|
| 1 | Token resolves to ACTIVE session bound to this shift-line | `ROLL_WORKER_SESSION_REQUIRED` (400 / 401 / 403 / 404) |
| 2 | Shift-line ACTIVE | `THERMOFORMING_SHIFT_LINE_NOT_FOUND` / `THERMOFORMING_SHIFT_LINE_NOT_ACTIVE` |
| 3 | Linked palletizing line has a `currentProductType` | `NO_CURRENT_PRODUCT_ON_LINE` (409) |
| 4 | Roll exists by 12-digit `generatedRollId` | `ROLL_NOT_FOUND` (404) |
| 5 | Roll's `RollType` is allowed for current product (strict, no override) | `ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT` (409) |
| 6 | Roll is not BLOCKED | `ROLL_BLOCKED` (409) |
| 7 | Roll is not already CONSUMED / PARTIALLY_RETURNED / SENT_TO_GRINDING | `ROLL_ALREADY_CONSUMED` (409) |
| 8 | Roll is not already mounted on another shift-line | `ROLL_ACTIVE_ON_ANOTHER_LINE` (409) |

On success the backend creates an `IN_CONSUMPTION` `RollConsumptionItem`, opens the initial segment, and stamps V67 attribution columns (roll-worker operator + session + name snapshot).

### Response (201 Created)

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

The frontend should persist `consumptionItemId` and `activeSegmentId` on the active-mount card. They're useful for analytics or "current segment" displays, but **all** mutating endpoints take `shiftLineId` (not item / segment ids), so the frontend never needs to send them back.

### UI

- Primary action: `مسح QR للرول` (camera scanner).
- Manual fallback: `إدخال رقم الرول يدويًا` — opens a 12-digit numeric input. Validate locally that it's exactly 12 digits before sending.
- Optional pre-mount summary: if you want to show a "you scanned X — confirm mount?" dialog, do it client-side only (the backend does not have a separate "preview" call). Keep it short — confirmations slow the floor down.
- On success: snackbar `تم تركيب الرول بنجاح` and refresh the mount card.

### Hard rules

- **Do not allow scanning if the roll-worker session is missing.** Verify `sessionTokenProvider.value != null` before invoking the scanner. If missing, route to PIN.
- **Do not bypass the camera if the worker is in PIN-needed state.**
- **Do not send any other roll fields** (rollTypeId, productTypeId, etc.) from the client — only `generatedRollId` (or `scannedValue`). Everything else is server-derived.

---

## 10. Previous-roll resolution flow

Three exclusive flows. All three return the same response shape; the frontend dispatches based on which button the worker tapped.

### Endpoints

| Method | Path | Body | Response shape |
|---|---|---|---|
| `POST` | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/previous-roll/full-consume` | — | `ThermoformingPreviousRollResolutionResponse` |
| `POST` | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/previous-roll/return` | `{remainingWeightKg}` | same |
| `POST` | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/previous-roll/grinding` | `{remainingWeightKg}` | same |

All three require `X-Device-Key` + `X-Session-Token`.

### Full-consume (no remainder)

```http
POST /api/v1/thermoforming-roll-app/shift-lines/800/previous-roll/full-consume
X-Device-Key: <device-key>
X-Session-Token: <roll-worker session token>
```

No body. UX: simple confirmation dialog ("هل تم استهلاك الرول بالكامل؟"); no weight input.

### Return remaining

```http
POST /api/v1/thermoforming-roll-app/shift-lines/800/previous-roll/return
X-Device-Key: <device-key>
X-Session-Token: <roll-worker session token>
Content-Type: application/json

{ "remainingWeightKg": 75.5 }
```

UX: numeric decimal-keypad input. Client-side validation: `>= 0` and `<= activeSegment startWeight` (the value the home card shows as `lastKnownWeightKg` for the open segment).

### Send remaining to grinding

```http
POST /api/v1/thermoforming-roll-app/shift-lines/800/previous-roll/grinding
X-Device-Key: <device-key>
X-Session-Token: <roll-worker session token>
Content-Type: application/json

{ "remainingWeightKg": 40.0 }
```

UX: same numeric input pattern with a different button label and confirmation dialog:

> سيتم إرسال هذه البقايا إلى خط الجرش، هل أنت متأكد؟

### Backend validation

- Token resolves and binds to the shift-line → otherwise `ROLL_WORKER_SESSION_REQUIRED`.
- An ACTIVE roll item must exist on the shift-line → otherwise `NO_ACTIVE_ROLL_ON_LINE` (409).
- The active item must have an open segment → otherwise `NO_OPEN_SEGMENT_ON_ITEM` (500; data-integrity case — show generic Arabic + "contact support").
- For `return` and `grinding`: `remainingWeightKg` must be non-null and ≥ 0 → `INVALID_REMAINING_ROLL_WEIGHT` (400) otherwise.
- For `return` and `grinding`: `remainingWeightKg` must NOT exceed the open segment's start weight → also `INVALID_REMAINING_ROLL_WEIGHT` (400).

The backend computes consumed weight server-side: `consumedWeight = openSegment.startWeight − remainingWeightKg`.

### Response (200 OK — same shape for all three)

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

`finalState` ∈ `{CONSUMED, PARTIALLY_RETURNED, SENT_TO_GRINDING}`.
`remainderAction` ∈ `{NONE, RETURN, GRINDING}`.
`eventType` ∈ `{CLOSED_FULL, CLOSED_PARTIAL_RETURN, CLOSED_PARTIAL_GRINDING}`.

`reprintAvailable: true` means the worker should immediately see an `إعادة طباعة الليبل` button — they're going to attach a sticker to the partial roll right now (§12).

### UI

Three clear actions on the active-mount card when a roll is currently mounted:

- `استهلاك كامل` → confirmation → call `/full-consume`.
- `إرجاع المتبقي` → numeric input + confirmation → call `/return`.
- `إرسال المتبقي للجرش` → numeric input + confirmation → call `/grinding`.

Show the response summary in a small card after success. Arabic labels:

| Concept | Arabic |
|---|---|
| Remaining weight | الوزن المتبقي |
| Remaining > segment start (validation) | لا يمكن أن يكون الوزن المتبقي أكبر من وزن بداية الرول |
| Roll closed | تم إغلاق الرول |
| Reprint available | يمكن إعادة طباعة الليبل |

---

## 11. Product switch flow

Product changes happen ONLY on this app (Roll Worker App). The Operator App and Palletizing App do NOT change products.

### Endpoint

```http
POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/product-switch
X-Device-Key: <device-key>
X-Session-Token: <roll-worker session token>
Content-Type: application/json

{
  "newProductTypeId": 6,
  "currentRollWeightKg": 175.0
}
```

Both fields are **required**. The frontend must collect a fresh weight reading (scale tare → weigh → enter) before sending — the worker is supposed to actually weigh the still-mounted roll.

### Backend validation

| # | Check | Error code |
|---|---|---|
| 1 | Token resolves to ACTIVE session on shift-line | `ROLL_WORKER_SESSION_REQUIRED` |
| 2 | Shift-line ACTIVE | `THERMOFORMING_SHIFT_LINE_NOT_FOUND` / `THERMOFORMING_SHIFT_LINE_NOT_ACTIVE` |
| 3 | Active mounted roll exists | `NO_ACTIVE_ROLL_ON_LINE` (409) |
| 4 | Open segment exists | `NO_OPEN_SEGMENT_ON_ITEM` (500) |
| 5 | `currentRollWeightKg` non-null | `CURRENT_ROLL_WEIGHT_REQUIRED` (400) |
| 6 | `currentRollWeightKg` ≥ 0 and ≤ open segment startWeight | `INVALID_CURRENT_ROLL_WEIGHT` (400) |
| 7 | New product exists | `PRODUCT_TYPE_NOT_FOUND` (404) |
| 8 | New product is `active = true` | `PRODUCT_TYPE_INACTIVE` (400) |
| 9 | Still-mounted roll's RollType is allowed for new product (strict, no override) | `ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT` (409) |

On success: backend closes the open segment (reason `PRODUCT_SWITCHED`), computes consumed weight, opens a new segment for the new product on the same active item, updates the linked palletizing line's `currentProductType`, appends a `PRODUCT_SWITCHED` event with V67 attribution, and publishes a `LineStateChangedEvent` for palletizing-side observers.

### Response (200 OK)

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

After a successful switch the active-mount card refreshes: same mounted roll, new product name, new segment id. The worker continues without re-mounting.

### UI

- Show current product **read-only** at the top of the screen.
- Choose new product from a list (see gap below).
- Numeric input: `الوزن الحالي للرول (كغ)` with decimal keypad.
- Confirmation dialog before submit:
  > هل تريد تغيير المنتج إلى "<new product name>"؟
- Success snackbar: `تم تغيير المنتج بنجاح`.

### BACKEND GAP — no allowed-products endpoint for product-switch

> **Gap status**: confirmed by code inspection. The `ProductRollCompatibilityService` has `getAllowedRollTypesForProduct(productTypeId)` (returns roll-types for a given product) but no inverse — no `getAllowedProductsForRollType()` method, and no exposed endpoint. The Roll Worker App cannot pre-populate the new-product picker today.
>
> **Why it matters**: hard-coding products in Flutter is a maintenance nightmare and silently breaks when admins add or deactivate products. Letting the worker pick a product that's incompatible only to get rejected with `ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT` is a poor UX (and discourages product-switch — which is meant to be a fast operation).

### Recommended backend follow-up

Add a read-only endpoint:

```
GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/product-switch-options
Headers: X-Device-Key, X-Session-Token
```

Suggested response: `[{productTypeId, productTypeName, allowedForCurrentRollType: true}, ...]` — only products compatible with the still-mounted roll's `RollType`. The Roll Worker App's product-switch screen calls this and renders the list.

See §24 for the formal backend follow-up entry.

### Frontend behavior until the gap is filled

Until the endpoint exists:

- **Do not hard-code a product list in the app**, full stop — that creates compliance / audit risk and silently breaks on admin changes.
- **Acceptable temporary measure**: the existing `/api/v1/product-types?active=true` endpoint (if accessible to `ROLE_DEVICE`) can populate a generic "all active products" list. The user chooses, the backend will reject incompatible choices with `ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT`. Render the rejection clearly:
  > هذا المنتج غير متوافق مع نوع الرول الحالي، اختر منتجًا آخر.
- If `/product-types` is **not** accessible to `ROLE_DEVICE`, mark the product-switch flow as **disabled in this build** and document the gap visibly in the deployment notes — do not ship a broken feature.

---

## 12. Roll label reprint flow

### Endpoint

```http
GET /api/v1/thermoforming-roll-app/rolls/{generatedRollId}/reprint-label
X-Device-Key: <device-key>
X-Session-Token: <roll-worker session token>
```

This endpoint uses the **looser** session check (`requireAnyActiveSession`): any active roll-worker session (across any shift-line) is accepted. It's read-only and keyed by `generatedRollId`, not by shift-line.

### Strict eligibility

The backend serves the response **only** when the roll's `RollConsumptionState` is `PARTIALLY_RETURNED` or `SENT_TO_GRINDING`. Other states return `ROLL_LABEL_REPRINT_NOT_AVAILABLE` (409):

- `AVAILABLE` / `IN_CONSUMPTION` — original label is still attached, no reprint.
- `CONSUMED` — no roll left to relabel.
- `BLOCKED` — admin must clear first.

> **Frontend gate**: only show the `إعادة طباعة الليبل` button when the previous-roll-resolution response said `reprintAvailable: true`. That's the safe upstream signal — don't infer eligibility from local state.

### Response (200 OK)

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

### Critical rules

- **Same `generatedRollId`** — never show or generate a new roll number. The QR encodes this exact value.
- **No new serial.** This is a reprint, not a new roll.
- The `consumptionState` field drives a small badge on the printed sticker:
  - `PARTIALLY_RETURNED` → badge `إعادة طباعة بعد الإرجاع`
  - `SENT_TO_GRINDING` → badge `إعادة طباعة قبل الجرش`
- `lastKnownWeightKg` is the declared remainder. Show it prominently on the sticker — it's the value the warehouse / grinding station will use when receiving the partial roll.

### UI

- Show the `إعادة طباعة الليبل` button only when `reprintAvailable === true` in the upstream close-flow response.
- Tap → confirmation dialog:
  > هل تريد إعادة طباعة ليبل هذا الرول؟
- On confirm → call the endpoint → render the sticker locally and send to the connected printer.
- Success snackbar: `تم تجهيز الليبل للطباعة`.

### Local printing payload

The response payload is the canonical sticker source — map every field from this DTO to the sticker template. Match the layout of the original label (printed at production time) so warehouses don't have to learn a new sticker. The QR payload is exactly the `generatedRollId` string — no JSON, no extra wrapping.

### BACKEND GAP — no print-attempt logging

> **Gap status**: the backend has no endpoint to record a print-attempt event. If a sticker fails to print physically and the worker needs to retry, there's no audit trail.
>
> **Production-safe behavior today**: the worker can hit the reprint button as many times as the eligibility window allows (state stays `PARTIALLY_RETURNED` or `SENT_TO_GRINDING` until a new event mutates it). Each call is idempotent and read-only.
>
> **Recommended follow-up** (§24): add `POST /api/v1/thermoforming-roll-app/rolls/{generatedRollId}/reprint-label/attempt` with `{outcome: "SUCCESS" | "FAILURE", reason?}` to record audit events. Not blocking for the first production release.

---

## 13. Current product and current roll display

The home screen / mount card must always render four fields:

| Concept | Arabic | Source |
|---|---|---|
| Current product | المنتج الحالي | `ThermoformingRollScanResponse.productTypeName` (after scan) or null |
| Current roll | الرول الحالي | `ThermoformingRollScanResponse.generatedRollId` (after scan) or null |
| Roll state | حالة الرول | `ThermoformingRollScanResponse.state` (e.g. `IN_CONSUMPTION`) |
| Last known weight | الوزن المعروف الأخير | `ThermoformingRollScanResponse.lastKnownWeightKg` (kg) |

Plus secondary line context:

- خط التشكيل — from session response
- خط الطبليات المرتبط — from session response

### Empty / fallback strings

| Condition | Arabic |
|---|---|
| Current product is missing on the linked palletizing line | لم يتم تحديد المنتج بعد |
| No roll mounted on this shift-line | لا يوجد رول مركّب حاليًا |

### BACKEND GAP — no read-only "current mounted roll" endpoint

> **Gap status**: confirmed by code inspection. There is **no** `GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/current-roll` (or equivalent) that returns the active mounted roll's state. The only way the Roll Worker App learns about a mounted roll is from a **fresh** scan response.
>
> **Why it matters**: if the app is restarted (cold-start) while a roll is mounted, the worker has no way to refresh the mount card without re-mounting the same roll (which would fail with `ROLL_ACTIVE_ON_ANOTHER_LINE` because it's already active on this very shift-line). The worker would have to remember the roll details from physical inspection.

### Recommended backend follow-up

Add a read-only endpoint:

```
GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/current-roll
Headers: X-Device-Key, X-Session-Token
```

Suggested response (200 if a roll is mounted; 404 with a structured error code if not):

```json
{
  "success": true,
  "data": {
    "rollId": 999,
    "generatedRollId": "777000000001",
    "rollTypeId": 70,
    "rollTypeRollCode": "TT-1S B250 White",
    "productTypeId": 5,
    "productTypeName": "أحمر 20 كغ",
    "consumptionItemId": 5000,
    "activeSegmentId": 6000,
    "state": "IN_CONSUMPTION",
    "lastKnownWeightKg": 250.000,
    "segmentStartWeightKg": 250.000
  }
}
```

See §24.

### Frontend behavior until the gap is filled

- After a successful scan, persist the `ThermoformingRollScanResponse` in `RollScanState` (and optionally cache it to disk keyed by `shiftLineId`).
- On app cold-start, if no cached state exists, show "لا يوجد رول مركّب حاليًا" and rely on the worker to physically check the line before any close-flow attempt. The first close-flow attempt without a fresh mount will return `NO_ACTIVE_ROLL_ON_LINE` if there's actually no roll, or proceed normally if there is.
- This is a production-safe temporary fallback — but the backend gap should be filled before scaling to many devices.

---

## 14. API endpoint inventory

### Endpoints this app SHOULD call

All require `X-Device-Key`. Token-bound endpoints additionally require `X-Session-Token` unless noted.

| Purpose | Method | Path | Required headers | Request | Response | Notes |
|---|---|---|---|---|---|---|
| Roll-worker auth | `POST` | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-auth` | `X-Device-Key` | `{pin}` | `RollWorkerAuthResponse` (with raw `sessionToken` once) | Replace-existing pattern; rejects if shift-line not ACTIVE or operator not `rollWorkerEnabled` |
| Get current session | `GET` | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-session/current` | `X-Device-Key` | — | `RollWorkerSessionResponse` (no `sessionToken` field) | **NO X-Session-Token** required — discovery mode |
| Logout | `POST` | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-logout` | `X-Device-Key` | `{sessionToken}` | `Void` | Token in BODY, not header. Idempotent. |
| Scan / mount roll | `POST` | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/scan-roll` | `X-Device-Key`, `X-Session-Token` | `{generatedRollId}` or `{scannedValue}` | `ThermoformingRollScanResponse` (201) | Backend prefers `generatedRollId` |
| Full-consume previous roll | `POST` | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/previous-roll/full-consume` | `X-Device-Key`, `X-Session-Token` | — | `ThermoformingPreviousRollResolutionResponse` | `reprintAvailable: false` |
| Return remaining | `POST` | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/previous-roll/return` | `X-Device-Key`, `X-Session-Token` | `{remainingWeightKg}` | same response shape | `reprintAvailable: true` |
| Send to grinding | `POST` | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/previous-roll/grinding` | `X-Device-Key`, `X-Session-Token` | `{remainingWeightKg}` | same response shape | `reprintAvailable: true` |
| Product switch | `POST` | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/product-switch` | `X-Device-Key`, `X-Session-Token` | `{newProductTypeId, currentRollWeightKg}` | `ThermoformingProductSwitchResponse` | Both fields required |
| Reprint roll label | `GET` | `/api/v1/thermoforming-roll-app/rolls/{generatedRollId}/reprint-label` | `X-Device-Key`, `X-Session-Token` | — | `RollLabelReprintResponse` | Strict eligibility (PARTIALLY_RETURNED or SENT_TO_GRINDING only); uses looser `requireAnyActiveSession` gate |

### Endpoints this app MUST NOT call

| Path | Owner |
|---|---|
| `/api/v1/thermoforming-app/auth/operator-pin` | Operator App |
| `/api/v1/thermoforming-app/shifts/start` | Operator App |
| `/api/v1/thermoforming-app/shifts/current` | Operator App |
| `/api/v1/thermoforming-app/shifts/{shiftId}/end` | Operator App |
| `/api/v1/thermoforming-app/shifts/{shiftId}/lines` (POST/GET) | Operator App |
| `/api/v1/thermoforming-app/shift-lines/{shiftLineId}/end` | Operator App |
| `/api/v1/thermoforming-app/shifts/{shiftId}/notes` | Operator App |
| `/api/v1/thermoforming-app/my-production` | Operator App |
| `/api/v1/palletizing-line/lines/{lineId}/palletizer-auth` | Palletizing App |
| `/api/v1/palletizing-line/lines/{lineId}/palletizer-session/current` | Palletizing App |
| `/api/v1/palletizing-line/lines/{lineId}/palletizer-logout` | Palletizing App |
| `/api/v1/palletizing-line/lines/{lineId}/pallets` (POST/cancel/FALET) | Palletizing App |
| `/api/v1/thermoforming-app/shift-lines/{id}/scan-roll` | **REMOVED** in commit `7b0eca8`; use the `/thermoforming-roll-app/...` replacement |
| `/api/v1/thermoforming-app/shift-lines/{id}/previous-roll/*` | **REMOVED**; use `/thermoforming-roll-app/...` |
| `/api/v1/thermoforming-app/shift-lines/{id}/product-switch` | **REMOVED**; use `/thermoforming-roll-app/...` |
| `/api/v1/thermoforming-app/rolls/{generatedRollId}/reprint-label` | **REMOVED**; use `/thermoforming-roll-app/...` |

If you find a reference to any of the removed endpoints in older docs, ignore it.

---

## 15. Token handling

### `rollWorkerSessionToken` (per shift-line)

| Property | Value |
|---|---|
| Issued by | `POST /roll-worker-auth` response, field `data.sessionToken` (raw, returned ONCE) |
| Sent as | `X-Session-Token` header on every roll-operation endpoint |
| Storage | secure storage (e.g. `flutter_secure_storage`), keyed by `shiftLineId`: `roll_worker_session_token_{shiftLineId}` |
| Header name | `X-Session-Token` (case-sensitive, exact spelling — backend constant `SESSION_TOKEN_HEADER` in `RollWorkerRollController` and `RollWorkerShiftLineController`) |
| Sent on `GET .../roll-worker-session/current` | **No** — that endpoint discovers session existence with only `X-Device-Key` |
| Sent on `POST .../roll-worker-logout` | **In body** as `{sessionToken}`, not as a header |
| Lifetime | duration of the shift-line's ACTIVE state, or until manual logout, or until replaced by a new auth |
| Cleared when | logout succeeds, OR on any `ROLL_WORKER_SESSION_REQUIRED` response, OR on shift-line cascade-end, OR on user-initiated reset |

### Mandatory rules

- Use `flutter_secure_storage` (or platform equivalent). **Never** plain shared-prefs / disk plain-text.
- **Never** log the token — not in stdout, debug overlays, crash reports, or analytics.
- **Never** display the token in any UI.
- **Clear** the token immediately on any `ROLL_WORKER_SESSION_REQUIRED` (400 / 401 / 403 / 404). Route to PIN.
- **On app resume**: call `GET /roll-worker-session/current` to validate the stored token. If it returns 200 with status `ACTIVE`, the token is still good. If 404, clear and route to PIN.
- **Replace-existing semantics**: if a NEW auth happens on the same shift-line on another device, your token becomes invalid (the previous session row is `REPLACED`). Treat the next `ROLL_WORKER_SESSION_REQUIRED` as a normal session-loss event — clear and route to PIN.

### Header summary

| Header | Required by | Notes |
|---|---|---|
| `X-Device-Key` | every `/api/v1/thermoforming-roll-app/**` endpoint | Shared transport secret across the three apps |
| `X-Session-Token` | every roll-operation endpoint (scan, previous-roll, product-switch, reprint) | Backend SHA-256-hashes and matches against the stored row hash |

---

## 16. State management details

Production-grade Riverpod state shapes. Use Freezed unions; keep states immutable.

### `RollWorkerAuthState`

```
@freezed
sealed class RollWorkerAuthState with _$RollWorkerAuthState {
  const factory RollWorkerAuthState.initial() = _Initial;
  const factory RollWorkerAuthState.authenticating() = _Authenticating;
  const factory RollWorkerAuthState.authenticated(RollWorkerSession session) = _Authenticated;
  const factory RollWorkerAuthState.notAllowed() = _NotAllowed;          // ROLL_WORKER_NOT_ALLOWED
  const factory RollWorkerAuthState.noActiveShiftLine() = _NoLine;       // THERMOFORMING_SHIFT_LINE_NOT_ACTIVE / NOT_FOUND
  const factory RollWorkerAuthState.tokenInvalid() = _TokenInvalid;      // ROLL_WORKER_SESSION_REQUIRED
  const factory RollWorkerAuthState.failure(AppFailure failure) = _Failure;
}
```

### `CurrentShiftLineState`

```
@freezed
sealed class CurrentShiftLineState with _$CurrentShiftLineState {
  const factory CurrentShiftLineState.loading() = _Loading;
  const factory CurrentShiftLineState.waitingForOperator() = _Waiting;   // no active option resolvable yet
  const factory CurrentShiftLineState.selected(int shiftLineId) = _Selected;
  const factory CurrentShiftLineState.active(ShiftLineContext context) = _Active;
  const factory CurrentShiftLineState.ended() = _Ended;                  // cascade-on-end happened
  const factory CurrentShiftLineState.failure(AppFailure failure) = _Failure;
}
```

### `RollOperationState`

```
@freezed
sealed class RollOperationState with _$RollOperationState {
  const factory RollOperationState.idle() = _Idle;
  const factory RollOperationState.scanning() = _Scanning;
  const factory RollOperationState.mounted(MountedRoll roll) = _Mounted;
  const factory RollOperationState.resolvingPreviousRoll() = _Resolving;
  const factory RollOperationState.switchingProduct() = _Switching;
  const factory RollOperationState.labelReprintReady(LabelPayload payload) = _ReprintReady;
  const factory RollOperationState.failure(AppFailure failure) = _Failure;
}
```

### Rules

- One Freezed state union per feature. Do NOT compose them into one giant state.
- Notifiers are feature-scoped (`RollWorkerAuthController`, `RollScanController`, etc.) — one per feature folder.
- The backend is the source of truth — no optimistic transitions for any roll operation. Mutate state ONLY on a successful response.
- Refresh after every mutation if a refresh endpoint exists. Today most refreshes happen via the response payload of the mutating call (acceptable as long as the response carries enough state — see §13 for the gap).
- Provide `invalidate` / `refresh` semantics on each AsyncNotifier so app-resume (§19) can drive a coherent re-fetch.
- Cache nothing for product/roll-type compatibility — backend is strict and authoritative.
- Cache nothing about an active mount across device reboots without a means to verify it (until the §13 gap closes).

---

## 17. Error handling

Backend returns the project envelope:

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "ERROR_CODE",
    "message": "human-readable",
    "details": { ... }
  }
}
```

Treat the `code` as the source of truth. The Arabic copy below mirrors `messages_ar.properties` where present. For codes without bundle entries, render the suggested copy and request an i18n entry as a follow-up.

| Code | HTTP | Arabic message | UX action |
|---|---|---|---|
| `ROLL_WORKER_NOT_ALLOWED` | 403 | هذا المشغّل غير مفعّل لتطبيق عامل الرولات. | Inline error on PIN screen. Do not retry. |
| `ROLL_WORKER_SESSION_REQUIRED` | 400 / 401 / 403 / 404 | انتهت الجلسة، يُرجى تسجيل الدخول مجددًا. | Clear token → route to PIN. Refresh state. |
| `THERMOFORMING_SHIFT_LINE_NOT_FOUND` | 404 | تخصيص مناوبة خط التشكيل الحراري غير موجود. | Refresh line picker (§7). |
| `THERMOFORMING_SHIFT_LINE_NOT_ACTIVE` | 409 | تخصيص مناوبة خط التشكيل الحراري غير نشط. | Refresh line picker. The line was ended elsewhere. |
| `NO_CURRENT_PRODUCT_ON_LINE` | 409 | لا يوجد منتج محدد حالياً على خط الطبليات المرتبط. حدد المنتج قبل تحميل الرول. | Block scan. Show banner instructing the operator (in Operator App / via supervisor) to set the product. |
| `ROLL_NOT_FOUND` | 404 | الرول غير موجود. | Inline error on scan dialog. Worker re-scans. |
| `ROLL_ALREADY_CONSUMED` | 409 | تم استهلاك هذا الرول بالفعل ولا يمكن تحميله مرة أخرى. | Inline error on scan dialog. Worker picks another roll. |
| `ROLL_ACTIVE_ON_ANOTHER_LINE` | 409 | هذا الرول مُحمَّل بالفعل على خط تشكيل حراري آخر. | Inline error on scan dialog. |
| `ROLL_BLOCKED` | 409 | هذا الرول محظور ولا يمكن استخدامه. | Inline error on scan dialog. Escalate to supervisor. |
| `ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT` | 409 | نوع الرول غير مسموح لهذا المنتج. | Inline error. Worker picks a compatible roll (or compatible product on switch). |
| `NO_ACTIVE_ROLL_ON_LINE` | 409 | لا يوجد رول مُحمَّل حالياً على هذا الخط. | Refresh mount card. Worker mounts a roll first. |
| `NO_OPEN_SEGMENT_ON_ITEM` | 500 | حدث خطأ تقني، يُرجى التواصل مع الدعم. | Generic error. Log code internally. Escalate to support. |
| `INVALID_REMAINING_ROLL_WEIGHT` | 400 | الوزن المتبقي غير صالح. يجب أن يكون صفراً أو موجباً ولا يتجاوز وزن بداية الجزء. | Inline error on the weight input. |
| `CURRENT_ROLL_WEIGHT_REQUIRED` | 400 | وزن الرول الحالي مطلوب قبل تغيير المنتج. | Bug — never hit if you implemented §11 correctly. Block submit. |
| `INVALID_CURRENT_ROLL_WEIGHT` | 400 | وزن الرول الحالي غير صالح. يجب أن يكون صفراً أو موجباً ولا يتجاوز وزن بداية الجزء. | Inline error on the weight input. |
| `ROLL_LABEL_REPRINT_NOT_AVAILABLE` | 409 | إعادة طباعة ملصق الرول متاحة فقط بعد الإرجاع الجزئي أو إغلاق الجرش. | Hide the reprint button. Refresh state. |
| `OPERATOR_PIN_INVALID` | 401 | رقم تعريف غير صحيح. | Inline error under PIN. |
| `OPERATOR_PIN_LOCKED` | 423 | تم قفل رقم التعريف بسبب محاولات خاطئة، حاول لاحقًا. | Inline error; disable PIN input until unlock. |
| `PRODUCT_TYPE_NOT_FOUND` | 404 | لم يتم العثور على المنتج المطلوب. | Inline error on product-switch. Refresh product list. |
| `PRODUCT_TYPE_INACTIVE` | 400 | هذا المنتج غير نشط. | Inline error on product-switch. Worker picks another product. |
| `VALIDATION_ERROR` | 400 | use the backend `message` if present, else a generic Arabic fallback. | Inline. |
| Any other / network failure | — | حدث خطأ، حاول مرة أخرى. | Snackbar with retry. |

### UX rules

- PIN errors → inline error under the PIN input. Do not bounce out of the PIN screen.
- Scan / weight validation errors → inline on the relevant input or dialog. Do not lose the operator's typed weight.
- Network errors / 5xx → snackbar with `إعادة المحاولة`. Do not lose state.
- Card-load failures → inline retry on the affected card.
- Confirmation dialogs before irreversible actions (close roll, send to grinding, product switch).
- For `NO_OPEN_SEGMENT_ON_ITEM` (500) — log internally with full context (shift-line id, item id from last scan), show generic message, do not blame the operator.

---

## 18. Loading, empty, offline, and app-resume states

| Trigger | UX |
|---|---|
| Roll-worker login submitted | Disable button + inline spinner inside the button |
| Line picker loading | Card-list shimmer; do not block whole app |
| Scan submitted | Disable scan controls until response; spinner inside the action button |
| Previous-roll close submitted | Disable confirm button in the dialog |
| Product switch submitted | Disable confirm button in the dialog |
| Label reprint submitted | Spinner inside the reprint button; do not block other actions |
| No active shift-line | Centered card: `لا يوجد خط تشكيل نشط حاليًا، انتظر بدء المناوبة من المشغّل.` + retry button |
| No mounted roll | Empty mount card with primary action `تركيب رول جديد` |
| No internet / server unreachable | Top banner: `لا يوجد اتصال بالخادم، سيتم إعادة المحاولة تلقائيًا.` + retry on the affected card |
| `ROLL_WORKER_SESSION_REQUIRED` mid-flow | Snackbar: `انتهت الجلسة، يُرجى تسجيل الدخول مجددًا.` + clear token + route to PIN |
| Cascade-on-end (shift-line ended elsewhere) | Snackbar: `تم إنهاء خط التشكيل، يُرجى تسجيل الدخول مجددًا عند فتح خط جديد.` + clear token + route to line picker |

> Do not flash the entire UI during background refreshes. Use subtle inline indicators. Connectivity banner should be a persistent slim strip at the top, not a modal.

---

## 19. Polling / refresh policy

This app has no live-state stream today (see §24 gap #5). Use a conservative polling policy:

- **App resume** → call `GET /roll-worker-session/current` once. If state has changed, refresh the home card.
- **Manual pull-to-refresh** on the home screen → re-fetches the current session.
- **Lightweight polling** on the active home screen — every 15 seconds while foregrounded — to detect cascade-on-end (shift-line ended by operator) and reflect it before the next mutation fails. **Pause polling when the screen is disposed or backgrounded.**
- **Do NOT poll** label-reprint, product-switch, or any heavy / printing endpoint.
- **Do NOT poll** scan-roll (it's a mutation; never call it speculatively).
- Polling is the production-safe temporary fallback for the first production release. If/when the SSE/live-state endpoint ships (§24 — backend gap), drop polling and switch to push.

### App resume specifically

On app foreground:

1. If `sessionTokenProvider.value == null` → route to PIN (or line picker if shift-line not yet selected).
2. Else call `GET /roll-worker-session/current` for the stored `shiftLineId`:
   - 200 with `status: ACTIVE` → home with refreshed session info.
   - 200 with non-ACTIVE status → clear token, route to PIN.
   - 404 → clear token, route to PIN (or line picker if shift-line is also stale).
   - 5xx / network → keep current state; show connectivity banner and retry.
3. If a mounted-roll cache exists locally (until §13 gap closes), display it as-is — but mark it as "from local cache" if you want to be explicit. The next mutation either confirms or contradicts it.

---

## 20. UI/UX acceptance criteria

The app is acceptable when ALL of the following are true.

- [ ] Roll worker can select an active shift-line safely (production-grade picker — not manual ID entry in production builds; see §7 / §24).
- [ ] Roll worker can log in with PIN.
- [ ] Unauthorized roll worker (`rollWorkerEnabled = false`) is rejected with an Arabic inline error and never gets a token.
- [ ] When no active shift-line exists, the app shows a clear waiting state and does NOT allow any further interaction.
- [ ] Roll worker session is per-shift-line — token storage is keyed by `shiftLineId`.
- [ ] Roll worker can scan / mount a compatible roll.
- [ ] App rejects scan when the roll-worker session is missing (does not call `/scan-roll` without a valid token).
- [ ] App shows the current product (read-only).
- [ ] App shows the current roll state and last-known weight on the active mount card.
- [ ] Roll worker can full-consume the previous roll (no remainder input).
- [ ] Roll worker can return remaining roll (with weight input + bounds validation).
- [ ] Roll worker can send remaining roll to grinding (with weight input + bounds validation).
- [ ] Reprint label button shows ONLY when the upstream close response said `reprintAvailable: true`.
- [ ] Reprint endpoint returns the canonical sticker payload; the Flutter renderer produces the same sticker layout as the original print.
- [ ] Product switch requires both `newProductTypeId` AND `currentRollWeightKg`.
- [ ] App never starts/ends shifts.
- [ ] App never opens or closes shift-lines.
- [ ] App never creates pallets, calls palletizer-auth, or touches palletizing endpoints.
- [ ] App uses Arabic / RTL correctly everywhere.
- [ ] Visual rhythm matches the Operator App and Palletizing App.
- [ ] App handles app resume per §19.
- [ ] App handles offline / 5xx errors per §17 / §18.
- [ ] App prevents duplicate submits on every mutating action.
- [ ] No raw PIN, `sessionToken`, or `DEVICE_KEY` appears in logs, crash reports, or analytics.
- [ ] Automated grep check in CI: scan the build for any occurrence of forbidden endpoint paths (§14) and fail the build if found.

---

## 21. Manual end-to-end verification

Use a local backend at `http://localhost:8080` with V67 + V68 applied. You also need the Operator App and Palletizing App available on test devices (or a way to call those endpoints).

Pre-conditions:
- An operator with `pin = "1234"`, `active = true`, `thermoformingOperatorEnabled = true`. Use this as the supervisor in the Operator App.
- A second operator with `pin = "5678"`, `active = true`, `rollWorkerEnabled = true`. Use this as the roll worker.
- A Thermoforming line linked to a Palletizing line, both `active = true`.
- The Palletizing line will get its `currentProductType` set as part of the workflow.
- At least two compatible roll types and two compatible product types so you can exercise product-switch.

### Steps

1. Start with no active Thermoforming shift-line.
2. Open the **Roll Worker App** → it shows the waiting / no-active-line state (§7).
3. In the **Operator App**, log in (operator `1234`), start the shift, and add the Thermoforming line — the shift-line goes ACTIVE.
4. (If the line picker endpoint is shipped) the **Roll Worker App** auto-discovers the active line. (If not, use the temporary fallback path until §24 gap #1 closes.) The PIN screen appears.
5. Roll worker logs in with PIN `5678`. The home screen shows the empty mount card with the linked Palletizing line + (if the operator set a product) the current product.
6. Roll worker scans a compatible roll — mount card updates with the roll details, segment id, last-known weight.
7. (Optional) Open the **Palletizing App** on the linked Palletizing line — verify it shows the new product / line context (this confirms the bridge is working).
8. Roll worker taps `استهلاك كامل` → confirmation → roll closes, `reprintAvailable: false`.
9. Roll worker scans another compatible roll → mounted.
10. Roll worker taps `إرجاع المتبقي`, enters a weight ≤ start weight, confirms → roll closes with `PARTIALLY_RETURNED` and `reprintAvailable: true`.
11. Reprint button visible → tap → reprint endpoint returns the partial-roll sticker payload → printer prints the same `generatedRollId` with the "إعادة طباعة بعد الإرجاع" badge.
12. Roll worker scans a third compatible roll → product-switch flow → enters new compatible product + current weight → switch succeeds → mount card refreshes with new product, same `generatedRollId`.
13. In the **Operator App**, end the shift-line.
14. **Roll Worker App** — the next 15-second poll (or any mutation attempt) returns `ROLL_WORKER_SESSION_REQUIRED` (cascade-on-end). The app clears the token, snackbar appears, routes to the line picker / waiting state.

### Negative-path checks

- Try to scan a roll while logged out → blocked client-side, no network call.
- Try to scan a CONSUMED roll → 409 `ROLL_ALREADY_CONSUMED` → inline error.
- Try to scan a roll with incompatible RollType → 409 `ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT` → inline error.
- Try to product-switch with `currentRollWeightKg` greater than segment start → 400 `INVALID_CURRENT_ROLL_WEIGHT` → inline error on the weight input.
- Try to call reprint while state is `IN_CONSUMPTION` → 409 `ROLL_LABEL_REPRINT_NOT_AVAILABLE` → button should not have been shown.

---

## 22. Frontend implementation checklist

Plan & scaffolding:
- [ ] Approve implementation plan based on this document.
- [ ] Add Riverpod, `flutter_secure_storage`, Freezed + `build_runner`, `json_serializable` to `pubspec.yaml`.
- [ ] Decide on QR scanner package (e.g. `mobile_scanner`) and printer package (whatever the existing apps use).

Core / shared:
- [ ] `core/config/AppConfig` — read `API_BASE_URL` and `DEVICE_KEY` from `String.fromEnvironment`.
- [ ] `core/api/ApiClient` — base URL + `X-Device-Key` interceptor + `X-Session-Token` interceptor (only for token-bound endpoints).
- [ ] `core/storage/SecureTokenStorage` — `flutter_secure_storage` wrapper, keyed by `shiftLineId`.
- [ ] `core/errors/AppFailure` + `ErrorCode` mapping → Arabic message.
- [ ] Connectivity banner widget.

API client methods:
- [ ] `verifyRollWorkerPin(shiftLineId, pin)` → returns `RollWorkerAuthResponse`.
- [ ] `getCurrentRollWorkerSession(shiftLineId)` → returns `RollWorkerSessionResponse?`.
- [ ] `logoutRollWorker(shiftLineId, sessionToken)`.
- [ ] `scanRoll(shiftLineId, sessionToken, generatedRollId)` → returns `ThermoformingRollScanResponse`.
- [ ] `previousRollFullConsume(shiftLineId, sessionToken)`.
- [ ] `previousRollReturn(shiftLineId, sessionToken, remainingWeightKg)`.
- [ ] `previousRollGrinding(shiftLineId, sessionToken, remainingWeightKg)`.
- [ ] `productSwitch(shiftLineId, sessionToken, newProductTypeId, currentRollWeightKg)`.
- [ ] `reprintRollLabel(generatedRollId, sessionToken)`.

Screens:
- [ ] Line-picker / waiting screen (§7).
- [ ] PIN screen (§6).
- [ ] Home / active mount card (§8, §13).
- [ ] Scan-roll flow (camera + manual fallback) (§9).
- [ ] Previous-roll resolution dialogs (§10).
- [ ] Product-switch screen (§11).
- [ ] Label reprint flow (§12).

Behavior:
- [ ] Token storage / clearing rules (§15).
- [ ] App-resume refresh (§19).
- [ ] Polling on home screen (§19).
- [ ] Error mapping per §17.
- [ ] Duplicate submit prevention on every mutation.
- [ ] Arabic / RTL correct on every screen.

Forbidden — explicitly ensure NONE of these exist:
- [ ] No call to any `/api/v1/thermoforming-app/**` endpoint (Operator App).
- [ ] No call to any `/api/v1/palletizing-line/**` endpoint (Palletizing App).
- [ ] No call to any of the hard-removed pre-V67 endpoints (§14).
- [ ] No PIN / token / device-key in logs.
- [ ] CI grep check enforcing the above.

QA:
- [ ] Multi-line / multi-session test (one operator, one roll worker, two devices on different lines).
- [ ] Replace-existing test (two devices auth on the same line — first device's token invalidates).
- [ ] Cascade-on-end test (operator ends shift-line; roll-worker app drops session).
- [ ] App resume after backgrounding.
- [ ] Arabic RTL spot-check on every screen.
- [ ] Network-loss recovery on each mutation.
- [ ] Reprint-button gating (only visible when `reprintAvailable: true`).

---

## 23. Deployment warning

- This app is part of a **three-app workflow**. Do not deploy it standalone to production.
- Coordinate the rollout: **backend (V67 + V68) → Operator App → Palletizing App → Roll Worker App**. The Operator App opens shift-lines first; the Palletizing App needs the new auth/product model; the Roll Worker App is the consumer of both.
- The Operator App must open shift-lines before the Roll Worker App is usable — otherwise every PIN attempt rejects with `THERMOFORMING_SHIFT_LINE_NOT_ACTIVE`.
- The Palletizing App must be on the new auth/product model — otherwise palletizers cannot create pallets even on lines that the Operator App opened.
- Do not enable the new flow for an operator until their `rollWorkerEnabled` flag has been turned on by an admin. Default is `FALSE` after V67 deploy.
- Run §21 end-to-end against staging before production. Pay special attention to cascade-on-end and replace-existing.

---

## 24. Backend follow-ups / gaps

The Roll Worker App can ship its first production release today, but the following backend gaps must close before this app is production-ready at scale. Each gap below was confirmed by code inspection at HEAD `ff0115f`.

### Gap 1 — Active shift-lines picker

**Why it matters**: production-floor roll workers cannot type 19-digit shift-line IDs. Manual ID entry is not acceptable as final production UX.

**Frontend behavior until it ships**: see §7. Use a build-flag-gated developer entry as a temporary fallback ONLY in non-production builds.

**Recommended endpoint**:

```
GET /api/v1/thermoforming-roll-app/shift-lines/active-options
Headers: X-Device-Key
```

Response: list of currently-ACTIVE shift-lines with line/code/name + linked palletizing line + current product + current mounted roll's `generatedRollId` if any + supervising operator name + `hasActiveRollWorkerSession` flag.

Rationale: lets the Roll Worker App show a card per active line on first launch. No session token required (discovery mode).

### Gap 2 — Allowed products for product-switch

**Why it matters**: hard-coding product lists in Flutter is a maintenance nightmare and a compliance risk. Letting the worker pick a product only to be rejected with `ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT` is poor UX.

**Frontend behavior until it ships**: see §11. Either disable product-switch in the build, or fall back to a generic "all active products" list and rely on the backend's strict rejection (with a clear Arabic error).

**Recommended endpoint**:

```
GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/product-switch-options
Headers: X-Device-Key, X-Session-Token
```

Response: `[{productTypeId, productTypeName, allowedForCurrentRollType: true}, ...]` — only products compatible with the still-mounted roll's `RollType`.

### Gap 3 — Current mounted roll state (read-only)

**Why it matters**: after app cold-start, there's no way to refresh the mount card without re-scanning. The worker has to remember the roll details.

**Frontend behavior until it ships**: see §13. Cache the last scan response locally; if missing on cold-start, show "no roll" until the next mutation either confirms (200) or contradicts (`NO_ACTIVE_ROLL_ON_LINE`).

**Recommended endpoint**:

```
GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/current-roll
Headers: X-Device-Key, X-Session-Token
```

Response: same shape as `ThermoformingRollScanResponse` if a roll is mounted, plus `segmentStartWeightKg` for client-side bounds validation; 404 with a structured code if no roll mounted.

### Gap 4 — Print-attempt audit logging

**Why it matters**: no audit trail for sticker prints. If a sticker fails physically and is retried multiple times, there's no way to reconcile.

**Frontend behavior until it ships**: idempotent reprint calls work as-is. Log nothing locally beyond standard error logs.

**Recommended endpoint**:

```
POST /api/v1/thermoforming-roll-app/rolls/{generatedRollId}/reprint-label/attempt
Headers: X-Device-Key, X-Session-Token
Body: { "outcome": "SUCCESS" | "FAILURE", "reason": "string?" }
```

Append-only audit row, server-stamped with V67 attribution. Not blocking for the first production release.

### Gap 5 — Live state stream (SSE / WebSocket)

**Why it matters**: the Roll Worker App polls every 15 seconds on the home screen to detect cascade-on-end and product changes from the Operator App or other devices. At scale (many devices), polling generates needless load and adds latency to user-facing state changes.

**Frontend behavior until it ships**: polling per §19. Pause when backgrounded.

**Recommended endpoint**:

```
GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/events
Headers: X-Device-Key, X-Session-Token
Accept: text/event-stream
```

Emit events for: shift-line ended (cascade), product changed (from another device's product-switch), session replaced (replace-existing). Reuse the existing `LineStateChangedEvent` plumbing on the palletizing side as a starting point.

### Tracking

When the gaps above are addressed, update this doc — bump the front-matter HEAD reference, replace the "BACKEND GAP" callouts with the new endpoint specs, and remove the temporary frontend workarounds.
