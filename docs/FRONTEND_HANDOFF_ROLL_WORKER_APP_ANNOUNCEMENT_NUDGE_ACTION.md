# Frontend Handoff — Roll Worker App — Manager-Announcement Nudge `action`

## 1. Executive Summary

**What changed in the backend.** Manager announcements are now *timed*: every announcement carries an
absolute `expiresAt`, and the sanitized SSE nudge this app already receives gains an additive
**`action`** field describing what happened to the announcement (`CREATED` / `UPDATED` /
`DEACTIVATED` / `DELETED`). Previously the nudge only ever meant "one was created".

**Why this app must change.** Strictly speaking it does **not have to**. The change is additive and the
app's existing behaviour — refetch the generic pending notice when a nudge arrives — remains correct
for every action value. This handoff exists because the app's SSE contract changed and that must be
documented rather than discovered.

**Business problem solved.** An announcement that has been switched off, deleted, or retargeted to
another department previously produced no signal at all for this app, so a generic notice could linger
until the next natural refetch. Now every lifecycle step produces a nudge.

**Required before production rollout?** **No.** Backend may deploy first; this app keeps working
unchanged.

## 2. Affected App

**Roll Worker App.**

Related apps, documented separately:

- Roll Production App → `FRONTEND_HANDOFF_ROLL_PRODUCTION_APP_TIMED_MANAGER_ANNOUNCEMENTS.md`
- Thermoforming Operator App → `FRONTEND_HANDOFF_OPERATOR_APP_THERMOFORMING_MANAGER_NOTE_AND_ANNOUNCEMENT_TICKER.md`
- Palletizing App → `FRONTEND_HANDOFF_PALLETIZING_APP_ANNOUNCEMENT_NUDGE_ACTION.md`

Explicitly **unaffected**: Warehouse App, Admin App.

## 3. Business Context

A manager posts an urgent announcement targeted at the **Thermoforming** department. The Roll Worker
App is **not the full-content audience**. The roll worker must never receive the real
manager-announcement body, sender name, or title. It receives only the fixed sanitized generic notice,
so the worker knows that an urgent Thermoforming operator announcement exists and that the operator
needs to open the Operator App to read it. That privacy split is unchanged.

What is new is that the manager can now also **time** the announcement, **edit** it, **switch it off**,
or **move it to another department** — and each of those now reaches the roll worker as a nudge.

## 4. Backend Contract Changes

### 4.0 Authentication — read this before the endpoint sections

Every Roll Worker endpoint sits behind the shared **device** security chain
(`SecurityConfig.thermoformingRollAppFilterChain`, `securityMatcher("/api/v1/thermoforming-roll-app/**")`,
`anyRequest().hasRole("DEVICE")`). Two different headers do two different jobs, and neither substitutes
for the other:

| Header | What it proves | Enforced where |
|---|---|---|
| `X-Device-Key` | **Transport / device identity.** The shared device secret. `DeviceApiKeyFilter` grants `ROLE_DEVICE`; without it the chain never admits the request. It is **not** a business identity. | Security filter chain — applies to *every* path under `/api/v1/thermoforming-roll-app/**`, including SSE |
| `X-Session-Token` | **Business identity.** Resolves an **ACTIVE** Roll Worker session and, through it, the worker's operator id. This is what scopes the pending list and the acknowledgement. | Inside the controller, via `RollWorkerSessionService.requireAnyActiveSession(...)` — *not* at the security layer |

**`X-Device-Key` is required even though it never appears as a controller method parameter.** Only
`X-Session-Token` is declared as an explicit `@RequestHeader`; the device key is consumed by the filter
chain before the controller is reached. Sending only `X-Session-Token` fails at the chain, not in the
controller.

> **The SSE stream is the one exception, and it is deliberate.**
> `GET /api/v1/thermoforming-roll-app/events` requires **only** `X-Device-Key`. It is the *pre-login*
> device-level refresh channel for the line picker — `RollWorkerLineEventsController.subscribe()` takes
> no session-token parameter and `RollWorkerLineEventsSseBroker.register()` holds no session, so the app
> opens the stream **before** PIN login. Sending `X-Session-Token` as well is harmless (it is ignored),
> but it is not required and its absence is not an error. Do not treat the stream as session-scoped:
> the sanitized nudge is broadcast to every connected device, which is exactly why it carries no
> announcement content.

No bearer/JWT authentication exists on any Roll Worker path.

### 4.1 SSE nudge — `urgent-manager-announcement`

Stream: `GET /api/v1/thermoforming-roll-app/events` (unchanged).
SSE event name: `urgent-manager-announcement` (**unchanged**).

```http
GET /api/v1/thermoforming-roll-app/events
X-Device-Key: <shared device key>          # REQUIRED — enforced by the security chain
# X-Session-Token is NOT required on this stream (see §4.0) — it is the pre-login channel
```

**Before**

