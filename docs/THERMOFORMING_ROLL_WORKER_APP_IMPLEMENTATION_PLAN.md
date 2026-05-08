# Thermoforming Roll Worker App — Implementation Plan

> **Source of truth:** `docs/THERMOFORMING_ROLL_WORKER_APP_FRONTEND_REQUIREMENTS.md`
> **Visual reference:** `docs/desing_system_needed_examples/`
> **Printer reference (READ-ONLY, do not modify):** `roll_production_app/` (sibling project in workspace)

---

## 1. Context

This is the **Thermoforming Roll Worker App** (`تطبيق عامل الرولات`) for Taleeb factory production-floor workers. It is one of three Flutter apps in the Thermoforming workflow (Operator App, Roll Worker App, Palletizing App).

The project today is a **blank Flutter scaffold** (`lib/main.dart` boilerplate counter, no Riverpod, no Dio, no domain code). This plan rebuilds it as a production-grade Arabic RTL app following the requirements doc (V67 + V68 backend).

---

## 2. Architecture decisions

### Mandatory stack

- **Riverpod 2** with `AsyncNotifier` / `Notifier` (riverpod_generator code-gen).
- **Freezed** sealed states for all controllers.
- **json_serializable** DTOs (one per backend response).
- **Dio** API layer with interceptors (X-Device-Key, X-Session-Token).
- **flutter_secure_storage** for session tokens, **keyed per shiftLineId**.
- **Clean Architecture** per feature: `data/` (api + repo impl + dto), `domain/` (entities + repo interface), `presentation/` (controllers + screens + widgets).
- **Repository pattern**: controllers depend on repository interfaces, not Dio directly.
- **Backend is source of truth**: never fake mounted roll, active line, product switch, or session locally beyond response-cache.

### Disallowed

- `ChangeNotifier` for business state, single global `Provider`, GetX, `setState` for anything non-trivial.

### Routing

Use `go_router` for declarative, type-safe routes (consistent with most production Flutter apps; preserves deep-link semantics).

### Decisions made with the user

| Topic | Decision | Why |
|---|---|---|
| Shift-line picker (BACKEND GAP §7) | **Pure blocked waiting state** — no way past until backend ships `GET /shift-lines/active-options`. No `STATIC_SHIFT_LINE_ID`, no manual entry. | User: production-safe blocked is the right answer. |
| Product-switch product list (BACKEND GAP §11) | **Block entirely** with a clear waiting-for-backend message; hide the product-switch action button on home until backend ships `/product-switch-options`. | User: do not hardcode lists; do not call generic `/product-types`. |
| Printer integration (Stage 8) | **Inspect `roll_production_app` first** (read-only), document findings in this plan, then propose preview-only vs physical-printing path. **Wait for approval before any printer code.** | User: roll_production_app is the reference; do not modify it; do not depend on it via path. |
| Review cadence | **Stage-by-stage approval**: after each stage run `dart format`, `flutter analyze`, tests, forbidden-API grep, `git status`, summarize, wait for approval. | Production app — must catch wrong UX/architecture early. |

---

## 3. Folder structure

