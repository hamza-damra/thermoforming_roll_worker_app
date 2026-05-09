# Stage 8 Manual QA Report — Roll Worker App Physical Reprint

**Roll Worker app commit hash:** `a3ed2ff`
**Stage 8 scope:** Roll label reprint with direct physical printing (TSPL/socket pipeline).

> Fillable factory-floor template. Use `TODO` until a case has been executed.
> Do **not** edit the test steps or expected results — they correspond to commit `a3ed2ff`.
> Record actual outcomes inline. Save photos under `docs/qa/stage8/` and reference them by filename per case.
> Do **not** mark any case `PASS` or `FAIL` until it has actually been executed against real hardware.

---

## 1. Test session metadata

| Field | Value |
|---|---|
| Tester name | TODO |
| Test date / time (local timezone) | TODO |
| Backend environment | TODO (e.g. `staging`, `production`, hostname/IP) |
| Backend `GET /reprint-label` reachable | TODO (yes / no — confirm with a 200 response for the chosen roll) |
| Device manufacturer + model | TODO (e.g. Samsung Galaxy A14) |
| Device OS / version | TODO (e.g. Android 13) |
| App APK version / build ID | TODO |
| Printer manufacturer + model | TODO (e.g. Zebra ZD230, TSC TE200) |
| Printer firmware version | TODO |
| Printer IP address | TODO |
| Printer port | TODO (default `9100`) |
| Label stock size | TODO (e.g. 100 mm × 50 mm continuous, 75 mm × 50 mm with gap) |
| Label stock type | TODO (continuous / gap / black-mark) |
| `generatedRollId` under test | TODO (12-digit string) |
| Roll consumption state at test time | TODO (`PARTIALLY_RETURNED` or `SENT_TO_GRINDING`) |
| Worker PIN authenticated successfully | TODO (yes / no) |

---

## 2. Cross-cutting observations (one row per session)

| Observation | Result |
|---|---|
| Backend `GET /reprint-label` JSON matches printed sticker fields (top, bottom, side, QR) | TODO |
| QR code scans cleanly with a separate device on the first attempt | TODO |
| `generatedRollId` printed on the sticker matches backend `generatedRollId` exactly | TODO |
| Label alignment within stock margins (no clipping, no skew) | TODO |
| Spacing between successive stickers (gap detection / feed length correct) | TODO |
| Printer feed / cut / tear-off behavior | TODO |
| Text readability at arm's length (Arabic + Latin) | TODO |

---

## 3. Test cases

### Case 1 — Default printer happy path

**Preconditions**
- A printer is configured and marked default (Settings → الطابعات shows the "افتراضي" badge on the chosen printer).
- Worker is logged in with a valid session token.
- A closed-roll card with consumption state `PARTIALLY_RETURNED` or `SENT_TO_GRINDING` is visible on the home screen.

**Steps**
1. Locate the closed-roll card on the home screen.
2. Tap **إعادة طباعة الليبل** (primary button).

**Expected result**
- Blocking dialog appears immediately.
- Dialog text transitions: `جاري تجهيز الليبل…` → `جاري إرسال الليبل للطابعة…` → `تم إرسال الليبل للطابعة`.
- Final dialog has a single **إغلاق** button.
- A physical sticker prints with: QR = `generatedRollId`, top text = roll-type code + color, bottom = display name, side = `generatedRollId`.

**Observed result:** TODO
**Result:** TODO / PASS / FAIL
**Notes:** TODO
**Photo / screenshot reference:** TODO (e.g. `docs/qa/stage8/case1_sticker.jpg`)

---

### Case 2 — No printer configured

**Preconditions**
- All printers removed from Settings → الطابعات, OR no printer is marked default.
- Worker is logged in with a valid session token.
- A closed-roll card is visible on the home screen.

**Steps**
1. Tap **إعادة طباعة الليبل** on the closed-roll card.

**Expected result**
- The blocking print dialog does **not** appear.
- App navigates to the printer settings screen (`PrinterSettingsScreen`).
- After configuring a default printer and returning, re-tapping reprint behaves like Case 1.

**Observed result:** TODO
**Result:** TODO / PASS / FAIL
**Notes:** TODO
**Photo / screenshot reference:** TODO

---

### Case 3 — Printer unreachable + retry

**Preconditions**
- A default printer is configured but is **powered off** or **disconnected from the LAN** before the test starts.
- Worker is logged in.
- Closed-roll card visible.

**Steps**
1. Tap **إعادة طباعة الليبل**.
2. Wait for the dialog to surface a printer error.
3. Power the printer back on / reconnect to the LAN. Wait until it is pingable.
4. In the still-open dialog, tap **إعادة المحاولة**.

**Expected result**
- Step 2 ends with the dialog showing an Arabic printer error (e.g. `انتهت مهلة الاتصال بالطابعة` or `تعذّر الاتصال بالطابعة`) plus three buttons: **إعادة المحاولة** / **إعدادات الطباعة** / **إغلاق**.
- Step 4 transitions through `جاري إرسال الليبل للطابعة…` to `تم إرسال الليبل للطابعة` and the sticker prints.
- Backend access log shows **only one** `GET /reprint-label` call for the entire interaction (retry reused the cached label, no second backend round-trip).

