# Frontend Handoff — Roll Worker App — Employee-Scoped Consumed List & Kg (V123)

> **Additive & backward-compatible (semantic change, not contract change).** No field was renamed or removed. The shift-line **summary** now sources the consumed list + consumed-kg from a new **roll-employee accounting model** keyed on the **worker's operator identity** instead of the raw session, so the list/kg **survive logout/login** and correctly follow worker takeovers. Backend may deploy first.

> **App impact matrix** (one row per Taleeb app):
>
> | App | Affected? | Reason | Required Handoff File |
> |---|---:|---|---|
> | **Roll Worker App** | **Yes — additive/semantic** | Consumed list + consumed-kg are now employee-scoped (survive logout/login); two count fields clarified; provisional open-block kg surfaced. | **this file** |
> | Operator App | **Yes (separate)** | Roll-weight dispute receipt flow — see `FRONTEND_HANDOFF_OPERATOR_APP_ROLL_WEIGHT_DISPUTES.md`. | separate |
> | Admin App | **Yes (separate, breaking)** | Admin-forced shift-end decision set — see `FRONTEND_HANDOFF_ADMIN_APP_FORCED_SHIFT_END_MOUNTED_ROLL_DECISION.md`. | separate |
> | Warehouse App | **No** | No roll-floor surface. | — |
> | Palletizing App | **No** | Legacy device API. | — |
> | Roll Production App | **No** | Extrusion/roll-production app; this is the thermoforming **roll-worker** consumption summary. | — |
>
> Cross-cutting backend contract reference: `FRONTEND_HANDOFF_BACKEND_API_CONTRACT_ROLL_WEIGHT_ACCOUNTING.md`.
> Prior related handoffs: `FRONTEND_HANDOFF_ROLL_WORKER_APP_SESSION_CONTRIBUTION_LIST_FIX.md`, `FRONTEND_HANDOFF_ROLL_WORKER_APP_TAKEOVER_WITH_WEIGHT_DECLARATION.md`, `FRONTEND_HANDOFF_ROLL_WORKER_SESSION_AND_MOUNTED_ROLL_OWNERSHIP_CHANGE.md`.

## 1. Executive Summary

- **What changed:** the Roll Worker shift-line **summary** previously computed the worker's "consumed rolls" list and consumed-kg from **session-scoped** queries — so when the worker logged out and back in, their list went empty / kg reset. V123 re-sources these from a new **roll-employee consumption model** (`roll_employee_consumption_segments`) keyed on **`operators.id` + `shiftLineId`**, so:
  - the consumed list and consumed-kg **survive logout/login** for the **same** worker on the same line,
  - a **different-worker takeover** attributes the unmeasured delta to the **new** worker at the next trusted weight (deterministic; the previous worker keeps only what was measured before the takeover),
  - the **live open block** on the currently-mounted roll contributes **provisional** kg immediately (before any terminal close).
- **What did NOT change:** the endpoint path, method, auth header, the response class name, and every existing field name/type. New fields are additive and nullable. The `completedRollsInSession` counter still means session-scoped completed mount cycles.
- **Required before production?** **No.** Additive/backward-compatible; backend may deploy first. The app should adopt the corrected semantics (and optionally surface the new fields), but an old build keeps deserializing the response.

## 2. Affected App

**Roll Worker App** (thermoforming roll app, base path `/api/v1/thermoforming-roll-app`). Unaffected: Warehouse, Palletizing, Roll Production, Admin, Operator apps (the last two are affected by *other* V123 changes — separate files).

## 3. Business Context

A roll worker mounts and consumes rolls on a thermoforming shift-line. The app shows "rolls I've finished" and "kg I've consumed". The old session-scoped computation broke continuity:

- Same worker logs out (end of break) and back in → the old list/kg were tied to the **session id**, so they reset to empty/0 even though the worker is the same person on the same line.
- A roll carried across a worker takeover wasn't attributed deterministically.

The fix keys consumption on **employee identity** (`operators.id`) + shift-line, so the worker's history is continuous across logins, and takeovers credit the worker who actually consumed each interval. **Ownership rules (backend, for context):**

- Worker **logout does not** close the roll, ask for weight, or create a boundary; the open interval stays owned by that worker.
- Same worker re-logs-in with **no different worker in between** → keeps owning the open interval.
- A **different-worker takeover** records a trusted weight; the **new** worker receives the full unmeasured delta from that boundary forward; the previous worker keeps what was measured up to the boundary.
- **No active worker** at a trusted boundary → that block is unattributed (never fabricated to an owner) and excluded from precise per-worker totals.

## 4. Backend Contract Changes

**Endpoint (unchanged):**

```
GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/summary
Header: X-Session-Token   (also X-Device-Key device chain)
→ ApiResponse<RollWorkerShiftLineSummaryResponse>
```

**Response — `RollWorkerShiftLineSummaryResponse` (relevant fields):**