```jsonc
{
  "eventType": "URGENT_MANAGER_ANNOUNCEMENT_CREATED",
  "announcementId": 99,
  "targetDomain": "THERMOFORMING",
  "priority": "URGENT"
}
```

**Now**

```jsonc
{
  "eventType": "URGENT_MANAGER_ANNOUNCEMENT_CREATED",
  "announcementId": 99,
  "targetDomain": "THERMOFORMING",
  "priority": "URGENT",
  "action": "CREATED"                 // ← NEW: CREATED | UPDATED | DEACTIVATED | DELETED
}
```

**`eventType` is a frozen legacy literal.** It still reads `..._CREATED` for every action, deliberately,
so deployed builds keep matching it. New code should branch on `action`.

The frame still carries **no `message`, no `messageBody`, no `senderDisplayName`, no `title`** — those
fields do not exist on the event type, so they cannot leak.

### 4.2 Generic pending endpoint — unchanged route, two new fields

`GET /api/v1/thermoforming-roll-app/urgent-announcements/pending`

```http
GET /api/v1/thermoforming-roll-app/urgent-announcements/pending
X-Device-Key: <shared device key>                  # REQUIRED — security chain
X-Session-Token: <active roll-worker session token> # REQUIRED — resolves the operator identity
```

Both headers were always required; earlier revisions of this document listed only `X-Session-Token`,
which was incomplete. The route itself is unchanged.

```jsonc
{
  "success": true,
  "data": [
    {
      "id": 99,
      "targetDomain": "THERMOFORMING",
      "title": "ملاحظة عاجلة من المدير",
      "message": "أرسل المدير ملاحظة عاجلة للمشغل. يجب فتح تطبيق المشغل لقراءتها.",
      "createdAt": "2026-07-31T09:00:00.000Z",
      "createdAtDisplay": "2026-07-31، 12:00 مساءً",
      "expiresAt": "2026-07-31T11:00:00.000Z",       // ← NEW (null on a legacy row)
      "expiresAtDisplay": "2026-07-31، 02:00 مساءً",  // ← NEW (null on a legacy row)
      "priority": "URGENT"
    }
  ],
  "error": null
}
```

`title` and `message` remain **fixed generic constants** — never the real announcement content.

Empty case: `{ "success": true, "data": [], "error": null }`

**Expired announcements are now excluded server-side.** The endpoint applies
`active AND (expiresAt IS NULL OR expiresAt > now)`, boundary exclusive.

### 4.3 Ack endpoint

`POST /api/v1/thermoforming-roll-app/urgent-announcements/{id}/ack` — **unchanged**.

```http
POST /api/v1/thermoforming-roll-app/urgent-announcements/{id}/ack
X-Device-Key: <shared device key>                  # REQUIRED — security chain
X-Session-Token: <active roll-worker session token> # REQUIRED — resolves the operator identity
```

**Idempotency is scoped to the acking operator**, resolved from the session — not to the device key and
**not to a line**. The Roll Worker ack passes no line id at all, so one ack dismisses the notice for
that worker across every line session they hold. Acking the same id twice is a no-op. This is unchanged.

### 4.4 Error codes

**No new error codes.** The existing ones, with the precise condition each maps to:

| Condition | HTTP | `error.code` |
|---|---:|---|
| `X-Device-Key` missing, empty, or wrong | 401 | `AUTH_INVALID_CREDENTIALS` — the security chain rejects the request before the controller runs; the message is the generic `"Authentication required"` |
| `X-Session-Token` header entirely absent | 400 | `ROLL_OP_SESSION_TOKEN_MISSING` — Spring's missing-required-header path, handled in `GlobalExceptionHandler` |
| `X-Session-Token` present but blank/whitespace | 400 | `ROLL_WORKER_SESSION_REQUIRED` |
| `X-Session-Token` does not match any session | 404 | `ROLL_WORKER_SESSION_REQUIRED` |
| session found but **not ACTIVE** (ended, replaced, expired) | 401 | `ROLL_WORKER_SESSION_REQUIRED` |
| session ACTIVE but has no resolvable operator | 401 | `ROLL_WORKER_SESSION_REQUIRED` |
| ack of an unknown announcement id | 404 | `ROLL_ANNOUNCEMENT_NOT_FOUND` |

Two things worth reading twice, because the previous revision of this document got them wrong:

- **A device-key failure is *not* `ROLL_WORKER_SESSION_REQUIRED`.** It never reaches the controller, so
  it surfaces as `AUTH_INVALID_CREDENTIALS` (401). An app that maps every 401 to "your shift session
  ended" will tell the worker to log in again when the real fault is a misconfigured device key.
- **`ROLL_WORKER_SESSION_REQUIRED` is not always 401.** It is 400 for a blank token and 404 for an
  unknown one. Branch on `error.code`, not on the status.

### 4.5 Refresh expectations

Unchanged and still mandatory: refetch the pending list on app start, on resume, on SSE connect and on
every reconnect, and on each `urgent-manager-announcement` nudge.

