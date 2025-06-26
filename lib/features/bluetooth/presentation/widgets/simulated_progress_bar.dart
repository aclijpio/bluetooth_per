import 'dart:async';
import 'package:flutter/material.dart';
import 'progress_bar.dart';

/// Shows animated progress from 0 to 1 within [duration].
/// When progress reaches 100 %, [onCompleted] is invoked.
class SimulatedProgressBar extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onCompleted;
  const SimulatedProgressBar({
    super.key,
    this.duration = const Duration(seconds: 5),
    this.onCompleted,
  });

  @override
  State<SimulatedProgressBar> createState() => _SimulatedProgressBarState();
}

class _SimulatedProgressBarState extends State<SimulatedProgressBar> {
  double _progress = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final totalTicks = widget.duration.inMilliseconds ~/ 50;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _progress += 1 / totalTicks;
        if (_progress >= 1) {
          _progress = 1;
          t.cancel();
          widget.onCompleted?.call();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProgressBarWithPercent(progress: _progress);
  }
}
