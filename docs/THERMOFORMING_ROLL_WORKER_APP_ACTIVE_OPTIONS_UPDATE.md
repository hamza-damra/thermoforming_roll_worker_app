# Thermoforming Roll Worker App — Active Shift-Line Options Update

**Date:** 2026-05-09
**Audience:** Flutter team owning the **Thermoforming Roll Worker app**.
**Backend version:** Adds `GET /api/v1/thermoforming-roll-app/shift-lines/active-options`. No DB migration. Read-only.

---

## 1. What changed

Backend now exposes the list of currently-ACTIVE Thermoforming shift-lines (i.e. lines the operator app has already opened against the current shift). This unblocks the roll worker pre-login picker.

- The Roll Worker app **no longer needs** the permanent "blocked / waiting" screen.
- It can now list active shift-lines, let the worker pick one, and proceed to the existing roll-worker auth flow.
- Backend is the source of truth: no manual `shiftLineId` entry, no `STATIC_SHIFT_LINE_ID`, no fake local state.
- The endpoint runs **before** roll worker authentication, so it does not require a roll-worker session token.

---

## 2. Endpoint

```
GET /api/v1/thermoforming-roll-app/shift-lines/active-options
```

Read-only. No request body.

---

## 3. Required headers

| Header | Required | Notes |
| --- | --- | --- |
| `X-Device-Key` | yes | Same device key already used everywhere under `/api/v1/thermoforming-roll-app/**`. |
| `X-Session-Token` (roll worker) | **no** | Not required. This endpoint exists precisely to be reachable before login. Do not send a roll-worker token. |

---

## 4. Response

Wrapped in the standard `ApiResponse<T>` envelope. `data` is an array of active shift-line rows. Empty array when no operator has an active line yet.

### 4.1 Active shift-line with current product (no roll mounted yet)

```json
{
  "success": true,
  "data": [
    {
      "shiftLineId": 500,
      "thermoformingShiftId": 100,
      "thermoformingLineId": 10,
      "thermoformingLineCode": "TH-01",
      "thermoformingLineName": "Thermo 1",
      "palletizingLineId": 20,
      "palletizingLineCode": "PL-01",
      "palletizingLineName": "Palletizer 1",
      "currentProductTypeId": 50,
      "currentProductTypeName": "Cup-200ml",
      "currentRollId": null,
      "currentRollGeneratedRollId": null,
      "currentRollTypeCode": null,
      "currentRollTypeName": null,
      "currentRollLastKnownWeightKg": null,
      "operatorId": 7,
      "operatorName": "محمد",
      "shiftLineStatus": "ACTIVE",
      "selectable": true,
      "blockingReason": null
    }
  ],
  "error": null
}
```

### 4.2 Active shift-line with mounted roll

```json
{
  "success": true,
  "data": [
    {
      "shiftLineId": 501,
      "thermoformingShiftId": 100,
      "thermoformingLineId": 11,
      "thermoformingLineCode": "TH-02",
      "thermoformingLineName": "Thermo 2",
      "palletizingLineId": 21,
      "palletizingLineCode": "PL-02",
      "palletizingLineName": "Palletizer 2",
      "currentProductTypeId": 50,
      "currentProductTypeName": "Cup-200ml",
      "currentRollId": 900,
      "currentRollGeneratedRollId": "001000000123",
      "currentRollTypeCode": "RT-A",
      "currentRollTypeName": "Regular Black",
      "currentRollLastKnownWeightKg": "180.500",
      "operatorId": 7,
      "operatorName": "محمد",
      "shiftLineStatus": "ACTIVE",
      "selectable": true,
      "blockingReason": null
    }
  ],
  "error": null
}
```

### 4.3 Empty list (no active shift-lines)

```json
{ "success": true, "data": [], "error": null }
```

### 4.4 Notes on fields

- `currentRollLastKnownWeightKg` is sourced from the consumption-state `lastKnownWeightKg` and is **null** when no roll is mounted, when the consumption-state row is missing, or when the field itself is null. The backend never substitutes the original mounted/start weight as a fallback.
- `currentRollTypeName` is the optional display name of the roll type and may be null; use `currentRollTypeCode` as the unambiguous identifier.
- `selectable` is always `true` in the current first-pass implementation. Treat the field as future-proof: if a backend update starts returning `false`/`blockingReason`, render the row as disabled and show the localized reason. Do not assume it will always be `true`.
- The DTO **never** carries token, hash, pin, sessionToken, or operatorAuthToken fields.

---

## 5. UI behavior

Replace the pure waiting screen with an active-shift-line picker.

**If the response array is empty** — show the existing waiting state copy:

> بانتظار فتح خط من تطبيق المشغّل

Add a refresh affordance (pull-to-refresh + an explicit retry button).

**If the response has rows** — render a card per row:

- خط التشكيل: `thermoformingLineName` (`thermoformingLineCode`)
- خط الطبليات المرتبط: `palletizingLineName` (`palletizingLineCode`)
- المنتج الحالي: `currentProductTypeName` if non-null, else `—`
- المشغّل: `operatorName`
- الرول الحالي (only if `currentRollId != null`):
  - رقم الرول: `currentRollGeneratedRollId`
  - نوع الرول: `currentRollTypeName ?? currentRollTypeCode`
  - الوزن الحالي: `currentRollLastKnownWeightKg` kg (display `—` if null)
- Action button (when `selectable == true`):
  - Label: **اختيار الخط**
- If `selectable == false` (future): render disabled and show the localized `blockingReason`.

---

## 6. After selecting a shift-line

1. Persist the selected `shiftLineId` in app state for the duration of the picker → auth flow.
2. Run the existing current-session check:
   ```
   GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-session/current
   Headers: X-Device-Key
   ```
   - If a session exists → navigate to the Roll Worker home, using the returned session token for subsequent shift-line-scoped requests.
   - If no session exists (404) → navigate to the PIN/auth screen and call:
     ```
     POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-auth
     ```

3. Do not persist the selected `shiftLineId` forever.
   - On app resume / pull-to-refresh, re-fetch active options and validate that the persisted `shiftLineId` still appears in the list.
   - If it no longer appears, clear the selection and return the user to the picker (or the empty-state waiting screen).

4. Existing flows (roll scan, previous-roll resolution, product-switch, label reprint) keep using the selected `shiftLineId` — none of those endpoints change.

---

## 7. Important restrictions

- No manual `shiftLineId` entry.
- No `STATIC_SHIFT_LINE_ID`.
- No hardcoded line list.
- No fake or local-only "active line" state.
- No use of operator-app endpoints from inside the roll worker app.
- No use of palletizing-app endpoints from inside the roll worker app.
- Backend is the source of truth at every refresh.

---

## 8. Acceptance criteria

- [ ] Roll Worker app can render active options from the new endpoint.
- [ ] Empty-state copy still works (`بانتظار فتح خط من تطبيق المشغّل`).
- [ ] Selecting a line leads to the existing current-session/auth flow without modification.
- [ ] If the selected shift-line disappears from the active options on refresh, the app clears the selection and returns to picker/waiting.
- [ ] Existing roll-scan and previous-roll flows use the selected `shiftLineId` from the picker.
- [ ] No operator-app endpoints are called from the roll worker app.
- [ ] No palletizing-app endpoints are called from the roll worker app.
- [ ] No client-side display of any token/hash/pin field (the DTO doesn't carry them).
- [ ] RTL/Arabic styling is preserved.
