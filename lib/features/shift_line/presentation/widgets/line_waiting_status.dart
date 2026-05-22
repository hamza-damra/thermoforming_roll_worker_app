import '../../domain/entities/roll_worker_bootstrap_line.dart';

/// Why a `/bootstrap` machine row is currently **not selectable**.
///
/// The Roll Worker app is passive: it never acts on a handover / takeover, it
/// only explains to the worker why a line cannot be started yet.
enum LineWaitingReason {
  /// No ACTIVE shift-line on the machine — no operator has taken it over.
  noActiveShift,

  /// A shift handover is in progress; the next operator has not yet taken
  /// the line.
  pendingHandover,

  /// A line-takeover request is being processed.
  takeover,

  /// Backend reports the row non-selectable for an unrecognised reason.
  unknown,
}

/// Pure mapping from a non-selectable [RollWorkerBootstrapLine] to the Arabic
/// copy shown in the picker (the status pill) and the blocking dialog.
///
/// Raw backend tokens (`NO_ACTIVE_SHIFT`, `PENDING_HANDOVER`,
/// `TAKEOVER_PENDING`, …) are deliberately never shown to the worker.
abstract final class LineWaitingStatus {
  // ─── Status-pill labels (picker rows) ──────────────────────────────────
  static const String pillNoActiveShift = 'بانتظار مشغّل';
  static const String pillPendingHandover = 'تسليم مناوبة';
  static const String pillTakeover = 'طلب استلام قيد المعالجة';
  static const String pillUnknown = 'غير متاح حالياً';

  // ─── Blocking-dialog copy ──────────────────────────────────────────────
  static const String dialogTitle = 'الخط غير جاهز حالياً';

  static const String dialogBodyDefault =
      'لا يوجد مشغّل مستلم لهذا الخط حالياً. يرجى الانتظار حتى يقوم المشغّل '
      'القادم باستلام الخط من تطبيق المشغّل.';
  static const String dialogBodyNoActiveShift =
      'لا يوجد مشغّل مستلم لهذا الخط حالياً.';
  static const String dialogBodyHandover =
      'الخط حالياً في مرحلة تسليم مناوبة. سيصبح متاحاً بعد استلام المشغّل '
      'القادم.';
  static const String dialogBodyTakeover =
      'يوجد طلب استلام خط قيد المعالجة. يرجى الانتظار حتى يكتمل الاستلام.';

  static const String dialogHelper =
      'يتم تحديث حالة الخط تلقائياً عند استلام المشغّل.';

  static const String dialogPrimaryAction = 'حسناً';
  static const String dialogRefreshAction = 'تحديث الحالة';

  /// Classifies a non-selectable row. Takeover outranks handover, which
  /// outranks "no active shift" — a machine mid-takeover may also report
  /// `NO_ACTIVE_SHIFT`, and the takeover copy is the more informative one.
  static LineWaitingReason reasonFor(RollWorkerBootstrapLine line) {
    final String status = line.lineLifecycleStatus.toUpperCase();
    final String blockedReason = (line.blockedReason ?? '').toUpperCase();
    final bool hasTakeover =
        (line.takeoverRequestStatus ?? '').trim().isNotEmpty;

    if (hasTakeover ||
        status.startsWith('TAKEOVER') ||
        blockedReason.startsWith('TAKEOVER')) {
      return LineWaitingReason.takeover;
    }
    if (line.handoverPending ||
        status == 'PENDING_HANDOVER' ||
        blockedReason == 'PENDING_HANDOVER') {
      return LineWaitingReason.pendingHandover;
    }
    if (status == 'NO_ACTIVE_SHIFT' || line.shiftLineId == null) {
      return LineWaitingReason.noActiveShift;
    }
    return LineWaitingReason.unknown;
  }

  /// Short Arabic label for the small status pill on a non-selectable row.
  static String pillLabelFor(RollWorkerBootstrapLine line) =>
      switch (reasonFor(line)) {
        LineWaitingReason.noActiveShift => pillNoActiveShift,
        LineWaitingReason.pendingHandover => pillPendingHandover,
        LineWaitingReason.takeover => pillTakeover,
        LineWaitingReason.unknown => pillUnknown,
      };

  /// Body copy for the blocking dialog.
  static String dialogBodyFor(RollWorkerBootstrapLine line) =>
      switch (reasonFor(line)) {
        LineWaitingReason.noActiveShift => dialogBodyNoActiveShift,
        LineWaitingReason.pendingHandover => dialogBodyHandover,
        LineWaitingReason.takeover => dialogBodyTakeover,
        LineWaitingReason.unknown => dialogBodyDefault,
      };

  /// `true` for handover / takeover states — the dialog uses a calm orange
  /// accent for those, and a reassuring green accent for plain waiting.
  static bool isWarningReason(RollWorkerBootstrapLine line) {
    final LineWaitingReason reason = reasonFor(line);
    return reason == LineWaitingReason.pendingHandover ||
        reason == LineWaitingReason.takeover;
  }
}