**Observed result:** TODO
**Result:** TODO / PASS / FAIL
**Backend `GET /reprint-label` call count for this interaction:** TODO
**Notes:** TODO
**Photo / screenshot reference:** TODO

---

### Case 4 — Preview path + print

**Preconditions**
- Default printer configured.
- Worker logged in.
- Closed-roll card visible.

**Steps**
1. On the closed-roll card, tap the secondary **معاينة الليبل** text link (below the primary button).
2. Observe the preview screen.
3. On the preview screen, tap the print action.

**Expected result**
- Step 2 opens the preview screen with title `معاينة الليبل` and the sticker rendered inline (no print job fired yet).
- Step 3 surfaces the same blocking dialog used by Case 1, ending in `تم إرسال الليبل للطابعة`.
- Backend access log shows **only one** `GET /reprint-label` call total across steps 1–3 (the preview fetch is reused for printing — no double fetch).

**Observed result:** TODO
**Result:** TODO / PASS / FAIL
**Backend `GET /reprint-label` call count for this interaction:** TODO
**Notes:** TODO
**Photo / screenshot reference:** TODO

---

### Case 5 — Session loss / token expiry

**Preconditions**
- Default printer configured.
- Worker is logged in, but the session has been invalidated server-side (delete the session, or wait for natural expiry — whichever your environment supports).
- Closed-roll card visible (the card itself was loaded before invalidation).

**Steps**
1. Tap **إعادة طباعة الليبل**.

**Expected result**
- Dialog surfaces a session-required Arabic message (no physical print attempt is made).
- The locally stored session token for the active `shiftLineId` is cleared.
- The app returns the worker to the PIN screen.

**Observed result:** TODO
**Result:** TODO / PASS / FAIL
**Notes:** TODO
**Photo / screenshot reference:** TODO

---

### Case 6 — QR readability

**Preconditions**
- A sticker has been produced by Case 1 (and ideally also by Case 3 retry and Case 4 preview path).
- A separate scanning device is available (a second phone with a QR scanner app, or the factory's hand scanner).

**Steps**
1. Hold the scanner over the printed QR at a normal working distance (~15 cm).
2. Record whether the QR decodes on the first attempt.
3. Repeat for each printed sticker from Cases 1, 3, 4.

**Expected result**
- Every printed QR decodes to the exact `generatedRollId` on the first scan attempt, with no need to reposition or zoom.

**Observed result:** TODO
**Per-sticker scan outcomes:**
- Case 1 sticker: TODO
- Case 3 sticker: TODO
- Case 4 sticker: TODO

**Result:** TODO / PASS / FAIL
**Notes:** TODO
**Photo / screenshot reference:** TODO

---

### Case 7 — `generatedRollId` matches backend label data

**Preconditions**
- At least one sticker has been printed.
- The backend `GET /reprint-label` JSON response for the same `generatedRollId` is captured (server log, network sniffer, or device log).

**Steps**
1. Decode the printed QR.
2. Read the printed top / bottom / side text.
3. Compare every field against the backend JSON.

**Expected result**
- QR value == backend `generatedRollId`.
- Printed top text == backend `rollTypeRollCode` + ` ` + color.
- Printed bottom text == backend `rollTypeDisplayName`.
- Printed side text == backend `generatedRollId`.

**Observed result:**
- QR value: TODO
- Top text printed vs. backend: TODO
- Bottom text printed vs. backend: TODO
- Side text printed vs. backend: TODO

**Result:** TODO / PASS / FAIL
**Notes:** TODO
**Photo / screenshot reference:** TODO

---

### Case 8 — Label alignment / spacing / feed / readability

**Preconditions**
- A series of consecutive stickers from Cases 1, 3, 4 is available on the printer's output stack (do not separate them — keep the strip intact for inspection).

**Steps**
1. Inspect each sticker on the strip.
2. Measure or visually confirm: top/bottom margin, left/right margin, skew angle.
3. Inspect the gap / spacing between successive stickers.
4. Confirm the printer's tear-off / cut / feed-forward behavior at the end of each job.
5. Read every text element at arm's length under normal factory lighting.

**Expected result**
- All sticker content is fully within the printable area (no clipping at any edge).
- No visible skew (text and QR sit square to the stock).
- Spacing between successive stickers is consistent and matches the gap-detection / feed-length configured on the printer.
- The printer advances to a clean tear-off position after each job (no half-presented sticker on the next print).
- All Arabic and Latin text is legible at arm's length without leaning in.

**Observed result:**
- Margins: TODO
- Skew: TODO
- Spacing between stickers: TODO
- Feed / tear-off behavior: TODO
- Readability at arm's length: TODO

**Result:** TODO / PASS / FAIL
**Notes:** TODO
**Photo / screenshot reference:** TODO

---

## 4. Final release-readiness decision

| Field | Value |
|---|---|
| Overall decision | TODO (`READY FOR RELEASE` / `NOT READY`) |
| If NOT READY — primary blocker | TODO |
| Follow-up tickets / TODOs filed | TODO |
| Sign-off name | TODO |
| Sign-off date | TODO |
