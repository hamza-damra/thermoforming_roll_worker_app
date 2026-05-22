import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks which Line Takeover Request the roll worker has acknowledged (tapped
/// `حسناً`) on a given shift-line.
///
/// The blocking dialog shows only while the takeover is `PENDING` **and** its
/// `requestId` differs from the acknowledged id. Once acknowledged, the dialog
/// collapses into the persistent banner and never re-opens for that request —
/// a fresh request (new `requestId`) naturally re-arms the dialog.
class AcknowledgedTakeoverController extends FamilyNotifier<int?, int> {
  @override
  int? build(int arg) => null;

  /// Records [requestId] as acknowledged for this shift-line.
  void acknowledge(int requestId) {
    state = requestId;
  }
}

final acknowledgedTakeoverProvider =
    NotifierProvider.family<AcknowledgedTakeoverController, int?, int>(
      AcknowledgedTakeoverController.new,
    );