```
lib/
  main.dart                 # bootstrap + ProviderScope
  app/
    app.dart                # MaterialApp.router + RTL + theme
    router.dart             # go_router configuration
  core/
    config/
      app_config.dart       # String.fromEnvironment(API_BASE_URL, DEVICE_KEY)
    api/
      api_client.dart       # Dio instance factory
      device_key_interceptor.dart
      session_token_interceptor.dart
      response_envelope.dart   # {success, data} parser
      api_error_parser.dart    # parses {success:false, error:{code,message}}
    errors/
      app_failure.dart      # sealed: NetworkFailure | ServerFailure | BusinessFailure
      error_code.dart       # enum mirroring backend codes
      error_messages_ar.dart
    storage/
      secure_token_storage.dart   # key: roll_worker_session_token_{shiftLineId}
    theme/
      app_colors.dart
      app_text_styles.dart
      app_theme.dart        # ThemeData (green primary, orange accent, RTL-aware)
    widgets/
      app_card.dart
      app_primary_button.dart
      app_secondary_button.dart
      info_row.dart
      pin_field.dart
      empty_state_view.dart
      inline_error.dart
      loading_button.dart
      connectivity_banner.dart
      app_scaffold.dart     # standard app bar + connectivity strip
  features/
    config_check/
      presentation/
        missing_config_screen.dart   # إعدادات التطبيق غير مكتملة...
    shift_line/
      data/
        shift_line_api.dart          # only GET /roll-worker-session/current today
        shift_line_repository_impl.dart
        dto/
          roll_worker_session_response.dart
      domain/
        entities/active_shift_line.dart
        shift_line_repository.dart
      presentation/
        controllers/
          current_shift_line_controller.dart  # AsyncNotifier
          current_shift_line_state.dart        # Freezed
        screens/
          waiting_for_line_screen.dart        # blocked waiting state, 10s auto-refresh
        widgets/
          waiting_card.dart
    roll_worker_auth/
      data/
        roll_worker_auth_api.dart
        roll_worker_auth_repository_impl.dart
        dto/
          roll_worker_auth_response.dart
      domain/
        entities/roll_worker_session.dart
        roll_worker_auth_repository.dart
      presentation/
        controllers/
          roll_worker_auth_controller.dart   # AsyncNotifier
          roll_worker_auth_state.dart
        screens/
          pin_screen.dart
        widgets/
          pin_input.dart
    roll_scan/
      data/
        roll_scan_api.dart
        roll_scan_repository_impl.dart
        dto/
          thermoforming_roll_scan_response.dart
      domain/
        entities/mounted_roll.dart
        roll_scan_repository.dart
      presentation/
        controllers/
          roll_scan_controller.dart          # AsyncNotifier (mounted roll state)
          home_state_controller.dart         # combines session + mount + reprint flag
        screens/
          home_screen.dart
          scan_roll_screen.dart
        widgets/
          mount_card.dart
          empty_mount_card.dart
          qr_scanner_view.dart
          manual_roll_input_dialog.dart
    previous_roll/
      data/
        previous_roll_api.dart
        previous_roll_repository_impl.dart
        dto/
          previous_roll_resolution_response.dart
      domain/
        previous_roll_repository.dart
      presentation/
        controllers/
          previous_roll_resolution_controller.dart
          previous_roll_resolution_state.dart
        widgets/
          close_previous_roll_dialog.dart
          remaining_weight_input.dart
          full_consume_confirm_dialog.dart
          grinding_confirm_dialog.dart
          return_confirm_dialog.dart
    product_switch/
      presentation/
        screens/
          product_switch_blocked_screen.dart  # backend gap UI; no API calls
    label_reprint/
      data/
        label_reprint_api.dart
        label_reprint_repository_impl.dart
        dto/
          roll_label_reprint_response.dart
      domain/
        roll_label_reprint_repository.dart
      presentation/
        controllers/
          roll_label_reprint_controller.dart
          roll_label_reprint_state.dart
        screens/
          label_preview_screen.dart           # render-only; printer comes after Stage 8 inspection
        widgets/
          label_sticker_widget.dart           # visual sticker matches original layout
          reprint_button.dart
test/
  ... mirrors lib/ tree for unit tests
```

---

## 4. Backend gaps and blocked-UI behavior

| Gap | Behavior in this app |
|---|---|
| `GET /shift-lines/active-options` (§7) | **Pure blocked state.** `WaitingForLineScreen` shows centered card: `لا يوجد خط تشكيل نشط حاليًا، انتظر بدء المناوبة من المشغّل` + retry button. Auto-refresh every 10s. **No** manual entry, **no** STATIC_SHIFT_LINE_ID. App is non-functional until backend ships endpoint. |
| `GET /current-roll` (§13) | After a successful scan, persist response in `RollScanState`. On cold-start with no cached state, show `لا يوجد رول مركّب حاليًا`. First close-flow attempt will surface `NO_ACTIVE_ROLL_ON_LINE` if line is empty. |
| `GET /product-switch-options` (§11) | **Hide the product-switch action** on home. The product-switch route renders `ProductSwitchBlockedScreen` with: `تغيير المنتج غير متاح حاليًا — بانتظار دعم الخادم`. Make zero API calls in this flow. |
| Print-attempt logging (§12) | No-op. Reprint endpoint is idempotent; rely on backend-side audit when added. |
| SSE/live state (§19) | Polling fallback: 15s on home, 10s on waiting screen. Pause on dispose/background. |

