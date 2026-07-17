/// Validation for the free-text reason captured on `إرجاع المتبقي` (return
/// remaining) and `توصية بالجرش` (recommend grinding) — V127.
///
/// Business rule (mirrors the backend): the reason is REQUIRED, trimmed, must
/// not be whitespace-only, and must not exceed 500 characters. There are no
/// predefined reasons / dropdowns — it is always free text.
class ReasonTextValidation {
  ReasonTextValidation._();

  /// Maximum allowed length after trimming (server-enforced too).
  static const int maxLength = 500;

  /// Shown when the field is empty or whitespace-only.
  static const String required = 'السبب مطلوب';

  /// Shown when the entered text exceeds [maxLength] characters.
  static const String tooLong = 'الحد الأقصى $maxLength حرف.';

  /// Returns the Arabic error for [rawText], or `null` when it is a valid
  /// reason (`non-blank` and `length <= maxLength` after trimming).
  static String? validate(String rawText) {
    final String text = rawText.trim();
    if (text.isEmpty) return required;
    if (text.length > maxLength) return tooLong;
    return null;
  }

  /// `true` when [rawText] is a valid, submittable reason.
  static bool isValid(String rawText) => validate(rawText) == null;
}
