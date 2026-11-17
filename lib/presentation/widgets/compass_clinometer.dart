import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_provider.dart';

class CompassClinometer extends StatefulWidget {
  final int selectedUnit;
  final double? targetAzimuth; // لعرض اتجاه الهدف على البوصلة

  const CompassClinometer({Key? key, required this.selectedUnit, this.targetAzimuth}) : super(key: key);

  @override
  State<CompassClinometer> createState() => _CompassClinometerState();
}

class _CompassClinometerState extends State<CompassClinometer> {
  double? _heading;
  double _pitch = 0.0;
  
  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  @override
  void initState() {
    super.initState();
    _compassSub = FlutterCompass.events?.listen((event) {
      if (event.heading != null && mounted) {
        setState(() => _heading = event.heading);
      }
    });

    _accelSub = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      double x = event.x;
      double y = event.y;
      double z = event.z;
      double pitchRad = math.atan2(y, math.sqrt(x * x + z * z));
      double pitchDeg = pitchRad * 180 / math.pi;
      setState(() => _pitch = pitchDeg.abs()); 
    });
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }

  String _formatAngle(double degrees) {
    if (widget.selectedUnit == 360) return "${degrees.toStringAsFixed(1)}°";
    return "${(degrees * (widget.selectedUnit / 360.0)).toStringAsFixed(0)} مل";
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors['surface'],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors['primary']!, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Icon(Icons.height, color: colors['warning'], size: 30),
                  Text("زاوية السبطانة (Elevation)", style: TextStyle(color: colors['text'], fontSize: 12)),
                  Text(_formatAngle(_pitch), style: TextStyle(color: colors['warning'], fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                children: [
                  Icon(Icons.explore, color: colors['primary'], size: 30),
                  Text("الاتجاه (Heading)", style: TextStyle(color: colors['text'], fontSize: 12)),
                  Text(_heading != null ? _formatAngle(_heading!) : "--", style: TextStyle(color: colors['primary'], fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // قرص البوصلة التفاعلي
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: -(_heading ?? 0) * math.pi / 180,
                  child: CustomPaint(
                    size: const Size(200, 200),
                    painter: CompassPainter(colors: colors),
                  ),
                ),
                // مؤشر ثابت في المنتصف
                Icon(Icons.arrow_drop_up, color: colors['danger'], size: 40),
              ],
            ),
          ),
          Text("ضع الهاتف على السبطانة لقراءة الزاوية", style: TextStyle(color: colors['text']?.withOpacity(0.5), fontSize: 10)),
        ],
      ),
    );
  }
}

// رسم قرص البوصلة
class CompassPainter extends CustomPainter {
  final Map<String, Color> colors;
  CompassPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    final paint = Paint()
      ..color = colors['primary']!
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // رسم الدائرة الخارجية
    canvas.drawCircle(center, radius - 10, paint);

    // رسم العلامات (كل 10 درجات)
    for (int i = 0; i < 360; i += 10) {
      final angle = i * math.pi / 180;
      final isMajor = i % 30 == 0;
      final p1 = Offset(center.dx + (radius - 10) * math.cos(angle), center.dy + (radius - 10) * math.sin(angle));
      final p2 = Offset(center.dx + (radius - (isMajor ? 25 : 15)) * math.cos(angle), center.dy + (radius - (isMajor ? 25 : 15)) * math.sin(angle));
      
      paint.color = isMajor ? colors['primary']! : colors['text']!.withOpacity(0.3);
      canvas.drawLine(p1, p2, paint);

      // كتابة الاتجاهات الرئيسية (N, E, S, W)
      if (i % 90 == 0) {
        String text = i == 0 ? "N" : i == 90 ? "E" : i == 180 ? "S" : "W";
        textPainter.text = TextSpan(text: text, style: TextStyle(color: colors['danger'], fontSize: 16, fontWeight: FontWeight.bold));
        textPainter.layout();
        textPainter.paint(canvas, Offset(center.dx + (radius - 40) * math.cos(angle) - 6, center.dy + (radius - 40) * math.sin(angle) - 8));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 