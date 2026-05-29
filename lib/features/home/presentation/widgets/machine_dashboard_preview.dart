import 'package:flutter/material.dart';

import '../../../../core/widgets/status_field.dart';
import '../../../shift_line/domain/entities/roll_worker_bootstrap_line.dart';
import '../../domain/entities/shift_line_summary.dart';
import 'compact_mounted_roll_card.dart';
import 'current_product_card.dart';
import 'empty_roll_state_card.dart';

/// Read-only dashboard preview built from the `/bootstrap` row for a machine.
///
/// Rendered behind the blocking auth / waiting overlay so the worker sees the
/// machine's real context (operator, product, mounted roll) dimmed by the
/// overlay scrim — matching the reference app, where the dashboard stays
/// visible behind the PIN modal. Purely presentational: no live calls, no
/// interactivity.
class MachineDashboardPreview extends StatelessWidget {
  const MachineDashboardPreview({
    super.key,
    required this.line,
    required this.accent,
  });

  final RollWorkerBootstrapLine line;
  final Color accent;

  static const String operatorLabel = 'المشغّل';

  @override
  Widget build(BuildContext context) {
    final bool hasRoll = line.currentRollId != null;
    return ListView(
      // Disabled scrolling — the overlay owns interaction; this is a backdrop.
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: <Widget>[
        StatusField(
          label: operatorLabel,
          icon: Icons.person_rounded,
          value: line.activeOperatorName,
          accent: accent,
          placeholder: 'غير مسجل',
        ),
        const SizedBox(height: 12),
        CurrentProductCard(
          productName: line.currentProductTypeName,
          accent: accent,
        ),
        const SizedBox(height: 12),
        if (hasRoll)
          CompactMountedRollCard(
            roll: SummaryMountedRoll(
              consumptionItemId: 0,
              rollId: line.currentRollId!,
              generatedRollId: line.currentRollGeneratedRollId ?? '—',
              rollTypeCode: line.currentRollTypeCode ?? '—',
              rollTypeName: line.currentRollTypeName ?? '',
              lastKnownWeightKg: line.currentRollLastKnownWeightKg,
            ),
            accentColor: accent,
          )
        else
          EmptyRollStateCard(accent: accent),
      ],
    );
  }
}
