# Consumed Rolls Shift / Session Scope Handoff

> Backend: TaleebBackend (Spring Boot 4.0.3 / Java 17)
> Frontends affected: **Thermoforming Operator App** + **Roll Worker App** (Flutter)
> Admin: `/web/admin/shift-history/sessions/{authId}`
> Slice: Bug-fix + admin-audit follow-up, no Flyway migration

## 1. Problem

Consumed roll history was leaking across operators / sessions:

1. **Thermoforming Operator App** (`/api/v1/palletizing-line/lines/{lineId}/operator-dashboard*`) returned every roll ever consumed on the palletizing line, including rolls from prior operators' shifts. Produced pallets were already correctly scoped to the current `LineOperatorAuthorization`; consumed rolls were not.
2. **Roll Worker App** (`/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/summary`) returned counters that aggregated all closed rolls on the shift-line regardless of which `RollWorkerSession` performed the close. When a worker logged in fresh, they saw counts that included other workers / their own previous sessions.
3. **Admin shift-history detail page** (`/web/admin/shift-history/sessions/{authId}`) had no card for consumed rolls on the viewed shift, and its existing roll-workers card was hidden when the list was empty — making it look like the feature was missing.

All three are production data-isolation issues. The schema (post-V67) already carries `roll_worker_session_id`, `roll_worker_operator_id`, and `thermoforming_shift_line_id` on `roll_consumption_items`; the fix is repository/service-level only. **No Flyway migration was needed.**

## 2. Backend behaviour now

### 2.1 Thermoforming Operator App — scoped by ACTIVE `ThermoformingShiftLine`

[`OperatorDashboardService`](../../src/main/java/ps/taleeb/taleebbackend/palletizing/operatorapp/service/OperatorDashboardService.java) now resolves the ACTIVE `ThermoformingShiftLine` for the requested `palletizingLineId` and filters consumed rolls by `thermoforming_shift_line_id`. If there is no active shift-line, the response carries an empty list / page — same pattern as produced pallets when there is no active authorization.

Affected endpoints (paths unchanged, scope tightened):

| Path | What changed |
| --- | --- |
| `GET /api/v1/palletizing-line/lines/{lineId}/operator-dashboard` | `latestRollConsumptions` now contains only items from the active shift-line. Empty when no shift-line is active. |
| `GET /api/v1/palletizing-line/lines/{lineId}/current-session/roll-consumptions` | Page is scoped to the active shift-line. Returns `Page.empty(...)` when none. |

Repository methods:

- Removed: `findLatestByPalletizingLineId`, original `findCurrentSessionRollConsumptionsPage` (which filtered by `palletizingLineId`).
- Added: `findLatestByShiftLineId(shiftLineId, pageable)`, `findCurrentSessionRollConsumptionsPageByShiftLineId(shiftLineId, rollTypeId, fromUtc, toUtc, pageable)`. Both eagerly fetch `roll → rollType` via `@EntityGraph`.

### 2.2 Roll Worker App — scoped by current `RollWorkerSession`

[`RollWorkerShiftLineSummaryService`](../../src/main/java/ps/taleeb/taleebbackend/thermoformingrollapp/service/RollWorkerShiftLineSummaryService.java) now uses `session.getId()` (from `RollWorkerSessionService.requireActiveSession(...)`) for both the counter and the new consumed-rolls list. A fresh login on the same shift-line starts a NEW `RollWorkerSession` so the counter resets to 0 and the list is empty.

Endpoint (path unchanged):

```
GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/summary
Headers: X-Device-Key: <app.device-api-key>, X-Session-Token: <raw token>
```

Repository methods added on `RollConsumptionItemRepository`:

- `long countBySessionIdAndStatus(sessionId, status)`
- `List<RollConsumptionItem> findBySessionIdAndStatusOrderByEndedAtDesc(sessionId, status, pageable)` — `@EntityGraph({"roll","roll.rollType"})`.

### 2.3 Admin shift-history — consumed rolls + always-visible workers + drill-down

