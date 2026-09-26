# LINE_3 Handoff — Roll Worker App — Third Thermoforming Line (TF_LINE_3 → LINE_3)

## 0. Document status

| Item | Value |
|---|---|
| Audience | Engineer or agent working on the Roll Worker App (Flutter, package `thermoforming_roll_worker`). No backend knowledge assumed. |
| Backend source read | `Taleeb-Warehouse-Backend`, branch `main`, HEAD `e47c2c15`, **plus the uncommitted LINE_3 work** in the worktree. That work is not committed, tagged or deployed yet. |
| Generated | 2026-09-15 |
| Flutter repo read (read-only) | `C:\Users\Hamza Damra\Documents\thermoforming_roll_worker_app`, branch `main`, HEAD **`7b49c229cc1269a74e1923662ce0491a965106cf`**, clean working tree, `pubspec.yaml` version `1.0.1+2` |
| Verification level | Backend: read in source, with `file:line` citations. Flutter: read in source only. No app boot, no Maven, no database, no device run. §7 lists everything not proven at runtime. |
| Citation form | Backend Java paths are relative to `src/main/java/ps/taleeb/taleebbackend/`. Paths that start with `src/` or `docs/` are relative to the backend repo root. Flutter paths start with `lib/` or `test/`. |
| Related handoffs (cross-reference only, not repeated here) | `docs/frontend-handoffs/FRONTEND_HANDOFF_ROLL_WORKER_APP_MULTI_LINE_SESSIONS.md`, `FRONTEND_HANDOFF_ROLL_WORKER_APP_WAVE11_LEGACY_CONTRACT_REMOVAL.md`, `FRONTEND_HANDOFF_ROLL_WORKER_APP_UTC_INSTANT_WIRE_FORMAT.md`. V190 close handshake: `docs/frontend-handoffs/THERMOFORMING_OPERATOR_PLAN_ITEM_CLOSE_HANDSHAKE.md` line 16 says "Roll Worker App — No". |
| **Open owner decision** | **D1: label vocabulary** ("ماكينة C" or "خط ج"). See §6.1 site S1 and §7. |

## 1. Executive Summary

**What changed in the backend**

- The factory gets a third thermoforming machine, `TF_LINE_3`, which feeds palletizing line `LINE_3`. Migration V191 creates `LINE_3` **inactive** and `TF_LINE_3` **active** (`src/main/java/db/migration/V191__provision_three_line_thermoforming_topology.java:20-22,194,206`).
- The Roll Worker bootstrap now lists only **commissioned** machines: the machine is active **and** its palletizing line is active (`thermoformingrollapp/service/RollWorkerBootstrapService.java:80`, `thermoforming/repository/ThermoformingLineRepository.java:29-31`). Before an admin enables `LINE_3` the app gets 2 rows; afterwards it gets 3.
- The backend's curated Roll Worker machine name now maps `TF_LINE_3` to `ماكينة C` (`thermoformingrollapp/service/RollWorkerMachineDisplayNameResolver.java:42-46`).
- Enabling or disabling `LINE_3` sends one `roll-worker-lines-changed` frame on `GET /api/v1/thermoforming-roll-app/events`, with `type` `LINE_STATE_CHANGED` and `palletizingLineId` 3 (§4.4).

**Why this app must change.** The app already handles 3 machines: its tabs come from the server list, sessions are keyed by `shiftLineId`, and `start-batch` sends `shiftLineIds`. **Presentation and identity handling are wrong for line 3:**

1. **Wrong letter.** The app builds the tab label itself from `machineNumber` using an alphabetical letter table, so line 3 reads **`خط ت`**. Everyone else calls this line `خط ج` (palletizing name) or `ماكينة C` (Roll Worker display name). A wrong letter can send a worker to the wrong machine.
2. **Server label ignored.** The bootstrap parser never reads the server label `lineDisplayName`.
3. **Tab jump on claim.** The selected tab is remembered by a key that switches from machine id to shift-line id when an operator claims the machine. A worker watching machine C's tab is thrown back to the first tab exactly when machine C comes online during go-live.
4. **Fallback tabs labelled by position.** A tab kept alive only by a local session (for example after `LINE_3` is disabled mid-shift) gets its label from its position in the tab strip.

**Required before enabling LINE_3?** **Yes.** The rollout runbook's CHECKPOINT requires this app to pass §6.11 before the admin enables `LINE_3`. The backend itself can be deployed first while `LINE_3` stays inactive (§8).

## 2. Affected App & Impact Matrix

This document covers the Roll Worker App only. The rows for the other apps come from the shared brief and audit and were **not re-verified** here; see the sibling LINE_3 handoff for each app in the same folder.

| App | Affected? | Reason | Handoff |
|---|---|---|---|
| Warehouse App | No | Shows backend line names as-is; no line list or letter logic (audit evidence) | none |
| Admin App | Yes | Overview cards and plan reference data are commissioned-only. The THERMOFORMING SSE `lineId` is a ProductionLine id, not the card's ThermoformingLine id. | sibling Admin App LINE_3 handoff |
| Palletizing App | Yes (blocker candidates) | Two-line layout (`TabController(length: 2)`, `const [1, 2]`, `A`/`B` ternary) | sibling Palletizing App LINE_3 handoff |
| **Roll Worker App** | **Yes** | Local letter table gives `خط ت`; `lineDisplayName` not parsed; tab selection keyed by shift-line; fallback tabs labelled by position | **this file** |
| Roll Production App | No | Roll lines only; never references thermoforming or palletizing lines (audit evidence) | none |
| Operator App | Yes | Label resolver maps line 3 to `خط د`; handover-scope dialog assumes at most 2 lines | sibling Operator App LINE_3 handoff |

## 3. Business Context

**Floor vocabulary**

- A **machine** (ماكينة, thermoforming line `TF_LINE_n`) makes the product.
- A **line** (خط, palletizing/production line `LINE_n`) stacks that product into pallets.
- Each machine feeds exactly one line: `TF_LINE_1→LINE_1`, `TF_LINE_2→LINE_2`, `TF_LINE_3→LINE_3`.
- A thermoforming **operator** claims a machine for their shift. That claim is a **shift-line**.
- A **roll worker** logs in with a PIN against that shift-line and mounts and closes plastic rolls on the machine.

**Staged go-live, in floor terms**

1. **Deploy day (LINE_3 off).** The backend with V191 is running. Machine C exists, but palletizing line C is switched off. Every Roll Worker tablet still shows only machines A and B. An operator cannot claim machine C: the claim is refused with `PRODUCTION_LINE_INACTIVE` (`thermoforming/service/ThermoformingShiftLineService.java:165-170`).
2. **CHECKPOINT.** Operator, Palletizing, Roll Worker and Admin App builds pass their LINE_3 acceptance checklists (for this app: §6.11).
3. **Admin switches LINE_3 on** at `/web/admin/production-lines` (`web/admin/WebAdminProductionLinesController.java:129`) or with `PATCH /api/v1/admin/production-lines/{id}/enable` (`palletizing/ProductionLineAdminController.java:34,69`). No migration or release is needed. Every Roll Worker tablet gets a **third tab** within seconds. Its state is "waiting": no operator yet.
4. The planner adds a `خط ج` item to the production plan. The operator claims machine C, and the third tab becomes PIN-enterable.
5. A roll worker enters their PIN on that tab and mounts a roll. Mounting needs a current plan item; otherwise it fails with `PRODUCTION_PLAN_ITEM_REQUIRED`.

**Rollback.** Pause the line or end the shift first, then disable `LINE_3`. There is no in-use guard on disable. Disabling mid-shift removes machine C from the Roll Worker bootstrap, but does **not** end roll-worker sessions or block roll mounting (§4.5, §6.9).

**Id domains.** Four separate id spaces reach this app. They are never interchangeable:

