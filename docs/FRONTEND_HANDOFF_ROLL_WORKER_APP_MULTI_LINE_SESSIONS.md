# Frontend Handoff — Roll Worker App — Multiple Active Lines Per Worker (Multi-Line Sessions)

> Audience: the **Roll Worker App** frontend AI agent (Flutter).
> Backend status: **the required contract is already implemented and correct on the backend.** This change is **frontend-side + backend tests + this document**. No backend behaviour changed. Backend tests added: `RollWorkerMeServiceTest`, additive/no-duplicate cases in `RollWorkerSessionServiceBatchTest`, and a real-MySQL `RollWorkerSessionMultiLineMysqlTest` (per-shift-line uniqueness + multi-line coexistence).
> Backend module: `ps.taleeb.taleebbackend.thermoformingrollapp`. All endpoints are under `/api/v1/thermoforming-roll-app/**` and behind the device-key chain (`X-Device-Key`).

---

## App Impact Matrix

| App | Affected? | Reason | Required Handoff File |
|---|---:|---|---|
| Warehouse App | No | Pallet/warehouse flows are untouched. | — |
| Admin App (mobile) | No | No roll-worker session contract is consumed there. | — |
| Palletizing App | No | Palletizer sessions are a separate subsystem. | — |
| **Roll Worker App** | **Yes** | The local **active-session registry must become merge-based**, tokens must be stored **per `shiftLineId`**, and the app must stop cascade-dropping a line based on a misread of `/sessions/me`. | `docs/frontend-handoffs/FRONTEND_HANDOFF_ROLL_WORKER_APP_MULTI_LINE_SESSIONS.md` (this file) |
| Roll Production App | No | Upstream of consumption; no contract changed. | — |
| Operator App (Thermoforming) | No | No operator contract changed. | — |

---

## 1. Executive Summary

**Corrected business rule:** *One roll worker may be ACTIVE on more than one machine / thermoforming shift-line at the same time.* This is normal floor behaviour — one roll worker (عامل الرولات) commonly runs two thermoforming lines. The system does **not**, and must **not**, enforce "one active machine per roll worker."

**The production bug (what users saw):**
1. Worker was already ACTIVE on machine B (`shiftLine=82`).
2. Worker logged into machine A: `POST /sessions/start-batch` with `shiftLineIds=[81]` → **201**.
3. `GET /shift-lines/81/summary` → **200** (81 is genuinely active).
4. App then called `GET /sessions/me`, saw a list it interpreted as "only 82", logged **"cascade detected → dropping [81]"**, and fell back to `لا يوجد موظف رولات مسجل` → login loop.
5. After logging out of machine B, machine A worked normally.