---

## 5. Forbidden APIs (CI grep — fail build on hit)

This app must contain ZERO occurrences of:

```
/api/v1/thermoforming-app/auth/operator-pin
/api/v1/thermoforming-app/shifts/start
/api/v1/thermoforming-app/shifts/current
/api/v1/thermoforming-app/shifts/{shiftId}/end
/api/v1/thermoforming-app/shifts/{shiftId}/lines
/api/v1/thermoforming-app/shifts/{shiftId}/notes
/api/v1/thermoforming-app/shift-lines/{shiftLineId}/end
/api/v1/thermoforming-app/my-production
/api/v1/palletizing-line/lines/{lineId}/palletizer-auth
/api/v1/palletizing-line/lines/{lineId}/palletizer-session/current
/api/v1/palletizing-line/lines/{lineId}/palletizer-logout
/api/v1/palletizing-line/lines/{lineId}/pallets
create-pallet
authorize-pin
select-product
```

Plus pre-V67 paths under `/thermoforming-app/shift-lines/.../scan-roll`, `/previous-roll/*`, `/product-switch`, `/rolls/{id}/reprint-label` (all moved to `/thermoforming-roll-app/...`).

Grep command run after each stage:

```bash
grep -rE "thermoforming-app/(auth|shifts|shift-lines|my-production)|palletizing-line/lines|create-pallet|authorize-pin|select-product" lib/
# expected: zero hits
```

---

## 6. Allowed endpoints (the only ones this app calls)

