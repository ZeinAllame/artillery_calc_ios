import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../../theme/theme_provider.dart';

class ArSightsScreen extends StatefulWidget {
  const ArSightsScreen({Key? key}) : super(key: key);

  @override
  State<ArSightsScreen> createState() => _ArSightsScreenState();
}

class _ArSightsScreenState extends State<ArSightsScreen> {
  CameraController? _cameraController;
  double? _heading;
  double _pitch = 0.0;
  StreamSubscription? _compassSub;
  StreamSubscription? _accelSub;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initSensors();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  void _initSensors() {
    _compassSub = FlutterCompass.events?.listen((event) {
      if (event.heading != null && mounted) {
        setState(() => _heading = event.heading);
      }
    });
    _accelSub = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      double pitchRad = math.atan2(event.y, math.sqrt(event.x * event.x + event.z * event.z));
      setState(() => _pitch = (pitchRad * 180 / math.pi).abs());
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _compassSub?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. بث الكاميرا
          if (_cameraController != null && _cameraController!.value.isInitialized)
            Positioned.fill(child: CameraPreview(_cameraController!))
          else
            const Center(child: CircularProgressIndicator()),

          // 2. شبكة التصويب (HUD)
          Center(
            child: CustomPaint(
              size: const Size(200, 200),
              painter: ReticlePainter(colors: colors),
            ),
          ),

          // 3. بيانات البوصلة والزاوية
          Positioned(
            top: 50, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHudText("HDG: ${_heading?.toStringAsFixed(0) ?? '--'}°", colors['primary']!),
                _buildHudText("ELV: ${_pitch.toStringAsFixed(1)}°", colors['warning']!),
              ],
            ),
          ),

          // 4. خط الأفق
          Center(
            child: Container(
              height: 2, width: double.infinity,
              color: colors['primary']!.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHudText(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
    );
  }
}

class ReticlePainter extends CustomPainter {
  final Map<String, Color> colors;
  ReticlePainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = colors['primary']!..strokeWidth = 2..style = PaintingStyle.stroke;
    final center = Offset(size.width / 2, size.height / 2);

    // الدائرة المركزية
    canvas.drawCircle(center, 40, paint);
    // التقاطع
    canvas.drawLine(Offset(center.dx - 60, center.dy), Offset(center.dx - 20, center.dy), paint);
    canvas.drawLine(Offset(center.dx + 20, center.dy), Offset(center.dx + 60, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - 60), Offset(center.dx, center.dy - 20), paint);
    canvas.drawLine(Offset(center.dx, center.dy + 20), Offset(center.dx, center.dy + 60), paint);
    // النقطة الحمراء
    canvas.drawCircle(center, 2, Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}