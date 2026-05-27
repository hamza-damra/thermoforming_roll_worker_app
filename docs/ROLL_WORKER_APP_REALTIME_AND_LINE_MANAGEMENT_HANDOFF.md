# Roll Worker App Realtime + Line Management Handoff

> Backend: TaleebBackend (Spring Boot 4.0.3 / Java 17)
> Frontend: Flutter "Roll Worker App" (تطبيق موظف الرولات)
> Backend module: `ps.taleeb.taleebbackend.thermoformingrollapp`
> Base path: `/api/v1/thermoforming-roll-app/**`

## 1. Summary

### Problem

The Flutter Roll Worker App had four production gaps:

1. **Stale state after the thermoforming operator ends their shift** — the app polled every few seconds, so closing a shift-line from the Thermoforming Operator App took up to one poll interval to reflect on every connected Roll Worker device.
2. **Polling kept running even when the SSE channel was already open** — bandwidth and battery waste, plus unnecessary backend load.
3. **No bulk "leave all lines" or unified "my current state across all lines" endpoint** — the app had to loop per shift-line, which was both N+1 chatter and brittle when lines were closed mid-loop.
4. **Roll mount / consume / return / send-to-grinding never fired any SSE event** — those operations updated the DB silently, so a connected device looking at the "currently mounted roll" card would not see the change until its next poll or manual refresh.

### What the backend now supports

- **One unified post-login state endpoint**: `GET /api/v1/thermoforming-roll-app/sessions/me` returns the worker's identity plus a per-line snapshot (active product, mounted roll, line lifecycle / blocked / handover / takeover flags) for every ACTIVE session they hold. The frontend calls this on first load AND on every SSE frame.
- **One post-login "add another line" picker endpoint**: `GET /api/v1/thermoforming-roll-app/sessions/me/joinable-lines` returns the pre-login picker rows minus the lines the worker already holds.
- **One bulk-logout endpoint**: `POST /api/v1/thermoforming-roll-app/sessions/leave-all` ends every ACTIVE session belonging to the calling worker, publishing one `ROLLS_EMPLOYEE_CHANGED` event per freed palletizing line.
- **SSE event coverage now covers every change relevant to the Roll Worker App** — see §3. The existing `/api/v1/thermoforming-roll-app/events` SSE channel is unchanged in shape; only the publish sites have been added. The Flutter client needs no SSE-protocol change.

### Out of scope (intentionally)

- **No new SSE infrastructure** — we reuse `RollWorkerLineEventsSseBroker` and `OperatorDashboardEventPublisher`.
- **No backend localization of error messages** — error codes are documented in §7 and the Flutter app maps them to Arabic. Zero API-contract change.
- **No manual product-switch flow** — active product is driven exclusively by the Thermoforming Production Plan. The old `/product-switch` endpoint was removed. See §6.
- **No new Flyway migration** — every column referenced is already present (V67 and earlier).

## 2. Backend endpoints

> All endpoints in this section are guarded by `DeviceApiKeyFilter` (`X-Device-Key: <app.device-api-key>`). Endpoints that operate on a specific worker (everything except `/events`, `/bootstrap`, and the initial auth endpoints) additionally require an `X-Session-Token` header carrying ANY one of the worker's active session tokens.

### 2.1 Bootstrap & SSE (pre-login)

| Method | Path | Auth | Body | Returns | When |
| --- | --- | --- | --- | --- | --- |
| GET | `/api/v1/thermoforming-roll-app/bootstrap` | `X-Device-Key` only | — | `RollWorkerBootstrapResponse` (line-picker state for every ACTIVE shift-line) | On app launch BEFORE PIN entry, and as a fallback when SSE drops or after a debounced refresh trigger fires |
| GET | `/api/v1/thermoforming-roll-app/events` | `X-Device-Key` only, `Accept: text/event-stream` | — | SSE stream of `roll-worker-lines-changed` frames | Open once on app launch and keep open. See §3 for the frame contract and §4 for the polling fallback. |

### 2.2 Session lifecycle (login + logout)

| Method | Path | Auth | Body | Returns | When |
| --- | --- | --- | --- | --- | --- |
| POST | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-auth` | `X-Device-Key` only | `{ "pin": "...." }` | `RollWorkerAuthResponse` incl. raw `sessionToken` (returned exactly once) | Single-line login from the picker. |
| POST | `/api/v1/thermoforming-roll-app/sessions/start-batch` | `X-Device-Key` only | `{ "pin": "...", "shiftLineIds": [..] }` | `RollWorkerBatchAuthResponse` with one entry per line, each carrying its own `sessionToken` | Multi-select login from the picker. Atomic all-or-nothing — if any line fails preconditions the entire batch is rejected with no sessions created on any line. |
| GET | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-session/current` | `X-Device-Key` only | — | `RollWorkerSessionResponse` | Optional health check for a specific line; the frontend should prefer `/sessions/me` for its unified post-login state. |
| POST | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-logout` | `X-Device-Key` + `{ "sessionToken": "..." }` in body | `{ "sessionToken": "..." }` | 200 OK, empty `data` | "Leave this one specific line" UX action. Idempotent. |

### 2.3 NEW post-login endpoints (this change set)

| Method | Path | Auth | Body | Returns | When |
| --- | --- | --- | --- | --- | --- |
| GET | `/api/v1/thermoforming-roll-app/sessions/me` | `X-Device-Key` + `X-Session-Token: <any of the worker's tokens>` | — | `RollWorkerMeResponse` (operator id/name + array of `RollWorkerActiveLineResponse`) | On first load after login AND on every SSE frame. One round-trip replaces the per-line loop. |
| GET | `/api/v1/thermoforming-roll-app/sessions/me/joinable-lines` | `X-Device-Key` + `X-Session-Token` | — | `List<RollWorkerShiftLineOptionResponse>` (every ACTIVE shift-line minus the ones the worker already owns) | When the user opens the "add another line" sheet. |
| POST | `/api/v1/thermoforming-roll-app/sessions/leave-all` | `X-Device-Key` + `X-Session-Token` | — | `204 No Content` | When the user picks "تسجيل خروج من جميع الخطوط". Idempotent — returns 204 even when zero sessions were active. |

