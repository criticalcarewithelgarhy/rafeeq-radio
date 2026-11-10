import 'package:flutter/material.dart';
import '../theme.dart';

class EqBars extends StatefulWidget {
  final int barCount;
  final bool playing;
  final String size;

  const EqBars({
    super.key,
    this.barCount = 4,
    required this.playing,
    this.size = 'small',
  });

  @override
  State<EqBars> createState() => _EqBarsState();
}

class _EqBarsState extends State<EqBars> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  static const _durations = [320, 380, 290, 420, 350];

  @override
  void initState() {
    super.initState();
    _initControllers();
    if (widget.playing) _startAll();
  }

  void _initControllers() {
    _controllers = List.generate(widget.barCount, (i) {
      final dur = _durations[i % _durations.length];
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: dur),
      );
    });

    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0.1, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();
  }

  void _startAll() {
    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 60), () {
        if (mounted && widget.playing) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  void _stopAll() {
    for (final c in _controllers) {
      c.stop();
      c.animateTo(0.1, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void didUpdateWidget(EqBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing != oldWidget.playing) {
      if (widget.playing) {
        _startAll();
      } else {
        _stopAll();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLarge = widget.size == 'large';
    final barWidth = isLarge ? 4.0 : 2.0;
    final minHeight = isLarge ? 8.0 : 4.0;
    final maxHeight = isLarge ? 32.0 : 14.0;
    final gap = isLarge ? 3.0 : 2.0;

    return AnimatedBuilder(
      animation: Listenable.merge(_controllers),
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(widget.barCount, (i) {
            final h =
                minHeight + (maxHeight - minHeight) * _animations[i].value;
            return Padding(
              padding: EdgeInsets.only(right: i < widget.barCount - 1 ? gap : 0),
              child: Container(
                width: barWidth,
                height: h,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(barWidth / 2),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
