# Roll Worker App — Error State & Printing Handoff

> Backend: TaleebBackend (Spring Boot 4.0.3 / Java 17)
> Frontend affected: **Roll Worker App** (Flutter)
> Slice: Frontend UX work driven by the PR that adds the admin mounted-roll
> decision gate and the manual-end guard. No backend close-roll endpoints
> change in this slice.

> **Scope note:** this handoff is intentionally limited. It does **not**
> introduce a mount-duration threshold rule, a `CARRIED_OVER` lifecycle, or
> any auto-consumption behaviour. Those topics are deferred to a follow-up.

## 1. Problem

1. **Incompatible / disallowed roll scan** — after a failed mount (wrong roll
   type, already-consumed roll, etc.) the app sometimes loses the primary
   "مسح رول" action or leaves the screen in an invalid state.
2. **Return / Grinding reprint** — closing a roll with `RETURN_REMAINING` or
   `SEND_REMAINING_TO_GRINDING` does not immediately surface the remainder
   label, and reprint on the consumed-roll card is unreliable.
3. **Old label layout** — the app still prints the legacy label; the new
   100×100 mm layout (matching the Roll Production App reference) needs to
   ship.
4. **Login / line-selection UX** — empty states and active-line ownership
   are unclear.

> `ROLL_STILL_MOUNTED_ON_SHIFT_LINE` is **not** a Roll Worker App concern.
> Mounted-roll handover belongs to the Thermoforming Operator App's combined
> handover checklist (pallet section + mounted-roll remaining-weight
> section). A mounted roll is unaffected by roll-worker login/logout. The
> Roll Worker App must not block its own logout because a roll is mounted
> and must not open the close dialog on logout.

## 2. Backend invariants (unchanged in this PR, restated for clarity)

- Three exclusive close paths, all under
  `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/previous-roll/*`:
  - `POST /full-consume` → closes with `closed_reason = FULL_CONSUMPTION`,
    state `CONSUMED`, event `CLOSED_FULL`. No weight in the request body.
  - `POST /return` → body `{ "remainingWeightKg": <BigDecimal> }`,
    `closed_reason = PARTIAL_RETURN`, state `PARTIALLY_RETURNED`, event
    `CLOSED_PARTIAL_RETURN`.
  - `POST /grinding` → body `{ "remainingWeightKg": <BigDecimal> }`,
    `closed_reason = PARTIAL_GRINDING`, state `SENT_TO_GRINDING`, event
    `CLOSED_PARTIAL_GRINDING`.
- Response shape (`ThermoformingPreviousRollResolutionResponse`): includes
  `finalState`, `remainderAction`, `eventType`, and
  `reprintAvailable: boolean`. **`reprintAvailable` is `true` only for
  partial-return and grinding closes — never for `FULL_CONSUMPTION`.**
- SSE: a successful close fires `ROLL_CONSUMED` on
  `GET /api/v1/thermoforming-roll-app/events` (event name
  `roll-worker-lines-changed`). The app should refresh after any
  `ROLL_CONSUMED`, `ROLL_MOUNTED`, `ROLLS_EMPLOYEE_CHANGED`,
  `OPERATOR_SESSION_ENDED`, or `LINE_STATE_CHANGED` event.

## 3. Frontend requirements

### 3.1 Failed-mount UX — preserve the screen and the action

When a mount fails with one of the listed error codes, the app **must**:

- Show a clear non-modal Arabic error (snackbar / inline banner is fine).
- Leave the mounted-roll state on the line **unchanged** — do not optimistic-
  apply on the client.
- Keep the "مسح رول" button visible and enabled (i.e. allow re-scan).
- Not require the worker to navigate away from the line view.

| Backend error code | Arabic message (already in [messages_ar.properties](../../src/main/resources/messages_ar.properties)) |
| --- | --- |
| `ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT` | "نوع الرول غير مسموح للمنتج الحالي" |
| `ROLL_ALREADY_CONSUMED` | "هذا الرول مغلق سابقًا ولا يمكن استخدامه مرة أخرى" |
| `ROLL_NOT_FOUND` | "الرول غير موجود" |
| `ROLL_WORKER_SESSION_REQUIRED` | App must refresh `/sessions/me`; if no active line found, navigate to line picker / session-ended state. |
| `PRODUCTION_PLAN_ITEM_REQUIRED` | "لا يوجد بند إنتاج نشط لهذا الخط" (admin must add an item to the plan) |

Add regression tests for each of these error states.

