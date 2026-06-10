import 'package:flutter/foundation.dart';

import '../../domain/entities/manager_announcement.dart';

/// DTO for one element of `GET /urgent-announcements/pending`'s `data` array.
///
/// PRIVACY (structural): this parser reads **only** `id`, `createdAt`,
/// `createdAtDisplay`, and `priority`. It deliberately does **not** read
/// `title`, `message`, `messageBody`, or `senderDisplayName` — even if a
/// backend bug ever included real manager content in any of those keys, it is
/// dropped on the floor here and can never reach the entity or the UI.
@immutable
class ManagerAnnouncementResponse {
  const ManagerAnnouncementResponse({
    required this.id,
    this.createdAt,
    this.createdAtDisplay,
    this.priority,
  });

  factory ManagerAnnouncementResponse.fromJson(Map<String, dynamic> json) {
    return ManagerAnnouncementResponse(
      id: _asInt(json['id']) ?? 0,
      createdAt: _asDateTime(json['createdAt']),
      createdAtDisplay: _asString(json['createdAtDisplay']),
      priority: _asString(json['priority']),
    );
  }

  final int id;
  final DateTime? createdAt;
  final String? createdAtDisplay;
  final String? priority;

  ManagerAnnouncement toEntity() => ManagerAnnouncement(
    id: id,
    createdAt: createdAt,
    createdAtDisplay: createdAtDisplay,
    priority: priority,
  );

  /// Maps the `data` payload already extracted from the success envelope
  /// (via `ResponseEnvelope.extractData`) into entities. The payload is a
  /// JSON array; non-object / id-less elements are skipped defensively.
  static List<ManagerAnnouncement> listFromEnvelopeData(Object? envelopeData) {
    if (envelopeData is! List) {
      throw const FormatException(
        'urgent-announcements: `data` is not an array',
      );
    }
    return <ManagerAnnouncement>[
      for (final Object? item in envelopeData)
        if (item is Map<String, dynamic> && _asInt(item['id']) != null)
          ManagerAnnouncementResponse.fromJson(item).toEntity(),
    ];
  }

  static int? _asInt(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static String? _asString(Object? v) {
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  static DateTime? _asDateTime(Object? v) {
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