### 2.4 Response shapes worth pinning

**`RollWorkerMeResponse`**
```json
{
  "rollWorkerOperatorId": 7,
  "rollWorkerName": "محمد سنتريسي",
  "lines": [
    { /* RollWorkerActiveLineResponse */ }
  ]
}
```

**`RollWorkerActiveLineResponse`** (one entry per ACTIVE session, ordered by session start time ASC)
```json
{
  "sessionId": 41,
  "shiftLineId": 102,
  "palletizingLineId": 1,
  "palletizingLineCode": "LINE_1",
  "palletizingLineName": "Line-1",
  "thermoformingLineId": 1001,
  "thermoformingLineCode": "TF_LINE_1",
  "thermoformingLineName": "ماكينة A",
  "thermoformingShiftId": 333,
  "supervisingOperatorId": 6,
  "supervisingOperatorName": "محمد سنتريسي",
  "currentPlanItemProductTypeId": 12,
  "currentPlanItemProductName": "Red 20kg",
  "currentRollId": null,
  "currentRollGeneratedRollId": null,
  "currentRollTypeCode": null,
  "currentRollTypeName": null,
  "currentRollLastKnownWeightKg": null,
  "handoverPending": false,
  "takeoverRequestStatus": null,
  "takeoverIncomingOperatorName": null,
  "blocked": false,
  "blockedReason": null,
  "lineLifecycleStatus": "ACTIVE",
  "sessionStartedAt": "2026-05-23T07:15:00+03:00",
  "sessionStartedAtDisplay": "23 أيار، 07:15 ص"
}
```

When no roll is mounted, every `currentRoll*` field is `null` and the frontend should render "لا يوجد رول مركب حالياً".

When the line is blocked (handover pending or takeover in progress), `blocked = true`, `blockedReason` is one of `PENDING_HANDOVER` / `TAKEOVER_<status>`, and `lineLifecycleStatus` mirrors `blockedReason`. The frontend should render the line in a "blocked" visual state and disable the scan button.

## 3. SSE contract

> The SSE endpoint and broker existed before this change set; only the publish sites have been added. The frame format and reconnect behaviour are unchanged.

### 3.1 Endpoint

```
GET /api/v1/thermoforming-roll-app/events
Headers:
  X-Device-Key: <app.device-api-key>
  Accept: text/event-stream
```

### 3.2 Connection lifecycle

| Aspect | Behaviour |
| --- | --- |
| Initial handshake | Server immediately sends `event: connected\ndata: {"status":"connected"}` |
| Keepalive | Server sends a `: ping` comment every 25 s |
| Server-side timeout | 5 minutes — server closes the connection if no activity; the client must reconnect |
| Dead-emitter cleanup | Any failed `send` from the broker drops the emitter immediately |
| Multi-instance | The emitter pool is process-local — behind a multi-instance backend, frames committed on instance A do not reach a subscriber on instance B. The frontend's fallback poll (§4) is the safety net. |
| Reconnect protocol | No `Last-Event-ID` support — on reconnect, the frontend must refetch `/sessions/me` once to catch up. |

### 3.3 Frame format

Every business frame uses the SSE event name `roll-worker-lines-changed` and carries a small JSON refresh trigger:

```
event: roll-worker-lines-changed
data: {
  "type": "ROLL_MOUNTED",
  "palletizingLineId": 1,
  "version": 42,
  "eventId": "8e7c5d3a-1234-...-ab",
  "occurredAt": "2026-05-23T07:15:00.123Z"
}
```

