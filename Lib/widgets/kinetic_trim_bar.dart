import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Minimalist Kinetic Pulse Trim Bar with glowing dual magnetic handles.
class KineticTrimBar extends StatelessWidget {
  final Duration duration;
  final Duration start;
  final Duration end;
  final Duration position;
  final void Function(Duration newStart, Duration newEnd) onChanged;

  const KineticTrimBar({
    super.key,
    required this.duration,
    required this.start,
    required this.end,
    required this.position,
    required this.onChanged,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = math.max(1, duration.inMilliseconds).toDouble();
    final startVal = start.inMilliseconds.clamp(0, totalMs.toInt()).toDouble();
    final endVal = end.inMilliseconds
        .clamp(startVal.toInt(), totalMs.toInt())
        .toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121622),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _badge('البداية ${_fmt(start)}', const Color(0xFF00E5FF)),
              Text(
                'المدة المحددة: ${_fmt(end - start)}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.white.withAlpha(185),
                  fontWeight: FontWeight.w600,
                ),
              ),
              _badge('النهاية ${_fmt(end)}', const Color(0xFFFF4D6D)),
            ],
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Subtle decorative pulse bars behind slider
                SizedBox(
                  height: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(32, (i) {
                      final norm = i / 31.0;
                      final inRange = norm >= (startVal / totalMs) &&
                          norm <= (endVal / totalMs);
                      final barH =
                          8.0 + ((math.sin(i * 0.9) + 1) * 0.5) * 18.0;
                      return Container(
                        width: 3,
                        height: barH,
                        decoration: BoxDecoration(
                          color: inRange
                              ? const Color(0xFF00E5FF).withAlpha(135)
                              : Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: const Color(0xFF00E5FF),
                    inactiveTrackColor: Colors.transparent,
                    rangeThumbShape: const RoundRangeSliderThumbShape(
                      enabledThumbRadius: 9,
                    ),
                  ),
                  child: RangeSlider(
                    min: 0,
                    max: totalMs,
                    values: RangeValues(startVal, math.max(startVal + 1, endVal)),
                    onChanged: (RangeValues v) {
                      if (v.end - v.start < 500) return;
                      onChanged(
                        Duration(milliseconds: v.start.round()),
                        Duration(milliseconds: v.end.round()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(110)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