### 3.2 Return / Grinding reprint flow

- After a successful `RETURN` or `GRINDING` close:
  - Show non-blocking success feedback (snackbar).
  - Immediately offer (or auto-trigger) the remainder-label print using the
    new layout (§3.3).
  - Expose a Reprint button on the consumed-roll card. The backend response
    sets `reprintAvailable = true` on these branches — gate the button on
    that flag.
- After a successful `FULL_CONSUMPTION` close:
  - Show success feedback only.
  - Do **not** offer a remainder label.
  - Do **not** show Reprint (`reprintAvailable = false`).

### 3.3 New label layout — 100 × 100 mm

Reference: the **Roll Production App** project (placed inside the Roll
Worker App project as a side-by-side reference). Inspect its label
renderer and printer drivers — do not depend on it at runtime. Adapt:

- **Label preset**: 100 × 100 mm default.
- **Right-side machine number** — large, scannable from a distance.
- **QR code** — encodes the roll's `generatedRollId` (12 digits).
- **Day / time / date** — short Arabic format consistent with
  `arabicDateTimeFormatter.formatShort(...)`.
- **TSPL** (Xprinter) and **ZPL** (Zebra) output paths.

### 3.4 Printing acceptance

| Scenario | Expected label |
| --- | --- |
| `FULL_CONSUMPTION` close | **No** remainder label is printed |
| `RETURN_REMAINING` close | "متبقي مرتجع" label, new layout |
| `SEND_REMAINING_TO_GRINDING` close | "متبقي للجرش" label, new layout |
| Default paper size | 100 × 100 mm |
| Xprinter (TSPL) | Working print path |
| Zebra (ZPL) | Working print path |
| QR code | Scans back to the same `generatedRollId` |
| Old layout | No longer used — retire |

### 3.5 Login / line-selection UX

- Empty states (no available line, session expired) show clear, actionable
  Arabic copy — no raw error codes.
- "Active line" ownership badge should make it visually obvious that the
  worker currently holds a line.
- Loading states are stable (no flicker between empty → list → empty).
- The primary action ("اختر خطًا" / "ابدأ مسح") is always reachable.
- When `/sessions/me` reports no active lines but the device is
  authenticated, route to the line picker — do not show a blank page.

## 4. Manual verification

1. Mount a roll, scan a roll of the wrong type → error banner, "مسح رول"
   stays visible.
2. Mount a roll, end the operator shift via the operator app while the roll
   is still mounted → operator app gets `ROLL_STILL_MOUNTED_ON_SHIFT_LINE`
   (backend invariant in this PR). The worker app sees the SSE refresh; the
   roll should remain mounted.
3. Close the roll with `RETURN`, supplying a weight → remainder label
   printed immediately; reprint button visible on the consumed-roll card.
4. Close the next roll with `FULL_CONSUMPTION` → no remainder label;
   reprint button hidden.
5. Switch to Zebra printer, repeat #3 → ZPL output, label scans back.

## 5. Prompt for the Frontend AI Agent

> You are working on the Roll Worker App Flutter project. The backend has
> not changed any close-roll endpoints in this PR. Update the app to:
>
> 1. **Preserve UI state on failed mount** for `ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT`,
>    `ROLL_ALREADY_CONSUMED`, `ROLL_NOT_FOUND`, `ROLL_WORKER_SESSION_REQUIRED`,
>    and `PRODUCTION_PLAN_ITEM_REQUIRED`. Each error gets its existing
>    Arabic message; the primary "مسح رول" action must remain visible.
>    `ROLL_STILL_MOUNTED_ON_SHIFT_LINE` is intentionally not in this list —
>    see the scope note in §1.
> 2. **Wire the reprint flow** to the `reprintAvailable` flag in
>    `ThermoformingPreviousRollResolutionResponse`. RETURN / GRINDING shows
>    the remainder label and a reprint button. FULL_CONSUMPTION shows
>    neither.
> 3. **Adopt the new 100×100 mm label** by adapting the Roll Production App
>    renderer + TSPL / ZPL drivers placed inside the Roll Worker App project
>    as a side-by-side reference. The Roll Production App is itself a
>    separate backend module — reference it as a static code template, not
>    a runtime dependency.
> 4. **Polish the login / line-selection UX** per §3.5.
>
> Out of scope (do **not** implement) for this PR slice: any 30-minute
> mount-duration rule, any "carry-over" lifecycle, any auto-consumption.
> The backend does not (and in this PR will not) emit those states.