- `type` — one of the reasons listed in §3.4. Use it to log / debug; do not branch business logic on it.
- `palletizingLineId` — server-side key for the affected line. The frontend can short-circuit the refetch if it holds no session on that line, OR it can always refetch `/sessions/me` (recommended, since the response is small and the worker's lines change rarely).
- `version` — process-local monotonic counter, ordering hint only. Not authoritative.
- `eventId` — UUID used by the broker for LRU dedupe. The frontend can ignore it.
- `occurredAt` — server-side UTC instant.

The frame is intentionally NOT authoritative state — it is only a refresh trigger. The REST `/sessions/me` is the single source of truth.

### 3.4 Event types the Roll Worker App will receive

| `type` | Fired by | What changed | Frontend action |
| --- | --- | --- | --- |
| `ROLL_MOUNTED` | `RollScanService.mount()` after a successful roll mount | The mounted roll on the named palletizing line just changed (or a roll is now mounted where none was before) | Refetch `/sessions/me`, re-render the per-line page |
| `ROLL_CONSUMED` | `PreviousRollResolutionService.{fullConsume,returnRemaining,sendRemainingToGrinding}` | The mounted roll on the named line was just closed (full consume / partial return / grinding) | Refetch `/sessions/me`. The `currentRoll*` fields will be null after this event. |
| `ROLLS_EMPLOYEE_CHANGED` | `RollWorkerSessionService.{authenticate,authenticateBatch,logout,endSessionsForShiftLine,logoutAllForOperator}` | A roll worker joined or left the named line | Refetch `/sessions/me`. If the line is yours and the change was someone else taking it over, your session was REPLACED — your token will start returning 401 on the next call. |
| `OPERATOR_SESSION_ENDED` | `ThermoformingShiftLineService.doRemoveShiftLine` | A thermoforming operator ended their shift on the named line | Refetch `/sessions/me`. Your roll-worker session on that line will also have ended (cascaded with `END_REASON_SHIFT_LINE_ENDED`). If `/sessions/me` no longer lists the line, drop the page from the PageView. |
| `LINE_STATE_CHANGED` | Coarse fallback — fires for admin plan-item add / edit / cancel / reorder / delete, and for operator-initiated plan-item close | The line's plan or product context changed | Refetch `/sessions/me`. The `currentPlanItemProduct*` fields may change. |
| `PALLET_CREATED`, `PALLET_QUANTITY_UPDATED`, `PALLET_VOIDED`, `PALLETIZING_EMPLOYEE_CHANGED`, `HANDOVER_CHANGED`, `SESSION_CHANGED`, `FALET_CHANGED` | Various palletizing-side flows | Not relevant to the Roll Worker App's "mounted roll" view | Frontend can ignore by `type`, OR (recommended) just refetch `/sessions/me` unconditionally — the response is small and idempotent. |

### 3.5 Recommended frontend handler

```
on every frame from /events:
  if (frame.type is in [PALLET_*, PALLETIZING_EMPLOYEE_CHANGED, FALET_CHANGED]) {
    optionally skip the refetch for performance
  }
  // Debounce ~200-300ms in case a burst of frames lands close together
  schedule a refetch of /sessions/me
  on refetch success:
    rebuild the per-line tabs / PageView from response.lines
```

## 4. Polling strategy for frontend

This section is the most important behaviour change. The current frontend polls regardless of SSE state — that must stop.

### 4.1 Required behaviour

| Condition | What the frontend MUST do |
| --- | --- |
| SSE is **connected** (handshake received, last frame or `ping` within the timeout window) | Do NOT run any repeating REST poll. The SSE channel is the change feed. |
| SSE is **disconnected** (initial connect failed, server closed the connection, network error, or no `ping` for > 30 s) | Start a fallback poll of `/sessions/me` every **2 seconds**. |
| SSE **reconnects** | (a) Refetch `/sessions/me` once immediately to catch up on missed frames. (b) Stop the fallback poll. |
| SSE reconnect attempts are failing repeatedly | Use exponential backoff on the **reconnect attempt cadence** (e.g., 1 s → 2 s → 4 s → 8 s, capped at 30 s). The fallback poll cadence stays at 2 s — those are two separate timers. |

### 4.2 Concretely (pseudo-code)

```
state:
  sseConnected = false
  reconnectBackoff = 1s
  fallbackPollTimer = null
  ssePingDeadline = null

start():
  openSse()
  if (!sseConnected) startFallbackPoll()

openSse():
  attempt EventSource(/events)
  onOpen:
    sseConnected = true
    reconnectBackoff = 1s
    stopFallbackPoll()
    refetchOnce(/sessions/me)
  onMessage(frame):
    ssePingDeadline = now() + 30s
    debouncedRefetch(/sessions/me)
  onError | onClose:
    sseConnected = false
    startFallbackPoll()
    schedule(openSse, reconnectBackoff)
    reconnectBackoff = min(reconnectBackoff * 2, 30s)

startFallbackPoll():
  if (fallbackPollTimer != null) return
  fallbackPollTimer = setInterval(2s, () => refetch(/sessions/me))

stopFallbackPoll():
  clearInterval(fallbackPollTimer)
  fallbackPollTimer = null
```

### 4.3 Why 2 seconds?

The SSE backend already publishes AFTER_COMMIT, so the worst-case latency from a real DB change to a refresh trigger arriving on the client is dominated by the network — sub-second on a healthy LAN. A 2 s fallback poll keeps the perceived latency ≤ ~3 s while keeping idle traffic low when SSE is healthy (zero polls).

## 5. Line management flow

### 5.1 Initial login

1. App opens `/events` (SSE) and `GET /bootstrap` in parallel.
2. App renders the line picker from the bootstrap response.
3. Worker selects one or more shift-lines and enters PIN.
4. App calls `POST /sessions/start-batch` (or `/shift-lines/{id}/roll-worker-auth` for single-line). Server returns one `sessionToken` per line.
5. App stores all session tokens locally (the raw token is returned exactly once per session — it is never re-issuable).
6. App immediately calls `GET /sessions/me` (passing any one of the tokens in `X-Session-Token`). This is the authoritative post-login state.
7. App renders per-line tabs / PageView from `response.lines`.

### 5.2 Add another line while already logged in

1. Worker taps "إضافة خط آخر".
2. App calls `GET /sessions/me/joinable-lines` (passing any existing token).
3. App renders the picker.
4. Worker selects one or more lines and re-enters PIN.
5. App calls `POST /sessions/start-batch` with the new line ids.
6. App stores the new session tokens alongside existing ones.
7. App refetches `/sessions/me` (an SSE `ROLLS_EMPLOYEE_CHANGED` frame will fire too, but the refetch is the authoritative path).

### 5.3 Leave one specific line

1. Worker taps "تسجيل خروج من الخط الحالي" on the active per-line page.
2. App calls `POST /shift-lines/{shiftLineId}/roll-worker-logout` with `{ "sessionToken": "<that line's token>" }`.
3. App discards that token from local storage.
4. App refetches `/sessions/me`. If the worker still has at least one ACTIVE session the bottom nav / PageView shrinks to the remaining lines. If they have zero sessions left, the app navigates back to the picker.

### 5.4 Leave all lines

1. Worker taps "تسجيل خروج من جميع الخطوط".
2. App calls `POST /sessions/leave-all` (any one of the tokens in `X-Session-Token`).
3. Server returns `204 No Content`.
4. App discards every stored session token and navigates back to the picker.

### 5.5 State after each operation

| Operation | `/sessions/me.lines` length after | SSE frame fired |
| --- | --- | --- |
| Single-line login | +1 | `ROLLS_EMPLOYEE_CHANGED` for the new line |
| Batch login (N lines) | +N | N × `ROLLS_EMPLOYEE_CHANGED` (one per line) |
| Leave one line | −1 | 1 × `ROLLS_EMPLOYEE_CHANGED` |
| Leave all | 0 | N × `ROLLS_EMPLOYEE_CHANGED` (one per line freed) |
| Thermoforming operator ends shift-line where this worker is active | −1 | 1 × `OPERATOR_SESSION_ENDED` (the roll-worker session is cascaded to ENDED with `END_REASON_SHIFT_LINE_ENDED`) |
| Roll mount on one of the worker's lines | unchanged; `currentRoll*` populated | 1 × `ROLL_MOUNTED` |
| Roll close (full / return / grinding) | unchanged; `currentRoll*` becomes null | 1 × `ROLL_CONSUMED` |
| Plan item closed by operator → next product on a line | unchanged; `currentPlanItemProduct*` updates | 1 × `LINE_STATE_CHANGED` (via the existing legacy-fallback listener) |

## 6. State model

### 6.1 Roll worker session

- Entity: `RollWorkerSession` (table `roll_worker_sessions`, V67).
- Bound to one `thermoforming_shift_line`. One ACTIVE session per shift-line at a time (DB unique constraint).
- Status: `ACTIVE` → `REPLACED` (someone else logged in on the same line) or `ENDED`.
- End reasons: `MANUAL_LOGOUT`, `SHIFT_LINE_ENDED`, `REPLACED_BY_NEW_AUTH`, `EXPIRED`.
- Same operator can hold multiple ACTIVE sessions across different shift-lines simultaneously — no cap.
- Token: raw UUID returned at auth time, only SHA-256 hash persisted (`session_token_hash`). Raw token is never recoverable.

### 6.2 Line assignment

- "Assignment" is implicit: an ACTIVE `RollWorkerSession` row for `(operatorId, shiftLineId)` IS the assignment. There is no separate assignment table.
- Adding a line = opening a new session (via `/roll-worker-auth` or `/sessions/start-batch`).
- Removing a line = ending the session (via `/roll-worker-logout` or `/sessions/leave-all`).

### 6.3 Active / inactive line

- A `ThermoformingShiftLine` has its own status (`ACTIVE` / `ENDED`). The Roll Worker App only sees ACTIVE shift-lines in `/sessions/me`, `/joinable-lines`, and `/bootstrap`.
- When a thermoforming operator ends a shift-line, `ThermoformingShiftLineService.doRemoveShiftLine` cascades: it ends every active roll-worker session on the line with `END_REASON_SHIFT_LINE_ENDED`, releases palletizing authorization, fires `OPERATOR_SESSION_ENDED`, and marks the shift-line `ENDED`. The roll-worker app sees this as a single SSE frame; the worker's token for that line will start returning 401.

### 6.4 Mounted roll state

- Per palletizing line, tracked by `RollConsumptionItem` (table `roll_consumption_items`) where `status = ACTIVE`.
- `RollConsumptionState.lastKnownWeightKg` is the authoritative current weight. The frontend MUST surface this exact column — do NOT fall back to `RollConsumptionItem.startWeightKg`.
- Mount = `RollScanService.mount()` creates an ACTIVE `RollConsumptionItem` + segment, sets state to `IN_CONSUMPTION`, writes a `MOUNTED` event, and (new) publishes `ROLL_MOUNTED` SSE.
- Close = `PreviousRollResolutionService.{fullConsume,returnRemaining,sendRemainingToGrinding}` closes the item + segment, transitions state to `CONSUMED` / `PARTIALLY_RETURNED` / `SENT_TO_GRINDING`, writes a `CLOSED_*` event, and (new) publishes `ROLL_CONSUMED` SSE.

### 6.5 Relationship to the thermoforming operator session

- The supervising thermoforming operator owns the shift on the line. Their session is `ThermoformingShift` / `ThermoformingShiftLine` — separate from the roll-worker session.
- The roll worker is **attribution-only** — every roll-consumption operation is stamped with both the supervising operator (audit trail) and the actor roll worker (per-action attribution).
- When the supervising operator ends their shift-line, the roll-worker session is cascaded to `ENDED` (see §6.3).
- When a roll worker leaves, the supervising operator's shift is unaffected.

### 6.6 What changes when the thermoforming operator ends their shift

In one transaction:
1. Every ACTIVE `RollWorkerSession` on the shift-line is set to `ENDED` with `END_REASON_SHIFT_LINE_ENDED`.
2. Every ACTIVE palletizer session on the shift-line is ended similarly.
3. The palletizing-line authorization is released.
4. The shift-line is marked `ENDED` with the operator-supplied end reason.
5. `OPERATOR_SESSION_ENDED` event is published (AFTER_COMMIT) to:
   - The palletizing operator dashboard SSE
   - The Roll Worker App's `/events` SSE
6. A legacy `LineStateChangedEvent` is also published for older listeners; it is deduped by the fallback listener so the Roll Worker App only sees one frame.

The Flutter app sees: one SSE frame (`type: OPERATOR_SESSION_ENDED, palletizingLineId: <id>`) → refetch `/sessions/me` → the line is gone from `response.lines` → drop the corresponding PageView page → if `lines` is now empty, navigate to the picker.

## 7. Error handling and Arabic messages

Backend returns errors via the existing `ApiResponse` envelope:

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT",
    "message": "Roll type TT-1S B250 White is not allowed for product Red 20kg.",
    "details": null
  }
}
```

The `message` is English. The Flutter app maps `error.code` to an Arabic string — the table below is the authoritative mapping. Backend will not change this contract.

### 7.1 Roll mount errors (the "cannot mount roll" dialog)

| Error code | HTTP | Recommended Arabic message | Notes |
| --- | --- | --- | --- |
| `THERMOFORMING_SHIFT_LINE_NOT_FOUND` | 404 | "الخط غير موجود. يرجى تحديث الشاشة." | Stale shift-line id |
| `THERMOFORMING_SHIFT_LINE_NOT_ACTIVE` | 409 | "هذا الخط لم يعد نشطاً. يرجى تحديث الشاشة." | Shift was ended between the refetch and the action |
| `PRODUCTION_PLAN_ITEM_REQUIRED` | 409 | "لا يوجد منتج نشط على هذا الخط. يرجى مراجعة المشرف لإضافة عنصر إلى خطة الإنتاج." | No active plan item — roll cannot be mounted |
| `ROLL_NOT_FOUND` | 404 | "الرول غير موجود. تأكد من رقم الرول." | Bad QR / typed number |
| `ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT` | 409 | "نوع الرول غير مسموح للمنتج الحالي على هذا الخط." | The "cannot mount" dialog the user reported |
| `ROLL_CURING_MINIMUM_NOT_MET` | 409 | "هذا الرول لم يكتمل فترة الحضانة الدنيا بعد." | Roll too fresh to mount (per type policy) |
| `ROLL_BLOCKED` | 409 | "هذا الرول محظور إدارياً ولا يمكن استخدامه." | Admin blocked the roll |
| `ROLL_ALREADY_CONSUMED` | 409 | "هذا الرول مستهلك بالفعل." | Final state (CONSUMED / PARTIALLY_RETURNED / SENT_TO_GRINDING) |
| `ROLL_ACTIVE_ON_ANOTHER_LINE` | 409 | "هذا الرول مركّب حالياً على خط آخر." | Another shift-line owns it |

### 7.2 Roll close errors (full consume / return / grinding)

| Error code | HTTP | Recommended Arabic message |
| --- | --- | --- |
| `NO_ACTIVE_ROLL_ON_LINE` | 409 | "لا يوجد رول مركب حالياً على هذا الخط." |
| `INVALID_REMAINING_ROLL_WEIGHT` | 400 | "الوزن المتبقي غير صالح. يجب أن يكون بين صفر ووزن الرول الحالي." |
| `NO_OPEN_SEGMENT_ON_ITEM` | 500 | "خطأ داخلي في حالة الرول. يرجى تحديث الشاشة وإعادة المحاولة." |

### 7.3 Session / auth errors

| Error code | HTTP | Recommended Arabic message |
| --- | --- | --- |
| `ROLL_WORKER_SESSION_REQUIRED` | 400/401/403/404 | "انتهت الجلسة. يرجى تسجيل الدخول من جديد." (treat any of the four statuses the same way) |
| `ROLL_WORKER_NOT_ALLOWED` | 403 | "هذا الموظف غير مخوّل للعمل كموظف رولات." |
| `OPERATOR_PIN_INVALID` | 401 | "رمز PIN غير صحيح." |
| `OPERATOR_PIN_LOCKED` | 409 | "تم قفل الحساب لعدد كبير من المحاولات الخاطئة. يرجى مراجعة المشرف." |
| `ROLL_WORKER_SESSION_BATCH_EMPTY` | 400 | "يجب اختيار خط واحد على الأقل." |
| `ROLL_WORKER_SESSION_LINE_DUPLICATE` | 400 | "تم اختيار نفس الخط أكثر من مرة." |
| `ROLL_WORKER_SESSION_LINE_INACTIVE` | 409 | "أحد الخطوط المختارة لم يعد نشطاً." |
| `ROLL_WORKER_SESSION_LINE_USED_BY_OTHER_WORKER` | 409 | "أحد الخطوط مستخدم بالفعل من قبل موظف آخر." (use `details.ownerOperatorName` to render the conflicting worker's name) |

### 7.4 Transport errors (frontend should treat these as transient)

| Condition | Recommended Arabic message |
| --- | --- |
| SSE disconnected | (silent — switch to the 2 s fallback poll; no user-visible dialog) |
| SSE reconnecting after error | (silent — show a small "إعادة الاتصال…" badge if useful, otherwise nothing) |
| `/sessions/me` returned 5xx three times in a row | "تعذّر الاتصال بالخادم. يتم إعادة المحاولة…" |

## 8. Frontend UX requirements

This section is the punch list the Flutter Roll Worker App must implement against. None of these require backend changes.

1. **SSE-first updates**: when SSE delivers a frame, the per-line view must update within ~500 ms (frame → debounced refetch → re-render). No reliance on polling.
2. **Smart polling fallback**: as specified in §4 — never poll while SSE is connected; 2 s poll when SSE is down; refetch-once on reconnect.
3. **Add another line after login**: implement the flow in §5.2 using `/sessions/me/joinable-lines` and `/sessions/start-batch`.
4. **Leave one specific line**: §5.3.
5. **Leave all lines**: §5.4, single call to `/sessions/leave-all`.
6. **Horizontal swipe between lines**: a `PageView` over `response.lines`, with one page per ACTIVE session.
7. **Bottom navigation synced with swipe**: when the user swipes the PageView, the bottom-nav highlight follows; when the user taps a bottom-nav item, the PageView animates to that page. They share one selected-index controller.
8. **Per-line color theme / accent**: assign a distinct accent color to each line (e.g., from `palletizingLineCode` or a stable id-modulo-N hash) so the worker can tell at a glance which line they are looking at. Use the same color on the bottom-nav item AND the line header.
9. **All dialog / error / banner copy in Arabic**, sourced from the §7 mapping. No English strings should leak through.
10. **Avoid stale state**: never compute counts or "currently mounted roll" locally — always re-render from the latest `/sessions/me` response.
11. **Token storage**: store each line's session token in secure storage. Use ANY one of them as the `X-Session-Token` for the post-login endpoints.
12. **Reauthentication on 401 from `/sessions/me`**: if all of the worker's tokens have been replaced (race with another device), the app must fall back to the picker.

## 9. Testing checklist

### 9.1 Backend tests (added in this change set, all pass)

- [x] `RollScanServiceTest.RollMountedEvent` — `ROLL_MOUNTED` is published once per successful mount, never on validation failure, never on incompatible roll.
- [x] `PreviousRollResolutionServiceTest.RollConsumedEvent` — `ROLL_CONSUMED` is published once per close path (full / return / grinding); not published on validation failure.
- [x] `RollWorkerSessionServiceTest.LogoutAllForOperator` — `logoutAllForOperator` ends N sessions with `MANUAL_LOGOUT`, publishes N `ROLLS_EMPLOYEE_CHANGED` events, is idempotent with zero ACTIVE sessions, skips rows that lost the row-lock race (does not overwrite `SHIFT_LINE_ENDED` with `MANUAL_LOGOUT`), no-ops on null operatorId.
- [x] `RollWorkerSessionControllerTest.MyActiveLines / JoinableLines / LeaveAll` — controller delegation, propagation of `ROLL_WORKER_SESSION_REQUIRED`, 204 on leave-all, 401 when the resolved session has no operator on the row.
- [x] Existing `RollWorkerLineEventsSseBrokerTest` — passive listener still works.
- [x] Existing `OperatorDashboardSseBrokerTest` — palletizing-side dashboard not regressed.

### 9.2 Backend manual smoke (requires MySQL on 3307)

- [ ] `./mvnw spring-boot:run`.
- [ ] `curl -N -H "X-Device-Key: $KEY" http://localhost:8080/api/v1/thermoforming-roll-app/events` — observe the initial `connected` frame, then `ping` comments every 25 s.
- [ ] Scan a roll via the thermoforming flow — observe a `roll-worker-lines-changed` frame with `type=ROLL_MOUNTED, palletizingLineId=<id>`.
- [ ] Full-consume the roll — observe a frame with `type=ROLL_CONSUMED`.
- [ ] End the thermoforming operator's shift-line — observe `type=OPERATOR_SESSION_ENDED`.
- [ ] Auth as a roll worker on two lines (batch), then `POST /sessions/leave-all` — observe two `type=ROLLS_EMPLOYEE_CHANGED` frames.