```jsonc
{
  "shiftLineId": 80,
  "thermoformingShiftId": 1201,
  "thermoformingLineId": 5,
  "thermoformingLineCode": "TL-05",
  "thermoformingLineName": "خط التشكيل 5",
  "thermoformingLineDisplayName": "TL-05 — خط التشكيل 5",
  "currentPlanItemProductTypeId": 33,
  "currentPlanItemProductName": "كوب 200مل",
  "allowedRolls": [ /* AllowedRoll[] — unchanged */ ],

  // ── counters ──
  "completedRollsInSession": 3,          // session-scoped completed mount cycles (resets on fresh login) — UNCHANGED meaning
  "completedRollsByCurrentWorker": 3,    // NEW: == completedRollsInSession (a session is tied to one worker)

  // ── employee-scoped metrics (V123) ──
  "consumedWeightKgInSession": 142.500,  // PRIMARY kg metric — this worker's CLOSED blocks on this line + live provisional
  "rollsContributedInSession": 4,        // SECONDARY — DISTINCT rolls the worker consumed (>0 kg)

  // ── live mounted roll (provisional kg source) ──
  "mountedRoll": {
    "consumptionItemId": 8801,
    "rollId": 4501,
    "generatedRollId": "003000000777",
    "rollTypeCode": "PP-1200",
    "rollTypeName": "بولي بروبيلين 1200",
    "lastKnownWeightKg": 30.000          // current physical weight; drives provisional kg (start − current)
  },

  // ── employee-scoped consumed list ──
  "consumedRolls": [
    {
      "consumptionItemId": 8790,
      "rollId": 4490,
      "generatedRollId": "003000000770",
      "rollTypeCode": "PP-1200",
      "rollTypeName": "بولي بروبيلين 1200",
      "startWeightKg": 50.000,
      "endWeightKg": 8.000,
      "consumedWeightKg": 42.000,        // THIS worker's interval contribution (not necessarily the whole roll)
      "remainingWeightKg": 8.000,
      "contributionType": "FINAL_FULL",  // FINAL_FULL/FINAL_RETURN/FINAL_GRINDING/HANDOVER/TAKEOVER_*/OPERATOR_*
      "closedReason": "FULL_CONSUMPTION",
      "remainderAction": "NONE",
      "endedAt": "2026-06-21T11:00:00.000+03:00",
      "endedAtDisplay": "٢١ يونيو ٢٠٢٦، ١١:٠٠ صباحاً",
      "reprintAvailable": false,
      "reprintLabelType": null,
      "labelTimestamp": null
    }
  ],

  // ── additive line-state fields (nullable) ──
  "activeOperatorId": 71,
  "activeOperatorName": "م. أحمد",
  "blocked": false,
  "blockedReason": null,
  "handoverPending": false,
  "takeoverRequestStatus": null,
  "takeoverIncomingOperatorName": null,
  "lineLifecycleStatus": "ACTIVE"
}
```

**Key semantics:**

- **`consumedRolls`** — now the worker's **CLOSED, positively-consuming blocks on this shift-line**, newest-first, capped at `CONSUMED_ROLLS_LIMIT = 10`. Sourced via `RollEmployeeConsumptionSegmentRepository.findOperatorContributionsForShiftLine(operatorId, shiftLineId, …)`. **Survives logout/login** (re-queried by operator id + line). The live mounted roll is **excluded** here and reported in `mountedRoll`. Empty list = the worker hasn't consumed anything on this line yet.
- **`consumedWeightKgInSession`** — sum of the worker's CLOSED blocks **plus** live provisional from the open block on the mounted roll (`mountedRoll.lastKnownWeightKg`): provisional `= openBlock.boundaryStartWeight − mountedRoll.lastKnownWeightKg` when positive and owned by this worker. So a freshly-taken-over roll (start 50, now 30 → 20 kg) shows immediately, before terminal close.
- **`rollsContributedInSession`** — count of **distinct** rolls the worker consumed with positive weight (zero-consumption handovers excluded); survives logout/login.
- **`completedRollsInSession` / `completedRollsByCurrentWorker`** — both are **session-scoped** completed mount cycles (FULL/RETURN/GRINDING), reset on a fresh login. They are intentionally equal (a session = one worker). These are "rolls I just finished this session", distinct from the employee-scoped kg metrics above.
- **Card ↔ list reconciliation:** card totals = Σ(`consumedRolls[].consumedWeightKg`) + provisional from the open block. Same source ⇒ always reconciles.

**Empty case:**

```jsonc
{
  "shiftLineId": 80,
  "completedRollsInSession": 0,
  "completedRollsByCurrentWorker": 0,
  "consumedWeightKgInSession": 0.000,
  "rollsContributedInSession": 0,
  "mountedRoll": null,
  "consumedRolls": [],
  "allowedRolls": [ /* … */ ]
  // nullable line-state fields omitted (NON_NULL)
}
```

**Worker-scoped session endpoint (unchanged, for reference):**

```
GET /api/v1/thermoforming-roll-app/sessions/me
Header: X-Session-Token
→ ApiResponse<RollWorkerMeResponse>
{
  "rollWorkerOperatorId": 91,
  "rollWorkerName": "م. سامي",
  "lines": [ /* RollWorkerActiveLineResponse[] — every ACTIVE line for this operator */ ]
}
```

