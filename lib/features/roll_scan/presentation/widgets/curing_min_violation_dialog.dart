import 'package:flutter/material.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_primary_button.dart';

/// Blocking modal shown when the backend rejects a mount with
/// `ROLL_CURING_MINIMUM_NOT_MET` (HTTP 409). The mount did not happen and
/// the worker MUST acknowledge before the scan flow re-arms.
///
/// The body is composed entirely from our own Arabic copy plus the structured
/// `error.details` payload — the raw backend `message` (often English, e.g.
/// "Roll … has not met the minimum curing period (48h). Actual age: 45h") is
/// never surfaced to the operator. Uses the business term `الحضانة`.
Future<void> showCuringMinViolationDialog(
  BuildContext context, {
  required BusinessFailure failure,
  Color? accent,
  String? rollNumber,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => _CuringMinViolationDialog(
      failure: failure,
      accent: accent,
      rollNumber: rollNumber,
    ),
  );
}

class _CuringMinViolationDialog extends StatelessWidget {
  const _CuringMinViolationDialog({
    required this.failure,
    this.accent,
    this.rollNumber,
  });

  final BusinessFailure failure;

  /// Active line accent for the OK button (header icon stays the semantic
  /// error color).
  final Color? accent;

  /// Roll number sourced from the scanned value, when the screen has it.
  /// Falls back to `error.details` (`rollNumber` / `rollCode` / `rollId`).
  final String? rollNumber;

  static const String _title = 'لا يمكن تركيب الرول';

  /// Safe lead sentence used when we cannot identify the roll (no scanned value
  /// and no id in `error.details`). The operator still gets a fully-Arabic,
  /// professional message instead of the raw (often English) backend text.
  static const String _fallbackMessage =
      'هذا الرول لم يكمل مدة الحضانة الدنيا المطلوبة ولا يمكن تركيبه الآن.';
  static const String _guidance =
      'يرجى الانتظار حتى اكتمال مدة الحضانة ثم المحاولة مرة أخرى.';
  static const String _ok = 'حسنًا';

  /// The Arabic body lines, composed entirely from our own copy plus the
  /// structured `error.details` payload — never the raw backend `message`.
  ///
  /// Line 0 is the lead sentence: it names the roll when we know it (scanned
  /// value or `details`), otherwise the safe [_fallbackMessage]. The
  /// current-age and minimum-required lines are appended only when the backend
  /// supplied those numbers, so a sparse (or absent) details block degrades
  /// gracefully instead of crashing.
  List<String> _bodyLines() {
    final Map<String, Object?>? details = failure.details;
    final List<String> lines = <String>[];

    final String? roll = _rollNumber(details);
    lines.add(
      roll != null
          ? 'الرول $roll لم يكمل مدة الحضانة الدنيا المطلوبة.'
          : _fallbackMessage,
    );

    final String? actualHours = _formatHours(details?['actualAgeHours']);
    if (actualHours != null) lines.add('العمر الحالي: $actualHours ساعة.');

    final String? minHours = _formatHours(details?['minCuringHours']);
    if (minHours != null) lines.add('الحد الأدنى المطلوب: $minHours ساعة.');

    return lines;
  }

  String? _rollNumber(Map<String, Object?>? details) {
    final String? scanned = _nonEmpty(rollNumber);
    if (scanned != null) return scanned;
    return _nonEmpty(details?['rollNumber']?.toString()) ??
        _nonEmpty(details?['rollCode']?.toString()) ??
        _nonEmpty(details?['rollId']?.toString());
  }

  static String? _nonEmpty(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Renders a numeric hours value without a trailing `.0` (e.g. `48`, not
  /// `48.0`), and passes through any other non-null representation as-is.
  static String? _formatHours(Object? value) {
    if (value == null) return null;
    if (value is num) {
      return value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toString();
    }
    return _nonEmpty(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    final List<String> lines = _bodyLines();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text(_title, style: AppTextStyles.h3)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lines.first, style: AppTextStyles.body),
            if (lines.length > 1) ...[
              const SizedBox(height: 12),
              for (final String line in lines.skip(1))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line, style: AppTextStyles.body),
                ),
            ],
            const SizedBox(height: 12),
            Text(
              _guidance,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          AppPrimaryButton(
            label: _ok,
            color: accent,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