[`AdminSessionDetailService`](../../src/main/java/ps/taleeb/taleebbackend/web/admin/AdminSessionDetailService.java) now fetches every `RollConsumptionItem` on the viewed shift-line in one query ([`findAllByShiftLineIdWithDetails`](../../src/main/java/ps/taleeb/taleebbackend/thermoforming/repository/RollConsumptionItemRepository.java)) with `@EntityGraph` eager-loading `roll → rollType`, `rollWorkerOperator`, and `rollWorkerSession`. Per-worker drill-down lists and per-worker CLOSED counts are derived in-memory — this also removes the previous N-COUNT-queries pattern (one count per distinct worker) the old `buildParticipationContext` had.

[`detail.html`](../../src/main/resources/templates/web/admin/shift-history/detail.html) now renders:

- New card "الرولات المستهلكة في المناوبة" after the FALET timeline. Empty state: "لا توجد رولات مستهلكة في هذه المناوبة".
- Roll-workers card "عمال الرول الذين عملوا على هذا الخط" is **always rendered**. Empty state: "لا يوجد عمال رولات لهذه المناوبة".
- Each row's "رولات أنجزها" cell is a Bootstrap collapse trigger that reveals an inline drill-down table of that worker's rolls.

Arabic labels for `status` / `closedReason` / `remainderAction` live in [`RollConsumptionArabicLabels`](../../src/main/java/ps/taleeb/taleebbackend/web/admin/RollConsumptionArabicLabels.java).

## 3. API contract changes

### 3.1 `RollWorkerShiftLineSummaryResponse` (Roll Worker App)

- **Renamed:** `completedRollsInShift` → `completedRollsInSession`. Same JSON type (long), new semantics (session-scoped).
- **Kept:** `completedRollsByCurrentWorker` — now equal to `completedRollsInSession` (a session is by definition tied to one worker). Preserved for frontend contract continuity; may be removed in a future release.
- **New:** `consumedRolls: List<ConsumedRoll>` — latest closed rolls in the current session, newest-first, capped at `CONSUMED_ROLLS_LIMIT = 10`.

`ConsumedRoll` shape:

```jsonc
{
  "consumptionItemId": 900,
  "rollId": 12345,
  "generatedRollId": "001000000123",
  "rollTypeCode": "TP-1",
  "rollTypeName": "White",
  "startWeightKg": 200.000,
  "endWeightKg": 0.000,
  "consumedWeightKg": 200.000,
  "remainingWeightKg": null,
  "closedReason": "FULL_CONSUMPTION", // or PARTIAL_RETURN, PARTIAL_GRINDING
  "remainderAction": "NONE",          // or RETURN, GRINDING
  "endedAt": "2026-05-23T10:00:00.000Z",
  "endedAtDisplay": "23 أيار، 10:00 ص"
}
```

`@JsonInclude(NON_NULL)` is applied — fields the backend doesn't have are omitted from the wire.

### 3.2 Thermoforming Operator App

- Response shapes unchanged. Only the **filter scope** of `latestRollConsumptions` (on the dashboard JSON) and the paginated "view all" page tightened. Frontends that already render the array as-is need no code change — they will just see fewer / empty rows for new shifts.

### 3.3 Admin shift-history

- New JSON / DTO field on `AdminSessionDetailView`: `consumedRolls: List<ShiftHistoryConsumedRollRow>`. Only relevant to server-rendered Thymeleaf templates; no JSON API.
- `WorkerParticipationView` (per roll-worker row) gains `rollsConsumed: List<ShiftHistoryConsumedRollRow>` — drill-down detail rows.

## 4. Current product in Roll Worker App

`GET /api/v1/thermoforming-roll-app/sessions/me` **already** populates the current product fields per-line — backend was not changed for this point. The data is sourced from the active Thermoforming production-plan item in [`RollWorkerMeService.toActiveLineResponse`](../../src/main/java/ps/taleeb/taleebbackend/thermoformingrollapp/service/RollWorkerMeService.java).

Frontend must render these existing fields (already present in the response):

- `currentPlanItemProductTypeId` — `Long`
- `currentPlanItemProductName` — `String`

If the field is non-null, render it. If null (no active plan item), render a neutral placeholder. **Do not** add a `/product-switch` or `/select-product` round-trip — those endpoints were intentionally removed; product context is plan-driven only.

## 5. Frontend requirements

