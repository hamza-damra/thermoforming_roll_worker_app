# Frontend Handoff — Roll Worker App: Session & Mounted-Roll Ownership Change (V109)

> **App:** Roll Worker App (Flutter, separate repo).
> **Backend:** Taleeb-Warehouse-Backend, migration **V109**. Hard cutover.
> **Status:** backend implemented & compiling; deploy backend BEFORE installing the new app.

## 1. Executive summary

A mounted roll now belongs to the **line / operator-shift context**, not the roll worker. The roll worker keeps all physical operations during the shift, but **no longer owns mounted-roll continuity**: changing/logging-out/replacing the worker requires **no** mounted-roll disposition and **no** weight. "Roll remains mounted for the next roll **worker**" is removed from active ownership — the OUTGOING OPERATOR decides the roll at shift handover instead.

## 2. App impact matrix

| App | Affected? | Reason |
|---|---|---|
| Roll Worker App | **YES** | Remove keep-mounted/takeover-declaration UX; logout/login with roll mounted; worker-kg metric is now historical. THIS DOC. |
| Operator App | YES | Separate handoff (operator owns the decision). |
| Palletizing App | No | No new contract. Existing automatic session closure during operator-shift handover is unchanged. |
| Roll Production App / Admin App | No | No contract change unless direct code evidence proves otherwise. |

## 3. PRESERVED (unchanged during the active shift)

Keep these actions and their existing contracts:
- Scan / mount a roll — `POST /shift-lines/{id}/scan-roll`.
- Full consume — `POST /shift-lines/{id}/previous-roll/full-consume`.
- Return remaining — `POST /shift-lines/{id}/previous-roll/return`.
- Recommend for grinding — `POST /shift-lines/{id}/previous-roll/grinding`.
- Per-line summary, current mounted-roll visibility — `GET /shift-lines/{id}/summary`, `GET /sessions/me`.
- Login/logout, multi-line worker support, `start-batch`.

## 4. CHANGED behaviour

### 4.1 Login while a roll is mounted — now succeeds
A roll worker (same OR different person) may authenticate on a line that already has a roll mounted. The previous ACTIVE session is cleanly **REPLACED**. No weight is entered; `lastKnownWeightKg` is unchanged; the mounted roll is neither closed nor reopened.
- **`ROLL_WORKER_TAKEOVER_REQUIRED` is no longer thrown on the normal auth path.** Remove the takeover-required dialog/flow from the login path.

### 4.2 Logout while a roll is mounted — plain logout, no weight
`POST /shift-lines/{id}/roll-worker-logout` ends the session and **leaves the roll mounted**, with no weight prompt. Remove any "declare remaining weight before logout" UX.

### 4.3 REMOVE "Roll remains mounted for the next worker"
- The legacy endpoint `POST /shift-lines/{id}/previous-roll/keep-mounted-handover` is **deprecated**: the backend now treats it as a **plain logout** — the submitted weight is **ignored**, `lastKnownWeightKg` is unchanged, no worker segment is written. **Remove this action from the UI** and use plain `/roll-worker-logout` instead.
- The legacy endpoint `POST /sessions/takeover-with-roll-declaration` is **no longer required** for normal login (the takeover gate is removed). Remove the mandatory takeover screen. (The endpoint may remain temporarily but must not be invoked by the new app.)

## 5. Worker-consumption metric change (important)

After removing inter-worker weight boundaries, **per-worker kilograms can no longer be computed for new data**. New `roll_worker_consumption_segments` rows are audit-only (no kg). Consequently:
- The Roll Worker App "kg consumed this session" / per-session contribution list (`GET /sessions/me`, `/shift-lines/{id}/summary`, session-contribution lists) will return **0 / empty for new sessions**. Historical (pre-V109) data is unchanged.
- **Re-source or relabel** this metric: show the worker's **actions** (rolls mounted/closed this session) rather than a fabricated per-worker kg, OR present line/shift production figures clearly labeled as line totals (not personal). Do **not** present a fabricated per-worker kg. Confirm the exact UI with the product owner.

## 6. SSE / state refresh

No new SSE stream. The existing per-line "refresh now" events (operator-dashboard / roll-worker line events) still fire after mount/close/handover. Continue to refetch `GET /bootstrap` (picker) and `GET /shift-lines/{id}/summary` on receipt. REST is authoritative.

## 7. Deployment order & smoke test

Maintenance window (see Operator handoff §10): deploy backend → install Operator App → install Roll Worker App → smoke test (mount; logout with roll mounted → no weight prompt; different worker logs in with roll mounted → succeeds, no takeover dialog; full/return/grinding still work) → return to production.

## 8. Acceptance criteria

Worker can mount/full/return/grind during the shift; can log out and (same or different worker) log in while a roll is mounted with no weight and no takeover dialog; the removed keep-mounted/takeover actions are gone from the UI; the per-worker kg metric is historical/relabeled (never fabricated).
