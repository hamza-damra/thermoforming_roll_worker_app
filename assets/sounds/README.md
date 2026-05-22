# Takeover alert sound

`takeover_alert.mp3` is the sound played when a `LINE_TAKEOVER_REQUESTED`
event arrives (see `lib/core/services/takeover_alert_service.dart`).

The committed `takeover_alert.mp3` is a **placeholder** — it is not a valid
audio file. Replace it with a real, loud, attention-grabbing alert tone
(1–3 s, looping not required) before shipping.

The app does **not** crash if the asset is missing or invalid:
`TakeoverAlertService` catches the playback error and falls back to
`SystemSound.play(SystemSoundType.alert)`.
