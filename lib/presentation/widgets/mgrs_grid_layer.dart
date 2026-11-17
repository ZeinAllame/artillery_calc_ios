import 'dart:ui' as ui;
import 'dart:math' as math; // 👈 ضروري لـ Point<double>
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart';

class MgrsGridLayer extends StatelessWidget {
  final Color lineColor;
  final Color labelColor;
  final double labelFontSize;
  final bool showLabels;

  const MgrsGridLayer({
    super.key,
    this.lineColor = const Color(0x80FFFFFF),
    this.labelColor = Colors.white,
    this.labelFontSize = 10,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _MgrsGridPainter(
            camera: camera,
            lineColor: lineColor,
            labelColor: labelColor,
            labelFontSize: labelFontSize,
            showLabels: showLabels,
          ),
        ),
      ),
    );
  }
}

class _MgrsGridPainter extends CustomPainter {
  final MapCamera camera;
  final Color lineColor;
  final Color labelColor;
  final double labelFontSize;
  final bool showLabels;

  _MgrsGridPainter({
    required this.camera,
    required this.lineColor,
    required this.labelColor,
    required this.labelFontSize,
    required this.showLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    if (camera.zoom < 5) return;

    double interval;
    if (camera.zoom >= 15) {
      interval = 100;
    } else if (camera.zoom >= 13) {
      interval = 200;
    } else if (camera.zoom >= 11) {
      interval = 500;
    } else if (camera.zoom >= 9) {
      interval = 1000;
    } else if (camera.zoom >= 7) {
      interval = 5000;
    } else {
      interval = 10000;
    }

    final bounds = camera.visibleBounds;
    final center = camera.center;

    int zoneNum;
    String zoneLetter;
    try {
      final mgrs = Mgrs.forward([center.longitude, center.latitude], 1);
      final match = RegExp(r'^(\d{1,2})([A-Z])').firstMatch(mgrs);
      if (match == null) return;
      zoneNum = int.parse(match.group(1)!);
      zoneLetter = match.group(2)!;
    } catch (_) {
      return;
    }

    try {
      final swUtm = Mgrs.LLtoUTM(bounds.south, bounds.west);
      final neUtm = Mgrs.LLtoUTM(bounds.north, bounds.east);
      final nwUtm = Mgrs.LLtoUTM(bounds.north, bounds.west);
      final seUtm = Mgrs.LLtoUTM(bounds.south, bounds.east);

      final eastings = [swUtm.easting, neUtm.easting, nwUtm.easting, seUtm.easting];
      final northings = [swUtm.northing, neUtm.northing, nwUtm.northing, seUtm.northing];
      final minE = eastings.reduce((a, b) => a < b ? a : b);
      final maxE = eastings.reduce((a, b) => a > b ? a : b);
      final minN = northings.reduce((a, b) => a < b ? a : b);
      final maxN = northings.reduce((a, b) => a > b ? a : b);

      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      final labelStyle = TextStyle(
        color: labelColor,
        fontSize: labelFontSize,
        fontWeight: FontWeight.w600,
        backgroundColor: const Color(0x80000000),
      );

      // ============ الخطوط العمودية (Easting ثابت) ============
      final firstE = (minE / interval).floor() * interval;
      for (double e = firstE; e <= maxE; e += interval) {
        final screenPoints = <Offset>[];
        const samples = 15;
        for (int i = 0; i <= samples; i++) {
          final n = minN + (maxN - minN) * i / samples;
          try {
            final utm = UTM(
              easting: e,
              northing: n,
              zoneNumber: zoneNum,
              zoneLetter: zoneLetter,
            );
            final latLng = _utmToLatLng(utm);
            if (latLng == null) continue;
            // ✅ التصحيح: استخدام latLngToScreenPoint بدلاً من latLngToScreenOffset
            final math.Point<double> point = camera.latLngToScreenPoint(latLng);
            screenPoints.add(Offset(point.x, point.y));
          } catch (_) {}
        }
        if (screenPoints.length < 2) continue;

        final path = ui.Path()..moveTo(screenPoints[0].dx, screenPoints[0].dy);
        for (int i = 1; i < screenPoints.length; i++) {
          path.lineTo(screenPoints[i].dx, screenPoints[i].dy);
        }
        canvas.drawPath(path, linePaint);

        if (showLabels) {
          Offset? best;
          for (final pt in screenPoints) {
            if (pt.dx >= 0 && pt.dx <= size.width && pt.dy >= 0 && pt.dy <= size.height) {
              if (best == null || pt.dy < best.dy) best = pt;
            }
          }
          if (best != null) {
            _drawLabel(canvas, labelStyle, _fmt(e), best + const Offset(2, 2));
          }
        }
      }

      // ============ الخطوط الأفقية (Northing ثابت) ============
      final firstN = (minN / interval).floor() * interval;
      for (double n = firstN; n <= maxN; n += interval) {
        final screenPoints = <Offset>[];
        const samples = 15;
        for (int i = 0; i <= samples; i++) {
          final e = minE + (maxE - minE) * i / samples;
          try {
            final utm = UTM(
              easting: e,
              northing: n,
              zoneNumber: zoneNum,
              zoneLetter: zoneLetter,
            );
            final latLng = _utmToLatLng(utm);
            if (latLng == null) continue;
            // ✅ التصحيح: استخدام latLngToScreenPoint
            final math.Point<double> point = camera.latLngToScreenPoint(latLng);
            screenPoints.add(Offset(point.x, point.y));
          } catch (_) {}
        }
        if (screenPoints.length < 2) continue;

        final path = ui.Path()..moveTo(screenPoints[0].dx, screenPoints[0].dy);
        for (int i = 1; i < screenPoints.length; i++) {
          path.lineTo(screenPoints[i].dx, screenPoints[i].dy);
        }
        canvas.drawPath(path, linePaint);

        if (showLabels) {
          Offset? best;
          for (final pt in screenPoints) {
            if (pt.dx >= 0 && pt.dx <= size.width && pt.dy >= 0 && pt.dy <= size.height) {
              if (best == null || pt.dx < best.dx) best = pt;
            }
          }
          if (best != null) {
            _drawLabel(canvas, labelStyle, _fmt(n), best + const Offset(2, 2));
          }
        }
      }
    } catch (_) {
      // تجاهل أخطاء التحويل
    }
  }

  LatLng? _utmToLatLng(UTM utm) {
    try {
      final result = Mgrs.UTMtoLL(utm);
      if (result is LonLat) {
        return LatLng(result.lat, result.lon);
      }
      if (result is List<double>) {
        return LatLng(result[1], result[0]);
      }
    } catch (_) {}
    return null;
  }

  String _fmt(double val) {
    final s = val.truncate().toString();
    if (s.length > 5) return s.substring(s.length - 5);
    return s;
  }

  void _drawLabel(Canvas canvas, TextStyle style, String text, Offset position) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, position);
  }

  @override
  bool shouldRepaint(_MgrsGridPainter old) {
    return old.camera.center != camera.center ||
        old.camera.zoom != camera.zoom ||
        old.lineColor != lineColor ||
        old.labelColor != labelColor;
  }
}