# Frontend Handoff — Roll Worker App: Reason Capture, Scan Dialogs & Summary Counters (Backend V127)

**Audience:** Flutter **Roll Worker App** agent (separate repo).
**Backend status:** Implemented, verified on real MySQL (Flyway head V127). Backend is **additive + backward-compatible EXCEPT** the two reason fields below (now required) — deploy backend first, then ship the app changes.

---

## App impact matrix

| App | Affected? | Reason | Action |
| --- | --- | --- | --- |
| **Roll Worker App** | ✅ YES | return/grinding now require `reasonText`; richer scan errors; corrected summary counters; main-screen cleanup | This handoff |
| Operator App | ⚠️ Minor | Its operator-decision close paths pass `reasonText=null` server-side — **no app change required** (it does not call `/previous-roll/return|grinding`). | None |
| Admin App | ⚠️ Minor | A roll lookup may now show state `ملغى إدارياً` and consumption that was restored-fresh disappears from totals — **API contract unchanged** (same fields, corrected values). | None (values only) |
| Warehouse / Palletizing / Roll Production | ❌ No | No contract touched. | None |

---

## 1. Feature summary

The backend now:
- **Requires a manual free-text reason** when a roll worker **returns the remaining roll** or **recommends grinding** (no predefined options).
- Returns **richer scan errors** for **consumed**, **grinding-recommended**, and the new **admin-cancelled** rolls, so the app can show a professional dialog instead of a generic error.
- **Fixed the summary counters**: the "closed rolls" count no longer resets across logout/login on the same line (it now follows the same scope as consumed kg).

---

## 2. API contract changes

Base: `/api/v1/thermoforming-roll-app`. Header `X-Session-Token` (+ device key) unchanged.

### 2.1 Return remaining — `POST /shift-lines/{shiftLineId}/previous-roll/return`
### 2.2 Recommend grinding — `POST /shift-lines/{shiftLineId}/previous-roll/grinding`

**Request body (BOTH endpoints) — NEW required field `reasonText`:**
```json
{
  "remainingWeightKg": 50.000,
  "reasonText": "سبب كتبه موظف الرولات"
}
```
- `remainingWeightKg` — unchanged (required, ≥ 0, ≤ current mounted weight server-side).
- `reasonText` — **NEW, REQUIRED**. Free text. **Trimmed** server-side; blank/whitespace-only is rejected. **Max 500 characters.** No predefined options.

**Validation errors (envelope `{ success:false, error:{ code, message, details } }`):**
- Missing/blank reason → domain code **`ROLL_RETURN_REASON_REQUIRED`** (return) / **`ROLL_GRINDING_REASON_REQUIRED`** (grinding), HTTP 400 (a malformed body may also surface a bean-validation 400 on `reasonText`). Show the field error inline; do not submit until non-empty.
- Weight out of range → existing `INVALID_REMAINING_ROLL_WEIGHT`.

**Response:** unchanged (`ThermoformingPreviousRollResolutionResponse`: finalState, consumedWeightKg, remainingWeightKg, remainderAction, eventType, reprintAvailable, reprintLabelType, labelTimestamp).

### 2.3 Keep-mounted-handover — UNCHANGED
`POST /shift-lines/{shiftLineId}/previous-roll/keep-mounted-handover` still takes only `{ "remainingWeightKg": ... }`. **Do NOT add `reasonText` to this call.**

### 2.4 Full-consume — UNCHANGED (no body, no reason).

---

## 3. Error contract for scan / mount failures

`POST /shift-lines/{shiftLineId}/scan-roll` (body `{ generatedRollId | scannedValue }`). On rejection the envelope now carries a structured `details` object. Render a dialog from `details` (all fields optional — guard for null).

### 3.1 `SENT_TO_GRINDING` → code `ROLL_SENT_TO_GRINDING_NOT_REUSABLE` (HTTP 409)
```json
{ "success": false, "error": {
  "code": "ROLL_SENT_TO_GRINDING_NOT_REUSABLE",
  "message": "Roll ... was sent to grinding ...",
  "details": {
    "rollNumber": "001000000123",
    "currentState": "SENT_TO_GRINDING",
    "displayStatusLabel": "موصى بالجرش",
    "workerName": "محمد",
    "workerReasonText": "الرول فيه مشكلة واضحة",
    "remainingWeightKg": 12.500,
    "recommendedAt": "2026-06-23T10:30:00.000+03:00",
    "message": "هذا الرول موصى بالجرش ولا يمكن تركيبه كمتبقي صالح."
  } } }
```

### 3.2 `CONSUMED` → code `ROLL_ALREADY_CONSUMED` (HTTP 409)
```json
{ "details": {
  "rollNumber": "001000000123", "currentState": "CONSUMED",
  "displayStatusLabel": "مستهلك بالكامل", "workerName": "محمد",
  "consumedAt": "2026-06-23T09:00:00.000+03:00",
  "message": "هذا الرول مستهلك بالكامل." } }
```

