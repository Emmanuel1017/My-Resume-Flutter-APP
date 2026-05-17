import 'package:flutter/material.dart';

/// Auto-scrolling text label.
///
/// Measures the text against the available width via [LayoutBuilder].
/// - If the text fits → renders as a plain [Text] with zero animation overhead.
/// - If the text overflows → clips it and drives a ticker that scrolls to the
///   end, pauses, reverses, pauses, then repeats indefinitely.
///
/// The [AnimatedBuilder] inside only rebuilds the [Transform] subtree each
/// frame — nothing in the parent tree is dirtied by the animation.
class MarqueeLabel extends StatefulWidget {
  final String    text;
  final TextStyle style;
  const MarqueeLabel({required this.text, required this.style, super.key});

  @override
  State<MarqueeLabel> createState() => _MarqueeLabelState();
}

class _MarqueeLabelState extends State<MarqueeLabel>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  double _overflow = 0;
  double _lastMeasuredWidth = 0;

  void _setup(double maxWidth) {
    if (maxWidth <= 0 || !maxWidth.isFinite) return;
    if (maxWidth == _lastMeasuredWidth) return;
    _lastMeasuredWidth = maxWidth;

    final tp = TextPainter(
      text:          TextSpan(text: widget.text, style: widget.style),
      maxLines:      1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);

    final ov = tp.width - maxWidth;
    if (ov <= 0) {
      _ctrl?.dispose();
      _ctrl = null;
      _overflow = 0;
      return;
    }
    if (_ctrl != null && ov == _overflow) return;

    _ctrl?.dispose();
    _overflow = ov;

    final ms = (ov * 28).round().clamp(1000, 3500);
    _ctrl = AnimationController(
      vsync:    this,
      duration: Duration(milliseconds: ms),
    )..addStatusListener(_onStatus);
    _ctrl!.forward();
  }

  Future<void> _onStatus(AnimationStatus s) async {
    if (!mounted) return;
    if (s == AnimationStatus.completed) {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) _ctrl?.reverse();
    } else if (s == AnimationStatus.dismissed) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _ctrl?.forward();
    }
  }

  @override
  void didUpdateWidget(MarqueeLabel old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.style != widget.style) {
      _ctrl?.dispose();
      _ctrl = null;
      _overflow = 0;
      _lastMeasuredWidth = 0;
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final maxW = constraints.maxWidth;
      if (_lastMeasuredWidth != maxW) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _setup(maxW);
        });
      }

      if (_ctrl == null) {
        return Text(
          widget.text, style: widget.style,
          maxLines: 1, overflow: TextOverflow.ellipsis,
        );
      }

      return ClipRect(
        child: AnimatedBuilder(
          animation: _ctrl!,
          builder: (_, child) => Transform.translate(
            offset: Offset(-_ctrl!.value * _overflow, 0),
            child:  child,
          ),
          child: Text(
            widget.text, style: widget.style,
            maxLines: 1, softWrap: false,
          ),
        ),
      );
    });
  }
}
