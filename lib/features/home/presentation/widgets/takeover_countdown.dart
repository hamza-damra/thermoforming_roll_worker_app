import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A 1-second-ticking countdown to a backend-supplied [target] timestamp,
/// rendered as `mm:ss` plus a progress bar over the full [window].
///
/// The countdown is **display only** — it never decides that a request has
/// expired. When it reaches zero it fires [onExpired] exactly once so the
/// caller can re-fetch the authoritative backend state (spec §7).
class TakeoverCountdown extends StatefulWidget {
  const TakeoverCountdown({
    super.key,
    required this.target,
    required this.window,
    this.onExpired,
    this.color = AppColors.offline,
  });

  /// Absolute moment the window ends (resume-safe).
  final DateTime target;

  /// Total length of the window, used to scale the progress bar.
  final Duration window;

  /// Invoked once when the displayed time reaches zero.
  final VoidCallback? onExpired;

  /// Foreground colour for the text and progress bar.
  final Color color;

  @override
  State<TakeoverCountdown> createState() => _TakeoverCountdownState();
}

class _TakeoverCountdownState extends State<TakeoverCountdown> {
  Timer? _ticker;
  bool _expiredFired = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(TakeoverCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new target (a refreshed snapshot) re-arms the expiry callback.
    if (oldWidget.target != widget.target) {
      _expiredFired = false;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (_remaining() <= Duration.zero && !_expiredFired) {
      _expiredFired = true;
      widget.onExpired?.call();
    }
  }

  Duration _remaining() {
    final Duration left = widget.target.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  String _format(Duration d) {
    final String mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final Duration remaining = _remaining();
    final double progress = widget.window.inSeconds <= 0
        ? 0
        : (remaining.inSeconds / widget.window.inSeconds).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.timer_outlined, size: 16, color: widget.color),
            const SizedBox(width: 6),
            Text(
              _format(remaining),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: widget.color,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: widget.color.withValues(alpha: 0.18),
            valueColor: AlwaysStoppedAnimation<Color>(widget.color),
          ),
        ),
      ],
    );
  }
}
