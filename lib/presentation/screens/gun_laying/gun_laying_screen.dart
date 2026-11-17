import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // جديد
import '../../../theme/theme_provider.dart';

class GunLayingScreen extends StatefulWidget {
  const GunLayingScreen({Key? key}) : super(key: key);

  @override
  State<GunLayingScreen> createState() => _GunLayingScreenState();
}

class _GunLayingScreenState extends State<GunLayingScreen> {
  double? _magneticHeading;
  double _gridHeading = 0.0;
  double _gmAngle = 0.0;
  double _pitch = 0.0;
  int selectedUnit = 6400;
  bool _hasInterference = false;

  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  @override
  void initState() {
    super.initState();
    _loadGmAngle();
    
    _compassSub = FlutterCompass.events?.listen((event) {
      if (event.heading != null && mounted) {
        setState(() {
          _magneticHeading = (event.heading! + 360) % 360;
          // الاتجاه الشبكي = الاتجاه المغناطيسي + زاوية الانحراف
          _gridHeading = (_magneticHeading! + _gmAngle + 360) % 360;
          _hasInterference = event.accuracy != null && event.accuracy! < 3;
        });
      }
    });

    _accelSub = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      double pitchRad = math.atan2(event.y, math.sqrt(event.x * event.x + event.z * event.z));
      setState(() => _pitch = (pitchRad * 180 / math.pi).abs());
    });
  }

  Future<void> _loadGmAngle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _gmAngle = prefs.getDouble('g_m_angle') ?? 0.0;
    });
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }

  String _formatAngle(double degrees) {
    if (selectedUnit == 360) return "${degrees.toStringAsFixed(1)}°";
    return "${(degrees * (selectedUnit / 360.0)).toStringAsFixed(0)} مل";
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('توجيه المدفع (Gun Laying)'),
        backgroundColor: colors['surface'],
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              dropdownColor: colors['surface'],
              value: selectedUnit,
              style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold),
              items: const [
                DropdownMenuItem(value: 6400, child: Text('ملات 6400')),
                DropdownMenuItem(value: 6000, child: Text('ملات 6000')),
                DropdownMenuItem(value: 360, child: Text('درجات 360')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => selectedUnit = val);
              },
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          if (_hasInterference)
            Container(
              width: double.infinity,
              color: Colors.red,
              padding: const EdgeInsets.all(8),
              child: const Text(
                "⚠️ تداخل مغناطيسي قريب - يرجى إبعاد الهاتف عن المعادن",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            color: colors['surface'],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Icon(Icons.height, color: colors['warning'], size: 40),
                    Text("زاوية السبطانة", style: TextStyle(color: colors['text'], fontSize: 14)),
                    Text(_formatAngle(_pitch), style: TextStyle(color: colors['warning'], fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.explore, color: colors['primary'], size: 40),
                    Text("الاتجاه الشبكي (Grid)", style: TextStyle(color: colors['text'], fontSize: 14)),
                    Text(_formatAngle(_gridHeading), style: TextStyle(color: colors['primary'], fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 320,
                height: 320,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: -_gridHeading * math.pi / 180, // نستخدم الاتجاه الشبكي
                      child: CustomPaint(
                        size: const Size(320, 320),
                        painter: NumberedCompassPainter(colors: colors, milsFullCircle: selectedUnit),
                      ),
                    ),
                    Icon(Icons.arrow_drop_up, color: colors['danger'], size: 50),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class NumberedCompassPainter extends CustomPainter {
  final Map<String, Color> colors;
  final int milsFullCircle;
  NumberedCompassPainter({required this.colors, required this.milsFullCircle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = colors['primary']!;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    canvas.drawCircle(center, radius - 10, paint);

    int step = milsFullCircle == 360 ? 30 : (milsFullCircle == 6400 ? 400 : 300);
    
    for (int i = 0; i < milsFullCircle; i += step) {
      double angle = ((i / milsFullCircle) * 2 * math.pi) - (math.pi / 2);
      
      final p1 = Offset(center.dx + (radius - 10) * math.cos(angle), center.dy + (radius - 10) * math.sin(angle));
      final p2 = Offset(center.dx + (radius - 25) * math.cos(angle), center.dy + (radius - 25) * math.sin(angle));
      canvas.drawLine(p1, p2, paint);

      textPainter.text = TextSpan(
        text: "$i", 
        style: TextStyle(color: colors['text'], fontSize: 14, fontWeight: FontWeight.bold)
      );
      textPainter.layout();
      textPainter.paint(
        canvas, 
        Offset(
          center.dx + (radius - 45) * math.cos(angle) - (textPainter.width / 2), 
          center.dy + (radius - 45) * math.sin(angle) - (textPainter.height / 2)
        )
      );
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 