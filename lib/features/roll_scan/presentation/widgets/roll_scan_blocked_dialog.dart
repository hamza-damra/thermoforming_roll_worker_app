import 'package:flutter/material.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/util/arabic_datetime.dart';
import '../../../../core/widgets/app_primary_button.dart';

/// The scan/mount rejections that get a dedicated dialog instead of a generic
/// snackbar: grinding-recommended, already-consumed, admin-cancelled (V127),
/// and reconciled-out-of-inventory (V132). Each is terminal for mounting — the
/// dialog acknowledges only, it never offers a retry of the rejected roll.
enum RollScanBlockedKind {
  grinding,
  consumed,
  adminCancelled,
  reconciledOutOfStock,
}

/// Structured fields parsed from the rejection's `error.details`. Every field
/// is optional — the backend may omit any of them — so the dialog guards each
/// row individually and never renders an ugly placeholder for a missing value.
class ScanBlockedDetails {
  const ScanBlockedDetails({
    this.rollNumber,
    this.displayStatusLabel,
    this.workerName,
    this.workerReasonText,
    this.remainingWeightKg,
    this.recommendedAt,
    this.consumedAt,
    this.cancelledBy,
    this.cancelReason,
    this.cancelledAt,
    this.message,
  });

  final String? rollNumber;
  final String? displayStatusLabel;
  final String? workerName;
  final String? workerReasonText;
  final double? remainingWeightKg;
  final DateTime? recommendedAt;
  final DateTime? consumedAt;
  final String? cancelledBy;
  final String? cancelReason;
  final DateTime? cancelledAt;

  /// Backend-authored message inside `details.message`. Preferred over the
  /// static per-kind message when present.
  final String? message;

  /// Parses the [BusinessFailure.details] map defensively. Unknown / wrongly
  /// typed entries collapse to `null` rather than throwing.
  factory ScanBlockedDetails.fromFailure(BusinessFailure failure) {
    final Map<String, Object?>? d = failure.details;
    return ScanBlockedDetails(
      rollNumber: _str(d?['rollNumber']),
      displayStatusLabel: _str(d?['displayStatusLabel']),
      workerName: _str(d?['workerName']),
      workerReasonText: _str(d?['workerReasonText']),
      remainingWeightKg: _dbl(d?['remainingWeightKg']),
      recommendedAt: tryParseTimestamp(d?['recommendedAt']),
      consumedAt: tryParseTimestamp(d?['consumedAt']),
      cancelledBy: _str(d?['cancelledBy']),
      cancelReason: _str(d?['cancelReason']),
      cancelledAt: tryParseTimestamp(d?['cancelledAt']),
      message: _str(d?['message']),
    );
  }

  static String? _str(Object? v) {
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }

  static double? _dbl(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }
}

/// Shows the appropriate blocked-roll dialog for [kind], built from [failure]'s
/// structured `details`. Centered modal, matches the app theme / RTL.
Future<void> showRollScanBlockedDialog(
  BuildContext context, {
  required RollScanBlockedKind kind,
  required BusinessFailure failure,
  Color? accent,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => _RollScanBlockedDialog(
      kind: kind,
      details: ScanBlockedDetails.fromFailure(failure),
      accent: accent,
    ),
  );
}

class _RollScanBlockedDialog extends StatelessWidget {
  const _RollScanBlockedDialog({
    required this.kind,
    required this.details,
    this.accent,
  });

  final RollScanBlockedKind kind;
  final ScanBlockedDetails details;

  /// Active line accent for the OK button. The header icon keeps its semantic
  /// color (warning / error).
  final Color? accent;

  static const String _ok = 'حسنًا';

  // ── Per-kind copy ─────────────────────────────────────────────────────────
  static const String _grindingTitle = 'الرول موصى بالجرش';
  static const String _grindingMessage =
      'هذا الرول موصى بالجرش ولا يمكن تركيبه كمتبقي صالح.';
  static const String _grindingGuidance =
      'إذا كنت تعتقد أن هذا الرول صالح للاستهلاك الآن، تواصل مع م. حمزه ضمره '
      'لتعديل حالة الرول لتتمكن من استهلاكه.';

  static const String _consumedTitle = 'الرول مستهلك بالكامل';
  static const String _consumedMessage = 'هذا الرول مستهلك بالكامل.';
  static const String _consumedGuidance =
      'إذا كان الرول غير مستهلك فعليًا ويحتاج تعديلًا، تواصل مع الإدارة.';

  static const String _cancelledTitle = 'الرول ملغى';
  static const String _cancelledMessage =
      'تم إلغاء هذا الرول من الإدارة ولا يمكن تركيبه.';

  // Reconciled out of physical inventory (V132). The backend sends
  // `details: null` for this code, so this static copy — not a server-authored
  // `details.message` — is what the worker actually reads.
  static const String _reconciledTitle = 'الرول مُسوّى مخزونياً';
  static const String _reconciledMessage =
      'تمت تسوية هذا الرول مخزونياً ولا يمكن تركيبه.';
  static const String _reconciledGuidance =
      'إذا كان الرول موجودًا فعليًا لديك، تواصل مع الإدارة لتصحيح حالته '
      'المخزونية.';