### 9.3 Frontend verification (Flutter, real device)

- [ ] App connects to `/events` on launch; observe the `connected` frame in logs.
- [ ] While SSE is connected, app makes ZERO repeating REST calls (only one `/sessions/me` per SSE frame received).
- [ ] Disable network → app starts polling `/sessions/me` every ~2 s.
- [ ] Re-enable network → SSE reconnects, fallback poll stops, ONE catch-up `/sessions/me` fires.
- [ ] End a thermoforming operator shift in the Thermoforming Operator App → Roll Worker App removes the line from PageView within ≤ 1 s (no manual refresh).
- [ ] Tap "إضافة خط آخر" → joinable-lines picker shows ONLY lines the worker doesn't already own → multi-select + PIN → new tab appears in PageView immediately.
- [ ] Tap "تسجيل خروج من الخط الحالي" → that single tab disappears; other tabs remain; if it was the last tab, app navigates to picker.
- [ ] Tap "تسجيل خروج من جميع الخطوط" → all tabs gone, app at picker, returns 204.
- [ ] Swipe left/right → bottom nav highlight follows; tap a different bottom-nav item → PageView animates.
- [ ] Each line tab uses a distinct accent color.
- [ ] Attempt to mount an incompatible roll → "نوع الرول غير مسموح للمنتج الحالي على هذا الخط." (Arabic, not English).

