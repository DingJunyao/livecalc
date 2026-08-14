import 'dart:ui';

/// Builds a Catmull-Rom style curve through every point.
///
/// Control points are constrained to each segment so trend charts do not
/// overshoot their recorded min/max values.
Path buildSmoothPath(List<Offset> points) {
  final path = Path();
  appendSmoothSegments(path, points);
  return path;
}

/// Appends a smooth segment to [path]. When [moveToFirst] is false, the first
/// point is connected from the path's current point instead of opening a new
/// subpath; this lets chart bands form one closed outline.
void appendSmoothSegments(
  Path path,
  List<Offset> points, {
  bool moveToFirst = true,
}) {
  if (points.isEmpty) return;

  if (points.length < 3) {
    if (moveToFirst) {
      path.moveTo(points.first.dx, points.first.dy);
    } else {
      path.lineTo(points.first.dx, points.first.dy);
    }
    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
    }
    return;
  }

  if (moveToFirst) {
    path.moveTo(points.first.dx, points.first.dy);
  } else {
    path.lineTo(points.first.dx, points.first.dy);
  }

  for (var i = 0; i < points.length - 1; i++) {
    final current = points[i];
    final next = points[i + 1];
    final previous = i == 0 ? current : points[i - 1];
    final following = i + 2 == points.length ? next : points[i + 2];

    final control1 = Offset(
      _clamp(current.dx + (next.dx - previous.dx) / 6, current.dx, next.dx),
      _clamp(current.dy + (next.dy - previous.dy) / 6, current.dy, next.dy),
    );
    final control2 = Offset(
      _clamp(next.dx - (following.dx - current.dx) / 6, current.dx, next.dx),
      _clamp(next.dy - (following.dy - current.dy) / 6, current.dy, next.dy),
    );
    path.cubicTo(
      control1.dx,
      control1.dy,
      control2.dx,
      control2.dy,
      next.dx,
      next.dy,
    );
  }
}

double _clamp(double value, double lower, double upper) {
  return value
      .clamp(
        lower < upper ? lower : upper,
        lower < upper ? upper : lower,
      )
      .toDouble();
}
