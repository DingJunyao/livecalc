import 'package:flutter/material.dart';
import '../utils/smooth_path.dart';

/// 迷你趋势线（列表行尾展示，对应 Web SparklineBackground）。
class Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;
  final double width;

  const Sparkline({
    super.key,
    required this.data,
    this.color = const Color(0xFFE65100),
    this.height = 28,
    this.width = 56,
  });

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return SizedBox(width: width, height: height);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _SparklinePainter(data, color)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    var minV = data.reduce((a, b) => a < b ? a : b);
    var maxV = data.reduce((a, b) => a > b ? a : b);
    if (maxV == minV) {
      maxV += 1;
      minV -= 1;
    }
    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y = size.height -
          (data[i] - minV) / (maxV - minV) * (size.height - 2) -
          1;
      points.add(Offset(x, y));
    }
    final path = buildSmoothPath(points);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..isAntiAlias = true;
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.data != data || old.color != color;
}