## 10. Open risks

1. **Single-instance SSE pool** — the `RollWorkerLineEventsSseBroker` emitter pool is in-memory. Behind a multi-instance deployment a frame committed on instance A will not reach a subscriber on instance B. The 2 s fallback poll is the safety net. Documented at `RollWorkerLineEventsSseBroker.java:52-57`.
2. **No `Last-Event-ID` resume** — on reconnect the client cannot replay missed frames. Mitigated by always refetching `/sessions/me` once on reconnect.
3. **`/sessions/me` reuses `RollWorkerSessionService.requireAnyActiveSession` for token resolution** — that method bumps `lastUsedAt` on the matched session. So every `/sessions/me` call also acts as a session-keepalive. Acceptable, matches existing roll-production-app pattern.
4. **Pre-existing DataSeeder issue in working tree** — the `DataSeeder.seedThermoformingLines()` method (added by an earlier uncommitted change in the working tree, NOT by this slice) queries `thermoforming_lines` at startup before H2 has created the table in some test profiles. This causes ~395 ApplicationContext load failures in `./mvnw test` runs that include `@SpringBootTest`-style tests. **It is not caused by this slice** (the baseline at HEAD without any uncommitted changes shows it too once the DataSeeder change is applied). Recommend separately: guard `seedThermoformingLines` with `@ConditionalOnProperty` or move its body into `@Transactional` so it runs after schema init, or add `@DependsOn(... entityManagerFactory ...)` — out of scope for this PR.
5. **Frontend must not hardcode line state** — every UI element that shows mounted roll, current product, or line lifecycle must come from `/sessions/me`. Local computation of state is forbidden (see CLAUDE.md §16 on "no fake state").