### 5.1 Roll Worker App

1. **Consumed rolls are session-scoped.** The `consumedRolls` array returned by `/summary` is authoritative — render exactly what the backend returns, do not accumulate across sessions, do not deduplicate globally, do not cache outside the current session/line context.
2. **New login on the same line = clean slate.** When the worker logs out and logs back in, the new session returns `completedRollsInSession = 0` and `consumedRolls = []`. The UI must reflect that immediately.
3. **Cache key includes shiftLineId + sessionToken.** Do not keep a global "consumed rolls" cache keyed only by line — that re-introduces the bug.
4. **Refresh on SSE.** When a `ROLL_CONSUMED` or `ROLL_MOUNTED` event arrives for one of the worker's lines (debounced ~250 ms), refetch `/summary` for that line and re-render.
5. **Drop on session loss.** When `/sessions/me` no longer lists a line (operator ended the shift), drop that line's consumed-rolls state.
6. **Read `completedRollsInSession`.** The renamed counter is the authoritative number. If your client previously consumed `completedRollsInShift`, switch it to `completedRollsInSession`. Both are session-scoped now but `completedRollsInShift` is **gone**.
7. **Render current product from `/sessions/me`.** Use the existing `currentPlanItemProductTypeId` / `currentPlanItemProductName` fields. Do not show the line's stale legacy `currentProductType`. If null, show a neutral "لا يوجد منتج نشط" placeholder.

### 5.2 Thermoforming Operator App

1. **Consumed rolls list on the dashboard is shift-scoped automatically.** No frontend filtering required. Render the response as-is.
2. **"View all" page is shift-scoped.** Pagination state should reset when the operator opens a fresh shift on the same palletizing line — but since the backend now returns an empty page when no shift-line is active, simply re-fetching on shift open is enough.
3. **Refresh on SSE.** `ROLL_MOUNTED` / `ROLL_CONSUMED` events on the line should trigger a refetch (debounced) — same as before; this slice did not change SSE.
4. **Do NOT compute or cache rolls locally across shifts.** Always re-render from the latest backend response.

## 6. Admin behaviour now

On `/web/admin/shift-history/sessions/{authId}` the admin sees:

- **"الرولات المستهلكة في المناوبة"** — every `RollConsumptionItem` (ACTIVE + CLOSED) on the shift-line bound to the viewed authorization. Columns: رقم الرول / النوع / الوزن الابتدائي / المستهلك / المتبقي / العامل / وقت التركيب / وقت الإغلاق / سبب الإغلاق / إجراء المتبقي. Empty state: "لا توجد رولات مستهلكة في هذه المناوبة".
- **"عمال الرول الذين عملوا على هذا الخط"** — always rendered. Empty state: "لا يوجد عمال رولات لهذه المناوبة". Each row's "رولات أنجزها" count is clickable; clicking expands an inline table of that worker's consumed rolls for this shift.
- **"عمال الطبليات على هذا الخط"** — unchanged.
- Sibling-lines and FALET timeline — unchanged.

Items with a null `rollWorkerSession` / `rollWorkerOperator` (legacy pre-V67 rows) are visible in the top audit table but excluded from per-worker drill-downs (they cannot be safely attributed).

## 7. Tests / verification

### 7.1 Backend (added in this slice — all pass)

- [`OperatorDashboardServiceTest`](../../src/test/java/ps/taleeb/taleebbackend/palletizing/operatorapp/service/OperatorDashboardServiceTest.java) — new cases:
  - `latestRollConsumptionsScopedByShiftLineId_notByPalletizingLineId` — hard regression guard.
  - `noActiveShiftLineYieldsEmptyRollList` — empty when no shift-line.
- [`RollWorkerShiftLineSummaryServiceTest`](../../src/test/java/ps/taleeb/taleebbackend/thermoformingrollapp/service/RollWorkerShiftLineSummaryServiceTest.java) — rewired to session-scoped queries + new cases:
  - `countersAreSessionScoped` — counter uses session id, old shift-line query never called.
  - `consumedRollsListIsMapped` — list mapping including Arabic timestamps + close reason / remainder action codes.
