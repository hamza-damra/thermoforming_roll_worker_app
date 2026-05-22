# Handoff: Roll Employee App — Realtime Sync With Operator Product Switch

> Audience: Roll Employee App (Thermoforming "عامل الرولات") frontend engineers.
> Backend branch: current working branch.
> Scope: SSE events the Roll Employee App must observe, and the UI behavior it must apply when the Operator App changes a product or affects roll state.
>
> **Initiating a product switch from this app is not supported** — the Roll Worker UI must not offer it; only the Operator / Palletizing Operator App performs product switches. This handoff covers how the Roll Employee App **reacts** (SSE + summary refresh) when the operator does so.

---

## 1. Summary of backend changes

The Operator App's product switch flow has been changed from blocking-on-incompatibility to **always succeeding** and branching internally:

- The operator-entered `currentRollWeightKg` is the boundary weight between the OUTGOING product segment and the new product state.
- A roll consumption segment is **always** closed for the OUTGOING product with `endWeight = currentRollWeightKg`.
- If the mounted roll's type is compatible with the new product → the same roll stays mounted; a new segment is opened for the new product with `startWeight = currentRollWeightKg`.
- If the mounted roll's type is **not** compatible with the new product → the backend automatically performs the standard "إرجاع المتبقي" close with `returnedWeight = currentRollWeightKg`, transitions consumption state to `PARTIALLY_RETURNED`, clears the mounted-roll references on the line, and leaves the roll in a state where the existing label-reprint endpoint is available.
- All persistence happens in a single `@Transactional` boundary. SSE events are emitted only after the transaction commits.

The Roll Employee App must update its UI **without manual refresh** in both branches. This handoff documents how to do that using the existing operator-dashboard SSE channel.

---

## 2. SSE channel and connection

The Roll Employee App subscribes to the same per-line SSE channel the Operator App uses:

```
GET /api/v1/palletizing-line/lines/{lineId}/operator-dashboard/events
SSE event name: operator-dashboard-changed
Handshake event name: connected
Heartbeat: 25 s comment (": ping\n\n"); reconnect on disconnect.
Emitter timeout: 5 minutes (server-side); clients should reconnect on stream end.
```

Frame schema (additive — existing subscribers continue to work):

```jsonc
{
  "lineId": 10,
  "reason": "PRODUCT_CHANGED",
  "affected": ["CURRENT_PRODUCT", "ROLL_CONSUMPTIONS"],
  "version": 42,                 // monotonic per line, process-local; ordering hint only
  "eventId": "f4e2-…",           // stable; use for client-side dedupe
  "occurredAt": "2026-05-14T05:36:42.123Z",
  "data": { /* typed payload, optional */ }
}
```

If `data` is absent, treat the frame as a notification-only hint and call your normal state-refresh endpoint.

---

## 3. Required SSE events to listen to

Backend fires the following events in order after a successful product switch (all post-commit):

### 3.1 `PRODUCT_CHANGED`

```jsonc
{
  "machineId": 10,
  "oldProductId": 5,
  "oldProductName": "Red 20kg",
  "newProductId": 6,
  "newProductName": "Blue 10kg",
  "changedBy": 7,
  "currentRollId": 999,
  "compatibilityResult": "compatible",   // or "incompatible" / "no_roll"
  "timestamp": "2026-05-14T05:36:42.123Z"
}
```

UI: update the active-product chip for the machine immediately.

### 3.2 `ROLL_CONSUMPTION_SEGMENT_RECORDED`

```jsonc
{
  "machineId": 10,
  "rollId": 999,
  "productId": 5,
  "productName": "Red 20kg",
  "previousWeight": 100.000,
  "currentWeight": 70.000,
  "consumedWeight": 30.000,
  "timestamp": "2026-05-14T05:36:42.123Z"
}
```

UI: update the "by product" breakdown of the roll (this product consumed `consumedWeight` more kg). If your UI does not visualize per-product segments, you can ignore this event safely.

### 3.3 `ROLL_CONTINUED_WITH_NEW_PRODUCT` (compatible branch)

```jsonc
{
  "machineId": 10,
  "rollId": 999,
  "rollNumber": "777000000001",
  "newProductId": 6,
  "newProductName": "Blue 10kg",
  "currentWeight": 70.000,
  "mounted": true,
  "timestamp": "…"
}
```

UI:
- Keep the same roll mounted on the machine view.
- Update the displayed current weight to `currentWeight`.
- Update the product label on the mount widget to `newProductName`.
- Do **not** show any prompt to mount a new roll.

### 3.4 `ROLL_RETURNED_REMAINING` (incompatible branch)

```jsonc
{
  "machineId": 10,
  "rollId": 999,
  "rollNumber": "777000000001",
  "returnedWeight": 70.000,
  "oldProductId": 5,
  "oldProductName": "Red 20kg",
  "newProductId": 6,
  "newProductName": "Blue 10kg",
  "labelId": null,
  "canPrintLabel": true,
  "mounted": false,
  "timestamp": "…"
}
```