---

# Prompt for Frontend AI Agent

Copy the section below verbatim into the Flutter Roll Worker App's AI agent.

---

You are updating the Flutter "Roll Worker App" (تطبيق موظف الرولات). The backend has already been updated to support real-time SSE events and a unified post-login state endpoint — your job is to wire the frontend up to use them correctly, plus implement the line-management UX the user asked for.

**Read this handoff first**: `docs/handoffs/ROLL_WORKER_APP_REALTIME_AND_LINE_MANAGEMENT_HANDOFF.md` in the backend repo. Every endpoint, SSE frame, error code, and recommended Arabic string is documented there. Do not guess.

## Hard requirements (do not skip any)

1. **SSE-first state updates**. Open `GET /api/v1/thermoforming-roll-app/events` once on app launch with `Accept: text/event-stream` and `X-Device-Key: <device key>`. On every frame, debounce ~250 ms then refetch `GET /api/v1/thermoforming-roll-app/sessions/me` (with `X-Session-Token: <any of the worker's tokens>`) and re-render. Do not branch business logic on the frame `type` — just refetch.

2. **Smart polling fallback**. Implement exactly this:
   - When SSE is connected: DO NOT run any repeating REST poll. Zero.
   - When SSE is disconnected: poll `/sessions/me` every 2 seconds.
   - On SSE reconnect: refetch `/sessions/me` ONCE to catch up, then stop the fallback poll.
   - Use exponential backoff for the SSE reconnect attempt cadence (1 s → 2 s → 4 s → 8 s, capped at 30 s). The fallback poll cadence stays at 2 s — these are two separate timers.
   The current frontend polls regardless of SSE state. Remove that behaviour.