| Purpose | Method | Path | Headers | Body |
|---|---|---|---|---|
| Roll-worker auth | POST | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-auth` | `X-Device-Key` | `{pin}` |
| Get current session | GET | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-session/current` | `X-Device-Key` | — |
| Logout | POST | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-logout` | `X-Device-Key` | `{sessionToken}` (in body) |
| Scan/mount roll | POST | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/scan-roll` | `X-Device-Key`, `X-Session-Token` | `{generatedRollId}` |
| Full-consume | POST | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/previous-roll/full-consume` | both | — |
| Return remaining | POST | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/previous-roll/return` | both | `{remainingWeightKg}` |
| Send to grinding | POST | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/previous-roll/grinding` | both | `{remainingWeightKg}` |
| Product switch | POST | `/api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/product-switch` | both | `{newProductTypeId, currentRollWeightKg}` | (NOT CALLED — backend gap; flow blocked in UI) |
| Reprint label | GET | `/api/v1/thermoforming-roll-app/rolls/{generatedRollId}/reprint-label` | both | — |

---

## 7. Token handling

- **Storage key**: `roll_worker_session_token_{shiftLineId}` via `flutter_secure_storage`.
- **Read once at boot**, expose as a Riverpod `FutureProvider`.
- **Never log** the token, PIN, or `DEVICE_KEY`. Dio request/response logger must redact `X-Device-Key`, `X-Session-Token` headers and `pin`/`sessionToken` body fields.
- **Clear token** on: logout success, any `ROLL_WORKER_SESSION_REQUIRED` (400/401/403/404), cascade-on-end, user reset.
- **Logout sends token in body** (not header), per backend convention.
- `X-Session-Token` header sent on: scan-roll, previous-roll/*, product-switch, reprint-label.
- `X-Session-Token` NOT sent on: roll-worker-auth (login), roll-worker-session/current (discovery), roll-worker-logout (token in body).

---

## 8. Riverpod providers / notifiers

| Provider | Type | Owns |
|---|---|---|
| `appConfigProvider` | `Provider<AppConfig>` | API_BASE_URL, DEVICE_KEY (or null → missing-config screen) |
| `dioProvider` | `Provider<Dio>` | configured Dio instance |
| `secureStorageProvider` | `Provider<SecureTokenStorage>` | wrapper over flutter_secure_storage |
| `connectivityStreamProvider` | `StreamProvider<bool>` | online/offline banner |
| `selectedShiftLineIdProvider` | `Notifier<int?>` | currently picked shift-line (null until backend ships picker) |
| `currentShiftLineControllerProvider(shiftLineId)` | `AsyncNotifierFamily` | session discovery via `GET /current` |
| `rollWorkerSessionTokenProvider(shiftLineId)` | `FutureProviderFamily` | reads token from secure storage |
| `rollWorkerAuthControllerProvider(shiftLineId)` | `AsyncNotifierFamily` | login + logout |
| `rollScanControllerProvider(shiftLineId)` | `AsyncNotifierFamily` | scan-roll + mounted-roll cache |
| `homeStateControllerProvider(shiftLineId)` | `NotifierFamily` | combines session + mount + last close response |
| `previousRollResolutionControllerProvider(shiftLineId)` | `AsyncNotifierFamily` | full-consume / return / grinding |
| `rollLabelReprintControllerProvider` | `AsyncNotifier` | reprint endpoint + sticker payload |
| `homePollerProvider(shiftLineId)` | `Provider` | 15s polling on home, pause on dispose |

---

## 9. Stages

After each stage: run `dart format --set-exit-if-changed .`, `flutter analyze`, relevant tests, forbidden-API grep, `git status`, summary. **Wait for approval before commit and before next stage.** No pushing.

### Stage 1 — Project setup, dependencies, RTL theme, smoke screen

- [ ] Update `pubspec.yaml`: add `flutter_riverpod`, `riverpod_annotation`, `freezed_annotation`, `json_annotation`, `dio`, `flutter_secure_storage`, `mobile_scanner`, `connectivity_plus`, `go_router`, `intl`. Dev deps: `build_runner`, `riverpod_generator`, `freezed`, `json_serializable`, `mocktail`, `flutter_lints`.
- [ ] Update `analysis_options.yaml` with strict rules.
- [ ] `android/app/src/main/AndroidManifest.xml`: add INTERNET + CAMERA permissions; set proper `applicationId` to `ps.taleeb.thermoforming_roll_worker`.
- [ ] `ios/Runner/Info.plist`: add `NSCameraUsageDescription` (Arabic).
- [ ] `lib/core/theme/app_colors.dart`, `app_text_styles.dart`, `app_theme.dart` — green primary `#2D8A5E`, orange accent `#FF9C00`, off-white scaffold, rounded cards, large bold buttons. Match `docs/desing_system_needed_examples/image.png`.
- [ ] `lib/core/widgets/`: AppCard, AppPrimaryButton, AppSecondaryButton, InfoRow, EmptyStateView, InlineError, LoadingButton, AppScaffold.
- [ ] `lib/main.dart`: `ProviderScope` + `MaterialApp` with `Directionality.rtl`, `Locale('ar')`, theme.
- [ ] `lib/app/app.dart` + `lib/app/router.dart` (placeholder routes).
- [ ] Smoke screen showing "تطبيق عامل الرولات" with one card and one primary button to validate theme + RTL.
- [ ] Add a `test/widget_smoke_test.dart` that pumps the app and asserts the smoke screen renders.
- [ ] Verify: `flutter analyze` clean, `dart format` clean, smoke test passes, forbidden grep zero.

### Stage 2 — Core API/config/storage/errors