## 5. Required Frontend Screens / Dialogs

**None.** No screen, dialog or flow changes. The existing generic-notice surface is correct as-is.

## 6. Required Models / DTO Changes

Optional, and only if the app wants exact-second removal:

| Field | Type | Notes |
|---|---|---|
| `expiresAt` | `DateTime?` | ISO-8601 UTC (`…Z`); `null` = never expires |
| `expiresAtDisplay` | `String?` | already business-zone formatted |
| `action` (SSE) | `String` | `CREATED` / `UPDATED` / `DEACTIVATED` / `DELETED` |

Unknown JSON keys must continue to be ignored — that is what makes this additive.

## 7. Required Repository / API Client Changes

**None required.** If adding the fields above, extend the existing generic-notice model only; no method
names, paths, error mapping or retry behaviour change.

## 8. Required Provider / State Management Changes

**None required.** Optionally arm a one-shot local timer at the nearest `expiresAt` so a generic notice
disappears exactly on time instead of at the next refetch. REST stays authoritative.

## 9. Required UX Flow

- **Happy path:** nudge arrives → refetch pending → render/clear the generic notice. Unchanged.
- **Validation failure:** not applicable.
- **Network failure:** existing retry/refetch-on-resume behaviour applies.
- **Backend business error:** unchanged.
- **Retry / double-submit:** ack is already idempotent per operator; unchanged.
- **Cancel / back:** unchanged.

## 10. Arabic UI Text

No new strings. The generic notice text is server-supplied and unchanged:

- Title: `ملاحظة عاجلة من المدير`
- Message: `أرسل المدير ملاحظة عاجلة للمشغل. يجب فتح تطبيق المشغل لقراءتها.`

## 11. Edge Cases

| Case | Expected |
|---|---|
| `action` key absent (older backend) | treat as `CREATED`; refetch anyway |
| unknown future `action` value | refetch anyway — refetching is always the safe response |
| `expiresAt: null` | never expires |
| announcement expires while app backgrounded | resume refetch already omits it |
| announcement retargeted away from Thermoforming | `DEACTIVATED` nudge → refetch → notice gone |
| SSE reconnect after a gap | mandatory refetch reconciles state — and note the stream needs only `X-Device-Key`, so it reconnects even while logged out |
| user double-taps ack | already idempotent **per operator**; the second call is a no-op |
| same worker holds sessions on several lines | one operator-scoped ack clears the notice on all of them — the ack carries no line id |
| Roll Worker session **replaced** by a newer login | the old token's session is no longer ACTIVE → `ROLL_WORKER_SESSION_REQUIRED` (401) → re-authenticate; do not silently retry |
| Roll Worker session **expired / ended** | same code, same handling as replacement |
| `X-Session-Token` absent from the request entirely | `ROLL_OP_SESSION_TOKEN_MISSING` (400) — a client bug, not a shift-ended condition |
| `X-Device-Key` misconfigured on the device | `AUTH_INVALID_CREDENTIALS` (401) on **every** Roll Worker call, including the SSE stream — surface it as a device/configuration fault, never as "session ended" |
| any response at all | it can only ever contain the fixed sanitized notice — no real announcement body, title or sender exists on this app's payloads |

## 12. Testing Requirements

- **Unit:** the nudge model tolerates the new `action` key and an absent one.
- **Repository/API:** `expiresAt` / `expiresAtDisplay` parse, including `null`.
- **Provider/state:** a nudge of each action value triggers exactly one refetch.
- **Manual smoke:** post a Thermoforming announcement → the worker sees the generic notice; deactivate it
  → the notice clears without restarting the app.
- **Auth:** every announcement call sends **both** `X-Device-Key` and `X-Session-Token`; the SSE stream
  sends `X-Device-Key` and still connects with no session. Assert the two failure modes are distinguished:
  `AUTH_INVALID_CREDENTIALS` → device/config fault, `ROLL_WORKER_SESSION_REQUIRED` → re-authenticate.
- **Regression:** the Roll Worker App never renders the real message body, title, or sender —
  only the fixed sanitized generic notice.

## 13. Backend Compatibility Notes

- Required backend version: the release containing timed manager announcements.
- **Old app versions remain fully compatible** — the change is additive and `eventType` is unchanged.
- No coordinated rollout required. No feature flag required.
- If the frontend is never updated: nothing breaks; expired notices simply clear on the next refetch
  rather than at the exact second.

## 14. Final Acceptance Criteria

- The app continues to refetch on every `urgent-manager-announcement` nudge, whatever its `action`.
- The real message body, title, and sender never appear on this app.
- Both `X-Device-Key` and `X-Session-Token` are sent on the pending and ack calls; the SSE stream sends
  `X-Device-Key` and does not depend on a session.
- A device-key failure and a session failure are surfaced differently to the worker.
- If `expiresAt` is adopted, an expired generic notice disappears without another SSE frame.
