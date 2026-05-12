# Thermoforming Roll Worker App — Home UX Handoff

> Audience: Roll Worker Flutter agent.
> Backend slice: this hand-off ships with a new per-line summary endpoint and admin worker-participation history. **No Flutter source changes are part of this slice.** This document tells the Flutter agent what to build next.

## 1. Goal & non-goals

**Goal.** Make the Roll Worker home screen fast and uncluttered. A worker on the production floor must see, at a glance:
1. which line they are on,
2. how many rolls have been completed on this line in the current operator shift,
3. the currently mounted roll (if any), and
4. a large primary scan / mount button.

**Non-goals.**
- No admin views in this app — admin participation history is exposed in the backend's web admin only.
- No analytics dashboards.
- No cross-line aggregation in the worker app.

## 2. Multi-line navigation rules

The worker may have started one or many lines via `POST /api/v1/thermoforming-roll-app/sessions/start-batch`. The home shell must adapt:

| Active sessions on this device | UI shell                                                     |
| ------------------------------- | ------------------------------------------------------------ |
| 0                               | (the worker has not authenticated yet; show the picker)      |
| 1                               | **No bottom navigation.** Render the per-line home directly. |
| ≥ 2                             | `BottomNavigationBar` / `NavigationBar`, **one item per active line**. |

Rules for the bottom nav:
- One destination per active `shiftLineId`. The label is the **line code** (e.g. `TH-01`) — short, factory-readable. If the code is missing, fall back to `خط 1`-style labels using the line's `name`. **Never** use internal numeric IDs (`#15`) as the primary label.
- **No top chips** for switching lines. The bottom nav is the only switcher.
- Switching destinations switches the line context — both the session token and the rendered state must be keyed by `shiftLineId`.

## 3. Per-line home layout

```
┌─────────────────────────────────────────┐
│ [TH-01]  خط التشكيل 1                   │  ← compact line header (one row)
├─────────────────────────────────────────┤
│   ╭───────────────────────────────╮     │
│   │  الرولات المنجزة في المناوبة  │     │
│   │            8                  │     │
│   │       منك: 3                  │     │  ← summary card
│   ╰───────────────────────────────╯     │
│                                         │
│   ╭───────────────────────────────╮     │
│   │ الرول المُحمَّل                │     │
│   │ TP-1  •  001000000123          │     │  ← mounted-roll card (only if any)
│   │ ~ 180.5 كجم                    │     │
│   ╰───────────────────────────────╯     │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │           مسح رول                    │ │  ← large primary action
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Required**

- **Compact line header** — code badge + name only. One row.
- **Summary card** — `completedRollsInShift` headline. If `completedRollsByCurrentWorker > 0`, append the small subline `منك: <n>`.
- **Mounted roll card** — render only when `mountedRoll != null`. Show roll-type code, generated roll id, and last-known weight. When `mountedRoll == null`, omit the card entirely (do not render an empty placeholder).
- **Large primary button** — the scan / mount action. The label switches by state:
  - no mounted roll → `مسح رول` (or `تركيب رول جديد`).
  - mounted roll exists → still primary, but its label reflects the next allowed action ("استبدل / استلم", or however the existing flow already labels it).
- The button must be **reachable without scrolling** on common phone sizes. Test on the smallest device the team supports.

**Forbidden**

- Do **not** repeat the line number / palletizing line number anywhere else on the home screen — the bottom nav + compact header carry that.
- Do **not** display internal row IDs like `#15/#16`.
- Do **not** show top chips for line switching.
- Do **not** compute `completedRollsInShift` or `completedRollsByCurrentWorker` locally; backend is the source of truth.
- Do **not** show a large duplicated session/operator card.

## 4. Summary endpoint contract

```
GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/summary

Headers:
  X-Device-Key:    <factory device api key>
  X-Session-Token: <roll-worker token bound to shiftLineId>
```

### 200 OK

```jsonc
{
  "success": true,
  "data": {
    "shiftLineId": 101,
    "thermoformingShiftId": 42,
    "thermoformingLineId": 10,
    "thermoformingLineCode": "TH-01",
    "thermoformingLineName": "خط التشكيل 1",
    "currentProductTypeId": 50,
    "currentProductName": "TBS-13 C1500 Black / Black / 32 كرتونة",
    "completedRollsInShift": 8,
    "completedRollsByCurrentWorker": 3,
    "mountedRoll": {
      "consumptionItemId": 555,
      "rollId": 12345,
      "generatedRollId": "001000000123",
      "rollTypeCode": "TP-1",
      "rollTypeName": "White",
      "lastKnownWeightKg": 180.5
    }
  },
  "error": null
}
```