- [ ] `core/config/app_config.dart`: read `API_BASE_URL` and `DEVICE_KEY` via `String.fromEnvironment`. Empty/missing → `AppConfig.missing()`.
- [ ] `MissingConfigScreen` with `إعدادات التطبيق غير مكتملة، يرجى التواصل مع المسؤول`. Wired in router as the boot gate.
- [ ] `core/api/api_client.dart`: factory that builds Dio with `baseUrl` + interceptors. Logger redacts secrets.
- [ ] `device_key_interceptor.dart`: appends `X-Device-Key` to every request.
- [ ] `session_token_interceptor.dart`: appends `X-Session-Token` if request `extra['requireSessionToken'] == true`. Token resolved from secure storage via `shiftLineId` passed in extras.
- [ ] `core/api/response_envelope.dart`: parses `{success, data}` envelope.
- [ ] `core/api/api_error_parser.dart`: parses `{success:false, error:{code, message}}` → `AppFailure`.
- [ ] `core/errors/error_code.dart`: enum mirroring backend codes (ROLL_WORKER_NOT_ALLOWED, ROLL_WORKER_SESSION_REQUIRED, THERMOFORMING_SHIFT_LINE_NOT_FOUND, THERMOFORMING_SHIFT_LINE_NOT_ACTIVE, NO_CURRENT_PRODUCT_ON_LINE, ROLL_NOT_FOUND, ROLL_ALREADY_CONSUMED, ROLL_ACTIVE_ON_ANOTHER_LINE, ROLL_BLOCKED, ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT, NO_ACTIVE_ROLL_ON_LINE, NO_OPEN_SEGMENT_ON_ITEM, INVALID_REMAINING_ROLL_WEIGHT, CURRENT_ROLL_WEIGHT_REQUIRED, INVALID_CURRENT_ROLL_WEIGHT, ROLL_LABEL_REPRINT_NOT_AVAILABLE, OPERATOR_PIN_INVALID, OPERATOR_PIN_LOCKED, PRODUCT_TYPE_NOT_FOUND, PRODUCT_TYPE_INACTIVE, VALIDATION_ERROR).
- [ ] `core/errors/app_failure.dart`: sealed `NetworkFailure`, `ServerFailure`, `BusinessFailure(code, message?)`.
- [ ] `core/errors/error_messages_ar.dart`: code → Arabic message map (per requirements §17).
- [ ] `core/storage/secure_token_storage.dart`: read/write/delete keyed by `shiftLineId`.
- [ ] `core/widgets/connectivity_banner.dart`: subscribes to `connectivityStreamProvider`, shows top strip `لا يوجد اتصال بالخادم، سيتم إعادة المحاولة تلقائيًا`.
- [ ] Unit tests: error parser, error mapping, secure storage round-trip, missing-config gate.

### Stage 3 — Roll worker auth (PIN flow)

- [ ] DTOs (Freezed + json_serializable): `RollWorkerAuthResponse`, `RollWorkerSessionResponse`.
- [ ] `RollWorkerAuthRepository` interface + impl using Dio + `ApiErrorParser`.
- [ ] `RollWorkerAuthController(shiftLineId)` AsyncNotifier with `login(pin)`, `logout()` methods. Stores token via `SecureTokenStorage` on success.
- [ ] `PinScreen`: title `تسجيل دخول عامل الرولات`, numeric PIN input (4 digits), button `دخول`, inline error mapped from BusinessFailure code.
- [ ] After login → navigate to home for that shiftLineId.
- [ ] Errors mapped: ROLL_WORKER_NOT_ALLOWED, OPERATOR_PIN_INVALID, OPERATOR_PIN_LOCKED, THERMOFORMING_SHIFT_LINE_NOT_ACTIVE, etc.
- [ ] Unit tests: controller success path, NOT_ALLOWED rejection (no token stored), pin-invalid (no token stored).

### Stage 4 — Shift-line waiting screen + session discovery

