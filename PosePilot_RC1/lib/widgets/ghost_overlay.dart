import 'package:flutter/material.dart';

class GhostOverlay extends StatelessWidget {
  final double score;
  const GhostOverlay({super.key, required this.score});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _GhostPainter(score)),
            Positioned(
              left: 16,
              right: 16,
              bottom: 80,
              child: Center(
                child: Text(
                  score >= 0.80
                      ? 'Отличная поза!'
                      : score >= 0.55
                          ? 'Почти получилось!'
                          : 'Попробуй повторить силуэт',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Color(0xFF000000),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _GhostPainter extends CustomPainter {
  final double score;
  _GhostPainter(this.score);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = score >= 0.80
          ? const Color(0xFF35D07F)
          : score >= 0.55
              ? const Color(0xFFFFC857)
              : const Color(0xFFFF6565)
                  .withValues(alpha: .28 + .5 * score.clamp(0, 1))
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final cx = s.width * .5, top = s.height * .22, unit = s.height * .09;
    c.drawCircle(Offset(cx, top), unit * .32, p);
    c.drawLine(Offset(cx, top + unit * .32), Offset(cx, top + unit * 2.2), p);
    c.drawLine(Offset(cx - unit * .75, top + unit * .9),
        Offset(cx + unit * .75, top + unit * .9), p);
    c.drawLine(Offset(cx - unit * .75, top + unit * .9),
        Offset(cx - unit * 1.05, top + unit * 1.8), p);
    c.drawLine(Offset(cx + unit * .75, top + unit * .9),
        Offset(cx + unit * 1.05, top + unit * 1.8), p);
    c.drawLine(Offset(cx, top + unit * 2.2),
        Offset(cx - unit * .55, top + unit * 3.5), p);
    c.drawLine(Offset(cx, top + unit * 2.2),
        Offset(cx + unit * .55, top + unit * 3.5), p);
  }

  @override
  bool shouldRepaint(covariant _GhostPainter old) => old.score != score;
}