- [`AdminSessionDetailServiceTest$ParticipationCases`](../../src/test/java/ps/taleeb/taleebbackend/web/admin/AdminSessionDetailServiceTest.java) — new cases:
  - `consumedRollsScopedToShiftLine` — top table + Arabic labels.
  - `perWorkerDrillDownContainsOnlyOwnRolls` — drill-down isolation.
  - `legacyUnattributedItemNotInDrillDown` — null-attribution rows visible in top table only.

Total: 65 tests pass across the three classes (+ peripheral ones that hit the same code paths).

### 7.2 Manual smoke (requires MySQL on 3307)

1. `./mvnw spring-boot:run`.
2. **Operator App scope**: Operator A opens a shift on palletizing line 1, mounts + closes 2 rolls, ends the shift. Operator B opens a fresh shift on line 1. `GET /api/v1/palletizing-line/lines/1/operator-dashboard` for B must NOT include A's rolls.
3. **Roll Worker App scope**: Worker X authenticates on shift-line 102, closes 2 rolls, logs out. Worker X authenticates again on shift-line 102. `GET /api/v1/thermoforming-roll-app/shift-lines/102/summary` must return `completedRollsInSession=0` and `consumedRolls=[]`.
4. **Admin page**: open `/web/admin/shift-history/sessions/{authId}` for a shift with closed rolls; see the new audit card with all four column groups. Open one for a shift with no roll workers; see the empty-state copy. Click a worker's "رولات أنجزها" count; the inline drill-down expands.

## 8. Prompt for Frontend AI Agent

Copy the block below into the Flutter Roll Worker App and Thermoforming Operator App AI agents.

---

You are updating the Flutter apps to consume the now-correctly-scoped backend consumed-rolls endpoints. **Read this handoff first**: `docs/handoffs/ROLL_WORKER_CONSUMED_ROLLS_SHIFT_SCOPE_HANDOFF.md`. Do not guess.

### Roll Worker App requirements

1. **Switch from `completedRollsInShift` to `completedRollsInSession`.** The old field is gone. The new field is session-scoped and resets to 0 on each new login to the same shift-line.
2. **Render the new `consumedRolls` array from `/summary` as-is.** Cap at 10 items, newest-first. Use `endedAtDisplay` for the date label. Translate `closedReason` and `remainderAction` codes to Arabic only on the UI (the codes themselves are stable — `FULL_CONSUMPTION`, `PARTIAL_RETURN`, `PARTIAL_GRINDING`, `NONE`, `RETURN`, `GRINDING`).
3. **Drop any global consumed-rolls cache.** Cache keys MUST include both `shiftLineId` and the active session token (or session id once it lands on the wire). Never share consumed-rolls state across logins.
4. **Drop the cache when the line disappears from `/sessions/me`.** The operator ended the shift; previous-session work belongs in admin audit, not in the worker UI.
5. **Refresh on SSE.** On `ROLL_CONSUMED` / `ROLL_MOUNTED` for one of your lines, debounce ~250 ms and refetch `/summary` for that line.
6. **Render current product from existing `/sessions/me` fields.** `currentPlanItemProductTypeId` and `currentPlanItemProductName` are already returned by the backend. If null, show a neutral "لا يوجد منتج نشط" placeholder. Do NOT call any legacy product-switch / select-product endpoint.

### Thermoforming Operator App requirements

1. **No code change required if you already render `latestRollConsumptions` as the source of truth.** The backend now filters at the database level — your view will just look correct.
2. **Drop any client-side workaround that filtered rolls by date / operator.** The backend handles it now.
3. **Verify the "View All" page resets between shifts.** Re-fetch on shift open; the backend returns an empty page when no shift-line is active.

### Verification (real device)

- Worker X logs in to shift-line 102, closes 2 rolls, logs out, logs in again → consumed rolls list is empty.
- Two workers in a row on the same shift-line → second worker's `consumedRolls` does NOT include the first worker's items.
- Operator B starts a fresh thermoforming shift on a palletizing line where Operator A previously consumed rolls → operator dashboard shows zero rolls until B closes one.
- "Current product" appears in the per-line header whenever the production plan has an active item; placeholder otherwise.
- Disconnect / reconnect SSE — no double counts, no stale rolls.