### 3.3 `ADMIN_CANCELLED` → code `ROLL_ADMIN_CANCELLED` (HTTP 409, **NEW**)
```json
{ "details": {
  "rollNumber": "001000000123", "currentState": "ADMIN_CANCELLED",
  "displayStatusLabel": "ملغى إدارياً", "cancelledBy": "م. حمزه ضمره",
  "cancelReason": "رول قديم استُهلك فعلياً", "cancelledAt": "2026-06-20T14:00:00.000+03:00",
  "message": "تم إلغاء هذا الرول من الإدارة ولا يمكن تركيبه." } }
```

> Cancelled rolls are excluded from all available-roll inventory and mount eligibility — the app should never offer them; this error is the safety net.

---

## 4. Required Flutter dialogs (replace generic snackbars)

### Grinding-recommended dialog
- **Title:** `الرول موصى بالجرش`
- **Message:** `هذا الرول موصى بالجرش ولا يمكن تركيبه كمتبقي صالح.`
- Show if present: `workerName`, `recommendedAt` (formatted), `remainingWeightKg`, `workerReasonText`.
- **Guidance line:** `إذا كنت تعتقد أن هذا الرول صالح للاستهلاك الآن، تواصل مع م. حمزه ضمره لتعديل حالة الرول لتتمكن من استهلاكه.`

### Consumed dialog
- **Title:** `الرول مستهلك بالكامل` — **Message:** `هذا الرول مستهلك بالكامل.`
- Show if present: `workerName`, `consumedAt`.
- **Guidance:** `إذا كان الرول غير مستهلك فعليًا ويحتاج تعديلًا، تواصل مع الإدارة.`

### Admin-cancelled dialog
- **Title:** `الرول ملغى` — **Message:** `تم إلغاء هذا الرول من الإدارة ولا يمكن تركيبه.`
- Show if present (and safe): `cancelReason`, `cancelledAt`.

---

## 5. Required input dialog changes

When the worker chooses **`إرجاع المتبقي`**:
- Remaining-weight input (existing) **+** a REQUIRED multiline text field labelled `سبب إرجاع المتبقي`.
- No dropdowns, no predefined choices. Disable/validate submit while blank. Send as `reasonText`.

When the worker chooses **`توصية بالجرش`**:
- Remaining-weight input **+** a REQUIRED multiline field labelled `سبب التوصية بالجرش`. Same rules. Send as `reasonText`.

---

## 6. Main screen UI improvements (Roll Worker home)

- Move **"الرولات التي تم إغلاقها"** BELOW **"الوزن المستهلك في هذه المناوبة"**.
- **Remove** the helper note under closed rolls: `تشمل الاستهلاك الكامل، إرجاع المتبقي، والتوصية بالجرش`.
- **Remove** the helper note under consumed weight: `رولات ساهمت بها: 2`.
- **Remove** non-expressive icons from these summary cards (they take space without helping under factory pressure).
- Keep the existing theme/visual identity; RTL; cleaner and easier to read.
- Use the **backend-corrected** summary counters (do not recompute locally).

---

## 7. Counter behavior after the backend fix

The `GET /shift-lines/{shiftLineId}/summary` response is unchanged in shape:
- `consumedWeightKgInSession`, `rollsContributedInSession`, `completedRollsInSession`, `completedRollsByCurrentWorker`, `consumedRolls[]`, `mountedRoll`.

What changed (server-side): `completedRollsInSession` / `completedRollsByCurrentWorker` are now EMPLOYEE + shift-line scoped — the **same scope as `consumedWeightKgInSession`**. So when the same worker logs out and back in on the same active line, **both** the consumed kg and the closed-roll count are preserved (the previous bug reset the count to 0 while kg stayed correct). **Trust the backend summary fields; never recompute the closed-roll count from the current token/session only.**

---

## 8. Testing checklist (Flutter)

- [ ] Return-remaining cannot submit without a reason; valid reason submits.
- [ ] Recommend-grinding cannot submit without a reason; valid reason submits.
- [ ] Keep-mounted-handover still works WITHOUT a reason field.
- [ ] Scan a CONSUMED roll → consumed dialog (with worker/time when present).
- [ ] Scan a grinding-recommended roll → grinding dialog showing the worker's reason + guidance line.
- [ ] Scan an admin-cancelled roll → cancelled dialog (`ROLL_ADMIN_CANCELLED`).
- [ ] Mohammad/Ahmad logout/login scenario → closed-roll count stays correct (does not reset to 0).
- [ ] Main screen: closed-rolls section is BELOW consumed-weight; both helper notes removed; no icons in those cards.
- [ ] Arabic RTL layout intact.

---

## 9. Backend compatibility / rollout

- The reason fields are a **breaking request change** for the two endpoints — deploy backend first, then release the app. Until the app sends `reasonText`, those two calls return 400.
- Everything else (scan `details`, summary counters, the admin tab) is additive/value-only.
