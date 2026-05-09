import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../core/printing_constants.dart';
import '../../domain/entities/printer_config.dart';
import '../controllers/printer_settings_controller.dart';

/// Add or edit a printer. Returns the configured `PrinterConfig` via
/// `Navigator.pop` if the worker confirmed, or `null` on cancel.
Future<PrinterConfig?> showPrinterFormDialog(
  BuildContext context, {
  PrinterConfig? existing,
}) {
  return showDialog<PrinterConfig>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => _PrinterFormDialog(existing: existing),
  );
}

class _PrinterFormDialog extends ConsumerStatefulWidget {
  const _PrinterFormDialog({this.existing});

  final PrinterConfig? existing;

  @override
  ConsumerState<_PrinterFormDialog> createState() => _PrinterFormDialogState();
}

class _PrinterFormDialogState extends ConsumerState<_PrinterFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _ip;
  late final TextEditingController _port;

  bool _testing = false;
  bool? _testResult;

  static final RegExp _ipRegex = RegExp(
    r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$',
  );

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _ip = TextEditingController(text: widget.existing?.ip ?? '');
    _port = TextEditingController(
      text: (widget.existing?.port ?? PrintingConstants.defaultPort).toString(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _ip.dispose();
    _port.dispose();
    super.dispose();
  }

  PrinterConfig _readForm() {
    return PrinterConfig(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      ip: _ip.text.trim(),
      port: int.parse(_port.text.trim()),
      isDefault: widget.existing?.isDefault ?? false,
      timeoutMs:
          widget.existing?.timeoutMs ?? PrintingConstants.connectionTimeoutMs,
    );
  }

  Future<void> _runTest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final bool ok = await ref
        .read(printerSettingsControllerProvider.notifier)
        .testConnection(_readForm());
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = ok;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_readForm());
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.existing != null;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isEdit ? 'تعديل الطابعة' : 'إضافة طابعة جديدة',
          style: AppTextStyles.h3,
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'اسم الطابعة',
                    hintText: 'مثال: طابعة المستودع',
                    prefixIcon: Icon(
                      Icons.label_outline_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  validator: (String? v) => (v == null || v.trim().isEmpty)
                      ? 'يرجى إدخال الاسم'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ip,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'عنوان IP',
                    hintText: '192.168.1.100',
                    prefixIcon: Icon(
                      Icons.lan_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  validator: (String? v) {
                    final String t = (v ?? '').trim();
                    if (t.isEmpty) return 'يرجى إدخال IP';
                    return _ipRegex.hasMatch(t) ? null : 'عنوان IP غير صالح';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _port,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'المنفذ',
                    hintText: '9100',
                    prefixIcon: Icon(
                      Icons.settings_ethernet_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  validator: (String? v) {
                    final int? p = int.tryParse((v ?? '').trim());
                    if (p == null || p < 1 || p > 65535) {
                      return 'منفذ غير صالح';
                    }
                    return null;
                  },
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: 12),
                  if (_testResult!)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'الاتصال بالطابعة ناجح',
                              style: AppTextStyles.body,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const InlineError(message: 'فشل الاتصال بالطابعة'),
                ],
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _testing ? null : _runTest,
                  icon: const Icon(Icons.wifi_find_rounded, size: 20),
                  label: Text(
                    _testing ? 'جاري الاختبار…' : 'اختبار الاتصال بالطابعة',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          Row(
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: 'إلغاء',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppPrimaryButton(
                  label: isEdit ? 'حفظ التعديلات' : 'حفظ',
                  icon: Icons.save_rounded,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