  static const String _reasonLabel = 'سبب التوصية';

  String get _title => switch (kind) {
    RollScanBlockedKind.grinding => _grindingTitle,
    RollScanBlockedKind.consumed => _consumedTitle,
    RollScanBlockedKind.adminCancelled => _cancelledTitle,
    RollScanBlockedKind.reconciledOutOfStock => _reconciledTitle,
  };

  /// Prefer the backend-authored `details.message`; fall back to the static
  /// per-kind sentence so the dialog always has a clear message.
  String get _message {
    final String? backend = details.message;
    if (backend != null) return backend;
    return switch (kind) {
      RollScanBlockedKind.grinding => _grindingMessage,
      RollScanBlockedKind.consumed => _consumedMessage,
      RollScanBlockedKind.adminCancelled => _cancelledMessage,
      RollScanBlockedKind.reconciledOutOfStock => _reconciledMessage,
    };
  }

  String? get _guidance => switch (kind) {
    RollScanBlockedKind.grinding => _grindingGuidance,
    RollScanBlockedKind.consumed => _consumedGuidance,
    RollScanBlockedKind.adminCancelled => null,
    RollScanBlockedKind.reconciledOutOfStock => _reconciledGuidance,
  };

  Color get _semanticColor => switch (kind) {
    RollScanBlockedKind.grinding => AppColors.warning,
    RollScanBlockedKind.consumed => AppColors.error,
    RollScanBlockedKind.adminCancelled => AppColors.error,
    RollScanBlockedKind.reconciledOutOfStock => AppColors.error,
  };

  IconData get _icon => switch (kind) {
    RollScanBlockedKind.grinding => Icons.recycling_rounded,
    RollScanBlockedKind.consumed => Icons.do_not_disturb_on_outlined,
    RollScanBlockedKind.adminCancelled => Icons.block_rounded,
    RollScanBlockedKind.reconciledOutOfStock => Icons.inventory_2_outlined,
  };

  List<_DetailRow> get _rows {
    final String? weight = details.remainingWeightKg != null
        ? '${details.remainingWeightKg!.toStringAsFixed(3)} كغ'
        : null;
    return switch (kind) {
      RollScanBlockedKind.grinding => <_DetailRow>[
        _DetailRow('رقم الرول', details.rollNumber),
        _DetailRow('العامل الذي أوصى بالجرش', details.workerName),
        _DetailRow('وقت التوصية', formatArabicDateTime(details.recommendedAt)),
        _DetailRow('الوزن المتبقي', weight),
      ],
      RollScanBlockedKind.consumed => <_DetailRow>[
        _DetailRow('رقم الرول', details.rollNumber),
        _DetailRow('العامل', details.workerName),
        _DetailRow('وقت الاستهلاك', formatArabicDateTime(details.consumedAt)),
      ],
      RollScanBlockedKind.adminCancelled => <_DetailRow>[
        _DetailRow('رقم الرول', details.rollNumber),
        _DetailRow('ألغاه', details.cancelledBy),
        _DetailRow('وقت الإلغاء', formatArabicDateTime(details.cancelledAt)),
        _DetailRow('سبب الإلغاء', details.cancelReason),
      ],
      // V132 sends no `details`, so this row is filtered out below and the
      // container is skipped entirely. Kept so the roll number renders for
      // free if the backend ever starts echoing it.
      RollScanBlockedKind.reconciledOutOfStock => <_DetailRow>[
        _DetailRow('رقم الرول', details.rollNumber),
      ],
    }
        .where((_DetailRow r) => r.value != null)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final List<_DetailRow> rows = _rows;
    // The recommender's free-text note is rendered as its own card (grinding
    // only) so it stands out under factory pressure.
    final String? reasonNote = kind == RollScanBlockedKind.grinding
        ? details.workerReasonText
        : null;
    final String? guidance = _guidance;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _semanticColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, size: 32, color: _semanticColor),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _title,
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _message,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (rows.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < rows.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(height: 8),
                        rows[i],
                      ],
                    ],
                  ),
                ),
              ],
              if (reasonNote != null) ...<Widget>[
                const SizedBox(height: 12),
                _ReasonNoteCard(
                  label: _reasonLabel,
                  text: reasonNote,
                  accent: _semanticColor,
                ),
              ],
              if (guidance != null) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  guidance,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: _ok,
                color: accent,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A label + value row inside the muted detail container. Only constructed for
/// non-null values (the parent filters nulls out).
class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$label: ',
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            value ?? '',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Visually separated note card for the recommender's free-text reason — kept
/// distinct from the metadata rows so it is easy to read at a glance.
class _ReasonNoteCard extends StatelessWidget {
  const _ReasonNoteCard({
    required this.label,
    required this.text,
    required this.accent,
  });

  final String label;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.sticky_note_2_outlined, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
