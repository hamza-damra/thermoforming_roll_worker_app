# Frontend Handoff — Roll Worker App — Takeover With Weight Declaration + Keep-Mounted Handover (V104)

> Audience: the **Roll Worker App** frontend AI agent (Flutter).
> Backend status: implemented and unit-tested on the backend; **MySQL integration verification of the V104 migration is still pending** (no Docker/MySQL in the build env). Treat the contract below as final; the only open backend item is DB-level migration verification, which does not change this contract.
> Backend module: `ps.taleeb.taleebbackend.thermoformingrollapp` (+ `thermoforming` domain). All endpoints are under `/api/v1/thermoforming-roll-app/**` and behind the device-key chain (`X-Device-Key`).

---

## App Impact Matrix

| App | Affected? | Reason | Required Handoff File |
|---|---:|---|---|
| Warehouse App | No | Pallet movement / warehouse flows are untouched. No roll-worker contract is consumed there. | — |
| Admin App (mobile) | No | The per-worker consumed-kg display changed on the **Thymeleaf web dashboard** (server-rendered, not a Flutter app). The Admin mobile app has no roll-worker session/attribution contract that changed. If it later surfaces roll-worker productivity it should prefer consumed-kg, but nothing breaks today. | — |
| Palletizing App | No | Palletizer sessions (`PalletizerSession`) are a separate subsystem; takeover/keep-mounted is roll-worker only. The shared `ROLLS_EMPLOYEE_CHANGED` / `LINE_STATE_CHANGED` SSE still fire as before. | — |
| **Roll Worker App** | **Yes** | New logout option, new keep-mounted handover endpoint, login now can return `ROLL_WORKER_TAKEOVER_REQUIRED`, new takeover endpoint with `clientRequestId`, new consumed-kg/rolls-contributed summary fields. | `docs/frontend-handoffs/FRONTEND_HANDOFF_ROLL_WORKER_APP_TAKEOVER_WITH_WEIGHT_DECLARATION.md` (this file) |
| Roll Production App | No | Roll production/printing is upstream of consumption; no contract changed. | — |
| Operator App (Thermoforming) | No | Keep-mounted intentionally does **not** publish the handover-checklist "no mounted roll" event (the roll stays mounted), so the operator handover-checklist state is unchanged. No operator contract changed. | — |

---

## 1. Executive Summary

**What changed in the backend (V104):**

- A mounted roll is **no longer credited to a single worker**. Consumption is split across the workers who actually worked it, by **consumed weight** = `weight when they took over − weight when they stopped`. Each worker is credited only for the kilograms they personally consumed. This is stored in a new per-worker history table (`roll_worker_consumption_segments`).
- **Normal logout (current worker)** gains a new **first** option: **"Roll Remains Mounted For Next Worker"** — the leaving worker declares the current remaining weight, is credited their consumed interval, and the roll stays mounted (NOT closed/returned/ground) for whoever comes next. The leaving worker is logged out in the same call.
- **Takeover With Weight Declaration (incoming worker)** — when a different worker logs into a line whose previous worker left a mounted roll **unresolved**, the backend no longer dead-ends the login. It returns `ROLL_WORKER_TAKEOVER_REQUIRED`. The incoming worker then resolves the mounted roll (crediting the **previous** worker for what was consumed) and takes the line.
- **Consumed kg is the primary worker-productivity metric**; "rolls contributed to" is secondary.

