import 'package:flutter/foundation.dart';

import '../../domain/entities/roll_label.dart';

/// Reprint state for one (shiftLineId, generatedRollId) pair. Sealed so
/// the UI must handle every branch via `switch`.
///
/// Stage 8 reshape: the controller is the full reprint orchestrator
/// (fetch + physical print). The blocking dialog reads this state.
@immutable
sealed class LabelReprintState {
  const LabelReprintState();
}

/// First-paint / no flow in progress.
class LabelReprintIdle extends LabelReprintState {
  const LabelReprintIdle();
}

/// Backend `GET /reprint-label` is in flight. UI shows a spinner with
/// the prescribed Arabic ("جاري تجهيز الليبل…").
class LabelReprintFetching extends LabelReprintState {
  const LabelReprintFetching();
}

/// Backend returned the canonical sticker payload but no print job has
/// fired yet. The preview screen renders from this state.
class LabelReprintReady extends LabelReprintState {
  const LabelReprintReady(this.label);
  final RollLabel label;
}

/// Physical TSPL job in flight against the configured printer. UI shows
/// a blocking progress dialog ("جاري إرسال الليبل للطابعة…").
class LabelReprintPrinting extends LabelReprintState {
  const LabelReprintPrinting(this.label);
  final RollLabel label;
}

/// Printer accepted the byte stream. We say "sent to the printer" — not
/// "physically printed" (no audit endpoint yet — see requirements
/// §24 gap #4).
class LabelReprintSent extends LabelReprintState {
  const LabelReprintSent(this.label);
  final RollLabel label;
}

/// Last attempt failed. Carries enough context for the dialog to render
/// the Arabic message and for the controller to retry the correct stage.
class LabelReprintFailureState extends LabelReprintState {
  const LabelReprintFailureState({
    required this.message,
    required this.generatedRollId,
    this.cachedLabel,
  });

  /// Arabic message to surface in the dialog.
  final String message;

  /// Original roll-id; used to retry the fetch when [cachedLabel] is null.
  final String generatedRollId;

  /// Present when the failure happened during the print stage. Retry can
  /// re-send this label without a new backend round-trip.
  final RollLabel? cachedLabel;

  bool get failedDuringPrint => cachedLabel != null;
  bool get failedDuringFetch => cachedLabel == null;
}
