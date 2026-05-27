import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/info_row.dart';
import '../../domain/entities/label_preset.dart';
import '../../domain/entities/printer_config.dart';
import '../controllers/printer_settings_controller.dart';
import '../widgets/printer_form_dialog.dart';

/// Settings screen for the printing subsystem. Multi-printer support,
/// preset picker, copies counter. Persists every change to Hive.
class PrinterSettingsScreen extends ConsumerWidget {
  const PrinterSettingsScreen({super.key});

  static const String title = 'إعدادات الطباعة';
  static const String printersHeading = 'الطابعات';
  static const String addPrinter = 'إضافة طابعة';
  static const String noPrinters =
      'لا توجد طابعات مضافة. أضف طابعة لبدء الطباعة.';
  static const String defaultPrinterChip = 'الطابعة الافتراضية';
  static const String makeDefault = 'تعيين كافتراضية';
  static const String editPrinter = 'تعديل';
  static const String deletePrinter = 'حذف';
  static const String confirmDeleteTitle = 'حذف الطابعة';
  static const String confirmDeleteBody = 'هل تريد حذف هذه الطابعة؟';
  static const String confirmDeleteOk = 'حذف';
  static const String confirmDeleteCancel = 'إلغاء';
  static const String presetsHeading = 'حجم الملصق';
  static const String copiesHeading = 'عدد النسخ';

  Future<void> _onAdd(BuildContext context, WidgetRef ref) async {
    final PrinterConfig? created = await showPrinterFormDialog(context);
    if (created == null) return;
    await ref
        .read(printerSettingsControllerProvider.notifier)
        .addPrinter(created);
  }

  Future<void> _onEdit(
    BuildContext context,
    WidgetRef ref,
    PrinterConfig printer,
  ) async {
    final PrinterConfig? updated = await showPrinterFormDialog(
      context,
      existing: printer,
    );
    if (updated == null) return;
    await ref
        .read(printerSettingsControllerProvider.notifier)
        .updatePrinter(updated);
  }

  Future<void> _onDelete(
    BuildContext context,
    WidgetRef ref,
    PrinterConfig printer,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(confirmDeleteTitle, style: AppTextStyles.h3),
          content: Text('$confirmDeleteBody\n${printer.name}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(confirmDeleteCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text(confirmDeleteOk),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(printerSettingsControllerProvider.notifier)
        .deletePrinter(printer.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PrinterSettingsSnapshot snap = ref.watch(
      printerSettingsControllerProvider,
    );

    return AppScaffold(
      title: title,
      body: ListView(
        children: [
          const SizedBox(height: 12),
          const _SectionHeading(label: printersHeading),
          const SizedBox(height: 8),
          if (snap.printers.isEmpty)
            const AppCard(child: Text(noPrinters, style: AppTextStyles.body))
          else
            ...snap.printers.map(
              (PrinterConfig p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PrinterRow(
                  printer: p,
                  onSetDefault: () => ref
                      .read(printerSettingsControllerProvider.notifier)
                      .setDefault(p.id),
                  onEdit: () => _onEdit(context, ref, p),
                  onDelete: () => _onDelete(context, ref, p),
                ),
              ),
            ),
          const SizedBox(height: 12),
          AppPrimaryButton(
            label: addPrinter,
            icon: Icons.add_rounded,
            onPressed: () => _onAdd(context, ref),
          ),
          const SizedBox(height: 24),
          const _SectionHeading(label: presetsHeading),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: snap.presets
                  .map(
                    (LabelPreset preset) =>
                        // RadioListTile.groupValue/onChanged are deprecated
                        // in Flutter 3.32+ in favour of a RadioGroup ancestor;
                        // they still work and produce identical UX. We'll
                        // migrate when we adopt the RadioGroup widget.
                        // ignore: deprecated_member_use
                        RadioListTile<String>(
                          value: preset.id,
                          // ignore: deprecated_member_use
                          groupValue: snap.selectedPresetId,
                          activeColor: AppColors.primary,
                          title: Text(
                            preset.name,
                            style: AppTextStyles.bodyLarge,
                          ),
                          subtitle: Text(
                            '${preset.widthMm.toStringAsFixed(0)} × '
                            '${preset.heightMm.toStringAsFixed(0)} مم',
                            style: AppTextStyles.caption,
                          ),
                          // ignore: deprecated_member_use
                          onChanged: (String? id) {
                            if (id != null) {
                              ref
                                  .read(
                                    printerSettingsControllerProvider.notifier,
                                  )
                                  .selectPreset(id);
                            }
                          },
                        ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeading(label: copiesHeading),
          const SizedBox(height: 8),
          AppCard(
            child: Row(
              children: [
                IconButton(
                  onPressed: snap.copies <= 1
                      ? null
                      : () => ref
                            .read(printerSettingsControllerProvider.notifier)
                            .setCopies(snap.copies - 1),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  color: AppColors.primary,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${snap.copies}',
                      style: AppTextStyles.metricValue,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: snap.copies >= 10
                      ? null
                      : () => ref
                            .read(printerSettingsControllerProvider.notifier)
                            .setCopies(snap.copies + 1),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(label, style: AppTextStyles.h3),
    );
  }
}

class _PrinterRow extends StatelessWidget {
  const _PrinterRow({
    required this.printer,
    required this.onSetDefault,
    required this.onEdit,
    required this.onDelete,
  });

  final PrinterConfig printer;
  final VoidCallback onSetDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.print_rounded,
                  size: 24,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            printer.name,
                            style: AppTextStyles.h3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            printer.language.shortBadge,
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (printer.isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              PrinterSettingsScreen.defaultPrinterChip,
                              style: AppTextStyles.caption,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${printer.ip}:${printer.port}',
                      style: AppTextStyles.label,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          InfoRow(
            label: 'مهلة الاتصال',
            value: '${printer.timeoutMs} ms',
            icon: Icons.timer_outlined,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (!printer.isDefault)
                Expanded(
                  child: TextButton.icon(
                    onPressed: onSetDefault,
                    icon: const Icon(Icons.star_outline_rounded, size: 18),
                    label: const Text(PrinterSettingsScreen.makeDefault),
                  ),
                ),
              if (!printer.isDefault) const SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text(PrinterSettingsScreen.editPrinter),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text(PrinterSettingsScreen.deletePrinter),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