**Why the app must change:** the login contract can now return a new error/flow code, there are two new endpoints, the logout decision sheet has a new option in a fixed order, and the summary payload has new fields. Old app versions will mishandle `ROLL_WORKER_TAKEOVER_REQUIRED` (they'll show a generic error and the worker will be stuck — exactly the production incident this fixes).

**Required before rollout?** The frontend change is **required to fully realize the feature**, but the backend is **backward-tolerant** (see §13): old apps keep working for the *unchanged* paths; they just can't perform takeover or keep-mounted handover.

---

## 2. Affected App

**Roll Worker App** (Flutter), the device app operated by عامل الرولات.

Explicitly **not** affected: Warehouse App, Palletizing App, Roll Production App, Operator App, Admin mobile App (see matrix).

---

## 3. Business Context

A thermoforming line runs continuously; rolls are mounted and consumed over long shifts, often spanning multiple roll workers. Previously the whole roll was credited to whoever mounted it, so a worker who actually consumed most of a roll got no credit, and a worker who left a roll mounted blocked the next worker entirely (login was rejected with "line used by another worker").

Two real-floor situations are now handled:

1. **Graceful handover** — Worker A is leaving but the roll is not finished. A taps "Roll Remains Mounted For Next Worker", enters the current weight, gets credited for what A consumed, and logs out. Worker B logs in later and continues the same mounted roll.
2. **Abandoned roll (takeover)** — Worker A left without resolving the mounted roll (closed the app, lost the device, crashed). Worker B logs in, the backend says "takeover required", B sees who left the roll and declares the current physical weight; **A is credited** for what was consumed up to that weight, and B takes over (either continuing the roll or closing it).

In both cases the consumed weight is attributed to the worker who actually consumed it, never to the incoming declarer.

---

## 4. Backend Contract Changes

All responses use the standard envelope:

```jsonc
// success
{ "success": true,  "data": <T>, "error": null }
// failure
{ "success": false, "data": null, "error": { "code": "ERROR_CODE", "message": "...", "details": { ... } } }
```

All endpoints require header `X-Device-Key`. Endpoints that act on an existing session also require `X-Session-Token`. `Content-Type: application/json`.

### 4.1 NEW — Keep-Mounted Handover (normal logout option 1)

```
POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/previous-roll/keep-mounted-handover
Headers: X-Device-Key, X-Session-Token   (the CURRENT worker's session token)
```

Request body (same shape/validation as return/grinding):

```json
{ "remainingWeightKg": 60.0 }
```

Success response `data`:

```json
{
  "rollId": 12345,
  "generatedRollId": "777000000001",
  "finalState": "IN_CONSUMPTION",
  "consumedWeightKg": 40.000,
  "currentWeightKg": 60.000,
  "rollRemainsMounted": true
}
```

- `consumedWeightKg` = what THIS (current) worker consumed = `lastKnownWeight − remainingWeightKg`.
- `currentWeightKg` = the new mounted-roll weight the next worker continues from.
- **Side effect: this call ENDS the current worker's session atomically.** The roll stays mounted/ACTIVE. After success the app must clear its session token and return to the PIN screen. **Do NOT call `roll-worker-logout` afterwards** (the session is already ended).

Validation / errors (HTTP status in `details`/status):

- `remainingWeightKg` must be non-null and `>= 0` → else `INVALID_REMAINING_ROLL_WEIGHT` (400).
- `remainingWeightKg` must be `<=` the current mounted-roll weight (`lastKnownWeightKg`) → else `INVALID_REMAINING_ROLL_WEIGHT` (400) with message naming the current weight.
- No roll mounted on the line → `NO_ACTIVE_ROLL_ON_LINE` (409).
- Invalid/missing/wrong-line session token → `ROLL_WORKER_SESSION_REQUIRED` (400/401/403/404).

### 4.2 CHANGED — Login / session start now signals takeover

Existing endpoints (unchanged paths):

```
POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-auth   (single line)
POST /api/v1/thermoforming-roll-app/sessions/start-batch                          (multi-line picker)
```

New behavior when a **different** worker tries to enter a line that already has an ACTIVE session:

- **No roll mounted** → the previous session is cleanly replaced and a new session is returned (normal success). No takeover needed.
- **A roll is mounted** → the call **fails** with:

```jsonc
{
  "success": false,
  "data": null,
  "error": {
    "code": "ROLL_WORKER_TAKEOVER_REQUIRED",   // HTTP 409
    "message": "Shift-line 80 has a mounted roll not closed by Mohammad; takeover resolution is required.",
    "details": {
      "shiftLineId": 80,
      "previousWorkerName": "محمد سنتريسي",     // use this in the dialog
      "previousWorkerOperatorId": 99,
      "lastKnownWeightKg": 100.000,             // may be null on legacy data
      "generatedRollId": "777000000001"
    }
  }
}
```

- The app must detect `error.code == "ROLL_WORKER_TAKEOVER_REQUIRED"` and open the **Takeover screen** (§5.2) instead of showing a generic error.
- For the **batch** picker: if any selected line returns this, the whole batch is rejected; resolve that line via the single-line takeover endpoint, then retry the batch.
- The legacy code `ROLL_WORKER_SESSION_LINE_USED_BY_OTHER_WORKER` is retained but is now only an internal/edge race signal; the user-facing path is `ROLL_WORKER_TAKEOVER_REQUIRED`.

### 4.3 NEW — Takeover With Roll Declaration

```
POST /api/v1/thermoforming-roll-app/sessions/takeover-with-roll-declaration
Headers: X-Device-Key      (NO session token — the incoming worker is not authenticated yet; PIN is in the body)
```

Request JSON:

```json
{
  "shiftLineId": 80,
  "incomingOperatorPin": "1234",
  "action": "ROLL_REMAINS_MOUNTED",   // or "FULL_CONSUMPTION_AND_CLOSE"
  "currentWeightKg": 60.0,            // REQUIRED only for ROLL_REMAINS_MOUNTED
  "clientRequestId": "b1c2...uuid"    // REQUIRED, idempotency key (see §6)
}
```

Success response `data`:

```json
{
  "alreadyProcessed": false,
  "sessionId": 950,
  "sessionToken": "raw-uuid-token-shown-once",
  "rollWorkerOperatorId": 5,
  "rollWorkerName": "باسم راضي",
  "thermoformingShiftLineId": 80,
  "palletizingLineId": 21,
  "action": "ROLL_REMAINS_MOUNTED",
  "rollClosed": false,
  "rollRemainsMounted": true,
  "currentWeightKg": 60.000,
  "previousWorkerName": "محمد سنتريسي"
}
```

- `sessionToken` is the **incoming worker's new session token**, returned once — store it exactly like the normal auth token.
- `FULL_CONSUMPTION_AND_CLOSE`: `rollClosed=true`, `rollRemainsMounted=false`, `currentWeightKg=null` — the previous worker is credited the whole `lastKnownWeightKg`; the incoming worker starts clean (no mounted roll).
- `ROLL_REMAINS_MOUNTED`: `rollClosed=false`, `rollRemainsMounted=true`, `currentWeightKg` echoed — the previous worker is credited `lastKnownWeightKg − currentWeightKg`; the incoming worker continues from `currentWeightKg`.
- `previousWorkerName` = the worker who was credited (display for confirmation).

Validation / errors:

- `shiftLineId`, `incomingOperatorPin`, `action`, `clientRequestId` are all required (bean validation → 400 with field message).
- `action == ROLL_REMAINS_MOUNTED` requires `currentWeightKg` (`>= 0`, `<= lastKnownWeightKg`) → else `INVALID_REMAINING_ROLL_WEIGHT` (400).
- PIN invalid / operator not roll-worker-enabled → `OPERATOR_PIN_INVALID` / `ROLL_WORKER_NOT_ALLOWED` (same as normal auth).
- Shift-line not found / not ACTIVE → `THERMOFORMING_SHIFT_LINE_NOT_FOUND` / `THERMOFORMING_SHIFT_LINE_NOT_ACTIVE`.
- No active session to take over, or the line was already taken over by someone else first → `ROLL_WORKER_SESSION_REQUIRED` (409). (Treat as "line state changed — refresh and re-evaluate".)
- No mounted roll anymore (e.g. it was just closed) for `FULL_CONSUMPTION_AND_CLOSE` → `NO_ACTIVE_ROLL_ON_LINE` (409).

### 4.4 CHANGED — Per-shift-line summary fields

```
GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/summary
```

New fields in `data` (additive; `@JsonInclude(NON_NULL)` so older clients ignore them):

```jsonc
{
  // ... existing fields ...
  "consumedWeightKgInSession": 142.500,   // PRIMARY metric: kg this session's worker consumed
  "rollsContributedInSession": 3,         // SECONDARY: distinct rolls with consumed > 0
  "completedRollsInSession": 3,           // existing (retained)
  "completedRollsByCurrentWorker": 3      // existing (retained)
}
```

- Show **`consumedWeightKgInSession` as the headline** worker metric; `rollsContributedInSession` as a secondary detail. Keep the existing count fields for back-compat during transition.
- `mountedRoll.lastKnownWeightKg` already reflects the current mounted-roll weight after any handover/takeover — the incoming worker should "continue from" this value with no extra plumbing.

### 4.5 SSE / refresh expectations

- No new SSE event types. The existing `ROLLS_EMPLOYEE_CHANGED` (operator-dashboard) and `LINE_STATE_CHANGED` still fire on keep-mounted, takeover, and the existing close flows. Keep-mounted intentionally does **not** fire the "no mounted roll" handover-checklist event (the roll stays mounted).
- After any successful keep-mounted/takeover/close, the app should re-fetch `GET .../summary` and `GET /sessions/me` (existing refresh behavior).

---

## 5. Required Frontend Screens / Dialogs

### 5.1 Normal logout decision sheet (current worker) — 4 options in EXACT order

Trigger: the current worker taps Logout while a roll is mounted on the line (`summary.mountedRoll != null`).

Show exactly these four options, in this order:

1. **الرول ما زال مركب للموظف التالي** → opens a weight prompt, then `POST .../previous-roll/keep-mounted-handover`. On success: logged out (session already ended) → PIN screen.
2. **استهلاك كامل وإغلاق الرول** → `POST .../previous-roll/full-consume` (no body) → then `POST .../roll-worker-logout` → PIN screen.
3. **إرجاع المتبقي** → weight prompt → `POST .../previous-roll/return` `{remainingWeightKg}` → then `roll-worker-logout` → PIN screen.
4. **إرسال للجرش** → weight prompt → `POST .../previous-roll/grinding` `{remainingWeightKg}` → then `roll-worker-logout` → PIN screen.

When NO roll is mounted, skip the sheet and call `roll-worker-logout` directly.

**Critical UX difference:** option 1 ends the session in one call (do NOT call logout after); options 2–4 do NOT end the session (call logout after the resolution succeeds).

Weight prompt for option 1:

- Title: **أدخل الوزن الحالي المتبقي على الرول**
- Numeric field (kg, up to 3 decimals), big keypad, validation `>= 0` and `<= currentWeight`.
- Helper: **سيتم احتساب الوزن المستهلك لك: {currentWeight} − {entered} = {diff} كغ**.

### 5.2 Takeover screen (incoming worker)

Trigger: login (`roll-worker-auth` or `start-batch`) returns `error.code == "ROLL_WORKER_TAKEOVER_REQUIRED"`.

Screen content (use `details` from the error):

- Title/message: **يوجد رول مركب لم يتم إغلاقه من: {previousWorkerName}**
- Subtitle: **الرجاء تحديد حالة الرول الحالية**
- Show `lastKnownWeightKg` and `generatedRollId` for context (e.g. **الوزن المسجّل: {lastKnownWeightKg} كغ — الرول: {generatedRollId}**).
- A clear note: **الوزن المستهلك سيُحتسب للموظف السابق ({previousWorkerName})، وليس لك.**

Exactly two options:

1. **استهلاك كامل وإغلاق الرول** → `action = FULL_CONSUMPTION_AND_CLOSE`. No weight needed. After success the incoming worker starts clean (no mounted roll).
2. **الرول ما زال مركب** → `action = ROLL_REMAINS_MOUNTED`. Prompt: **أدخل الوزن الحالي الموجود فعلياً على الرول** (numeric kg, `>= 0`, `<= lastKnownWeightKg`). After success the incoming worker continues from the declared weight.

Both submit to `POST /sessions/takeover-with-roll-declaration` with the incoming PIN (already entered at login), the action, the weight (option 2 only), and a single `clientRequestId`.

Loading: disable both buttons + show spinner while the call is in flight (anti double-submit, §6).

Success: store `sessionToken`, navigate into the line, then refresh summary + `/sessions/me`.

Error: see §9/§11.

---

## 6. Required Models / DTO Changes

New/updated client models (Dart):

- `RollWorkerTakeoverRequiredDetails` (parsed from `error.details` when code is `ROLL_WORKER_TAKEOVER_REQUIRED`): `shiftLineId:int`, `previousWorkerName:String`, `previousWorkerOperatorId:int?`, `lastKnownWeightKg:double?`, `generatedRollId:String?`.
- `RollWorkerTakeoverRequest`: `shiftLineId:int`, `incomingOperatorPin:String`, `action:RollWorkerTakeoverAction`, `currentWeightKg:double?`, `clientRequestId:String`.
- `RollWorkerTakeoverAction` enum: `FULL_CONSUMPTION_AND_CLOSE`, `ROLL_REMAINS_MOUNTED` (serialize as the exact uppercase strings).
- `RollWorkerTakeoverResponse`: `alreadyProcessed:bool`, `sessionId:int?`, `sessionToken:String?`, `rollWorkerOperatorId:int?`, `rollWorkerName:String?`, `thermoformingShiftLineId:int?`, `palletizingLineId:int?`, `action:String`, `rollClosed:bool`, `rollRemainsMounted:bool`, `currentWeightKg:double?`, `previousWorkerName:String?`.
- `RollWorkerHandoverResponse` (keep-mounted): `rollId:int`, `generatedRollId:String`, `finalState:String`, `consumedWeightKg:double?`, `currentWeightKg:double?`, `rollRemainsMounted:bool`.
- Summary model: add `consumedWeightKgInSession:double?` and `rollsContributedInSession:int`.

No fields were removed. `lastKnownWeightKg` and the weight fields can be null on legacy data — treat null as "unknown" and fall back gracefully.

---

## 7. Required Repository / API Client Changes

Add to the roll-worker API client:

- `keepMountedHandover(shiftLineId, sessionToken, remainingWeightKg)` → `POST .../previous-roll/keep-mounted-handover` → `RollWorkerHandoverResponse`. On success the session token is now invalid (logged out) — clear it.
- `takeoverWithRollDeclaration(RollWorkerTakeoverRequest)` → `POST /sessions/takeover-with-roll-declaration` → `RollWorkerTakeoverResponse`.
- Update the auth client (`roll-worker-auth`, `start-batch`) error mapping to surface `ROLL_WORKER_TAKEOVER_REQUIRED` with parsed `details`, distinct from generic auth failures, so the UI can branch into the takeover screen.

Error mapping: map `error.code` to typed failures — `takeoverRequired(details)`, `invalidWeight`, `noActiveRoll`, `sessionRequired/lineChanged`, `pinInvalid`, `notRollWorker`. Do not rely on `error.message` text (it is English/diagnostic); branch on `code`.

Retry/idempotency: the takeover call must reuse the same `clientRequestId` on retry (§6/§8).

---

## 8. Required Provider / State Management Changes

Add to the roll-worker session/line provider:

- `loading` flag for keep-mounted and takeover calls (drives spinner + button disable).
- `takeoverRequired` state holding the parsed `RollWorkerTakeoverRequiredDetails` (set when login returns the code).
- `pendingTakeover` holding the in-flight `RollWorkerTakeoverRequest` **including its `clientRequestId`**, so a retry reuses the same id; persist it across an app-resume if the call may have been in flight.
- `retrying` / `submitDisabled` flag to prevent double-submit.
- On success: store the new `sessionToken`, clear `takeoverRequired`/`pendingTakeover`, then trigger the existing post-action refresh (summary + `/sessions/me`).
- On keep-mounted success: clear the session token and route to PIN (do not keep stale session state).

---

## 9. Required UX Flow

**Keep-mounted handover (current worker):**
1. Worker taps Logout (roll mounted) → 4-option sheet.
2. Picks option 1 → weight prompt → validate locally (`0 ≤ x ≤ currentWeight`).
3. Submit → spinner. Success → toast **تم تسجيل استهلاكك ({consumedWeightKg} كغ). الرول ما زال مركب للموظف التالي.** → clear token → PIN screen.
4. Validation error from backend → show inline error, keep the prompt open, let the worker correct.
5. Network failure → show retry; the keep-mounted call is **not idempotent-keyed**, so on retry the app must first re-fetch the summary; if the session is already ended (the prior call may have succeeded) treat as success and route to PIN.

**Takeover (incoming worker):**
1. Worker enters PIN → login → backend returns `ROLL_WORKER_TAKEOVER_REQUIRED`.
2. App shows takeover screen with previous worker name + current weight + the credited-to-previous-worker note.
3. Worker picks an option (and enters weight for option 2) → generate ONE `clientRequestId` → submit → spinner + buttons disabled.
4. Success → store new token → enter the line → refresh.
5. Backend business error (`INVALID_REMAINING_ROLL_WEIGHT`, `NO_ACTIVE_ROLL_ON_LINE`, `ROLL_WORKER_SESSION_REQUIRED`) → show the mapped message; for "line changed/already taken over" offer "إعادة المحاولة" which re-fetches state (the takeover may no longer be required).
6. Network failure → retry with the **same** `clientRequestId`.
7. Cancel/back → discard `pendingTakeover` and its `clientRequestId`; return to PIN.

---

## 10. Arabic UI Text

- Logout sheet options (exact order): `الرول ما زال مركب للموظف التالي`, `استهلاك كامل وإغلاق الرول`, `إرجاع المتبقي`, `إرسال للجرش`.
- Keep-mounted weight prompt title: `أدخل الوزن الحالي المتبقي على الرول`.
- Keep-mounted success: `تم تسجيل استهلاكك ({x} كغ). الرول ما زال مركب للموظف التالي.`
- Takeover title: `يوجد رول مركب لم يتم إغلاقه من: {previousWorkerName}`; subtitle: `الرجاء تحديد حالة الرول الحالية`.
- Takeover credit note: `الوزن المستهلك سيُحتسب للموظف السابق، وليس لك.`
- Takeover options: `استهلاك كامل وإغلاق الرول`, `الرول ما زال مركب`.
- Takeover weight prompt: `أدخل الوزن الحالي الموجود فعلياً على الرول`.
- Takeover success (remains): `تم استلام الخط. تابع من الوزن {currentWeight} كغ.` / (close): `تم استلام الخط وإغلاق الرول. ابدأ رولاً جديداً.`
- Validation — weight too high: `الوزن المُدخل أكبر من الوزن الحالي للرول.`
- Validation — negative/empty: `الرجاء إدخال وزن صحيح (صفر أو أكثر).`
- Error — no active roll: `لا يوجد رول مركب على هذا الخط حالياً.`
- Error — line changed/already taken: `تغيّرت حالة الخط. الرجاء إعادة المحاولة.`
- Error — PIN invalid: `رقم سري غير صحيح.`
- Error — not roll worker: `هذا المستخدم غير مخوّل كموظف رولات.`
- Generic network: `تعذّر الاتصال. الرجاء إعادة المحاولة.`

Provide both `messages.properties` and `messages_ar.properties` only applies to the **backend Thymeleaf** side (already handled there); the Flutter app owns its own Arabic strings — the strings above are the source of truth.

---

## 11. Edge Cases

- **User double-taps** a takeover/keep-mounted button → disable buttons on first tap; the same `clientRequestId` (takeover) guarantees the backend ignores the duplicate.
- **Network lost after backend success** (takeover) → retry with the same `clientRequestId`; backend returns `alreadyProcessed: true` (no `sessionToken`). The app cannot recover the original token from this response — so on `alreadyProcessed`, **re-login with the incoming PIN** (the line is now owned by this operator, so login succeeds and issues a fresh token).
- **Network lost after backend success** (keep-mounted) → no idempotency key; re-fetch summary/`/sessions/me`; if the session is already ended, treat as success and go to PIN.
- **App resumes from background** mid-takeover → if `pendingTakeover` exists, re-submit with its stored `clientRequestId` (idempotent) or re-evaluate by re-login.
- **Declared weight > lastKnownWeightKg** → backend rejects with `INVALID_REMAINING_ROLL_WEIGHT`; also validate locally before submit.
- **Negative weight** → blocked locally + backend `INVALID_REMAINING_ROLL_WEIGHT`.
- **Session changed by another device** (someone else took over first) → `ROLL_WORKER_SESSION_REQUIRED` ("already taken over"); show "تغيّرت حالة الخط" and re-fetch; the takeover may no longer be required (now a clean login).
- **Backend says no active mounted roll anymore** → `NO_ACTIVE_ROLL_ON_LINE`; the roll was resolved meanwhile; re-login (clean) instead of takeover.
- **Duplicate `clientRequestId`** → backend returns `alreadyProcessed: true`; do not create a second segment; recover the session via re-login as above.
- **User cancels takeover screen** → discard `pendingTakeover` + `clientRequestId`; return to PIN; no backend call.

---

## 12. Testing Requirements

**Repository / API client tests:**
- keep-mounted handover request/response mapping; session token cleared on success.
- takeover request serialization (action enum exact strings; `currentWeightKg` omitted for full-consume); response mapping incl. `alreadyProcessed`.
- login error mapping: `ROLL_WORKER_TAKEOVER_REQUIRED` → typed `takeoverRequired(details)` with parsed details; other codes mapped distinctly.

**Provider / state tests:**
- takeover-required state set on the right error code; cleared on success/cancel.
- `clientRequestId` generated once per attempt and reused on retry; cleared on success/cancel.
- double-submit guarded.
- post-success refresh triggered.

**Widget tests:**
- logout sheet shows 4 options in the exact order only when a roll is mounted.
- option 1 ends session (no logout call after); options 2–4 call logout after.
- takeover screen renders previous worker name + current weight + credit note; two options; weight prompt only for "remains mounted"; weight validation.

**Manual smoke tests:**
- A mounts @100 → A keep-mounted @70 (A credited 30, logged out, roll mounted) → B logs in, summary shows mounted @70, B continues → B full-consume.
- A mounts @100, kills app → B logs in → takeover screen ("not closed by A") → "الرول ما زال مركب" @60 → A credited 40, B in line @60.
- Same as above but "استهلاك كامل" → A credited 100, roll closed, B clean.
- Re-submit a takeover with the same `clientRequestId` → no duplicate; recover via re-login.

**Regression checklist:**
- Old single-line/batch login on a free line still works unchanged.
- Existing full-consume/return/grinding + logout still work.
- Summary still renders for old data with null weight fields.

---

## 13. Backend Compatibility Notes

- **Required backend version:** the build that includes migration **V104** and the two new endpoints.
- **Can backend deploy before the app is updated?** Yes, with one caveat: the *new error code* `ROLL_WORKER_TAKEOVER_REQUIRED` will be returned to **old app versions** when a worker hits an abandoned mounted-roll line. Old apps don't recognize it and will show a generic error — the worker cannot take over (same dead-end as before the change, just a different message). All other flows (free-line login, mount, full-consume/return/grinding, logout, summary) are unchanged and old apps keep working.
- **What breaks on old app versions:** only the abandoned-roll takeover scenario (no worse than today's behavior) and the new keep-mounted option (absent). No data corruption — old apps simply can't use the new flows.
- **Coordination:** recommended to roll out the app update **shortly after** the backend so the takeover flow becomes usable on the floor. No DB-destructive coordination needed.
- **Feature flag:** not required by the backend. If the app team wants a staged rollout, gate the new logout option and takeover screen behind an app-side flag; the backend endpoints can remain live (idempotent + validated).

---

## 14. Final Acceptance Criteria

- Logout (roll mounted) shows the 4 options in the exact Arabic order; option 1 calls keep-mounted-handover and ends the session in one step.
- Login that returns `ROLL_WORKER_TAKEOVER_REQUIRED` opens the takeover screen with the previous worker name, current weight, and the "credited to previous worker" note — never a generic error.
- Takeover screen offers exactly the two options; "الرول ما زال مركب" asks for the current physical weight; both call `takeover-with-roll-declaration`.
- A single `clientRequestId` is generated per takeover attempt, reused on retry, cleared on success/cancel; double-submit is impossible; `alreadyProcessed` is handled via re-login recovery.
- Consumed kg is shown as the primary worker metric on the summary; rolls-contributed secondary.
- All listed edge cases are handled with the specified Arabic messages.
- Repository/provider/widget tests + the manual smoke + regression checklist pass.
