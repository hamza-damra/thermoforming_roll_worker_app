import 'package:flutter/foundation.dart';

import '../../core/printing_constants.dart';

/// One label-stock preset (mm dimensions + margin). Built-in defaults plus
/// optional worker-defined custom presets.
@immutable
class LabelPreset {
  const LabelPreset({
    required this.id,
    required this.name,
    required this.widthMm,
    required this.heightMm,
    this.marginMm = PrintingConstants.defaultMarginMm,
  });

  final String id;
  final String name;
  final double widthMm;
  final double heightMm;
  final double marginMm;

  double get printableWidthMm => widthMm - (marginMm * 2);
  double get printableHeightMm => heightMm - (marginMm * 2);

  LabelPreset copyWith({
    String? id,
    String? name,
    double? widthMm,
    double? heightMm,
    double? marginMm,
  }) {
    return LabelPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
      marginMm: marginMm ?? this.marginMm,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LabelPreset &&
        other.id == id &&
        other.name == name &&
        other.widthMm == widthMm &&
        other.heightMm == heightMm &&
        other.marginMm == marginMm;
  }

  @override
  int get hashCode => Object.hash(id, name, widthMm, heightMm, marginMm);
}

/// Built-in label-stock presets shipped with the app. Workers can add custom
/// presets on top of these.
class DefaultPresets {
  DefaultPresets._();

  static const LabelPreset preset40x30 = LabelPreset(
    id: 'default_40x30',
    name: '40×30 مم',
    widthMm: 40,
    heightMm: 30,
    marginMm: 2,
  );

  static const LabelPreset preset50x25 = LabelPreset(
    id: 'default_50x25',
    name: '50×25 مم',
    widthMm: 50,
    heightMm: 25,
    marginMm: 2,
  );

  static const LabelPreset preset50x30 = LabelPreset(
    id: 'default_50x30',
    name: '50×30 مم',
    widthMm: 50,
    heightMm: 30,
    marginMm: 2,
  );

  static const LabelPreset preset60x40 = LabelPreset(
    id: 'default_60x40',
    name: '60×40 مم',
    widthMm: 60,
    heightMm: 40,
    marginMm: 3,
  );

  static const LabelPreset preset100x50 = LabelPreset(
    id: 'default_100x50',
    name: '100×50 مم',
    widthMm: 100,
    heightMm: 50,
    marginMm: 4,
  );

  static const List<LabelPreset> all = <LabelPreset>[
    preset40x30,
    preset50x25,
    preset50x30,
    preset60x40,
    preset100x50,
  ];

  static LabelPreset? getById(String id) {
    for (final LabelPreset p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
