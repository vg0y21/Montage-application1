import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Innovative Orbital Jog-Wheel: drag horizontally to scrub frame-by-frame
/// with haptic micro-ticks and glowing kinetic feedback.
class KineticJogWheel extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onScrub;

  const KineticJogWheel({
    super.key,
    required this.position,
    required this.duration,
    required this.onScrub,
  });

  @override
  State<KineticJogWheel> createState() => _KineticJogWheelState();
}

class _KineticJogWheelState extends State<KineticJogWheel> {
  double _wheelOffset = 0.0;
  double _lastTickBucket = 0.0;
  bool _isDragging = false;

  String _formatTime(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs = (d.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return '$mins:$secs.$cs';
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (widget.duration.inMilliseconds <= 0) return;
    final dx = details.delta.dx;
    setState(() {
      _wheelOffset += dx;
    });

    // Haptic tick every 14 logical pixels
    final bucket = (_wheelOffset / 14).floorToDouble();
    if (bucket != _lastTickBucket) {
      _lastTickBucket = bucket;
      HapticFeedback.selectionClick();
    }

    // 1 pixel = 25ms precision scrubbing
    final deltaMs = (dx * 25).round();
    final nextMs = (widget.position.inMilliseconds + deltaMs)
        .clamp(0, widget.duration.inMilliseconds);
    widget.onScrub(Duration(milliseconds: nextMs));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: (_) => setState(() => _isDragging = true),
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
      child: Container(
        height: 62,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF10141F),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _isDragging
                ? const Color(0xFF00E5FF).withAlpha(180)
                : Colors.white.withAlpha(24),
            width: 1.2,
          ),
          boxShadow: _isDragging
              ? [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withAlpha(45),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: CustomPaint(
                size: const Size(double.infinity, 62),
                painter: _JogDialPainter(
                  offset: _wheelOffset,
                  active: _isDragging,
                ),
              ),
            ),
            // Center glowing needle & floating timecode pill
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF080A0F).withAlpha(220),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withAlpha(140),
                    ),
                  ),
                  child: Text(
                    '${_formatTime(widget.position)}  /  ${_formatTime(widget.duration)}',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00E5FF),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'اسحب العجلة للتحريك الدقيق إطاراً بإطار',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: Colors.white.withAlpha(130),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _JogDialPainter extends CustomPainter {
  final double offset;
  final bool active;

  _JogDialPainter({required this.offset, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 12.0;
    final centerX = size.width / 2;
    final shift = offset % spacing;

    for (double x = shift; x < size.width; x += spacing) {
      final distRatio = ((x - centerX).abs() / centerX).clamp(0.0, 1.0);
      final alpha = ((1.0 - distRatio) * (active ? 210 : 120)).round();
      final isMajor = ((x - shift) / spacing).round() % 5 == 0;
      final tickH = isMajor ? 20.0 : 10.0;
      final paint = Paint()
        ..color = (isMajor ? const Color(0xFF00E5FF) : Colors.white)
            .withAlpha(math.max(15, alpha))
        ..strokeWidth = isMajor ? 1.8 : 1.1
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x, size.height - tickH - 6),
        Offset(x, size.height - 6),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _JogDialPainter oldDelegate) =>
      oldDelegate.offset != offset || oldDelegate.active != active;
}
