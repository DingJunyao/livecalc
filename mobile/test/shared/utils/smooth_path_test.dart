import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/shared/utils/smooth_path.dart';

void main() {
  test('smooths a polyline without replacing it with a straight chord', () {
    final path = buildSmoothPath([
      Offset.zero,
      const Offset(50, 100),
      const Offset(100, 0),
    ]);
    final length = path.computeMetrics().fold<double>(
          0,
          (total, metric) => total + metric.length,
        );

    expect(length, greaterThan(100));
    expect(length, lessThan(math.sqrt2 * 100 * 2));
  });

  test('keeps a two-point path direct', () {
    final path = buildSmoothPath([
      Offset.zero,
      const Offset(60, 80),
    ]);
    final length = path.computeMetrics().single.length;

    expect(length, closeTo(100, 0.001));
  });

  test('continues a second segment without opening a subpath', () {
    final path = Path()..moveTo(0, 0);
    appendSmoothSegments(
      path,
      [
        const Offset(0, 100),
        const Offset(100, 50),
        const Offset(200, 100),
      ],
      moveToFirst: false,
    );

    final metrics = path.computeMetrics().toList();
    expect(metrics, hasLength(1));
    expect(metrics.single.length, greaterThan(200));
  });
}
