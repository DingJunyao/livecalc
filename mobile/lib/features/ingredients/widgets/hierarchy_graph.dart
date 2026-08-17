import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/models/hierarchy_relation.dart';
import '../repositories/ingredient_repository.dart';

class HierarchyGraph extends StatelessWidget {
  final int ingredientId;
  final String ingredientName;
  final IngredientHierarchyData? hierarchyData;

  const HierarchyGraph({
    super.key,
    required this.ingredientId,
    required this.ingredientName,
    this.hierarchyData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 420,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final relationCount = [
            ...?hierarchyData?.parentRelations,
            ...?hierarchyData?.childRelations,
            ...?hierarchyData?.expandedRelations,
          ].length;
          final graphSpan = math.sqrt((relationCount + 1).toDouble());
          final canvasWidth = math
              .max(
                constraints.maxWidth,
                math.min(760, 120 + graphSpan * 135),
              )
              .toDouble();
          final canvasHeight = math
              .max(
                420.0,
                math.min(640, 130 + graphSpan * 135),
              )
              .toDouble();
          final layout = buildHierarchyGraphLayout(
            ingredientId: ingredientId,
            ingredientName: ingredientName,
            hierarchyData: hierarchyData,
            size: Size(canvasWidth, canvasHeight),
          );
          return InteractiveViewer(
            constrained: false,
            alignment: Alignment.center,
            maxScale: 3,
            child: SizedBox(
              width: canvasWidth,
              height: canvasHeight,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _HierarchyPainter(
                      nodes: layout.nodes,
                      edges: layout.edges,
                    ),
                    child: const SizedBox.expand(),
                  ),
                  for (final node in layout.nodes.values)
                    Positioned(
                      left: node.position.dx - 44,
                      top: node.position.dy - 20,
                      width: 88,
                      height: 40,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _colorFor(node.level).withValues(alpha: .12),
                            border: Border.all(
                              color: _colorFor(node.level),
                              width: node.level == 0 ? 2.5 : 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            node.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _textColorFor(node.level, theme),
                              fontWeight:
                                  node.level == 0 ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _colorFor(int level) => switch (level) {
        0 => const Color(0xFFE91E63),
        1 => const Color(0xFF2196F3),
        _ => const Color(0xFF90CAF9),
      };

  Color _textColorFor(int level, ThemeData theme) {
    if (level == 0) return const Color(0xFFAD1457);
    if (level == 1) return const Color(0xFF0D47A1);
    return theme.colorScheme.onSurface;
  }
}

@visibleForTesting
HierarchyGraphLayout buildHierarchyGraphLayout({
  required int ingredientId,
  required String ingredientName,
  required IngredientHierarchyData? hierarchyData,
  required Size size,
}) {
  final nodes = <int, HierarchyGraphNode>{};
  final edges = <HierarchyGraphEdge>[];
  final center = Offset(size.width / 2, size.height / 2);
  nodes[ingredientId] = HierarchyGraphNode(
    id: ingredientId,
    name: ingredientName,
    level: 0,
    position: center,
  );

  void addNode(int id, String name, int level) {
    nodes.putIfAbsent(
      id,
      () => HierarchyGraphNode(
        id: id,
        name: name,
        level: level,
        position: center,
      ),
    );
  }

  if (hierarchyData != null) {
    for (final relation in [
      ...hierarchyData.parentRelations,
      ...hierarchyData.childRelations,
    ]) {
      final isParent = relation.parentId == ingredientId;
      addNode(
        isParent ? relation.childId : relation.parentId,
        isParent ? relation.childName : relation.parentName,
        1,
      );
      edges.add(_edge(relation, anchorId: ingredientId));
    }

    for (final expanded in hierarchyData.expandedRelations) {
      addNode(expanded.ingredientId, expanded.ingredientName, 1);
      for (final relation in [
        ...expanded.parentRelations,
        ...expanded.childRelations,
      ]) {
        addNode(relation.parentId, relation.parentName, 2);
        addNode(relation.childId, relation.childName, 2);
        edges.add(_edge(relation, anchorId: expanded.ingredientId));
      }
    }
  }

  _initializePositions(nodes, center);
  _relaxLayout(nodes, edges, center);
  _fitLayout(nodes, size);
  return HierarchyGraphLayout(nodes, edges);
}

void _initializePositions(
  Map<int, HierarchyGraphNode> nodes,
  Offset center,
) {
  final firstLevel = nodes.values.where((node) => node.level == 1).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  for (var i = 0; i < firstLevel.length; i++) {
    final angle = i * 2 * math.pi / firstLevel.length;
    firstLevel[i].position = Offset(
      center.dx + 140 * math.cos(angle),
      center.dy + 120 * math.sin(angle),
    );
  }

  final secondLevel = nodes.values.where((node) => node.level == 2).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  for (var i = 0; i < secondLevel.length; i++) {
    final node = secondLevel[i];
    final angle = i * 2 * math.pi / secondLevel.length + .35;
    node.position = Offset(
      center.dx + 245 * math.cos(angle),
      center.dy + 175 * math.sin(angle),
    );
  }
}

void _relaxLayout(
  Map<int, HierarchyGraphNode> nodes,
  List<HierarchyGraphEdge> edges,
  Offset center,
) {
  final ids = nodes.keys.toList();
  final positions = {
    for (final id in ids)
      id: Offset(nodes[id]!.position.dx, nodes[id]!.position.dy),
  };
  const iterations = 180;
  const repulsion = 15000;
  const desiredLength = 155.0;
  final fixedId = nodes.entries.first.key;

  for (var iteration = 0; iteration < iterations; iteration++) {
    final displacement = {
      for (final id in ids) id: Offset.zero,
    };

    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final delta = positions[ids[j]]! - positions[ids[i]]!;
        final distance = math.max(delta.distance, 24.0);
        final force = repulsion / (distance * distance);
        final direction = delta / distance;
        displacement[ids[i]] = displacement[ids[i]]! - direction * force;
        displacement[ids[j]] = displacement[ids[j]]! + direction * force;
      }
    }

    for (final edge in edges) {
      final source = positions[edge.sourceId];
      final target = positions[edge.targetId];
      if (source == null || target == null) continue;
      final delta = target - source;
      final distance = math.max(delta.distance, 1.0);
      final force = (distance - desiredLength) * .035;
      final direction = delta / distance;
      displacement[edge.sourceId] =
          displacement[edge.sourceId]! + direction * force;
      displacement[edge.targetId] =
          displacement[edge.targetId]! - direction * force;
    }

    final damping = .55 - iteration * .002;
    for (final id in ids) {
      if (id == fixedId) continue;
      var movement = displacement[id]! * damping;
      if (movement.distance > 16) {
        movement = movement / movement.distance * 16;
      }
      final current = positions[id]!;
      positions[id] = current + movement + (center - current) * .012;
    }
  }

  for (final id in ids) {
    nodes[id]!.position = positions[id]!;
  }
}

void _fitLayout(Map<int, HierarchyGraphNode> nodes, Size size) {
  if (nodes.isEmpty) return;
  final minX = nodes.values.map((node) => node.position.dx).reduce(math.min);
  final maxX = nodes.values.map((node) => node.position.dx).reduce(math.max);
  final minY = nodes.values.map((node) => node.position.dy).reduce(math.min);
  final maxY = nodes.values.map((node) => node.position.dy).reduce(math.max);
  final rawCenter = Offset((minX + maxX) / 2, (minY + maxY) / 2);
  final targetCenter = Offset(size.width / 2, size.height / 2);
  final rawWidth = math.max(maxX - minX, 1.0);
  final rawHeight = math.max(maxY - minY, 1.0);
  final scale = math.min(
    (size.width - 108) / rawWidth,
    (size.height - 100) / rawHeight,
  );
  for (final node in nodes.values) {
    node.position = targetCenter + (node.position - rawCenter) * scale;
  }
}

HierarchyGraphEdge _edge(
  HierarchyRelation relation, {
  required int anchorId,
}) {
  final otherId =
      anchorId == relation.parentId ? relation.childId : relation.parentId;
  final sourceId = switch (relation.relationType) {
    'fallback' => relation.childId,
    'substitutable' => anchorId,
    _ => relation.parentId,
  };
  final targetId = switch (relation.relationType) {
    'fallback' => relation.parentId,
    'substitutable' => otherId,
    _ => relation.childId,
  };
  return HierarchyGraphEdge(
    sourceId: sourceId,
    targetId: targetId,
    relationType: relation.relationType,
    strength: relation.strength,
  );
}

class HierarchyGraphLayout {
  final Map<int, HierarchyGraphNode> nodes;
  final List<HierarchyGraphEdge> edges;
  const HierarchyGraphLayout(this.nodes, this.edges);
}

class HierarchyGraphNode {
  final int id;
  final String name;
  final int level;
  Offset position;

  HierarchyGraphNode({
    required this.id,
    required this.name,
    required this.level,
    required this.position,
  });
}

class HierarchyGraphEdge {
  final int sourceId;
  final int targetId;
  final String relationType;
  final int strength;

  const HierarchyGraphEdge({
    required this.sourceId,
    required this.targetId,
    required this.relationType,
    required this.strength,
  });
}

class _HierarchyPainter extends CustomPainter {
  final Map<int, HierarchyGraphNode> nodes;
  final List<HierarchyGraphEdge> edges;

  const _HierarchyPainter({
    required this.nodes,
    required this.edges,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final source = nodes[edge.sourceId]?.position;
      final target = nodes[edge.targetId]?.position;
      if (source == null || target == null) continue;
      final color = switch (edge.relationType) {
        'contains' => const Color(0xFF2196F3),
        'fallback' => const Color(0xFFFF9800),
        'substitutable' => const Color(0xFF4CAF50),
        _ => const Color(0xFF666666),
      };
      final paint = Paint()
        ..color = color.withValues(alpha: .78)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final lineTarget = _awayFromTarget(source, target, 26);
      final lineSource = _awayFromTarget(target, source, 26);
      if (edge.relationType == 'fallback') {
        _paintDashes(canvas, lineSource, lineTarget, paint);
      } else if (edge.relationType == 'substitutable') {
        _paintDots(canvas, lineSource, lineTarget, paint);
      } else {
        canvas.drawLine(lineSource, lineTarget, paint);
      }
      _paintArrow(canvas, lineSource, lineTarget, color);
    }
  }

  Offset _awayFromTarget(Offset source, Offset target, double distance) {
    final delta = target - source;
    if (delta.distance < distance * 2) return source;
    return target - delta / delta.distance * distance;
  }

  void _paintDashes(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 8.0;
    const gap = 5.0;
    var distance = 0.0;
    final total = (b - a).distance;
    final direction = (b - a) / total;
    while (distance < total) {
      final start = a + direction * distance;
      final end = a + direction * (distance + dash).clamp(0, total);
      canvas.drawLine(start, end, paint);
      distance += dash + gap;
    }
  }

  void _paintDots(Canvas canvas, Offset a, Offset b, Paint paint) {
    var distance = 0.0;
    final total = (b - a).distance;
    final direction = (b - a) / total;
    while (distance < total) {
      canvas.drawCircle(a + direction * distance, 1.5, paint);
      distance += 9;
    }
  }

  void _paintArrow(Canvas canvas, Offset source, Offset target, Color color) {
    final delta = target - source;
    if (delta.distance == 0) return;
    final direction = delta / delta.distance;
    final base = target - direction * 9;
    final perpendicular = Offset(-direction.dy, direction.dx);
    final path = Path()
      ..moveTo(target.dx, target.dy)
      ..lineTo(base.dx + perpendicular.dx * 5, base.dy + perpendicular.dy * 5)
      ..lineTo(base.dx - perpendicular.dx * 5, base.dy - perpendicular.dy * 5)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .8)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _HierarchyPainter oldDelegate) {
    return oldDelegate.nodes != nodes || oldDelegate.edges != edges;
  }
}
