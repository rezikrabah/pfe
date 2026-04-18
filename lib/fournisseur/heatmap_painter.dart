import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

class HeatmapData {
  final LatLng  position;
  final double  weight; // 1.0 default, higher = more influence
  const HeatmapData(this.position, {this.weight = 1.0});
}

class HeatmapLayer extends StatelessWidget {
  final List<HeatmapData> points;
  final MapCamera         camera;
  final double            radius;     // influence radius in pixels
  final double            opacity;

  const HeatmapLayer({
    super.key,
    required this.points,
    required this.camera,
    this.radius  = 60.0,
    this.opacity = 0.75,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Opacity(
      opacity: opacity,
      child: CustomPaint(
        size: size,
        painter: _HeatmapPainter(
          points: points,
          camera: camera,
          radius: radius,
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<HeatmapData> points;
  final MapCamera         camera;
  final double            radius;

  _HeatmapPainter({
    required this.points,
    required this.camera,
    required this.radius,
  });

  // ── Convert LatLng → screen pixel offset ──────────────────────
  Offset _toOffset(LatLng ll, Size size) {
    final projected = camera.project(ll);
    final origin    = camera.project(camera.center);
    final dx = projected.x - origin.x + size.width  / 2;
    final dy = projected.y - origin.y + size.height / 2;
    return Offset(dx, dy);
  }

  // ── Map 0–1 heat value to colour ──────────────────────────────
  // cold (blue) → cyan → green → yellow → hot (red)
  Color _heatColor(double t) {
    t = t.clamp(0.0, 1.0);
    if (t < 0.25) {
      return Color.lerp(
        const Color(0xFF0000FF), // blue
        const Color(0xFF00FFFF), // cyan
        t / 0.25,
      )!;
    } else if (t < 0.5) {
      return Color.lerp(
        const Color(0xFF00FFFF), // cyan
        const Color(0xFF00FF00), // green
        (t - 0.25) / 0.25,
      )!;
    } else if (t < 0.75) {
      return Color.lerp(
        const Color(0xFF00FF00), // green
        const Color(0xFFFFFF00), // yellow
        (t - 0.5) / 0.25,
      )!;
    } else {
      return Color.lerp(
        const Color(0xFFFFFF00), // yellow
        const Color(0xFFFF0000), // red
        (t - 0.75) / 0.25,
      )!;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // ── 1. Project all points to screen space ────────────────────
    final List<({Offset offset, double weight})> screenPts = points
        .map((p) => (offset: _toOffset(p.position, size), weight: p.weight))
        .toList();

    // ── 2. Build a low-res heat grid (every 4px cell) ───────────
    const int cellSize = 4;
    final int cols = (size.width  / cellSize).ceil() + 1;
    final int rows = (size.height / cellSize).ceil() + 1;
    final grid = List.generate(rows, (_) => List.filled(cols, 0.0));

    for (final pt in screenPts) {
      final cx = pt.offset.dx;
      final cy = pt.offset.dy;
      final w  = pt.weight;

      // Only touch cells within radius
      final minCol = math.max(0, ((cx - radius) / cellSize).floor());
      final maxCol = math.min(cols - 1, ((cx + radius) / cellSize).ceil());
      final minRow = math.max(0, ((cy - radius) / cellSize).floor());
      final maxRow = math.min(rows - 1, ((cy + radius) / cellSize).ceil());

      for (int r = minRow; r <= maxRow; r++) {
        for (int c = minCol; c <= maxCol; c++) {
          final px = c * cellSize + cellSize / 2;
          final py = r * cellSize + cellSize / 2;
          final dist = math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
          if (dist < radius) {
            // Gaussian-ish falloff: 1 at centre → 0 at radius
            final influence = w * math.pow(1.0 - dist / radius, 2);
            grid[r][c] += influence;
          }
        }
      }
    }

    // ── 3. Find max for normalisation ────────────────────────────
    double maxVal = 0;
    for (final row in grid) {
      for (final v in row) {
        if (v > maxVal) maxVal = v;
      }
    }
    if (maxVal == 0) return;

    // ── 4. Paint each cell ───────────────────────────────────────
    final paint = Paint()..style = PaintingStyle.fill;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final v = grid[r][c];
        if (v < 0.01) continue; // skip empty cells

        final t     = (v / maxVal).clamp(0.0, 1.0);
        final color = _heatColor(t);
        // Alpha: invisible at 0, fully opaque at high density
        final alpha = (t * 220).round().clamp(0, 220);

        paint.color = color.withAlpha(alpha);
        canvas.drawRect(
          Rect.fromLTWH(
            (c * cellSize).toDouble(),
            (r * cellSize).toDouble(),
            cellSize.toDouble(),
            cellSize.toDouble(),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.points != points ||
          old.camera.center != old.camera.center ||
          old.camera.zoom   != old.camera.zoom;
}