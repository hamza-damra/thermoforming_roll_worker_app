import 'package:flutter/material.dart';

import 'roll_worker_home_screen.dart';

/// One stable PageView sibling — wraps [RollWorkerHomeScreen] for the
/// given [shiftLineId] and keeps its scaffold-less body alive across
/// swipes via [AutomaticKeepAliveClientMixin].
///
/// State preserved across swipes includes: scroll position, mount-roll
/// controller subscriptions, refresh-indicator state, and any in-flight
/// camera/scan screen pushed on top.
class PerLinePage extends StatefulWidget {
  const PerLinePage({
    super.key,
    required this.shiftLineId,
    required this.lineIndex,
    required this.accentColor,
  });

  final int shiftLineId;
  final int lineIndex;
  final Color accentColor;

  @override
  State<PerLinePage> createState() => _PerLinePageState();
}

class _PerLinePageState extends State<PerLinePage>
    with AutomaticKeepAliveClientMixin<PerLinePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RollWorkerHomeScreen(
      shiftLineId: widget.shiftLineId,
      lineIndex: widget.lineIndex,
      standaloneScaffold: false,
      accentColor: widget.accentColor,
    );
  }
}