- [ ] `WaitingForLineScreen`: centered RTL card `لا يوجد خط تشكيل نشط حاليًا، انتظر بدء المناوبة من المشغّل` + retry button. Lives at app root after config check.
- [ ] **Until backend ships `/active-options`**: this screen is the entry point. The retry button is the only action; the `selectedShiftLineIdProvider` stays null. Document gap inline.
- [ ] `CurrentShiftLineController(shiftLineId)`: discovery via `GET /roll-worker-session/current`. Drives router decisions: 200 ACTIVE → home; 404 SESSION_REQUIRED → PIN; non-ACTIVE → PIN; 5xx → connectivity banner.
- [ ] When `selectedShiftLineIdProvider` is set (today: never, until backend gap closes), router routes to PIN or home.
- [ ] Cascade-on-end handler: on `ROLL_WORKER_SESSION_REQUIRED` from any mutation, clear token + snackbar `تم إنهاء خط التشكيل، يُرجى تسجيل الدخول مجددًا عند فتح خط جديد` + route to waiting screen.
- [ ] Auto-refresh every 10s on waiting screen; pause on dispose.

### Stage 5 — Roll scan / mount

- [ ] DTO `ThermoformingRollScanResponse`.
- [ ] `RollScanRepository` + `RollScanController(shiftLineId)`.
- [ ] `mobile_scanner` integration in `QrScannerView`.
- [ ] `ManualRollInputDialog`: 12-digit numeric input with format validation `^\d{12}$`.
- [ ] `HomeScreen`: shows `EmptyMountCard` (no roll) or `MountCard` (with current product, current generatedRollId, state, lastKnownWeightKg). Primary buttons: `تركيب رول جديد`, `إغلاق الرول السابق`, (`تغيير المنتج` hidden — see Stage 7 blocked screen).
- [ ] `ScanRollScreen`: camera + manual fallback. Reject if session token null (route to PIN).
- [ ] Success snackbar `تم تركيب الرول بنجاح`; mount card refresh.
- [ ] Errors mapped: NO_CURRENT_PRODUCT_ON_LINE, ROLL_NOT_FOUND, ROLL_ALREADY_CONSUMED, ROLL_ACTIVE_ON_ANOTHER_LINE, ROLL_BLOCKED, ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT.
- [ ] Duplicate-submit guard.
- [ ] Tests: scan success, ROLL_NOT_FOUND inline, session-required → clear token.

### Stage 6 — Previous-roll resolution (full-consume / return / grinding)

- [ ] DTO `ThermoformingPreviousRollResolutionResponse`.
- [ ] `PreviousRollRepository` + `PreviousRollResolutionController`.
- [ ] `ClosePreviousRollDialog` with three actions: `استهلاك كامل`, `إرجاع المتبقي`, `إرسال المتبقي للجرش`.
- [ ] `FullConsumeConfirmDialog`: `هل تم استهلاك الرول بالكامل؟` → POST full-consume.
- [ ] `ReturnConfirmDialog`: `RemainingWeightInput` + bounds validation (≥ 0, ≤ open-segment startWeight from cached scan response). Inline error `لا يمكن أن يكون الوزن المتبقي أكبر من وزن بداية الرول`.
- [ ] `GrindingConfirmDialog`: same input + extra confirmation `سيتم إرسال هذه البقايا إلى خط الجرش، هل أنت متأكد؟`.
- [ ] On success: snackbar `تم إغلاق الرول`, update home state with `reprintAvailable` from response, surface reprint button if true.
- [ ] Errors mapped: NO_ACTIVE_ROLL_ON_LINE, NO_OPEN_SEGMENT_ON_ITEM, INVALID_REMAINING_ROLL_WEIGHT.
- [ ] Duplicate-submit guard on every dialog confirm.
- [ ] Tests: each flow happy path + bounds-validation rejection.

### Stage 7 — Product switch (BLOCKED — backend gap)

- [ ] `ProductSwitchBlockedScreen`: `تغيير المنتج غير متاح حاليًا — بانتظار دعم الخادم`. No API calls.
- [ ] Hide the `تغيير المنتج` action button on `HomeScreen` so workers don't reach a dead screen by accident; if forced via deep-link, show the blocked screen.
- [ ] Document the gap in this plan + leave a TODO marker pointing at requirements §11 / §24 gap #2.
- [ ] No code under `features/product_switch/data/` until the backend ships `/product-switch-options`.

### Stage 8 — Roll label reprint