3. **`/sessions/me` is the single source of truth** for the worker's state across all lines. Do not call `/shift-lines/{id}/roll-worker-session/current` in a loop — that endpoint exists but the new `/sessions/me` replaces the loop with one round-trip.

4. **When the thermoforming operator ends their session**, the Roll Worker App MUST update within ≤ 1 s without any user interaction. The SSE feed will deliver `OPERATOR_SESSION_ENDED` for the affected `palletizingLineId`. Your code must refetch `/sessions/me`, see the line is gone from `response.lines`, and drop the corresponding PageView page. If `response.lines` becomes empty, navigate the user back to the picker.

5. **Add another line while logged in**. Implement the "إضافة خط آخر" flow:
   - Tap → fetch `GET /api/v1/thermoforming-roll-app/sessions/me/joinable-lines` (header: `X-Session-Token: <any existing token>`).
   - Render the picker (uses the existing `RollWorkerShiftLineOptionResponse` shape).
   - Multi-select + PIN entry → `POST /api/v1/thermoforming-roll-app/sessions/start-batch` with `{ "pin": "...", "shiftLineIds": [...] }`.
   - Store the new per-line tokens alongside existing ones.
   - Refetch `/sessions/me` and append the new tabs to the PageView.

6. **Leave one specific line** ("تسجيل خروج من الخط الحالي"):
   - Call `POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-logout` with `{ "sessionToken": "<that line's token>" }` in the body.
   - Discard that token locally.
   - Refetch `/sessions/me`. If the worker still has at least one line, shrink the PageView; if zero, navigate to picker.