| Id | Entity | Where the app sees it | Use it for |
|---|---|---|---|
| `thermoformingLineId` | ThermoformingLine (the machine) | bootstrap row, `sessions/me` row, summary, `start-batch` entry | **machine identity: tab identity, label cache, colour** |
| `palletizingLineId` / `productionLineId` | ProductionLine (the palletizing line) | bootstrap row (both, same value), `sessions/me` row, `start-batch` entry, SSE frame | the per-line operator-dashboard SSE path; diagnostics |
| `shiftLineId` | ThermoformingShiftLine (an operator's claim of a machine) | bootstrap row (null until claimed), `sessions/me` row, `start-batch` request and response | **every roll action URL, `start-batch`, session token storage** |
| `sessionId` / session token | RollWorkerSession | `start-batch` response, `sessions/me` | auth header `X-Session-Token` |

**Production id skew.** In production `LINE_3.id = 3` but `TF_LINE_3.id = 4`, because `thermoforming_lines` already used id 3 (V191 javadoc, `V191__provision_three_line_thermoforming_topology.java:47-48`). For lines 1 and 2 the two ids happen to be equal (1=1, 2=2). Any code that mixes up `thermoformingLineId` and `palletizingLineId` therefore passes every test on lines 1 and 2 and breaks only on line 3. Shift-line ids are a third space with no relation to either; the examples below use 91xx on purpose.

## 4. CONFIRMED FROM BACKEND CODE

### 4.1 Topology and id domains

| Business code | Stored name | Kind | Production id | State after V191 | `line_number` | Source |
|---|---|---|---|---|---|---|
| `LINE_1` | `خط أ` | ProductionLine | 1 | active (existing row adopted unchanged) | 1 | V191 `:20` |
| `LINE_2` | `خط ب` | ProductionLine | 2 | active (existing row adopted unchanged) | 2 | V191 `:21` |
| `LINE_3` | `خط ج` | ProductionLine | 3 | **inactive** (`is_active FALSE`) | 3 | V191 `:22,69-71,194` |
| `TF_LINE_1` | `خط التشغيل أ` (DEV seed; production row adopted unchanged) | ThermoformingLine → `LINE_1` | 1 | active | n/a | V191 `:74` |
| `TF_LINE_2` | `خط التشغيل ب` (as above) | ThermoformingLine → `LINE_2` | 2 | active | n/a | V191 `:75` |
| `TF_LINE_3` | `خط التشغيل ج` | ThermoformingLine → `LINE_3` | **4** | active, `OPERATIONAL` | n/a | V191 `:22,76,206` |

- **Commissioned** = `tl.active = true AND pl.active = true`, ordered by `tl.code` (`ThermoformingLineRepository.java:29-31`). The palletizing line is fetched in the same query.
- **Display name** (`RollWorkerMachineDisplayNameResolver.java:42-46,59-70`):
  1. Curated map on the trimmed, upper-cased code: `TF_LINE_1`→`ماكينة A`, `TF_LINE_2`→`ماكينة B`, `TF_LINE_3`→`ماكينة C`.
  2. Otherwise the stored name if it is not blank.
  3. Otherwise the code.

  So a future `TF_LINE_4` would get its stored name (for example `خط التشغيل د`) unless the map is extended.
- `machineNumber` is `ProductionLine.lineNumber` (`RollWorkerBootstrapService.java:195`). It is a number, not a letter and not an id.
- The production ids 1/2/3/4 come from the V191 javadoc and the audit. This handoff did not query a database to confirm them.

### 4.2 Endpoints this app uses that involve lines

**Common to every endpoint below**

- Security chain `thermoformingRollAppFilterChain` (`config/SecurityConfig.java:291-308`): matcher `/api/v1/thermoforming-roll-app/**` (`:294`), `hasRole("DEVICE")` (`:304`), ASYNC dispatch permitted for SSE (`:303`).
- Device header `X-Device-Key` (`security/DeviceApiKeyFilter.java:57`). It also covers `/api/v1/palletizing-line/**` (`:71-75`).
- A missing or wrong key returns **401** `AUTH_INVALID_CREDENTIALS` (`security/SecurityAuthEntryPoint.java:28-29`).
- Worker identity uses header `X-Session-Token` (`thermoformingrollapp/controller/RollWorkerSessionController.java:48`) and is checked inside the controllers, not by the security chain.
- Success envelope `{"success":true,"data":…}`; failure envelope `{"success":false,"error":{"code","message","details"?}}`. The envelope and `error` omit nulls (`common/ApiResponse.java:13,44`).
- Absolute timestamps are ISO-8601 UTC with `Z` (`config/JacksonConfig.java:45-46`). Convert to `Asia/Hebron` for display; never use the device time zone.
- **Null handling differs by DTO.** Some DTOs omit null fields (`@JsonInclude(NON_NULL)`): bootstrap row, `sessions/me`, summary. Others have no class-level `@JsonInclude` and may send explicit `null`: `RollWorkerShiftLineOptionResponse`, `RollWorkerBatchAuthResponse`, `RollWorkerBatchSessionResponse`. **Parse absent and `null` the same way.**

#### A. `GET /api/v1/thermoforming-roll-app/bootstrap` — machine list (drives the tabs)

- Controller: `thermoformingrollapp/controller/RollWorkerBootstrapController.java:30,36-39`.
- Service: `RollWorkerBootstrapService.java:79-158`.
- Headers: `X-Device-Key` only. No PIN, no session token. Read-only.
- Request: none.
- Response: `data.lines[]`, **one row per commissioned machine, in `TF_LINE_n` code order** (`RollWorkerBootstrapService.java:80,150-157`). DTO `thermoformingrollapp/dto/RollWorkerLineStateResponse.java` (`@JsonInclude(NON_NULL)` at `:37`).

| Field | Type | Meaning | Line |
|---|---|---|---|
| `thermoformingLineId` | Long, never null | **stable row key** (machine) | `:42` |
| `lineCode` | String | `TF_LINE_n` business code | `:44` |
| `lineName` | String | raw stored machine name, e.g. `خط التشغيل ج`. **Not a UI label.** | `:46` |
| `lineDisplayName` | String | curated Roll Worker machine name, e.g. `ماكينة C` | `:54`, set at `RollWorkerBootstrapService.java:181-182` |
| `palletizingLineId` | Long | ProductionLine id | `:58` |
| `productionLineId` | Long | same value as `palletizingLineId` | `:64`, `RollWorkerBootstrapService.java:191-192` |
| `palletizingLineCode` | String | `LINE_n` | `:65` |
| `palletizingLineName` | String | e.g. `خط ج` | `:66` |
| `machineNumber` | Integer | `ProductionLine.lineNumber` (1/2/3) | `:68` |
| `shiftLineId` | Long, omitted when no operator | ThermoformingShiftLine id | `:72` |
| `thermoformingShiftId`, `activeOperatorId`, `activeOperatorName`, `currentPlanItemProductTypeId`, `currentPlanItemProductName`, `updatedAt` | omitted when no operator | shift-line context | `:73-85,122`, `RollWorkerBootstrapService.java:209-215` |
| `currentRollId`, `currentRollGeneratedRollId`, `currentRollTypeCode`, `currentRollTypeName`, `currentRollLastKnownWeightKg` | omitted when no roll is mounted | mounted roll | `:88-92` |
| `selectable`, `canStartRollWorkerSession` | boolean, always present, same value | true only when a shift-line exists **and** the line is not blocked | `:101,103`, `RollWorkerBootstrapService.java:198-246` |
| `blocked`, `handoverPending` | boolean, always present | handover or takeover in progress | `:106,110` |
| `blockedReason` | `PENDING_HANDOVER` or `TAKEOVER_<status>`; omitted when not blocked | | `:108`, `thermoformingrollapp/service/RollWorkerLineStateResolver.java:70-73` |
| `takeoverRequestStatus`, `takeoverIncomingOperatorName` | omitted when there is no takeover | | `:111-112` |
| `lineLifecycleStatus` | `PENDING_HANDOVER` / `TAKEOVER_<status>` / shift-line status (e.g. `ACTIVE`) / `NO_ACTIVE_SHIFT` | | `:119`, `RollWorkerLineStateResolver.java:41,75-82` |

LINE_3 example, **after LINE_3 is enabled and before an operator claims machine C**. Ids follow production (TF 4 → PL 3); shift-line and other ids are illustrative.

```json
{
  "success": true,
  "data": {
    "lines": [
      {
        "thermoformingLineId": 1, "lineCode": "TF_LINE_1", "lineName": "خط التشغيل أ", "lineDisplayName": "ماكينة A",
        "palletizingLineId": 1, "productionLineId": 1, "palletizingLineCode": "LINE_1", "palletizingLineName": "خط أ", "machineNumber": 1,
        "shiftLineId": 9120, "thermoformingShiftId": 5051, "activeOperatorId": 31, "activeOperatorName": "…",
        "currentPlanItemProductTypeId": 12, "currentPlanItemProductName": "…",
        "selectable": true, "canStartRollWorkerSession": true, "blocked": false, "handoverPending": false,
        "lineLifecycleStatus": "ACTIVE", "updatedAt": "2026-09-15T05:02:11.482Z"
      },
      {
        "thermoformingLineId": 2, "lineCode": "TF_LINE_2", "lineName": "خط التشغيل ب", "lineDisplayName": "ماكينة B",
        "palletizingLineId": 2, "productionLineId": 2, "palletizingLineCode": "LINE_2", "palletizingLineName": "خط ب", "machineNumber": 2,
        "shiftLineId": 9121, "thermoformingShiftId": 5051, "activeOperatorId": 31, "activeOperatorName": "…",
        "selectable": true, "canStartRollWorkerSession": true, "blocked": false, "handoverPending": false,
        "lineLifecycleStatus": "ACTIVE", "updatedAt": "2026-09-15T05:02:13.019Z"
      },
      {
        "thermoformingLineId": 4, "lineCode": "TF_LINE_3", "lineName": "خط التشغيل ج", "lineDisplayName": "ماكينة C",
        "palletizingLineId": 3, "productionLineId": 3, "palletizingLineCode": "LINE_3", "palletizingLineName": "خط ج", "machineNumber": 3,
        "selectable": false, "canStartRollWorkerSession": false, "blocked": false, "handoverPending": false,
        "lineLifecycleStatus": "NO_ACTIVE_SHIFT"
      }
    ]
  }
}
```

After the operator claims machine C, the third row gains `shiftLineId` (e.g. `9123`), `thermoformingShiftId`, `activeOperator*`, `currentPlanItem*` and `updatedAt`, and `selectable` becomes `true` unless the line is blocked.

**Before LINE_3 is enabled**, the same call returns only the first two rows. No `TF_LINE_3` row exists in the response at all.

Edge cases:

- No commissioned machine: `{"success":true,"data":{"lines":[]}}` (`RollWorkerBootstrapService.java:81-83`).
- JSON key order follows field declaration and is not a contract. Keep the **array order**; that is the machine order.

#### B. `POST /api/v1/thermoforming-roll-app/sessions/start-batch` — PIN login on one or more machines

- Controller `RollWorkerSessionController.java:77-85`; service `thermoformingrollapp/service/RollWorkerSessionService.java:179-274`.
- Headers: `X-Device-Key`.
- Request body (`thermoformingrollapp/dto/RollWorkerBatchAuthRequest.java:28-33`): `{"pin": "<worker PIN>", "shiftLineIds": [<ThermoformingShiftLine ids>]}`.
  - `pin` must not be blank; `shiftLineIds` must be a non-null, non-empty list. There is **no maximum** list size.
  - **Send `shiftLineId` values from bootstrap rows. Never send `thermoformingLineId` (4) or `palletizingLineId` (3).**
- Validation order (`RollWorkerSessionService.java`):
  1. A `null` id inside the list → `ROLL_WORKER_SESSION_BATCH_EMPTY` (`:192-199`).
  2. A duplicate id → `ROLL_WORKER_SESSION_LINE_DUPLICATE` with `details.shiftLineId` (`:200-207`). Both checks run before any PIN attempt.
  3. Unknown shift-line → `THERMOFORMING_SHIFT_LINE_NOT_FOUND` (`:212-217`).
  4. Machines are locked in ascending machine-id order and each must not be paused (`:210-220`).
  5. The PIN is checked once (`:224-225`).
  6. Each shift-line must be ACTIVE, otherwise `ROLL_WORKER_SESSION_LINE_INACTIVE` with `details.shiftLineId` (`:235-253`).
  7. An existing ACTIVE session on a line, even another worker's, is **replaced** (V109, `:314-335`).
- **No palletizing-line-active check.** This endpoint never returns `PRODUCTION_LINE_INACTIVE` (§4.5).
- Response **201** (`thermoformingrollapp/dto/RollWorkerBatchAuthResponse.java:23-25`, `RollWorkerBatchSessionResponse.java:20-27`). Entries come back in request order.

```json
{
  "success": true,
  "data": {
    "rollWorkerOperatorId": 77,
    "rollWorkerName": "…",
    "sessions": [
      {
        "shiftLineId": 9123, "sessionId": 40211, "sessionToken": "<raw token — returned once; store keyed by shiftLineId>",
        "thermoformingShiftId": 5052, "thermoformingLineId": 4, "palletizingLineId": 3,
        "startedAt": "2026-09-15T08:10:00Z", "startedAtDisplay": "\u200e2026-09-15، 11:10 صباحًا"
      }
    ]
  }
}
```

(`startedAtDisplay` starts with U+200E. Its format comes from `config/ArabicDateTimeFormatter.java:30-31,67-73`.)

The app currently sends one shift-line per PIN overlay (`lib/features/roll_worker_auth/presentation/widgets/roll_worker_auth_overlay.dart:93`, `lib/features/roll_worker_auth/data/session_batch_api.dart:17-27`). That is correct and stays.

The controller javadoc still says a line owned by another worker is rejected (`RollWorkerSessionController.java:72-75`). **That is stale:** the code replaces the session (`RollWorkerSessionService.java:314-335`).

#### C. `GET /api/v1/thermoforming-roll-app/sessions/me` — the worker's held lines (post-login truth)

- Controller `RollWorkerSessionController.java:136-141`; service `thermoformingrollapp/service/RollWorkerMeService.java:84-157`.
- Headers: `X-Device-Key`, `X-Session-Token` (any of the worker's tokens).
- Response (`RollWorkerMeResponse.java:31-41`, `RollWorkerActiveLineResponse.java:34-79`, NON_NULL): `{rollWorkerOperatorId, rollWorkerName, lines[]}`.
- `lines` are ordered by session start, then id (`thermoformingrollapp/repository/RollWorkerSessionRepository.java:81-86`).
- Row fields: `sessionId`, `shiftLineId`, `palletizingLineId`, `palletizingLineCode`, `palletizingLineName`, `thermoformingLineId`, `thermoformingLineCode`, `thermoformingLineName` (raw), `thermoformingShiftId`, `supervisingOperatorId`, `supervisingOperatorName`, `currentPlanItemProductTypeId`, `currentPlanItemProductName`, `currentRoll*`, `handoverPending`, `takeoverRequestStatus`, `takeoverIncomingOperatorName`, `blocked`, `blockedReason`, `lineLifecycleStatus`, `sessionStartedAt`, `sessionStartedAtDisplay` (`RollWorkerMeService.java:203-230`).
- **No display-name field** and no `machineNumber`.
- **Not filtered by commissioned.** A session on machine C is still listed after `LINE_3` is disabled.

LINE_3 row example:

```json
{
  "sessionId": 40211, "shiftLineId": 9123,
  "palletizingLineId": 3, "palletizingLineCode": "LINE_3", "palletizingLineName": "خط ج",
  "thermoformingLineId": 4, "thermoformingLineCode": "TF_LINE_3", "thermoformingLineName": "خط التشغيل ج",
  "thermoformingShiftId": 5052, "supervisingOperatorId": 31, "supervisingOperatorName": "…",
  "handoverPending": false, "blocked": false, "lineLifecycleStatus": "ACTIVE",
  "sessionStartedAt": "2026-09-15T08:10:00Z", "sessionStartedAtDisplay": "\u200e2026-09-15، 11:10 صباحًا"
}
```

Empty case: `lines: []` means the worker holds no session (for example after every line was ended). Errors: `ROLL_WORKER_SESSION_REQUIRED` 400/404/401 (§4.3).

#### D. `GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/summary` — per-machine home screen

- Controller `thermoformingrollapp/controller/RollWorkerShiftLineController.java:66-72`.
- Headers: `X-Device-Key`, and `X-Session-Token` bound to the path `shiftLineId` (`RollWorkerSessionService.java:551-564`).
- Line fields in the response (`RollWorkerShiftLineSummaryResponse.java:69-84`, NON_NULL at `:63`):
  - `shiftLineId`, `thermoformingShiftId`, `thermoformingLineId` (4 for machine C), `thermoformingLineCode` (`TF_LINE_3`), `thermoformingLineName` (`خط التشغيل ج`, raw).
  - **`thermoformingLineDisplayName`** (`ماكينة C`, set at `RollWorkerShiftLineSummaryService.java:262-263`).
- **The summary has no `palletizingLineId`.** All other fields (counters, mounted roll, consumed rolls, line state) are unchanged by this work.

#### E. Pickers not used by the current UI

Both return `List<RollWorkerShiftLineOptionResponse>` (`RollWorkerShiftLineOptionResponse.java:28-83`):

- `GET …/shift-lines/active-options` (device key only; `RollWorkerShiftLineOptionsController.java:39-43`).
- `GET …/sessions/me/joinable-lines` (device key + session token; `RollWorkerSessionController.java:149-163`).

Behaviour:

- One row per **ACTIVE shift-line**, ordered by `startedAt` (`thermoforming/repository/ThermoformingShiftLineRepository.java:125-130`). Not filtered by commissioned.
- Fields: `thermoformingLineId`, `thermoformingLineCode`, `thermoformingLineName` (raw), `palletizingLineId`, `palletizingLineCode`, `palletizingLineName`, `selectable` (always `true`), `blockingReason` (always `null`), `existingSessionOperatorId`, `existingSessionOperatorName` (`RollWorkerShiftLineOptionService.java:203-226`).
- **No display name.**
- The app has an API client for joinable-lines, but no screen calls it. The legacy `ActiveShiftLinePickerScreen` is not routed (`lib/app/bootstrap_screen.dart:151-152` always shows `MachineDashboardShell`). If either is revived, the label rules in §6.1 apply.

#### F. `POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/scan-roll` — mount a roll

- Controller `RollWorkerShiftLineController.java:74-84`. Line-agnostic except for one thing: the machine's current plan item is looked up **by the machine id** of that shift-line.
- No current item → **409** `PRODUCTION_PLAN_ITEM_REQUIRED` (`thermoforming/service/RollScanService.java:244-254`).
- This is the expected first failure on machine C if the planner has not added a `خط ج` item yet.
- Other scan errors are unchanged and out of scope.

#### G. Logout and leave-all (line-agnostic, listed for completeness)

- `POST …/shift-lines/{shiftLineId}/roll-worker-logout`, body `{"sessionToken"}` (`RollWorkerSessionController.java:117-123`).
- `POST …/sessions/leave-all`, header `X-Session-Token`, returns 204 (`RollWorkerSessionController.java:173-180`).
- Both are keyed by shift-line or operator only. No LINE_3 change.

#### H. `GET /api/v1/palletizing-line/lines/{lineId}/operator-dashboard/events` — per-line roll-state stream

- Controller `palletizing/operatorapp/controller/OperatorDashboardEventsController.java:27,33-36`; event name `operator-dashboard-changed` (`palletizing/operatorapp/event/OperatorDashboardSseBroker.java:74`).
- **`lineId` is the ProductionLine id**: 3 for LINE_3, **never 4**. The backend does not validate the id; a wrong id gives a healthy stream that never delivers a frame.
- The app already passes `session.palletizingLineId` (`lib/features/operator_dashboard_sse/presentation/controllers/operator_dashboard_sync_controller.dart:166-175,358-362`). Correct; keep it.

Not used by this app and unchanged: `POST …/shift-lines/{shiftLineId}/roll-worker-auth` (single-line login) and `POST …/sessions/takeover-with-roll-declaration` (`lib/core/api/api_paths.dart:42-46`).

### 4.3 Error codes

HTTP statuses are from the throw sites. Arabic text is **app-side**: backend messages are English and must never be shown. "Existing" means the string is already in `lib/core/errors/error_messages_ar.dart`; "PROPOSED" means it is new.

| Code | HTTP | When | Meaning for the worker | Recoverable? | UI pattern | Arabic message |
|---|---|---|---|---|---|---|
| `AUTH_INVALID_CREDENTIALS` | 401 | `X-Device-Key` missing or wrong (`SecurityAuthEntryPoint.java:28-29`; `ErrorCode.java:7`) | device misconfigured | No (admin) | full-screen inline error; **never clear sessions** | existing: `إعدادات الجهاز غير صحيحة، يرجى التواصل مع المسؤول.` |
| `ROLL_OP_SESSION_TOKEN_MISSING` | 400 | `X-Session-Token` header absent (`common/exception/GlobalExceptionHandler.java:251-266`; `ErrorCode.java:924`) | client bug | re-login | session-loss flow | existing: `انتهت الجلسة. يرجى تسجيل الدخول من جديد.` |
| `ROLL_WORKER_SESSION_REQUIRED` | 400 (blank), 404 (unknown), 403 (token of another shift-line), 401 (session not ACTIVE) | token gate (`RollWorkerSessionService.java:551-604`; `ErrorCode.java:1340`) | session gone | re-login on that tab | PIN overlay for that machine | existing: `انتهت الجلسة. يرجى تسجيل الدخول من جديد.` |
| `VALIDATION_ERROR` | 400 | `pin` blank, or `shiftLineIds` null or empty (bean validation; `GlobalExceptionHandler.java:63-78`) | bad request | fix client | inline under PIN | existing: `حدث خطأ، حاول مرة أخرى.` |
| `ROLL_WORKER_SESSION_BATCH_EMPTY` | 400 | a `null` id inside `shiftLineIds` (`RollWorkerSessionService.java:192-199`; `ErrorCode.java:1347`) | client bug | fix client | inline | existing: `يجب اختيار خط واحد على الأقل.` |
| `ROLL_WORKER_SESSION_LINE_DUPLICATE` | 400, `details.shiftLineId` | same id twice (`:200-207`; `ErrorCode.java:1355`) | client bug | fix client | inline | existing: `تم اختيار نفس الخط أكثر من مرة.` |
| `THERMOFORMING_SHIFT_LINE_NOT_FOUND` | 404, `details.shiftLineId` on the batch path | stale tab: the shift-line id no longer exists (`:212-217,237-243`; `ErrorCode.java:1559`) | tab out of date | Yes | close overlay, refetch bootstrap | existing: `الخط غير موجود. يرجى تحديث الشاشة.` |
| `THERMOFORMING_LINE_NOT_FOUND` | 404 | machine row missing (`thermoforming/service/ThermoformingLineOperationalGuard.java:99-103`; `ErrorCode.java:1482`) | configuration | refetch | as above | **not mapped in the app**. PROPOSED: `الخط غير موجود. يرجى تحديث الشاشة.` |
| `THERMOFORMING_LINE_PAUSED` | 409 | the machine is paused by management; login and roll actions are refused (`ThermoformingLineOperationalGuard.java:118-124`; `ErrorCode.java:1490`) | line stopped | wait for resume | inline error, keep tab | **not mapped in the app**. PROPOSED: `هذا الخط متوقف مؤقتاً من الإدارة. حاول لاحقاً.` |
| `OPERATOR_PIN_INVALID` | 401 | wrong PIN (`palletizing/OperatorPinService.java:159-163`; `ErrorCode.java:310`) | wrong PIN | Yes | clear PIN field, inline | existing: `رمز PIN غير صحيح.` |
| `ROLL_WORKER_NOT_ALLOWED` | 403 | operator is not a roll worker (`RollWorkerSessionService.java:515-525`; `ErrorCode.java:1331`) | not permitted | No | inline | existing: `هذا الموظف غير مخوّل للعمل كموظف رولات.` |
| `ROLL_WORKER_SESSION_LINE_INACTIVE` | 409, `details.shiftLineId` | the operator's claim ended between bootstrap and PIN (`:245-251`; `ErrorCode.java:1366`) | line no longer open | Yes | close overlay, refetch bootstrap | existing: `أحد الخطوط المختارة لم يعد نشطاً.` |
| `PRODUCTION_PLAN_ITEM_REQUIRED` | 409 | scan-roll on a machine with no current plan item (`RollScanService.java:246-254`; `ErrorCode.java:3049`) | nothing planned on this line yet | after planner action | blocking dialog, keep session | existing: `لا يوجد منتج نشط على هذا الخط. يرجى مراجعة المشرف لإضافة عنصر إلى خطة الإنتاج.` |

**Never returned by any Roll Worker endpoint:** `PRODUCTION_LINE_INACTIVE`, `PALLETIZING_LINE_INACTIVE`. A grep for `PRODUCTION_LINE_INACTIVE` finds it only in `palletizing/LineProductionGuard.java`, `palletizing/palletizer/service/PalletizerSessionService.java`, `thermoforming/service/ThermoformingShiftLineService.java` and `thermoformingplan/ThermoformingPlanService.java`. `PALLETIZING_LINE_INACTIVE` is an Operator App `blockingReason` string, not an `ErrorCode`. Do not add UI for either in this app.

Stale codes still declared but not thrown on the login path since V109: `ROLL_WORKER_SESSION_LINE_USED_BY_OTHER_WORKER` (`ErrorCode.java:1376`) and `ROLL_WORKER_TAKEOVER_REQUIRED` (`ErrorCode.java:1392`). Keep the existing mapping and do not rely on either.

### 4.4 SSE / polling / refresh contract

**Stream:** `GET /api/v1/thermoforming-roll-app/events`

- Headers: `X-Device-Key`. Works before login. One global stream per device, not per line.
- Controller `RollWorkerLineEventsController.java:33-41`; it sets `X-Accel-Buffering: no` and `Cache-Control: no-cache, no-store, must-revalidate`.
- Broker `thermoformingrollapp/event/RollWorkerLineEventsSseBroker.java`.

| Frame | SSE `event:` | `data:` payload | Source |
|---|---|---|---|
| Handshake, sent once on subscribe | `connected` | `{"status":"connected"}` | `:80,144-147` |
| Refresh trigger | `roll-worker-lines-changed` | `{"type": <reason>, "palletizingLineId": <ProductionLine id>, "version": <long, process-local>, "eventId": <UUID string>, "occurredAt": <ISO-8601 UTC>}` | `:77,325-333` |
| Urgent announcement nudge (unrelated to lines) | `urgent-manager-announcement` | `{"eventType","announcementId","targetDomain","priority","action"}` | `:83,340-350` |
| Heartbeat | comment `: ping` | none | every 25 s (`common/sse/SseInfrastructureProperties.java:30`; `:273-290`) |

Emitter timeout is 5 minutes (`:74`), so the client must reconnect. The server drops duplicate `eventId`s (LRU of 64, `:86`) and frames with a null line id (`:177-183`). There is **no replay**.

LINE_3 frame when the admin enables LINE_3:

```
event: roll-worker-lines-changed
data: {"type":"LINE_STATE_CHANGED","palletizingLineId":3,"version":42,"eventId":"6f1c…","occurredAt":"2026-09-15T08:00:00.123Z"}
```

How that frame is produced:

1. `ProductionLineAdminService.toggleActive` or `update` publishes `LineStateChangedEvent(3)`, only when the active flag actually changed, inside the transaction (`palletizing/ProductionLineAdminService.java:130-132,152-154,169-171`).
2. After commit, `OperatorDashboardLegacyFallbackListener` converts it into `OperatorDashboardChangedEvent(3, "LINE_STATE_CHANGED", …)` (`palletizing/operatorapp/event/OperatorDashboardLegacyFallbackListener.java:64-85`).
3. The broker fans it out (`RollWorkerLineEventsSseBroker.java:168-221`). A rolled-back toggle sends nothing.

Other `type` values that reach this stream on LINE_3 activity (reason constants in `palletizing/operatorapp/event/OperatorDashboardChangedEvent.java`):

- `LINE_STATE_CHANGED` when an operator claims machine C (`ThermoformingShiftLineService.java:267` → `thermoforming/event/ThermoformingLineRefreshPublisher.java:100-114`).
- `ROLLS_EMPLOYEE_CHANGED` on roll-worker login, logout and leave-all (`RollWorkerSessionService.java:360-363,654-657,898-901`).
- `OPERATOR_SESSION_ENDED` when a shift-line ends (`ThermoformingShiftLineService.java:608`).
- `ROLL_MOUNTED`, `ROLL_CONSUMED`, `HANDOVER_CHECKLIST_CHANGED` and others (`OperatorDashboardChangedEvent.java:75,83,162`).

**Treat every `type`, including unknown ones, as the same refresh trigger.**

**Client contract (required)**

1. **A frame is a trigger, never state.** Do not look up a tab by `palletizingLineId`, and never compare it to `thermoformingLineId` or `shiftLineId`.
2. **Logged out:** on any refresh frame, debounce and then refetch `GET /bootstrap`. The current app does this with a 250 ms debounce (`lib/features/shift_line/presentation/controllers/roll_worker_bootstrap_controller.dart:222-239`, `…/roll_worker_bootstrap_poll_config.dart:14-15`).
3. **Logged in:** on any refresh frame, refetch `GET /sessions/me` **and** `GET /bootstrap`. The current app ignores frames in the bootstrap controller while logged in (`roll_worker_bootstrap_controller.dart:204-207`). It refetches `/sessions/me` (`lib/features/sessions_me/presentation/controllers/sse_lifecycle_controller.dart:106-107`, `…/sessions_me_controller.dart:156-162`) and then nudges a background bootstrap refresh whenever a new `/sessions/me` snapshot lands (`lib/features/home/presentation/screens/machine_dashboard_shell.dart:315-323`). That chain is acceptable if §6.11 item 7 passes.
4. **On `connected` after a disconnect, and on app resume:** refetch immediately. The broker has no replay.
5. **Stream down:** fallback-poll `GET /bootstrap` (and `/sessions/me` when logged in). The current app polls every 2 s and treats 40 s of silence as a dead link (`roll_worker_bootstrap_poll_config.dart:14`, `lib/features/shift_line/data/roll_worker_lines_sse_client.dart:162`). Keep this.
6. The per-line `operator-dashboard-changed` stream (§4.2 H) still refreshes the summary of an authorized tab. It is keyed by PL id 3 for machine C.

### 4.5 Staged behaviour: before enable vs after enable

| Surface | Before enable (LINE_3 inactive, TF_LINE_3 active) | After enable, no operator on C | After an operator claims C | After LINE_3 is disabled mid-shift (rollback) |
|---|---|---|---|---|
| `GET /bootstrap` rows | 2 (`TF_LINE_1`, `TF_LINE_2`) | 3; third row `selectable:false`, `NO_ACTIVE_SHIFT`, no `shiftLineId` | 3; third row has `shiftLineId`, `selectable:true` unless blocked | **2**: machine C disappears (`RollWorkerBootstrapService.java:80`) |
| Tabs the app should show | 2 | 3 (C "waiting") | 3 (C PIN-enterable) | 2, plus C **only if this device holds a session on C** (from `/sessions/me`) |
| Can an operator claim C? | No, `PRODUCTION_LINE_INACTIVE` (`ThermoformingShiftLineService.java:165-170`; Operator App) | Yes, needs a plan item | n/a | new claims refused |
| `/events` frame | none for PL 3 until enable | `LINE_STATE_CHANGED` / PL 3 at enable | `LINE_STATE_CHANGED` / PL 3 on claim | `LINE_STATE_CHANGED` / PL 3 at disable |
| `start-batch` with C's `shiftLineId` | impossible (no shift-line exists) | impossible | works | **still works** (no PL-active check, §4.2 B) |
| `scan-roll` / previous-roll on C | n/a | n/a | works if a plan item exists, else `PRODUCTION_PLAN_ITEM_REQUIRED` | **still works** (no PL-active check on roll paths; runtime not verified) |
| `/sessions/me`, `active-options`, `joinable-lines` | no C rows | no C rows (no shift-line) | C rows present | **C rows still present** (not commissioned-filtered) |
| Pallet creation on LINE_3 (Palletizing App, context only) | refused | allowed | allowed | refused, `PRODUCTION_LINE_INACTIVE` |

## 5. IMPLEMENTED IN THIS TASK

Backend changes relevant to this app. All are uncommitted on top of `e47c2c15`.

| Change | File:line | Effect on this app |
|---|---|---|
| Commissioned-machine query added | `thermoforming/repository/ThermoformingLineRepository.java:29-31` | none directly |
| Roll Worker bootstrap switched from `findAllActive()` to `findAllCommissioned()` | `thermoformingrollapp/service/RollWorkerBootstrapService.java:80` | a machine whose palletizing line is inactive is no longer listed |
| Curated display name `TF_LINE_3 → ماكينة C` | `RollWorkerMachineDisplayNameResolver.java:45` | `lineDisplayName` and `thermoformingLineDisplayName` for machine C are `ماكينة C`, not the raw `خط التشغيل ج` |
| Activation change publishes `LineStateChangedEvent(productionLineId)` | `palletizing/ProductionLineAdminService.java:130-132,152-154,169-171` | enable/disable of LINE_3 now produces a `/events` frame, so tabs appear or disappear without a restart |
| V191 provisioning (LINE_3 inactive, TF_LINE_1/2/3 ensured by code) | `src/main/java/db/migration/V191__provision_three_line_thermoforming_topology.java` | machine C exists after deploy |
| DEV `DataSeeder` seeds LINE_3 inactive and TF names `خط التشغيل أ/ب/ج` (existing rows untouched) | `config/DataSeeder.java` (profile `!prod`) | DEV/staging databases carry machine C |

**Additive-only statement.** No Roll Worker endpoint path, HTTP method, header, request field, response field, error code, enum value or SSE event name was added, removed or renamed. The one behavioural change is that bootstrap **filters** rows by commissioned. Production had no machine on an inactive palletizing line before V191, so for existing lines 1 and 2 the output is unchanged.

**What did NOT change**

- `active-options`, `joinable-lines`, `sessions/me`, `summary`, `start-batch`, `roll-worker-auth`, `scan-roll` and previous-roll paths are not commissioned-filtered and have no palletizing-line-active check.
- No display-name field was added to `sessions/me`, `active-options` or `joinable-lines`.
- The `/events` payload shape is unchanged.
- There is no per-device line binding: every tablet sees every commissioned machine.
- No new error code.

## 6. FRONTEND MUST VERIFY

Everything in this section is a **candidate site** found by reading Flutter HEAD `7b49c229`. None of it has been proven at runtime. Confirm each site before changing it.

### 6.1 Candidate code sites in the Flutter repo

| # | File:line (HEAD 7b49c229) | What the code does | Why it matters for LINE_3 | Required change |
|---|---|---|---|---|
| **S1** | `lib/core/ui/line_labels.dart:13-22,30-37`; used at `lib/features/home/presentation/screens/machine_dashboard_shell.dart:195-198`, `:237` and `lib/features/home/presentation/screens/roll_worker_home_screen.dart:360-361` | Label `'خط ' + letters[n-1]` with alphabetical letters `أ ب ت ث ج …` from `machineNumber` or tab position | line 3 → **`خط ت`** (wrong); the backend never uses that letter | **Stop computing labels locally.** Use the server label (**D1**, below). Delete `LineLabels` or leave it unused; never fall back to a letter or an index. |
| **S2** | `lib/features/shift_line/data/dto/roll_worker_bootstrap_response.dart:44-85`; `lib/features/shift_line/domain/entities/roll_worker_bootstrap_line.dart:16-102` | `lineDisplayName` is not declared or parsed | the server label is thrown away | Add nullable `lineDisplayName` to the DTO and entity (and to `==` / `hashCode`). Keep `palletizingLineName`. |
| **S3** | `machine_dashboard_shell.dart:208` (key `sl-$sid` or `th-$thermoformingLineId`), `:258-271` (selection preserved by key) | When an operator claims a waiting machine, its key changes from `th-4` to `sl-9123`. `keys.indexOf('th-4')` is `-1`, so the selection resets to index 0. | during go-live the worker watching machine C is thrown to machine A just as C opens | Keep **tab identity = `thermoformingLineId`** and preserve selection by it. The child `ValueKey` may add the shift-line (e.g. `th-4/sl-9123`) so the summary still resets per session. |
| **S4** | `machine_dashboard_shell.dart:225-243` | Tabs backed only by a local session: label by position (`:237`), colour from `accentForLine(thermoformingLineId: sid)` with a **shift-line id passed as a machine id** (`:231`, same at `:122`), appended after all bootstrap tabs | after LINE_3 is disabled mid-shift, machine C's tab gets a position label and an arbitrary colour, possibly out of order | Build these tabs from the `/sessions/me` row: `thermoformingLineId` for identity and colour, the last-known server label for machine `thermoformingLineId` (from bootstrap or summary). Never pass `shiftLineId` as `thermoformingLineId`. |
| **S5** | `machine_dashboard_shell.dart:375-389` (`isScrollable: false` at `:378`, `Tab(height: 50)`) | Fixed-width tabs, each a 9 dp dot, 8 dp gap and label | 3 tabs with `ماكينة C` (or `خط ج`) must fit at phone width; 4 later may not | Verify on the smallest supported device (§6.7). Give labels `maxLines: 1` with ellipsis; switch to `isScrollable: true` when labels would overflow. |
| **S6** | `lib/features/home/data/dto/shift_line_summary_response.dart:218-224` | Hard casts `json['thermoformingLineCode'] as String`; `thermoformingLineDisplayName` not parsed | the server label is unavailable in-session when bootstrap lacks the machine | Parse `thermoformingLineDisplayName` as nullable; use tolerant casts. |
| **S7** | `roll_worker_home_screen.dart:360-361` (`_lineLabel`), `:460-467` (leave-line dialog gets `lineLabel`), `:594-596` (single-tab header) | Falls back to `LineLabels.label(fallbackIndex: lineIndex)` | the leave-confirmation dialog could name the wrong machine | Pass the server label from the shell; if none is known yet, show a neutral placeholder (§6.8), never a computed letter. |
| **S8** | `lib/core/errors/error_code.dart:6-104`; `lib/core/errors/error_messages_ar.dart:7-101` | No enum value for `THERMOFORMING_LINE_PAUSED` or `THERMOFORMING_LINE_NOT_FOUND`, so both fall to `unknown` and show `حدث خطأ، حاول مرة أخرى.` | a newly commissioned machine may be paused by management; the worker sees a meaningless error | Add both codes and their Arabic strings (§4.3). |
| **S9** | `test/features/home/machine_dashboard_shell_test.dart:326-329` | Asserts tabs `خط أ`/`خط ب` and `find.textContaining('ماكينة'), findsNothing` | pins the local-letter design; conflicts with D1 option A | Update according to D1; add the 3-machine skewed-id tests in §6.10. |
| S10 (pre-existing, not LINE_3-specific) | `roll_worker_bootstrap_response.dart:58-59` and `lib/features/home/presentation/widgets/machine_dashboard_preview.dart:45-46` | Reads `currentProductTypeId` / `currentProductTypeName`; the backend sends `currentPlanItemProductTypeId` / `currentPlanItemProductName` (`RollWorkerLineStateResponse.java:80-81`, renamed in backend commit `c12f5225`) | the dimmed preview behind the PIN overlay shows no product for every machine, C included | Recommended in the same release: read the `currentPlanItem*` keys. |
| S11 (dead code) | `lib/core/util/line_label_mapper.dart:56-76` | `TF_LINE_1/2`-only label maps; the only caller `CompactLineHeader` (`lib/features/home/presentation/widgets/compact_line_header.dart:30`) is never instantiated | could be revived by mistake | Delete, or leave unused. Must not become a label source. |
| S12 (correct, keep) | `lib/features/roll_worker_auth/data/session_batch_api.dart:17-27`, `roll_worker_auth_overlay.dart:93` | `start-batch` with `shiftLineIds: {tab.shiftLineId}` | correct id domain | none |
| S13 (correct, keep) | `operator_dashboard_sync_controller.dart:166-175,358-362` | per-line SSE opened with `session.palletizingLineId` | correct: 3 for LINE_3 | none |
| S14 (acceptable) | `lib/core/theme/app_colors.dart:61-78` | accent = palette[`palletizingLineId % 6`] | PL 1/2/3 give three distinct colours; purely cosmetic | Keep as decoration only; never as identity. With S4 fixed, fallback tabs use the machine's ids, not `shiftLineId`. |

**D1: label vocabulary. Owner decision required before implementation.**

- The backend's Roll Worker display field is **`lineDisplayName`** on bootstrap and **`thermoformingLineDisplayName`** on summary: `ماكينة A` / `ماكينة B` / `ماكينة C`. This handoff's default instruction is to **use `lineDisplayName` from the server**.
- **Conflict:** this app's own documented rule forbids machine vocabulary (`lib/core/ui/line_labels.dart:3-8`: "never surface `ماكينة A/B/1/2`"), and a widget test pins it (`machine_dashboard_shell_test.dart:326-329`). Option A would also change the LINE_1 and LINE_2 tabs from `خط أ`/`خط ب` to `ماكينة A`/`ماكينة B`.
- **Option A (default here):** label = `lineDisplayName`, falling back to the summary's `thermoformingLineDisplayName`. Update S9 and the rule in `line_labels.dart`.
- **Option B (keeps floor vocabulary):** label = **`palletizingLineName`** (`خط أ` / `خط ب` / `خط ج`). It is equally server-sourced and is present on bootstrap, `/sessions/me`, `active-options` and `joinable-lines`, but not on summary. It matches the Operator dashboard, the Admin App and the web portal.
- **Rules that hold under either option:**
  - No local letter table.
  - No label derived from `machineNumber`, any id, or tab position.
  - Never show `lineCode`, `lineName` (`خط التشغيل ج`) or `TF_LINE_3`.

### 6.2 Required screens / dialogs

No new screen. The existing surfaces below must handle three machines.

| Surface | Trigger | Title / label | Fields | Buttons | Loading / success / error | Arabic |
|---|---|---|---|---|---|---|
| Machine tab strip (`MachineDashboardShell`) | bootstrap rows ∪ held sessions | one tab per machine, server label (D1) | state dot: authorized / needs PIN / waiting | tap or swipe selects; selection preserved by `thermoformingLineId` | first load: shimmer; background refresh: in place; failure with no rows: `تعذّر تحميل الماكينات. حاول مرة أخرى.` | label from server |
| Waiting card on machine C | row `selectable:false` | existing `الخط غير جاهز حالياً` | pill: `بانتظار مشغّل` / `تسليم مناوبة` / `طلب استلام قيد المعالجة` / `غير متاح حالياً` | `تحديث الحالة` (refetch bootstrap), `حسناً` | spinner row while waiting | existing strings (`lib/features/shift_line/presentation/widgets/line_waiting_status.dart:29-52`) |
| PIN overlay on machine C | row `selectable:true`, no local session | existing overlay title | 4-digit PIN, large keypad | `دخول` | busy state blocks double submit; errors from §4.3 inline | existing |
| In-dashboard header (single tab) and leave-line dialog | authorized tab | server label (D1) | worker name, product, mounted roll | existing | n/a | label from server |
| Scan-roll error, machine C with no plan item | `PRODUCTION_PLAN_ITEM_REQUIRED` | existing dialog | n/a | `حسناً` | keep the session and the tab | existing string |
| Paused machine error | `THERMOFORMING_LINE_PAUSED` | inline under PIN or snackbar on roll actions | n/a | n/a | keep the tab; refresh on the next frame | PROPOSED string (§4.3) |

### 6.3 Models / DTOs

| Model | Field | Type / nullability | Use | Must NOT be used as |
|---|---|---|---|---|
| `RollWorkerBootstrapLine` | `thermoformingLineId` | int, non-null | **tab identity**, label cache key, selection | — |
| | `lineDisplayName` (**add**) | String? | label, option A | — |
| | `palletizingLineName` | String? | label, option B | — |
| | `shiftLineId` | int?, null until claimed | `start-batch`, summary and roll URLs, token key | tab or machine identity |
| | `palletizingLineId`, `productionLineId` | int? (same value) | diagnostics, colour | tab key; matching SSE frames to tabs; compared to `thermoformingLineId` |
| | `machineNumber` | int? | nothing required | label source, sort key, id |
| | `lineCode` | String | logs and tests only | UI text |
| | `lineName` | String (raw) | nothing | UI text |
| | `selectable` / `canStartRollWorkerSession`, `blocked`, `blockedReason`, `handoverPending`, `takeover*`, `lineLifecycleStatus` | as §4.2 A | tab state | — |
| `RollWorkerActiveLine` (`/sessions/me`) | `thermoformingLineId` | int? | machine identity for session-only tabs | — |
| | `shiftLineId`, `sessionId` | int | session binding | machine identity |
| | `palletizingLineName` | String? | label, option B | — |
| | (no display name) | — | option A: use the cached label for that `thermoformingLineId` | — |
| `ShiftLineSummary` | `thermoformingLineDisplayName` (**add**) | String? | label fallback, option A | — |
| | `thermoformingLineCode`, `thermoformingLineName` | String? (make tolerant) | nothing visible | UI text |
| `BatchSessionEntry` | `shiftLineId`, `sessionToken`, `thermoformingLineId`, `palletizingLineId` | as §4.2 B | store the token by `shiftLineId`; may seed the machine id ↔ shift-line link | — |
| `PickerSseRefreshTriggered` | `type`, `palletizingLineId`, `version`, `eventId`, `occurredAt` | all nullable | logging and dedupe only | business state, tab routing |

### 6.4 Repository / API client changes

- Bootstrap DTO: parse `lineDisplayName`. The recommended S10 fix also parses `currentPlanItemProductTypeId` and `currentPlanItemProductName`.
- Summary DTO: parse `thermoformingLineDisplayName`; replace hard `as String` / `as int` casts on line fields with tolerant parsing.
- Error enum and Arabic map: add `THERMOFORMING_LINE_PAUSED` and `THERMOFORMING_LINE_NOT_FOUND`.
- **No new endpoint, header or request field.** `start-batch`, `sessions/me`, logout, leave-all, scan and previous-roll calls are unchanged.
- Every parser treats an absent key and `null` the same way (§4.2 common).

### 6.5 Provider / state changes

- **Machine registry keyed by `thermoformingLineId`.** Tab list = bootstrap rows in server order, plus any held session (from `/sessions/me`) whose `thermoformingLineId` is not in bootstrap. Place those tabs by the machine's last-known server order, not at the end, if an order is known.
- **Label cache** `Map<thermoformingLineId, String>`, filled from every bootstrap row (option A: `lineDisplayName`; option B: `palletizingLineName`). Option A also fills it from the summary's `thermoformingLineDisplayName`. Option B can use `/sessions/me` `palletizingLineName` directly. The cache survives a machine disappearing from bootstrap.
- **Selection** stored as `thermoformingLineId`. When the tab list changes, reselect that machine if it is still present; otherwise keep the nearest stable choice. Never silently jump to index 0 because a key changed.
- **Refresh:** any `/events` refresh frame → bootstrap refetch (logged out), or `/sessions/me` then bootstrap (logged in). Reconnect or resume → immediate refetch. Stream down → 2 s fallback poll (existing).
- **Stale state:** out-of-order responses are already discarded by sequence numbers (`roll_worker_bootstrap_controller.dart:112-127`). Keep that.
- A machine missing from a **successful** bootstrap is not evidence that a session ended. Only `/sessions/me` ends sessions (existing reconcile, `sessions_me_controller.dart:241-275`).

### 6.6 UX flows

- **Happy path (go-live).**
  1. The tablet shows A and B.
  2. The admin enables LINE_3; within seconds tab C appears as waiting (`بانتظار مشغّل`) and the selected tab does not move.
  3. The operator claims C; tab C switches to the PIN overlay **while staying selected**.
  4. The worker enters a PIN, which calls `start-batch` with `[shiftLineId of C]`, and C becomes authorized.
  5. The worker scans a roll and it mounts.
- **Business error.**
  - `PRODUCTION_PLAN_ITEM_REQUIRED` on scan: blocking dialog; the session stays.
  - `ROLL_WORKER_SESSION_LINE_INACTIVE` or `THERMOFORMING_SHIFT_LINE_NOT_FOUND` on PIN: inline message, clear the PIN, refetch bootstrap.
  - `THERMOFORMING_LINE_PAUSED`: inline message; the tab stays.
- **Network failure.** Keep the last good tabs; show the connectivity banner `لا يوجد اتصال بالخادم، سيتم إعادة المحاولة تلقائيًا`; the fallback poll recovers. Never show a device-key error as a session loss.
- **Retry or double tap.** The PIN button is disabled while submitting (existing `_submitting` guard). A retried `start-batch` for the same shift-line replaces the worker's own session, which is harmless; the new token wins.
- **Cancel / back.** Switching tabs away from a PIN overlay discards the typed PIN. No server call.
- **App resume.** Refetch bootstrap, plus `/sessions/me` when logged in, before trusting the tab list.

### 6.7 Arabic RTL 3-line layout requirements

- The app already forces `Directionality(TextDirection.rtl)` with the `ar` locale (`lib/app/app.dart:24-33`).
- **Tab order = server array order** (`TF_LINE_1`, `TF_LINE_2`, `TF_LINE_3`). In RTL the first tab is the **rightmost**: A or أ on the right, C or ج on the left. Swipe direction follows RTL (`TabBarView` does this automatically).
- 3 tabs at phone width (about 360 dp): each tab is about 120 dp. The label (`ماكينة C` or `خط ج`) plus the 9 dp dot and 8 dp gap must not wrap or clip. Use `maxLines: 1` with `TextOverflow.ellipsis`; keep the 50 dp tab height (touch target of at least 48 dp).
- When 4 or more tabs would overflow, use `isScrollable: true` with `tabAlignment` start. There must be no layout that assumes 2 or 3 tabs.
- Mixed-script labels such as `ماكينة C`: verify the Latin letter renders **after** the Arabic word in RTL (bidi). If it flips, wrap the label in a Unicode isolate; do not rebuild the string locally.
- AppBar accent interpolation already works for any tab count (`machine_dashboard_shell.dart:70-81`).
- Big targets, no typing except the PIN, and state readable from the dot plus the waiting card text: keep all three.

### 6.8 Arabic UI text

| Key / use | Arabic | Status |
|---|---|---|
| Machine tab label | **from server** (D1): `ماكينة A/B/C` or `خط أ/ب/ج` | no local string |
| Label not yet known (session-only tab before any server label arrived) | `…` | PROPOSED (placeholder; never a letter) |
| Empty machine list | `بانتظار فتح خط من تطبيق المشغّل` / `سيظهر الخط هنا فور فتحه من تطبيق المشغّل. اسحب للأسفل للتحديث.` | existing (`machine_dashboard_shell.dart:39-41`) |
| Bootstrap load failure | `تعذّر تحميل الماكينات. حاول مرة أخرى.` | existing (`:558`) |
| Retry | `إعادة المحاولة` | existing |
| Waiting pill (no operator) | `بانتظار مشغّل` | existing |
| Waiting dialog title | `الخط غير جاهز حالياً` | existing |
| Refresh state | `تحديث الحالة` | existing |
| PIN submit | `دخول` | existing |
| `THERMOFORMING_LINE_PAUSED` | `هذا الخط متوقف مؤقتاً من الإدارة. حاول لاحقاً.` | PROPOSED |
| `THERMOFORMING_LINE_NOT_FOUND` | `الخط غير موجود. يرجى تحديث الشاشة.` | PROPOSED (reuses existing wording) |
| `PRODUCTION_PLAN_ITEM_REQUIRED` | `لا يوجد منتج نشط على هذا الخط. يرجى مراجعة المشرف لإضافة عنصر إلى خطة الإنتاج.` | existing |
| `ROLL_WORKER_SESSION_LINE_INACTIVE` | `أحد الخطوط المختارة لم يعد نشطاً.` | existing |

### 6.9 Edge cases

1. **LINE_3 disabled mid-session.** Bootstrap drops C, but `/sessions/me` still lists the worker's C session and roll actions still succeed (§4.5).
   - Required: keep C's tab while `/sessions/me` lists it, with its cached server label and the machine's colour.
   - Do not end the session locally.
   - When the operator ends the shift, `/sessions/me` drops it and the existing reconcile removes the tab.
   - If this device holds no session on C, the tab simply disappears.
2. **Stale bootstrap / SSE missed.** There is no replay. Recovery comes from the `connected` handshake refetch, the resume refetch and the 2 s fallback poll while down. A tablet that stayed connected but missed a frame is corrected by the next frame of any type.
3. **Ids skewed.**
   - TF 4 ↔ PL 3; shift-line ids unrelated.
   - Never compare `palletizingLineId` with `thermoformingLineId`.
   - Never build a URL from `thermoformingLineId` where a `shiftLineId` or PL id is required.
   - Never derive `machineNumber` from either id.
4. **Selected machine claimed or unclaimed.** Its shift-line id appears or disappears. The selection must stay on the same `thermoformingLineId` (S3).
5. **Two workers, same machine.** A second worker's PIN replaces the first worker's session (V109). The first tablet gets `ROLL_WORKER_SESSION_REQUIRED` 401 on its next call and shows the PIN overlay for that machine only.
6. **Machine paused.** PIN and roll actions return `THERMOFORMING_LINE_PAUSED` 409. The tab stays; resume produces a frame.
7. **Every tablet sees every machine.** There is no per-device binding, so a line-A tablet also gets tab C. That is expected.
8. **A 4th line later** (e.g. `TF_LINE_4`). No app change should be needed; tabs, labels and layout all follow the server. Two backend-side notes:
   - Unless the curated map gains `TF_LINE_4`, `lineDisplayName` falls back to the stored name (e.g. `خط التشغيل د`) (`RollWorkerMachineDisplayNameResolver.java:59-70`).
   - Server order is by string code: `TF_LINE_10` would sort between `TF_LINE_1` and `TF_LINE_2`.
9. **Old tabs keyed `sl-…` after an app update.** No persisted tab keys were found in storage code (sessions are stored by `shiftLineId`), so no migration of stored state is expected. Verify.

### 6.10 Testing requirements

Use **skewed ids in every fixture**: machines `thermoformingLineId` 1, 2, **4** mapped to `palletizingLineId` 1, 2, **3**, `machineNumber` 1, 2, 3, shift-line ids 9120, 9121, 9123.

- **Unit (DTO):**
  - Bootstrap parses `lineDisplayName`, and keeps parsing when it is absent or `null`.
  - Summary parses `thermoformingLineDisplayName` and tolerates missing line fields.
  - `currentPlanItem*` keys are read (S10).
  - Error enum maps `THERMOFORMING_LINE_PAUSED` and `THERMOFORMING_LINE_NOT_FOUND`.
- **Widget (shell):**
  1. Three bootstrap rows render 3 tabs in array order, labelled from the server (D1). **No `خط ت`** anywhere, and no text built from `machineNumber` or index.
  2. Waiting C becomes selectable (row gains `shiftLineId` 9123) while C is selected: C stays selected.
  3. Bootstrap without C plus `/sessions/me` with C: C's tab stays, with its cached label and correct colour.
  4. PIN on C calls `startBatch` with `{9123}` exactly, never 4 or 3.
  5. 3 tabs at 360 dp width and at tablet width: no overflow, no wrap; RTL order puts machine 1 rightmost.
- **Provider / controller:**
  - A `roll-worker-lines-changed` frame with `palletizingLineId: 3` refetches bootstrap when logged out, and `/sessions/me` then bootstrap when logged in.
  - Unknown `type` values also refetch.
  - A reconnect handshake refetches.
  - An out-of-order bootstrap response is discarded.
- **Repository:** the per-line operator-dashboard stream URL for a C session uses `3`.
- **Update** `machine_dashboard_shell_test.dart:326-329` according to D1.
- **Manual smoke:** run §6.11 on a DEV or staging backend.

**LINE_1 / LINE_2 regression checklist (must stay green)**

- [ ] Tabs A and B render with the D1 label and colours unchanged from today.
- [ ] PIN login on A and B, and a multi-line worker holding A and B, work.
- [ ] Scan, full consume, return and grinding on A and B are unchanged.
- [ ] Leave-line and leave-all are unchanged.
- [ ] The takeover banner and handover waiting card on A and B are unchanged.
- [ ] Urgent announcement nudge still works.
- [ ] The label printer flow is unchanged.
- [ ] Resume, reconnect and airplane-mode recovery are unchanged.

### 6.11 Acceptance checklist for the go-live CHECKPOINT

Run on a **staging or DEV backend with this release deployed**. Start with LINE_3 **inactive**; step 3 enables it. Use a phone-size device and a tablet. Record pass or fail for each item.

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Cold-start the app with LINE_3 inactive | exactly 2 tabs (machines A and B); no third tab; no error | |
| 2 | Log in on machine A with a PIN | authorized; summary loads | |
| 3 | Admin enables LINE_3 (`/web/admin/production-lines`) while the device from step 2 stays logged in | within about 5 s a **third tab appears without restart**; the selected tab stays on A | |
| 4 | Read the third tab's label | the server label for C per D1 (`ماكينة C` or `خط ج`); **never `خط ت`**, never `TF_LINE_3`, never `خط التشغيل ج` | |
| 5 | Open the third tab | waiting card, pill `بانتظار مشغّل`; no PIN overlay | |
| 6 | Planner adds a `خط ج` plan item; operator claims TF_LINE_3 in the Operator App while **the third tab is selected** on a logged-out device | the tab switches to the PIN overlay and **stays selected** (no jump to A) | |
| 7 | Repeat step 6's observation on a device logged in on A | the third tab becomes PIN-enterable within about 5 s with no manual refresh | |
| 8 | Enter a roll worker PIN on the third tab | authorized; network log shows `POST …/sessions/start-batch` with `shiftLineIds` = that tab's shift-line id (not 3, not 4) | |
| 9 | Open the per-line live stream (network log) | `…/palletizing-line/lines/3/operator-dashboard/events` | |
| 10 | Scan a compatible roll on C | 201; mounted roll shows | |
| 11 | Scan on C before any plan item (repeat on a fresh setup, or remove the item first) | Arabic `PRODUCTION_PLAN_ITEM_REQUIRED` dialog; session kept | |
| 12 | Hold sessions on A, B and C on one device; switch tabs by tap and by swipe | correct summary per tab; RTL order A → B → C from right to left; no clipped labels on the phone | |
| 13 | Admin pauses machine C, then the worker tries a roll action on C | Arabic paused message (§4.3), not the generic error; resume restores | |
| 14 | Rollback rehearsal: with a C session open, admin disables LINE_3 | C's tab **stays** while `/sessions/me` lists it, with the same label; A and B unaffected; other devices without a C session lose the third tab | |
| 15 | Operator ends the shift on C | C's tab disappears on every device; no crash; selection moves to an existing tab | |
| 16 | Airplane mode 60 s, then back online; also background the app for 2 min, then resume | tab list and labels refresh correctly; no duplicate tabs | |
| 17 | LINE_1/LINE_2 regression checklist (§6.10) | all pass | |

## 7. NOT VERIFIED

- **No runtime proof of any kind.** The backend was not booted, Maven was not run, no database was queried, and the app was not run on a device or emulator. Every backend statement is code-read; every Flutter statement is code-read at HEAD `7b49c229`.
- That the enable or disable of LINE_3 actually delivers a `roll-worker-lines-changed` frame end-to-end on a servlet container. The chain was traced in code (§4.4) but not observed.
- Production ids `LINE_3=3`, `TF_LINE_3=4`: taken from the V191 javadoc and the audit, not from a database query. Also not verified: the stored production names of `TF_LINE_1` and `TF_LINE_2` (V191 adopts existing rows untouched).
- That DTOs without a class-level `@JsonInclude` serialize `null` fields as explicit `null`. No global Jackson inclusion setting was found in `src/main`, but no response was captured.
- That roll mounting and closing on machine C still succeed after LINE_3 is disabled. Code shows no palletizing-line-active check on those paths; not executed.
- Whether any backend test currently covers the commissioned filter for the Roll Worker bootstrap. In the worktree as read, `src/test/java/ps/taleeb/taleebbackend/thermoformingrollapp/service/RollWorkerBootstrapServiceTest.java` still stubs `findAllActive()` (e.g. lines 119, 345, 386), and no Roll Worker test references `TF_LINE_3`. Other agents may be updating tests in parallel.
- **D1 (label vocabulary) is undecided.** Also not verified: whether shop-floor users read `ماكينة C` or `خط ج` more reliably.
- Bidi rendering of `ماكينة C` in RTL tabs; tab fit at the smallest supported device width.
- Which app build is installed on the factory tablets.
- That no persisted state depends on the old tab keys (S3 change); no such storage was found.
- The selection-jump behaviour (S3) was deduced from code, not observed.
- The Flutter candidate sites could have siblings this read missed. The search covered `lib/` for label helpers, `lineDisplayName`, `palletizingLineId`, the tab controller and the SSE flows.

## 8. Backend Compatibility & Rollout Notes

| Backend state | Current Roll Worker build (HEAD `7b49c229`) | Updated build (this handoff) |
|---|---|---|
| Release deployed, **LINE_3 inactive** | Works as today: 2 tabs. The bootstrap hides TF_LINE_3; a `/events` frame for PL 3 only causes a harmless refetch. | Works: 2 tabs |
| **LINE_3 active** | Functionally works (tabs from the list, `start-batch` by `shiftLineId`, per-line SSE by PL id 3), but the tab reads **`خط ت`**, the selection jumps when C is claimed, fallback tabs are labelled by position, and the paused error is generic. **Not acceptable for go-live.** | Passes §6.11 |

- **Can the backend deploy first?** **Yes**, provided LINE_3 stays inactive until this build passes the CHECKPOINT. Nothing in this release changes the shape of any Roll Worker request or response.
- **V190 coupling.** The plan-item close handshake does not change the Roll Worker contract (`docs/frontend-handoffs/THERMOFORMING_OPERATOR_PLAN_ITEM_CLOSE_HANDSHAKE.md` line 16). Old Operator and Palletizing builds are unsupported by this release regardless of LINE_3; that constraint does not apply to the Roll Worker App.
- **Wave 11** (already in `e47c2c15`): only the unused `keep-mounted-handover` route was removed. The existing Wave 11 handoff confirms this app is unaffected.
- **Rollout order:**
  1. Deploy the backend.
  2. Install the updated Roll Worker build on every roll-worker tablet, along with the Operator, Palletizing and Admin builds.
  3. CHECKPOINT: §6.11 passes on staging or DEV with LINE_3 enabled.
  4. Admin enables LINE_3 in production.
  5. Planner adds a `خط ج` item.
  6. Operator claims TF_LINE_3.
  7. Palletizer logs in on LINE_3.
  8. Roll worker joins machine C.
- **Rollback:** pause the line or end the shift first, then disable LINE_3. The app requirement for mid-shift disable is §6.9 item 1. No app rollback is needed: the updated build also works with LINE_3 inactive.

## 9. Final Acceptance Criteria

1. D1 is decided by the owner and recorded. Every machine label shown anywhere in the app (tabs, single-tab header, leave dialog, session-only tabs) comes from the chosen server field. No label is computed from `machineNumber`, any id, or tab position, and `خط ت` cannot appear for any machine.
2. The bootstrap parser reads `lineDisplayName`, and the summary parser reads `thermoformingLineDisplayName`. Both tolerate absent or `null` fields.
3. Tab identity and selection are keyed by `thermoformingLineId`. A machine being claimed, released or replaced never moves the selection to another machine.
4. `start-batch` sends `shiftLineIds` only. Roll action URLs use `shiftLineId`. The per-line operator-dashboard stream uses `palletizingLineId`. No code compares or substitutes one id space for another; tests use skewed ids (TF 4 ↔ PL 3).
5. Any `/events` refresh frame (any `type`) leads to a bootstrap refetch, plus `/sessions/me` when logged in. Reconnect and resume refetch immediately. The fallback poll still runs while the stream is down.
6. Three machine tabs lay out correctly in Arabic RTL on phone and tablet widths, and the layout does not assume a fixed tab count.
7. A session on a machine that disappears from bootstrap stays usable with its label until `/sessions/me` drops it.
8. `THERMOFORMING_LINE_PAUSED` and `THERMOFORMING_LINE_NOT_FOUND` show Arabic messages.
9. Every item in §6.11 passes on a staging or DEV backend with LINE_3 enabled, and the LINE_1/LINE_2 regression checklist in §6.10 passes.