**Phase 8a — Inspect roll_production_app printer pipeline (READ-ONLY)**

- [ ] Inspect `roll_production_app/`:
  - printer-related packages in its `pubspec.yaml`
  - printer settings screen and persistence model
  - label size / preset management
  - QR roll label widget layout
  - command generation (TSPL/ZPL/ESC-POS) if any
  - Bluetooth/network connection pattern
  - retry / success / failure UX
- [ ] Append a section to this plan: **"Printer reference findings"** — list every file inspected with one-line summary + propose preview-only vs physical-printing.
- [ ] **Wait for user approval** before any printer code in this app.
- [ ] **Do not** modify roll_production_app, **do not** add path dependency, **do not** copy files wholesale; copy only minimal pieces, adapted to Riverpod + Clean Architecture.

**Phase 8b — Implementation (post-approval)**

- [ ] DTO `RollLabelReprintResponse`.
- [ ] `LabelReprintRepository` + `RollLabelReprintController`.
- [ ] `ReprintButton` shown only when `reprintAvailable: true` from upstream close response.
- [ ] Tap → confirmation `هل تريد إعادة طباعة ليبل هذا الرول؟` → call endpoint.
- [ ] `LabelStickerWidget`: matches original label layout. QR encodes `generatedRollId` literally. Badge: `إعادة طباعة بعد الإرجاع` or `إعادة طباعة قبل الجرش`. `lastKnownWeightKg` prominent.
- [ ] `LabelPreviewScreen`: renders sticker.
- [ ] Physical print path TBD per Phase 8a outcome.
- [ ] Errors mapped: ROLL_LABEL_REPRINT_NOT_AVAILABLE → hide button + refresh state.

### Stage 9 — Lifecycle, polling, polish, final verification

- [ ] App-resume refresh: `WidgetsBindingObserver` triggers `CurrentShiftLineController` refresh.
- [ ] Home screen polling: 15s while foregrounded; pause on dispose/background.
- [ ] Connectivity banner integrated globally.
- [ ] Duplicate-submit guards audited on every mutating button.
- [ ] Final forbidden-API grep zero hits.
- [ ] `flutter analyze` zero issues, `dart format --set-exit-if-changed .` clean.
- [ ] All tests pass.
- [ ] README.md updated with `--dart-define` build instructions.
- [ ] Manual E2E checklist (per requirements §21) walked through.

---

## 10. Verification per stage

After each stage, the assistant MUST report:

1. `dart format --set-exit-if-changed .` result
2. `flutter analyze` result
3. Any added/changed test results
4. Forbidden-API grep result (must be zero)
5. `git status` (show new/modified files)
6. One-line summary per changed file
7. Any backend gap or blocked state introduced
8. Wait for user approval before commit and before next stage

---

## 11. Acceptance criteria (from requirements §20)

Roll-up tracking — must all be `true` at end of Stage 9:

- [ ] Roll worker can select an active shift-line safely (production-grade picker — blocked state until backend ships)
- [ ] Roll worker can log in with PIN
- [ ] Unauthorized roll worker rejected inline; never gets a token
- [ ] No active shift-line → clear waiting state, no further interaction
- [ ] Token storage keyed per shiftLineId
- [ ] Roll worker can scan / mount compatible roll
- [ ] Scan blocked when session missing (no network call)
- [ ] Current product + roll state + lastKnownWeight visible on mount card
- [ ] Full-consume / return / grinding flows work with bounds validation
- [ ] Reprint button shows only when `reprintAvailable: true`
- [ ] Reprint endpoint returns canonical sticker payload; widget matches original layout
- [ ] Product switch blocked until backend ships endpoint
- [ ] App never starts/ends shifts, never opens/closes lines, never creates pallets
- [ ] Arabic / RTL correct everywhere; visual rhythm matches sibling apps
- [ ] App resume refreshes state; offline banner works; duplicate submits prevented
- [ ] No raw PIN, sessionToken, or DEVICE_KEY in logs/crashes/analytics
- [ ] CI grep on forbidden endpoint paths returns zero hits