UI:
- Mark the roll as closed with state `PARTIALLY_RETURNED`.
- Show the returned weight (`returnedWeight`) on the roll detail card.
- Surface the label print/reprint affordance when `canPrintLabel == true` (the existing reprint endpoint still applies; `labelId` is null today and reserved for future synchronous label generation).
- Clear the "mounted roll" indicator for the machine (no roll is mounted now).
- Display the new active product on the machine card.

### 3.5 `MACHINE_ROLL_STATE_UPDATED` (final reconciliation)

```jsonc
{
  "machineId": 10,
  "activeProductId": 6,
  "activeProductName": "Blue 10kg",
  "mountedRollId": null,                              // null when returned remaining
  "mountedRollNumber": null,
  "mountedRollCurrentWeight": null,
  "mountedRollCompatibleWithActiveProduct": null,    // null when no mount
  "lastAction": "product_switch_roll_returned",       // or product_switch_roll_continued
  "timestamp": "…"
}
```

This event is intentionally **idempotent**: it carries the post-switch snapshot of `(active product, mounted roll, current weight)` so any client that missed an intermediate event can resync without an extra REST call. Treat this as the authoritative final state. When `mountedRollId == null`, also blank out `mountedRollNumber`, `mountedRollCurrentWeight`, and treat `mountedRollCompatibleWithActiveProduct` as "not applicable" (null).

---

## 4. Expected UI behavior — compatible roll case

Trigger: receive `MACHINE_ROLL_STATE_UPDATED` with `lastAction == "product_switch_roll_continued"` (or the `ROLL_CONTINUED_WITH_NEW_PRODUCT` frame).

- Same roll remains mounted on the machine view.
- Active product chip updates to `activeProductName`.
- Current roll weight on the mount widget updates to `mountedRollCurrentWeight`.
- No prompt to mount a new roll; no "إرجاع المتبقي" affordance.

---

## 5. Expected UI behavior — incompatible roll case

Trigger: receive `MACHINE_ROLL_STATE_UPDATED` with `lastAction == "product_switch_roll_returned"` (or the `ROLL_RETURNED_REMAINING` frame).

- Roll is closed as "إرجاع المتبقي"; returned weight equals the operator-entered `currentRollWeightKg`.
- Label print/reprint affordance is available when `canPrintLabel == true` (call the existing reprint endpoint).
- Mounted roll indicator is cleared on the machine card.
- Active product chip shows the new product; the machine now waits for a new roll scan.
- Any subsequent roll scan/mount will be validated against the new active product and may reject with `ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT` (unchanged behavior).

---

## 6. Reconnect behavior

- The SSE stream times out after 5 minutes; clients **must** reconnect automatically.
- On reconnect, refetch the latest machine/line state via the existing REST endpoint (e.g. `GET /api/v1/palletizing-line/lines/{lineId}/operator-dashboard`) and re-render from that snapshot. Then resume consuming SSE frames.
- Deduplicate events using `eventId` (the broker also has a per-line LRU dedupe with capacity 64 on the server side; clients should be defensive anyway).
- The `version` field is **process-local** and resets when the server restarts. Treat it as a best-effort ordering hint, not a global monotonic id.

---

## 7. Fallback behavior if event payload is incomplete

- If `data` is missing or any required field is null, fall back to the REST snapshot for the affected machine/line.
- Treat the SSE frames as **hints**; the REST endpoint remains the source of truth.
- Errors during SSE parsing should never crash the client — log and refetch.

---

## 8. Frontend testing checklist

- [ ] Subscribe to `/lines/{lineId}/operator-dashboard/events`; receive `connected` handshake.
- [ ] Trigger a switch in the Operator App with a compatible mounted roll → Roll Employee App receives `PRODUCT_CHANGED` + `ROLL_CONSUMPTION_SEGMENT_RECORDED` + `ROLL_CONTINUED_WITH_NEW_PRODUCT` + `MACHINE_ROLL_STATE_UPDATED`; UI keeps the roll mounted and updates the current weight + active product.
- [ ] Trigger a switch with an incompatible mounted roll → receives `PRODUCT_CHANGED` + `ROLL_CONSUMPTION_SEGMENT_RECORDED` + `ROLL_RETURNED_REMAINING` + `MACHINE_ROLL_STATE_UPDATED`; UI clears the mounted roll, surfaces reprint affordance, shows new active product.
- [ ] No `ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT` error is generated by the switch path (the Operator App never receives one).
- [ ] Scan a roll whose type is incompatible with the current active product → the existing scan endpoint still rejects with `ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT` (unchanged); make sure the Roll Employee App still displays this error correctly in the mount/scan flow.
- [ ] Drop and re-establish the SSE connection during a switch → after reconnect the Roll Employee App refetches state and the UI converges to the same end-state as the live SSE stream.
- [ ] Send the same frame twice (force-replay with the same `eventId`) → UI applies only once.
- [ ] Receive a frame with missing `data` → UI falls back to a REST refetch and renders correctly.
- [ ] After the incompatible branch completes, the next scan against the new product on the same machine works as expected (new mount, fresh ACTIVE consumption item).
