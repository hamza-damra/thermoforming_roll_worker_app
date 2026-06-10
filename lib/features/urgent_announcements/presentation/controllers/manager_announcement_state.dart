import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/manager_announcement.dart';

/// State for [ManagerAnnouncementController].
///
/// [pending] is the worker's not-yet-acked announcements, oldest first. The
/// blocking modal shows [front] (the oldest) and is removed entirely once
/// [pending] is empty. [acking] drives the button spinner while an ack is in
/// flight; [ackError] holds the last ack failure so the modal can show an
/// inline retry message without dismissing.
@immutable
class ManagerAnnouncementState {
  const ManagerAnnouncementState({
    this.pending = const <ManagerAnnouncement>[],
    this.acking = false,
    this.ackError,
  });

  final List<ManagerAnnouncement> pending;
  final bool acking;
  final AppFailure? ackError;

  bool get hasPending => pending.isNotEmpty;

  /// The oldest pending announcement (the one currently shown), or null.
  ManagerAnnouncement? get front => pending.isEmpty ? null : pending.first;

  ManagerAnnouncementState copyWith({
    List<ManagerAnnouncement>? pending,
    bool? acking,
    AppFailure? ackError,
    bool clearAckError = false,
  }) {
    return ManagerAnnouncementState(
      pending: pending ?? this.pending,
      acking: acking ?? this.acking,
      ackError: clearAckError ? null : (ackError ?? this.ackError),
    );
  }

  static const ManagerAnnouncementState empty = ManagerAnnouncementState();
}
