# Backend Handoff — Roll Worker — Remaining/Current Weight Must Be > 0

> Audience: the **Backend** team for the Roll Worker subsystem
> (`ps.taleeb.taleebbackend.thermoformingrollapp`).
> Origin: Roll Worker App (Flutter) production-data-integrity fix.
> Status: **frontend validation already shipped**; this handoff requests the
> matching **server-side** guard so invalid production data cannot be written
> by an older/forged client. Frontend validation is necessary but not
> sufficient.

---

## 1. Problem

When a roll worker leaves a line (or a new worker takes over) and the mounted
roll still has material, the worker declares the **remaining / current weight**
of the roll. The app previously allowed entering **0** for these actions, which
is wrong: a remaining weight of `0` means the roll is finished, and that case
must go through **full consumption** (which takes no weight), not through a
"the roll still has material" action.

Entering `0` for a remaining-weight action produced misleading bookkeeping
(e.g. `consumed = lastKnownWeight − 0 = lastKnownWeight`) while still flagging
the roll as partially handled.

## 2. Business rule

For the **"roll still has material"** decisions, the declared weight must be:

```
0 < remainingWeightKg <= lastKnownWeightKg
```

For **full consumption**, weight is omitted/ignored (the roll is finished).
`remainingWeightKg = 0` is valid **only** for full consumption.

## 3. Affected endpoints / actions

Please enforce the rule above on every endpoint that accepts a
remaining/current weight for a "still has material" decision:

| Action | Endpoint (approx.) | Weight field |
|---|---|---|
| Keep-mounted handover (leaving worker passes the roll to the next worker) | `POST …/shift-lines/{shiftLineId}/roll-worker-handover` (keep-mounted) | `remainingWeightKg` / `currentWeightKg` |
| Return remaining to warehouse | `POST …/shift-lines/{shiftLineId}/previous-roll/return-remaining` | `remainingWeightKg` |
| Send remaining to grinding | `POST …/shift-lines/{shiftLineId}/previous-roll/send-to-grinding` | `remainingWeightKg` |
| Takeover → "roll remains mounted" (new worker keeps the roll) | `POST …/sessions/takeover` with `action = ROLL_REMAINS_MOUNTED` | `currentWeightKg` |
| Full consumption | the full-consume endpoints | weight omitted/ignored — **no change** |

(Endpoint paths are indicative; apply the rule wherever these actions are
handled.)

## 4. Requested backend behavior

For the four "still has material" actions:

1. Reject the request when the declared weight is **null, ≤ 0, or
   > lastKnownWeightKg** (the backend's authoritative persisted current roll
   weight, e.g. `RollConsumptionState.lastKnownWeightKg`).
2. Return **`VALIDATION_ERROR`** (HTTP 400) — consistent with the existing
   weight-validation errors so the app renders an inline Arabic message.
3. The error message should make the corrective action explicit, e.g.:
   *"الوزن المتبقي يجب أن يكون أكبر من 0 وأقل من أو يساوي وزن الرول الحالي. إذا
   انتهى الرول اختر استهلاك كامل."*
   (English: "Remaining weight must be > 0 and ≤ the current roll weight. If
   the roll is finished, choose full consumption.")

For **full consumption**: keep current behavior — weight is omitted/ignored;
do **not** start requiring a positive weight there.

## 5. Why this is needed (do not rely only on the client)

The Flutter app now disables the confirm button and validates
`0 < weight <= lastKnownWeightKg` for all four actions
(`RemainingWeightValidation`). However, a stale app build, a replayed request,
or a non-app client could still submit `0`/invalid weights. Production weight
data feeds warehouse return and grinding records, so the invariant must be
enforced server-side as the source of truth.

## 6. Acceptance

- Keep-mounted / return / grinding / takeover-remains-mounted with
  `weight = 0` → `400 VALIDATION_ERROR` (not accepted).
- Same with `weight > lastKnownWeightKg` → `400 VALIDATION_ERROR`.
- Same with `0 < weight <= lastKnownWeightKg` → accepted.
- Full consumption with no weight → accepted (unchanged).

## 7. Frontend status (for reference)

- Frontend validator: `lib/features/previous_roll/presentation/widgets/remaining_weight_validation.dart`.
- Applied in: `keep_mounted_handover_dialog.dart`, `return_remaining_dialog.dart`,
  `grinding_dialog.dart`, and `roll_worker_takeover_card.dart` (remains-mounted).
- Confirm button stays disabled until `0 < weight <= lastKnownWeightKg`.
