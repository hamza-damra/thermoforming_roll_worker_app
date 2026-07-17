# Frontend Handoff — Backend/API Contract — Roll-Weight Disputes & Roll Accounting (V123)

> **Cross-cutting contract reference** for the V123 roll-weight-dispute + roll-employee-accounting release. This is the single source of truth for endpoints, request/response shapes, error codes, decimal precision, additive-vs-breaking classification, and rollout order across all apps. The per-app handoffs reference this file for the wire contract.

## 0. App Impact Matrix

| App | Affected? | Nature | Per-app handoff |
|---|---:|---|---|
| **Admin App** | **Yes** | **BREAKING** — admin-forced shift-end `mountedRollDecision` enum changed (removed RETURN/GRINDING, added PASS_TO_NEXT_SHIFT requiring weight). | `FRONTEND_HANDOFF_ADMIN_APP_FORCED_SHIFT_END_MOUNTED_ROLL_DECISION.md` |
| **Operator App** | **Yes** | **Additive** — roll-weight objection at receipt; observed-weight at takeover completion. | `FRONTEND_HANDOFF_OPERATOR_APP_ROLL_WEIGHT_DISPUTES.md` |
| **Roll Worker App** | **Yes** | **Additive/semantic** — consumed list + kg now employee-scoped (survive logout/login). | `FRONTEND_HANDOFF_ROLL_WORKER_APP_EMPLOYEE_SCOPED_CONSUMPTION.md` |
| Warehouse App | **No** | Movement + officer-plan endpoints only; no thermoforming/roll surface. | — |
| Palletizing App | **No** | Legacy device API; handover reject disabled; no admin shift-end. | — |
| Roll Production App | **No** | Extrusion/roll-production app; not a thermoforming receipt or roll-worker-summary consumer. | — |

**Manager resolution surface** is the **admin web portal** (`/web/admin/falet-disputes` → roll-weight tab), not a mobile app. It is server-rendered Thymeleaf in this repo and needs no frontend handoff.

## 1. Decimal Precision Policy

All roll weights are **`BigDecimal`**, DB column `DECIMAL(12,3)` → **scale 3** (max 3 fractional digits). Serialized as JSON **numbers** (not strings). Clients must:

- send at most 3 decimals (`@DecimalMin("0.000")` floors at 0; scale > 3 is rejected),
- not assume trailing zeros (`30`, `30.0`, `30.000` are equal; the no-mismatch guard normalizes scale before comparing declared vs observed).

## 2. Endpoint Catalog

### 2.1 Admin App — admin-forced operator-shift-end (BREAKING)

```
POST /api/v1/admin-app/thermoforming-lines/{lineId}/operator-shift/end
Auth: ADMIN role (JWT). MONITORING → 403.
```

