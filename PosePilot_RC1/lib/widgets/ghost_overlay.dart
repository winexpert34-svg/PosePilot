import '../models/pose.dart';
import 'package:flutter/material.dart';

class GhostOverlay extends StatelessWidget {
  final double score;
  final PoseTarget target;
  const GhostOverlay({super.key, required this.score, required this.target});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _GhostPainter(score, target)),
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
  final PoseTarget target;
  _GhostPainter(this.score, this.target);
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

    final cx = s.width * .5;
    final u = s.height * .09;
    final top = s.height * .22;
    final seated = target.name.toLowerCase().contains('chair') ||
        target.name.toLowerCase().contains('sitting') ||
        target.name.toLowerCase().contains('lounge') ||
        target.name.toLowerCase().contains('crossed legs');
    final armsUp = target.name.toLowerCase().contains('arms up');
    final handsWaist = target.name.toLowerCase().contains('waist');
    final walking = target.name.toLowerCase().contains('walking') ||
        target.name.toLowerCase().contains('step') ||
        target.name.toLowerCase().contains('one leg');
    final lean = target.shoulderTilt * 2.0;

    Offset pt(double x, double y) => Offset(cx + x * u, top + y * u);
    void line(double x1, double y1, double x2, double y2) =>
        c.drawLine(pt(x1, y1), pt(x2, y2), p);

    c.drawCircle(pt(lean, 0), u * .32, p);
    line(lean, .35, lean, 2.2);
    line(lean - .75, .9, lean + .75, .9);
    line(lean, 2.2, 0, 3.4);

    if (armsUp) {
      line(lean - .75, .9, -1.2, -.1);
      line(-1.2, -.1, -1.0, -1.1);
      line(lean + .75, .9, 1.2, -.1);
      line(1.2, -.1, 1.0, -1.1);
    } else if (handsWaist) {
      line(lean - .75, .9, -1.25, 1.6);
      line(-1.25, 1.6, -.5, 2.1);
      line(lean + .75, .9, 1.25, 1.6);
      line(1.25, 1.6, .5, 2.1);
    } else {
      final spread = target.armSpread * 2;
      line(lean - .75, .9, -1.0 - spread, 2.0);
      line(-1.0 - spread, 2.0, -1.0 - spread, 3.0);
      line(lean + .75, .9, 1.0 + spread, 2.0);
      line(1.0 + spread, 2.0, 1.0 + spread, 3.0);
    }

    if (seated) {
      line(0, 3.4, -1.2, 3.7);
      line(-1.2, 3.7, -1.2, 5.0);
      line(0, 3.4, 1.2, 3.7);
      line(1.2, 3.7, 1.2, 5.0);
    } else if (walking) {
      line(0, 3.4, -1.2, 4.5);
      line(-1.2, 4.5, -1.7, 5.4);
      line(0, 3.4, .9, 4.4);
      line(.9, 4.4, .5, 5.5);
    } else {
      line(0, 3.4, -.75, 5.5);
      line(0, 3.4, .75, 5.5);
    }
  }

  @override
  bool shouldRepaint(covariant _GhostPainter old) =>
      old.score != score || old.target != target;
}