This already returns **all** active lines for the worker (a roll worker may be active on multiple lines). No raw tokens are returned.

## 5. Required Frontend Screens / Dialogs

- **Consumed-rolls list:** unchanged structure; just keep rendering `consumedRolls`. It will now persist across logout/login and reflect per-interval (not whole-roll) contributions.
- **Consumed-kg card:** bind to `consumedWeightKgInSession` (includes live provisional). Optionally show `rollsContributedInSession` as "distinct rolls".
- **Counters:** if the app shows "rolls finished this session", keep using `completedRollsInSession` (or the alias `completedRollsByCurrentWorker`).

## 6. Required Models / DTO Changes

- **`RollWorkerShiftLineSummaryResponse`** — add nullable fields if not already present: `completedRollsByCurrentWorker: int`, `consumedWeightKgInSession: num`, `rollsContributedInSession: int`, plus the additive line-state fields (`activeOperatorId/Name`, `blocked`, `blockedReason`, `handoverPending`, `takeoverRequestStatus`, `takeoverIncomingOperatorName`, `lineLifecycleStatus`). Existing fields unchanged.
- **`ConsumedRoll`** — no field changes; the **population source** changed (employee-scoped), so the list may now include partial / keep-mounted / takeover-credited contributions on rolls not closed in the current session.
- **`MountedRoll`** — `lastKnownWeightKg` now also feeds the provisional kg; no shape change.
- No enum changes. No `attributionStatus`/`LEGACY` field on the response (employee continuity is implicit in the operator + line scoping).

## 7. Required Repository / API Client Changes

- None for compatibility. Optionally parse the new fields. Same path/method/header/error mapping.

## 8. Required Provider / State Management Changes

- None required. If surfacing the new fields, carry `consumedWeightKgInSession` / `rollsContributedInSession` into the summary view-model.
- **Remove any client-side assumption that the consumed list resets on logout** — it now persists; don't clear it locally on logout/login.

## 9. Required UX Flow

- **Same worker logout → login:** consumed list and kg persist (no reset). The card may include live provisional kg for the mounted roll.
- **Different-worker takeover:** the new worker sees the unmeasured delta credited to them at the trusted boundary; the previous worker's list shows only their measured contributions.
- **No active worker block:** excluded from per-worker totals (not shown as anyone's contribution).
- **Empty:** worker with no consumption shows an empty list + 0 kg (expected, not an error).

## 10. Arabic UI Text (suggested)

- Consumed-kg card: `الوزن المُستهلَك (كغم)`
- Distinct rolls: `عدد الرولات` / `رولات ساهمت بها`
- Provisional hint (optional): `يشمل الرول المُركّب حالياً (تقديري حتى الإغلاق).`
- Finished this session: `رولات أنهيتها في هذه الجلسة`

## 11. Edge Cases & Error Codes

| Error code | When |
|---|---|
| `ROLL_WORKER_SESSION_REQUIRED` | Token missing / mismatched against `shiftLineId` / shift-line gone / session not ACTIVE |
| `ROLL_WORKER_SESSION_BATCH_EMPTY` | Batch auth with no shift-line ids |
| `ROLL_WORKER_SESSION_LINE_DUPLICATE` | Duplicate id in batch |
| `ROLL_WORKER_SESSION_LINE_INACTIVE` | Line not ACTIVE |
| `ROLL_WORKER_SESSION_LINE_USED_BY_OTHER_WORKER` | Line owned by a different roll worker |

Other edge cases:
- **List capped at 10** (`CONSUMED_ROLLS_LIMIT`) — newest-first; older contributions beyond 10 are not returned (document if the app implies "all").
- **Provisional kg** appears only when a roll is mounted, owned by this worker, and the open-block start exceeds the current weight.
- **Multi-line worker:** `/sessions/me` returns all active lines; the summary is per shift-line.

## 12. Testing Requirements

- Same worker: consume → logout → login → summary still shows the list + kg (no reset).
- Different-worker takeover: previous worker's list excludes the post-takeover delta; new worker's includes it.
- Live provisional: mount at 50, consume to 30 → card shows +20 before close.
- Card ↔ list reconcile: Σ list `consumedWeightKg` + provisional == `consumedWeightKgInSession`.
- Empty worker → empty list + 0 kg (no crash).
- No-active-worker block → not attributed to anyone.

## 13. Backend Compatibility Notes (Rollout)

- **Additive / backward-compatible.** No field renamed/removed; new fields nullable/boxed (`@JsonInclude(NON_NULL)`).
- Backend may deploy **before** the app. Old builds keep deserializing; they simply won't reflect cross-login continuity until updated to rely on the corrected semantics (and they must stop locally clearing the list on logout to benefit).
- Decimal kg values are JSON numbers, scale 3.

## 14. Final Acceptance Criteria

- Consumed list + kg persist across the same worker's logout/login on the same line.
- Worker takeovers attribute the unmeasured delta to the new worker; previous worker keeps measured-only.
- Live provisional kg from the mounted open block shows in the card before terminal close.
- Card and list reconcile.
- No client code clears the consumed list purely because of a logout.