Request `EndOperatorShiftRequest`:
```jsonc
{ "confirm": true, "faletPackageQuantity": 6,
  "mountedRollDecision": "PASS_TO_NEXT_SHIFT",  // FULL_CONSUMPTION | PASS_TO_NEXT_SHIFT (only)
  "remainingWeightKg": 4.5 }                    // required >0 ONLY for PASS_TO_NEXT_SHIFT
```
Response `EndOperatorShiftResultDto`:
```jsonc
{ "successMessage": "…", "lineId": 1, "palletizingLineId": 10, "endedAuthorizationId": 555,
  "faletRecorded": true, "faletPackageQuantity": 6,
  "labelGeneratedRollId": null,    // ALWAYS null here
  "requiresRefresh": true }        // ALWAYS true → refetch detail
```
Option list (drive UI from this, don't hardcode):
```
GET /api/v1/admin-app/thermoforming-lines/{lineId}
→ data.actions.endOperatorShift.availableMountedRollDecisions: [{code,labelAr}]   // JSON field is "endOperatorShift" (type EndOperatorShiftCapabilityDto)
  [ {"code":"FULL_CONSUMPTION","labelAr":"استهلاك كامل"},
    {"code":"PASS_TO_NEXT_SHIFT","labelAr":"تمرير للمناوبة التالية"} ]
```

### 2.2 Operator App — receive-context (read inherited declaration)

```
GET /api/v1/thermoforming-app/lines/{thermoformingLineId}/receive-context
Auth: X-Device-Key + (X-Session-Token OR X-Operator-Auth-Token)
→ ThermoformingLineReceiveContextResponse.mountedRollHandover (MountedRollHandoverSection)
```
`mountedRollHandover.declaredRemainingWeightKg` (scale 3) is the weight the receipt dialog renders. Empty: `{ hasMountedRollDeclaration:false, status:"NO_MOUNTED_ROLL" }`.

### 2.3 Operator App — pending-handover preview / accept / object

```
GET  /api/v1/thermoforming-app/shift-lines/{shiftLineId}/pending-handover     (X-Session-Token)
POST /api/v1/thermoforming-app/shift-lines/{shiftLineId}/pending-handover/confirm  (LineHandoverConfirmRequest, nullable)  → accept
POST /api/v1/thermoforming-app/shift-lines/{shiftLineId}/pending-handover/reject   (LineHandoverRejectRequest)             → object
→ ApiResponse<LineHandoverResponse>
```

`LineHandoverRejectRequest` (existing FALET fields + V123 roll-weight fields):
```jsonc
{ "incorrectQuantity": false, "otherReason": false, "otherReasonNotes": null,
  "undeclaredFaletFound": false, "undeclaredFaletObservedQuantity": null, "undeclaredFaletNotes": null,
  "itemObservations": [],
  "incorrectMountedRollWeight": true,             // V123
  "mountedRollHandoverDeclarationId": 9001,       // V123 (Long)
  "mountedRollObservedWeightKg": 27.000,          // V123 (BigDecimal, scale ≤3, ≥0.000)
  "clientRequestId": "op-recv-7f3a" }             // V123 (≤64, idempotency)
```

**Objection scope semantics (no silent downgrade):**

| Scope | `incorrectMountedRollWeight` | FALET fields | Result |
|---|---|---|---|
| FALET only | false | set | handover **REJECTED** (FALET dispute); no roll dispute |
| Roll only | true | normal | handover **CONFIRMED** (FALET transfers); independent **OPEN** RollWeightDispute |
| Both | true | set | FALET dispute (REJECTED) **+** roll dispute, **atomic** |

Equal declared/observed (after scale-normalize) with `incorrectMountedRollWeight=true` → **`ROLL_WEIGHT_OBJECTION_NO_MISMATCH` (409)**, no mutation, for **both** roll-only and combined.

### 2.4 Operator App — takeover completion observed weight (no dispute)

```
POST /api/v1/thermoforming-app/lines/{thermoformingLineId}/takeover-request/complete-acceptance        (X-Session-Token, CompleteTakeoverAcceptanceRequest)
POST /api/v1/thermoforming-app/lines/{thermoformingLineId}/takeover-request/register-falet-and-accept   (X-Session-Token, RegisterUndeclaredFaletRequest)
POST …/complete-acceptance/pre-shift            (X-Operator-App-Token, CompleteTakeoverAcceptanceRequest)
POST …/register-falet-and-accept/pre-shift      (X-Operator-App-Token, RegisterUndeclaredFaletRequest)
→ ApiResponse<TakeoverRequestResponse>
```
`CompleteTakeoverAcceptanceRequest { observedMountedRollWeightKg: BigDecimal? (scale≤3, ≥0.000), clientRequestId: String? (≤64) }` — null observed ⇒ keep declared.
`RegisterUndeclaredFaletRequest { productTypeId, quantity(≥1), notes?, observedMountedRollWeightKg? }`.
Invalid observed → **`TAKEOVER_OBSERVED_WEIGHT_INVALID` (409)** — never a dispute.

### 2.5 Roll Worker App — employee-scoped summary (additive/semantic)

```
GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/summary   (X-Session-Token)
→ ApiResponse<RollWorkerShiftLineSummaryResponse>
GET /api/v1/thermoforming-roll-app/sessions/me                          (X-Session-Token)
→ ApiResponse<RollWorkerMeResponse>
```
Key fields: `consumedRolls` (employee-scoped, survives logout/login, cap 10), `consumedWeightKgInSession` (CLOSED blocks + live provisional), `rollsContributedInSession` (distinct rolls >0), `completedRollsInSession` / `completedRollsByCurrentWorker` (session-scoped, equal), `mountedRoll.lastKnownWeightKg` (provisional source). No field renamed/removed.

### 2.6 Manager resolution (web portal — informational, not a frontend app)

```
GET  /web/admin/falet-disputes/rolls          (ADMIN — roll-weight tab, real DB pagination)
GET  /web/admin/falet-disputes/rolls/{id}      (ADMIN — detail + both-option preview)
POST /web/admin/falet-disputes/rolls/{id}/decide   (ADMIN — decision = SENDER_RIGHT | RECEIVER_RIGHT, CSRF)
```
Decision corrects **accounting only** via a signed correction ledger; never touches the live physical roll weight. Resolved disputes are permanent (one dispute per declaration boundary for life).

## 3. Error-Code Matrix

| Code | HTTP | Surface | Trigger |
|---|---:|---|---|
| `VALIDATION_ERROR` | 400 | Admin end-shift | `confirm!=true`; FALET<0; PASS weight null/≤0; FALET>0 no plan item; admin actor missing |
| `MOUNTED_ROLL_DECISION_REQUIRED_FOR_PLAN_MUTATION` | 409 | Admin end-shift | Roll mounted, `mountedRollDecision` null |
| `THERMOFORMING_LINE_NOT_FOUND` | 404 | Admin end-shift | Line/linked palletizing line unknown |
| `LINE_AUTHORIZATION_NOT_FOUND` | 409 | Admin end-shift | No active operator session to end |
| `THERMOFORMING_SHIFT_LINE_NOT_FOUND` | 409 | Admin end-shift | No active thermoforming shift-line |
| *(Jackson deserialization)* | 400 | Admin end-shift | App sent removed enum (`RETURN_REMAINING`/`SEND_REMAINING_TO_GRINDING`) — **breaking** |
| `ROLL_HANDOVER_DECLARATION_NOT_FOUND` | 404 | Operator receipt | Declaration id unknown |
| `ROLL_WEIGHT_OBSERVATION_REQUIRED` | 400 | Operator receipt | Objection true, no observed weight |
| `ROLL_WEIGHT_OBSERVED_INVALID` | 400 | Operator receipt | Observed null/negative/scale>3 |
| `ROLL_WEIGHT_OBSERVED_EXCEEDS_START` | 400 | Operator receipt | Observed > interval start weight |
| `ROLL_HANDOVER_DECLARATION_LINE_MISMATCH` | 409 | Operator receipt | Declaration not for this line |
| `ROLL_HANDOVER_DECLARATION_ROLL_MISMATCH` | 409 | Operator receipt | Declaration for a different roll/item |
| `ROLL_HANDOVER_UNAUTHORIZED_RECEIVER` | 403 | Operator receipt | Caller not authorized receiver (not currently wired) |
| `ROLL_WEIGHT_OBJECTION_NOT_APPLICABLE` | 409 | Operator receipt | Source not dispute-capable / no live DECLARED declaration |
| `ROLL_WEIGHT_DISPUTE_ALREADY_EXISTS` | 409 | Operator receipt | Dispute already exists for this declaration boundary (permanent uniqueness) |
| `ROLL_WEIGHT_OBJECTION_NO_MISMATCH` | 409 | Operator receipt | Observed == declared after normalization |
| `TAKEOVER_OBSERVED_WEIGHT_INVALID` | 409 | Operator takeover | Observed null/negative/scale>3/exceeds start |
| `MOUNTED_ROLL_HANDOVER_ACK_REQUIRED` | 409 | Operator receipt | Legacy accept-only opt-out with live declaration |
| `ROLL_WEIGHT_DISPUTE_NOT_FOUND` | 404 | Web admin | Decision on nonexistent dispute |
| `ROLL_WEIGHT_DISPUTE_ALREADY_RESOLVED` | 409 | Web admin | Second/concurrent decision on resolved dispute |
| `ROLL_WEIGHT_DISPUTE_INVALID_DECISION` | 400 | Web admin | Decision not SENDER_RIGHT/RECEIVER_RIGHT |
| `OPERATOR_SHIFT_ACCOUNTING_SEGMENT_MISSING` | 409 | Web admin | OSRCS segment referenced by decision missing |
| `OPERATOR_SHIFT_ACCOUNTING_INVARIANT_VIOLATION` | 500 | Web admin | Decision yields negative consumption |
| `ROLL_WORKER_SESSION_REQUIRED` | 401/403 | Roll worker | Token missing/mismatched/inactive |
| `ROLL_WORKER_SESSION_LINE_USED_BY_OTHER_WORKER` | 409 | Roll worker | Line owned by a different roll worker |

All errors use the standard envelope `{ "success": false, "data": null, "error": { "code", "message", "details" } }`.

## 4. Additive vs Breaking Classification

| Change | Class | Reason |
|---|---|---|
| Admin `mountedRollDecision` enum (remove RETURN/GRINDING, add PASS_TO_NEXT_SHIFT) | **BREAKING** | Old enum values fail Jackson deserialization (400) |
| Admin `remainingWeightKg` required for PASS_TO_NEXT_SHIFT | Additive within new enum | Only relevant once app sends the new value |
| Operator `LineHandoverRejectRequest` roll-weight fields | **Additive** | New optional fields; old clients omit |
| Operator takeover `observedMountedRollWeightKg` | **Additive** | Optional; null keeps declared |
| Roll worker summary employee-scoped sourcing + new fields | **Additive/semantic** | No field renamed/removed; nullable additions; population source changed |
| New error codes | **Additive** | New codes only on new code paths |

## 5. Rollout Order

1. **Admin App update must ship before or with the backend** (the end-shift enum change is breaking). Prefer driving the picker from `availableMountedRollDecisions`.
2. **Operator App** and **Roll Worker App** updates are additive → backend may deploy first; ship app updates to expose the new capability/continuity.
3. Web admin roll-weight tab ships **in the same backend release** (server-rendered; no app dependency).
4. Backfill migrations V124 (reconstruct accounting from history) + V125 (finalize/cutover) run at boot **before** the app serves traffic, so re-pointed read paths are populated before any read switches over. (V124/V125 data verification on the real MySQL clone is a later phase; this contract is independent of that verification.)

## 6. i18n / Arabic UX Notes

- Manager decision result text and web-portal labels are localized server-side (both `messages.properties` and `messages_ar.properties`); the admin web portal renders Arabic/RTL.
- App-facing Arabic UI text (labels, validation messages, success toasts) is specified per app in the three per-app handoff files (§10 of each).
- Server-provided labels (e.g. `availableMountedRollDecisions[].labelAr`) should be preferred over hardcoded client strings where available.

## 7. Idempotency / Retry

- **Roll-weight objection:** `clientRequestId` (≤64) → stored as `RollWeightDispute.correlationId`. Same id + same declaration ⇒ existing dispute returned (no duplicate); permanent `UNIQUE(source_handover_declaration_id)` is the backstop (`ROLL_WEIGHT_DISPUTE_ALREADY_EXISTS`).
- **Takeover observed:** `CompleteTakeoverAcceptanceRequest.clientRequestId` correlates but creates **no** dispute (takeover boundaries are authoritative). Takeover operation idempotency is the existing shift-line-scoped key (V109/V110): same key + identical body → original outcome replayed; different body → 409.
- Clients should reuse the same `clientRequestId` on retry of the same logical action.

## 8. Acceptance (contract-level)

- Every endpoint above responds with the standard `ApiResponse<T>` envelope.
- Weights round-trip at scale ≤ 3 without precision loss.
- Breaking change (admin enum) is gated behind the Admin App update + rollout order in §5.
- All error codes in §3 are emitted only on their documented paths and map to Arabic messages in each app.
- No manager decision ever changes a live physical roll weight (accounting-only corrections).