**Root cause:** the backend `start-batch` is **additive** (it added 81 and left 82 active) and `/sessions/me` is **worker-scoped** (it returns *all* of the worker's active lines). The drop came from the app treating session state as **replace-based** and cascade-dropping a line that was never actually ended. The app must switch to a **merge-based** registry and only drop a line when the backend explicitly confirms *that exact* `shiftLineId` ended.

**What the app must change:** store one token per `shiftLineId`; merge (never replace) the registry on a successful `start-batch`; never drop a line unless an explicit end signal for that `shiftLineId` arrives; always call a per-line summary with **that line's own token**.

---

## 2. Affected App

**Roll Worker App** (Flutter), operated by عامل الرولات. Not affected: Warehouse App, Palletizing App, Roll Production App, Operator App, Admin mobile App.

---

## 3. The `/sessions/me` Contract (authoritative)

`GET /api/v1/thermoforming-roll-app/sessions/me`
Headers: `X-Device-Key`, `X-Session-Token` (any one of the worker's valid line tokens).

- **Worker/operator-scoped, NOT token-scoped.** The `X-Session-Token` is used **only** to identify the owning worker. The response then lists **every** ACTIVE session that worker holds, across **all** shift-lines — regardless of which line's token you sent. Calling it with line 81's token or line 82's token returns the **same** full list.
- It is **authoritative for the resolved worker**: the `lines` array is the complete set of that worker's currently-active lines at request time.
- It **does NOT return raw session tokens** — and cannot: the backend persists only a SHA-256 hash; the raw token is shown **once**, in the `start-batch` / single-line auth response. Per line it returns `sessionId` + `shiftLineId` (your join key) and rich per-line state.
- **Failure modes:** if the supplied token no longer resolves to an ACTIVE session, the call **errors** (HTTP 404 `No matching… session` / 401 `not active`) — it does **not** return a misleading partial list. So a non-2xx `/sessions/me` means "re-pick a still-valid token", not "all my lines ended."

Response shape:

```jsonc
{
  "success": true,
  "data": {
    "rollWorkerOperatorId": 7,
    "rollWorkerName": "Ahmad",
    "lines": [
      {
        "sessionId": 482,
        "shiftLineId": 82,            // ← JOIN KEY: map to your locally-stored token
        "palletizingLineId": 820,
        "thermoformingLineId": 12,
        "thermoformingLineName": "Thermo 82",
        "lineLifecycleStatus": "ACTIVE",
        "blocked": false,
        "handoverPending": false,
        "currentRollId": null,
        "sessionStartedAt": "2026-06-09T10:00:00.000+03:00"
        // ... NO sessionToken field
      },
      { "sessionId": 481, "shiftLineId": 81, /* ... */ }
    ]
  },
  "error": null
}
```

---

## 4. The `start-batch` Contract (additive — the key fix)

`POST /api/v1/thermoforming-roll-app/sessions/start-batch`
Headers: `X-Device-Key`. Body: `{ "pin": "1234", "shiftLineIds": [81] }`.

- **Additive per shift-line.** Opening sessions for the requested lines does **not** touch the worker's sessions on **other** lines. `start-batch [81]` while `82` is active leaves `82` ACTIVE and unchanged.
- Each returned session carries its **own raw `sessionToken`** — this is the **only** time you receive it. **Store it keyed by `shiftLineId`.**
- Re-running `start-batch` for a line the **same** worker already owns **replaces** that line's session (old → `REPLACED_BY_NEW_AUTH`) and returns a **fresh token** for it — there is never a duplicate ACTIVE session on one line. Update the stored token for that `shiftLineId`.
- If a line is owned by a **different** worker with a roll still mounted, `start-batch` returns `ROLL_WORKER_TAKEOVER_REQUIRED` (resolve via the takeover flow — see the V104 handoff). This is per-line and does not affect your other lines.

Response shape:

```jsonc
{
  "success": true,
  "data": {
    "rollWorkerOperatorId": 7,
    "rollWorkerName": "Ahmad",
    "sessions": [
      {
        "shiftLineId": 81,
        "sessionId": 481,
        "sessionToken": "raw-uuid-token-for-81",   // ← STORE THIS, keyed by shiftLineId 81
        "thermoformingShiftId": 900,
        "thermoformingLineId": 11,
        "palletizingLineId": 810,
        "startedAt": "2026-06-09T11:00:00.000+03:00",
        "startedAtDisplay": "..."
      }
    ]
  },
  "error": null
}
```

---

## 5. Per-Line Summary Contract

`GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/summary`
Headers: `X-Device-Key`, `X-Session-Token` = **the token for THAT `shiftLineId`**.

- The token is validated against the path's `shiftLineId`. Sending **line 82's token** to `…/shift-lines/81/summary` returns **403** (`Session token does not belong to thermoforming shift-line 81`). This is by design.
- Therefore: **refresh each line's summary using that line's own stored token.** Never share one token across lines.

---

## 6. Required Frontend Behaviour — Merge-Based Registry

The active-session registry must be a **map keyed by `shiftLineId`**, holding the token + last-known per-line state. It must be **merge-based, not replace-based**.

```
registry: Map<shiftLineId, { sessionToken, sessionId, ...lineState }>
```

### Rules

1. **On `start-batch` 201:** for each returned session, **add/update** `registry[shiftLineId] = { sessionToken, ... }`. **Keep all other entries.**
   - `start-batch [81]` while `82` is present → registry now holds **both** 81 and 82.
2. **Never replace the whole registry** from any single response.
3. **`/sessions/me` reconciliation (worker-scoped, authoritative for the worker):**
   - It returns every active line for the worker. **Merge** its `lines` into the registry by `shiftLineId` for state (lifecycle, blocked, mounted roll, etc.).
   - For a `shiftLineId` present in `/sessions/me` but missing a stored token (e.g. token lost): you cannot summarise that line until you re-auth it — surface "re-login this line", do **not** drop the others.
   - A `shiftLineId` you hold a token for but which is **absent** from a **successful** `/sessions/me` **is** authoritative evidence that line ended for this worker → you **may** drop that one entry (see §7).
   - A **non-2xx** `/sessions/me` is **not** evidence any line ended — keep the registry, retry / re-pick a valid token.
4. **Summary refresh uses the per-`shiftLineId` token** (§5). A 403 there means "wrong token for this line", not "line ended."
5. **Do NOT cascade-drop.** Never remove line 81 from the registry because a response (me or summary) was about 82, errored, or transiently omitted 81. Only an explicit end signal for **`shiftLineId=81`** removes 81.
6. **No login loop after a successful `start-batch`.** A 201 from `start-batch` for at least one line means the worker is logged in on those lines; render the multi-line view.

---

## 7. When It Is Legitimate To Drop A Line

Drop `registry[shiftLineId]` **only** when the backend confirms **that exact line** ended:

- You called `…/shift-lines/{id}/roll-worker-logout` for that `id` and it succeeded → drop that `id`.
- You called `POST /sessions/leave-all` → drop **all** (the worker chose to leave every line).
- A **successful** `/sessions/me` no longer lists that `shiftLineId` (the worker's authoritative active set) → drop that one `id`.
- A takeover of **that** line by another worker is confirmed for that `shiftLineId`.
- The line's `lineLifecycleStatus` for that `shiftLineId` reports it ended (`SHIFT_LINE_ENDED`).

Never drop a line because of: a token-scoped misread, a 403 from another line's summary, a transient network error, or a non-2xx `/sessions/me`.

---

## 8. Reproduction → Corrected Flow

| Step | Before (buggy) | After (required) |
|---|---|---|
| 82 active | registry = {82} | registry = {82: token82} |
| `start-batch [81]` → 201 | registry **replaced** → {81} | registry **merged** → {81: token81, 82: token82} |
| `GET /sessions/me` | misread as "only 82" → "cascade → drop 81" | merge → confirms {81, 82}; nothing dropped |
| `…/81/summary` (token81) | — | 200 |
| `…/82/summary` (token82) | — | 200 |
| Result | login loop | both machines visible & manageable |

---

## 9. Acceptance Tests (App)

1. `start-batch [81]` while `82` is active → registry contains **both** 81 and 82; no login loop.
2. Registry stores a distinct `sessionToken` per `shiftLineId`; summary for each line uses its own token (and only its own token).
3. `/sessions/me` returning a list (with either line's token) → registry is **merged**, never truncated to a single line.
4. A non-2xx `/sessions/me` (stale token) → registry preserved; app prompts to re-pick a valid token; no lines dropped.
5. `…/shift-lines/81/summary` called with line 82's token → handle the 403 as "use 81's token", not "81 ended."
6. Explicit logout of 81 → only 81 removed; 82 stays. `leave-all` → all removed.
7. After any successful `start-batch`, the multi-line management UI is shown (no fallback to the empty/login state).

---

## 10. Backward Compatibility

The backend contract is unchanged and additive-safe; this is purely a client-side correctness fix. Older app builds that are replace-based will keep mishandling the second line — which is exactly the incident this fixes. No coordinated backend deploy is required for the contract, though if production is running a build that predates the worker-scoped `/sessions/me`, deploying the current backend is recommended (subject to the JDK 25 + Datadog production gate).

---

## 11. Exact Final Rule

**One roll worker may be ACTIVE on multiple shift-lines at the same time. Uniqueness is enforced per `shiftLineId`, never per worker.** Tokens are stored per `shiftLineId`; the registry is merge-based; a line is dropped only when the backend explicitly confirms that exact `shiftLineId` ended.