`mountedRoll` is `null` when nothing is currently mounted on this line. `lastKnownWeightKg` is `null` when there is no `RollConsumptionState.lastKnownWeightKg` recorded yet — never substitute the roll's start weight as a fallback.

### Counter semantics (display these labels accurately)

- **`completedRollsInShift`** — number of `RollConsumptionItem` rows in `CLOSED` status for this `shiftLineId`. A roll closed via `FULL_CONSUMPTION`, `PARTIAL_RETURN`, or `PARTIAL_GRINDING` each count as one completed cycle. The shift-line is bound to a single parent operator shift, so this is exactly "rolls finished on this line in this operator shift, regardless of who closed them".
- **`completedRollsByCurrentWorker`** — same thing, additionally filtered by the current session's operator id. Items closed by previous workers on this line are excluded; legacy items with a null worker FK are excluded.

### Errors

The endpoint reuses the same `requireActiveSession(shiftLineId, token)` gate every other roll-worker endpoint already uses, with the existing error envelope:

| Failure                                              | HTTP | `error.code`                          |
| ---------------------------------------------------- | ---- | ------------------------------------- |
| Token header missing                                 | 400  | `ROLL_WORKER_SESSION_REQUIRED`        |
| Token does not match any active session             | 401  | `ROLL_WORKER_SESSION_REQUIRED`        |
| Token belongs to a different `shiftLineId`           | 403  | `ROLL_WORKER_SESSION_REQUIRED`        |
| Shift-line was ended / cancelled while you held it   | 404  | `ROLL_WORKER_SESSION_REQUIRED`        |

On any of these the Flutter app should treat the per-line session as gone: clear the token for that `shiftLineId`, drop the bottom-nav destination for that line if applicable, and surface the picker for re-auth on that line.

## 5. State management rules

- **Per-line keyed state.** Roll state, mounted-roll state, summary, and session token must all be keyed by `shiftLineId`. No global "current shift line" — bottom nav switches the active key.
- **Never hardcode line ids.** Every call uses the `shiftLineId` from the active session.
- **No fake counts.** All numbers come from the backend. Local optimistic increments are not allowed; refresh after each successful action.
- **Refresh triggers** — call the summary endpoint:
  - on first paint of the per-line tab,
  - on tab focus (e.g. `BottomNavigationBar` index change to this line),
  - after any successful action that may change state: `scan-roll`, `previous-roll/full-consume`, `previous-roll/return`, `previous-roll/grinding`, `product-switch`,
  - after pull-to-refresh.

## 6. Logout

- **Per-line logout** is preserved exactly as it is today: `POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-logout` with that line's session token.
- A "logout all" UX is implemented client-side as a fan-out of per-line logout calls. If one of them fails, **leave only that one line active** and clean up the rest. Do not roll back successful logouts.

## 7. Admin visibility (for context only — not implemented in Flutter)

The backend now exposes worker-participation history on the existing admin shift-history detail page:
`/web/admin/shift-history/sessions/{authId}`. For each shift-line, the admin sees:

- Roll Workers section — name, period start / end, session count, rolls completed by that worker.
- Palletizers section — name, period start / end, session count.
- Sibling-lines navigation card — links to the other shift-lines under the same parent operator shift.

Aggregation rule: consecutive same-worker periods on the same line collapse into one display period if no different worker took over in between. So `A → A` is one period and `A → B → A` is three. **Raw `RollWorkerSession` and `PalletizerSession` rows are never deleted or merged in the database** — this is a display-only projection.

The Roll Worker app does not render or manage admin views.

## 8. Acceptance checklist

Before marking the home redesign done:

- [ ] One active session → no bottom navigation; per-line home renders directly.
- [ ] Two active sessions → bottom navigation shows two destinations, each with the line code label.
- [ ] Switching destinations switches the line context; state is per-`shiftLineId`.
- [ ] Compact header is one row, no duplicated line/palletizing-line numbers anywhere on the home.
- [ ] Summary card sits above the scan button.
- [ ] Scan button is visible without scrolling on the smallest supported device.
- [ ] No top chips. No large duplicated session/operator card. No internal IDs as labels.
- [ ] `completedRollsInShift` and `completedRollsByCurrentWorker` come from the backend summary endpoint.
- [ ] Mounted-roll card is rendered only when the backend returns a non-null `mountedRoll`.
- [ ] Per-line logout works; "logout all" fans out and tolerates partial failure.
- [ ] All copy is RTL-clean, Arabic, and human (`خط 1` / `TH-01`, never `#15`).
- [ ] Touch targets remain large enough for factory-floor use.
