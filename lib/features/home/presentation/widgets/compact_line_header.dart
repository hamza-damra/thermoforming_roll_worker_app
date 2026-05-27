import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/util/line_label_mapper.dart';

/// Centered friendly machine name shown at the top of the home screen.
///
/// User-facing surfaces never show the technical wire code
/// (`TF_LINE_1`, `TF_LINE_2`, ...) — see [LineLabelMapper.friendlyMachineName]
/// for the resolution order. The per-line accent color, when supplied, is
/// rendered as a small dot beside the centered name so workers still get a
/// quick visual cue for the active line in multi-line mode.
class CompactLineHeader extends StatelessWidget {
  const CompactLineHeader({
    super.key,
    required this.lineCode,
    required this.lineName,
    required this.lineIndex,
    this.accentColor,
  });

  final String? lineCode;
  final String? lineName;
  final int lineIndex;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final String displayName = LineLabelMapper.friendlyMachineName(
      thermoformingLineCode: lineCode,
      thermoformingLineName: lineName,
      oneBasedIndex: lineIndex,
    );
    final Color dotColor = accentColor ?? AppColors.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            displayName,
            textAlign: TextAlign.center,
            style: AppTextStyles.h3,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
