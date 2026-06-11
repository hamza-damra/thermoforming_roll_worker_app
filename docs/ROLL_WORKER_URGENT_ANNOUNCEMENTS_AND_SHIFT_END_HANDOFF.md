# Roll Worker App — Handoff: Urgent Manager Announcements (sanitized) + Shift-End behavior

> Backend implemented and verified. Backend branch: `feature/manager-urgent-announcements-and-thermoforming-sse-reasons`.
>
> **The Roll Worker App is a distinct app from the Roll Production App.** Roll workers mount rolls on thermoforming shift-lines and use the API prefix **`/api/v1/thermoforming-roll-app/**`** (the Roll Production operator app uses `/api/v1/roll-production-app/**` and is covered by a separate handoff). Do not conflate the two.

Like the Roll Production and Palletizing apps, the Roll Worker App receives only a **sanitized generic notice** for a THERMOFORMING manager announcement — never the real body or sender.

## Auth & transport (unchanged)

- Endpoints stay under `/api/v1/thermoforming-roll-app/**`.
- Use the existing **`X-Device-Key`** transport header **+** **`X-Session-Token`** resolving to an ACTIVE roll-worker session (the same header you already send on post-login endpoints like `/sessions/me`).
- Acknowledgement idempotency is keyed by the **worker's operator id** (resolved server-side from the session). A roll worker may hold multiple line sessions at once; one operator-scoped ack dismisses the notice across all of them. The shared device key is **not** used as identity.

---

## Pending endpoint (SANITIZED)

```
GET /api/v1/thermoforming-roll-app/urgent-announcements/pending
Headers: X-Device-Key, X-Session-Token
```

Response (oldest first; active, not expired, not-yet-acked by this worker):

```json
{
  "success": true,
  "data": [
    {
      "id": 123,
      "targetDomain": "THERMOFORMING",
      "title": "ملاحظة عاجلة من المدير",
      "message": "أرسل المدير ملاحظة عاجلة للمشغل. يجب فتح تطبيق المشغل لقراءتها.",
      "createdAt": "2026-06-10T15:10:00Z",
      "createdAtDisplay": "2026-06-10، 06:10 مساءً",
      "priority": "URGENT"
    }
  ]
}
```

- `title`/`message` are **fixed generic strings**. There is **no `messageBody` and no `senderDisplayName` field** at all.
- Generic blocking notice to display:
  - title: **"ملاحظة عاجلة من المدير"**
  - message: **"أرسل المدير ملاحظة عاجلة للمشغل. يجب فتح تطبيق المشغل لقراءتها."**

## Acknowledge endpoint (GENERIC_NOTICE_ACK)

```
POST /api/v1/thermoforming-roll-app/urgent-announcements/{id}/ack
Headers: X-Device-Key, X-Session-Token
```

Response: `{ "success": true }`. Backend forces `acknowledgementType = GENERIC_NOTICE_ACK`, keyed by your operator id. Duplicate acks return success (idempotent). An unknown announcement id → `ROLL_ANNOUNCEMENT_NOT_FOUND`. A missing/invalid session → 401 (`ROLL_WORKER_SESSION_REQUIRED` / the usual session errors), matching every other Roll Worker endpoint.

---

## SSE nudge

On the existing Roll Worker SSE stream (`GET /api/v1/thermoforming-roll-app/events`, `RollWorkerLineEventsSseBroker`), a **new** SSE event name `urgent-manager-announcement` is emitted:

```json
{ "eventType":"URGENT_MANAGER_ANNOUNCEMENT_CREATED", "announcementId":123,
  "targetDomain":"THERMOFORMING", "priority":"URGENT" }
```

- Sanitized nudge (no body/sender). On receipt, call the pending endpoint and show the generic notice.
- This is **additive** and distinct from the existing `roll-worker-lines-changed` refresh-trigger frame — your existing refresh handling is unchanged.
- Also fetch pending on app start / resume / SSE reconnect. The pending endpoint is authoritative; the nudge is best-effort.

---

## Shift-end behavior (important — read this)

The Roll Worker App's `/events` stream is a **refresh-trigger** stream by design: every frame (`roll-worker-lines-changed`) carries no business state, only enough to tell you to refetch `GET /api/v1/thermoforming-roll-app/bootstrap`.

- When the thermoforming operator's shift-line you are mounted on ends (manager end, takeover, plan exhausted, etc.), you receive a normal **refresh trigger** (the underlying reason is `OPERATOR_SESSION_ENDED`). **Refetch bootstrap** — it will show that your roll-worker session on that line has ended.
- The Roll Worker App does **NOT** receive the rich operator-facing end-shift dialog payload (`reason`/`scope`/`titleAr`/`messageAr`/`requiresFullSessionExit`, etc.). That explicit dialog contract is the **Thermoforming Operator App's** concern (the operator who owns the shift). The roll worker is a downstream participant who is simply logged out of the ended line and re-renders from bootstrap.
- If product later decides the roll worker should also show an explicit end reason, the backend would need to enrich the Roll Worker stream separately — it is **not** in scope today, and you should not expect those fields on this stream.

---

## Privacy rule (must hold)

- **Never expect or render a real message body or sender** for a THERMOFORMING announcement. The sanitized DTO and the SSE nudge structurally have no such field.
- **Defensive:** even if a future backend bug ever sent a body field, **ignore it** — render only the fixed generic `title`/`message` + `createdAtDisplay`.

## Recommended Flutter integration

- A `ManagerAnnouncementNotifier` (Provider/ChangeNotifier) that polls `pending` on resume + listens to the `urgent-manager-announcement` SSE event, and calls `ack` on dismiss.
- A generic notice overlay that does not interfere with the roll-worker mount/scan/handover flows — it is informational ("open the operator app to read it").