7. **Leave all lines** ("تسجيل خروج من جميع الخطوط"):
   - Call `POST /api/v1/thermoforming-roll-app/sessions/leave-all` with `X-Session-Token: <any token>`. Body empty.
   - Server returns 204.
   - Discard all tokens locally and navigate back to the picker.

8. **Localize all dialog / banner / error copy to Arabic**. The "cannot mount roll" dialog (currently English) must use the §7 mapping in the handoff. The most important ones for that dialog:
   - `ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT` → "نوع الرول غير مسموح للمنتج الحالي على هذا الخط."
   - `ROLL_CURING_MINIMUM_NOT_MET` → "هذا الرول لم يكتمل فترة الحضانة الدنيا بعد."
   - `ROLL_ALREADY_CONSUMED` → "هذا الرول مستهلك بالفعل."
   - `ROLL_ACTIVE_ON_ANOTHER_LINE` → "هذا الرول مركّب حالياً على خط آخر."
   - `ROLL_BLOCKED` → "هذا الرول محظور إدارياً ولا يمكن استخدامه."
   - `PRODUCTION_PLAN_ITEM_REQUIRED` → "لا يوجد منتج نشط على هذا الخط. يرجى مراجعة المشرف لإضافة عنصر إلى خطة الإنتاج."
   - `ROLL_NOT_FOUND` → "الرول غير موجود. تأكد من رقم الرول."
   Map by `error.code` in the JSON envelope, NOT by `error.message`. The English `error.message` may change.

9. **Horizontal swipe between lines must work**. Use a `PageView` over `response.lines`. Make sure the gesture works on actual device (test scrolling sensitivity, scroll direction, RTL — Arabic layout may need `reverse: true` on the PageView so swipe-right goes to "next" tab naturally for an Arabic reader).

10. **Bottom navigation must stay in sync with swipe**. Share a single selected-index controller between the PageView (`onPageChanged`) and the BottomNavigationBar (`onTap`).

11. **Each line should have a distinct accent color**. Pick a stable mapping from `palletizingLineCode` (or `palletizingLineId % N`) to a color from a curated palette of at least 4 colors. Apply the accent to:
    - The line header / app bar background or border.
    - The bottom-nav item icon / label tint when selected.
    - The scan button color (subtle).
    This lets the worker tell which line they are looking at at a glance.

12. **Verify on a real device before declaring done**. Cover the checklist in §9.3 of the handoff. Specifically:
    - SSE connects and the per-line state updates without polling.
    - Disconnect network → app polls every ~2 s.
    - Reconnect → ONE catch-up `/sessions/me`, then polls stop.
    - End the thermoforming operator's shift → the line disappears from your PageView within ≤ 1 s.
    - Add another line, leave one line, leave all — all flows behave as in §5 of the handoff.
    - Swipe works, bottom nav syncs, accent colors visible.
    - "Cannot mount roll" dialog shows the Arabic string mapped from the error code.

## Constraints (do not violate)

- **Do NOT change the backend API contract**. Use the endpoints exactly as documented. If something feels missing, re-read §2 and §3 of the handoff before assuming.
- **Do NOT hardcode any line state, mount state, or product context**. Always re-render from the latest `/sessions/me` response. The current behaviour of "show a fake placeholder while loading" is OK; computing real state locally is not.
- **Do NOT poll when SSE is connected**. The user explicitly called this out as a regression — it must stop.
- **Do NOT re-implement product switching**. Active product is plan-driven only — there is no UI for the worker to change product. Show `currentPlanItemProductName` from `/sessions/me`; that's it.
- **Do NOT call deprecated endpoints**. The legacy `/product-switch`, `/select-product`, and `/product-options` endpoints have been removed backend-side.
- **Tokens are returned exactly once**. The raw `sessionToken` is in the auth response, never again. Store it securely. If you lose it, the worker must log in again to that line.

When you are done, run the app on a real device, walk through §9.3, and report which checks pass.
