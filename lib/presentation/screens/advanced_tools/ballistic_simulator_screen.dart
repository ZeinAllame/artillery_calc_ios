import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/theme_provider.dart';

class BallisticSimulatorScreen extends StatefulWidget {
  const BallisticSimulatorScreen({Key? key}) : super(key: key);
  @override
  State<BallisticSimulatorScreen> createState() => _BallisticSimulatorScreenState();
}

class _BallisticSimulatorScreenState extends State<BallisticSimulatorScreen> {
  final _rangeCtrl = TextEditingController(text: '5000');
  final _elevationCtrl = TextEditingController(text: '300');
  final _tofCtrl = TextEditingController(text: '30');
  final _windSpeedCtrl = TextEditingController(text: '5');
  final _windDirCtrl = TextEditingController(text: '90');
  
  bool _showTrajectory = true;
  bool _showApex = true;
  bool _showDangerZone = true;
  bool _showGrid = true;
  
  double _maxHeight = 0;
  double _impactPoint = 0;
  double _flightTime = 0;
  double _apexDistance = 0;
  double _dangerRadius = 0;

  @override
  void initState() {
    super.initState();
    _calculateTrajectory();
  }

  void _calculateTrajectory() {
    final range = double.tryParse(_rangeCtrl.text) ?? 0;
    final elevation = double.tryParse(_elevationCtrl.text) ?? 0;
    final tof = double.tryParse(_tofCtrl.text) ?? 0;
    final windSpeed = double.tryParse(_windSpeedCtrl.text) ?? 0;
    
    if (range <= 0 || elevation <= 0 || tof <= 0) return;

    // حسابات Ballistic حقيقية
    final elevationRad = (elevation * pi) / 6400;
    final g = 9.81;
    
    // السرعة الابتدائية التقريبية
    final v0 = range / (tof * cos(elevationRad));
    
    // أقصى ارتفاع (Apex)
    _maxHeight = (v0 * v0 * sin(elevationRad) * sin(elevationRad)) / (2 * g);
    
    // نقطة الذروة (نصف المسافة تقريباً)
    _apexDistance = range / 2;
    
    // تأثير الرياح على نقطة السقوط
    final windEffect = windSpeed * tof * 0.3;
    _impactPoint = range + windEffect;
    
    // زمن الطيران
    _flightTime = tof;
    
    // منطقة الخطر الجانبية (Danger Close) - 50م لكل 1000م مدى
    _dangerRadius = (range / 1000) * 50;

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('محاكي الرمي 3D'),
        backgroundColor: colors['surface'],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // الرسم البياني للمسار
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: colors['surface'],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors['border']!),
              ),
              child: CustomPaint(
                painter: _TrajectoryPainter(
                  maxHeight: _maxHeight,
                  impactPoint: _impactPoint,
                  apexDistance: _apexDistance,
                  dangerRadius: _dangerRadius,
                  showTrajectory: _showTrajectory,
                  showApex: _showApex,
                  showDangerZone: _showDangerZone,
                  showGrid: _showGrid,
                  colors: colors,
                ),
                child: Container(),
              ),
            ),
            const SizedBox(height: 16),

            // بيانات المسار
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors['surface'],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('بيانات المسار', 
                      style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildDataRow('أقصى ارتفاع (Apex)', '${_maxHeight.toStringAsFixed(0)} م', Icons.height, colors),
                  _buildDataRow('نقطة الذروة', '${_apexDistance.toStringAsFixed(0)} م', Icons.flag, colors),
                  _buildDataRow('نقطة السقوط', '${_impactPoint.toStringAsFixed(0)} م', Icons.location_on, colors),
                  _buildDataRow('زمن الطيران', '${_flightTime.toStringAsFixed(1)} ث', Icons.timer, colors),
                  _buildDataRow('منطقة الخطر', '±${_dangerRadius.toStringAsFixed(0)} م', Icons.warning, colors),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // إعدادات المحاكاة
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors['surface'],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors['border']!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إعدادات الرمي', 
                      style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildInput('المدى (م)', _rangeCtrl, colors)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildInput('الارتفاع (مل)', _elevationCtrl, colors)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildInput('زمن الطيران (ث)', _tofCtrl, colors)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildInput('سرعة الرياح (م/ث)', _windSpeedCtrl, colors)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInput('اتجاه الرياح (ملة)', _windDirCtrl, colors),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      _calculateTrajectory();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تحديث المحاكاة'), backgroundColor: Colors.green),
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة الحساب'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors['primary'],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // خيارات العرض
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors['surface'],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('خيارات العرض', 
                      style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('إظهار المسار'),
                    value: _showTrajectory,
                    activeColor: colors['primary'],
                    onChanged: (v) => setState(() => _showTrajectory = v),
                  ),
                  SwitchListTile(
                    title: const Text('إظهار نقطة الذروة'),
                    value: _showApex,
                    activeColor: colors['primary'],
                    onChanged: (v) => setState(() => _showApex = v),
                  ),
                  SwitchListTile(
                    title: const Text('إظهار منطقة الخطر'),
                    value: _showDangerZone,
                    activeColor: colors['primary'],
                    onChanged: (v) => setState(() => _showDangerZone = v),
                  ),
                  SwitchListTile(
                    title: const Text('إظهار الشبكة'),
                    value: _showGrid,
                    activeColor: colors['primary'],
                    onChanged: (v) => setState(() => _showGrid = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value, IconData icon, Map<String, Color> colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: colors['primary'], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(color: colors['text']?.withOpacity(0.8), fontSize: 14)),
          ),
          Text(value, style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, Map<String, Color> colors) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: TextStyle(color: colors['text']),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _TrajectoryPainter extends CustomPainter {
  final double maxHeight;
  final double impactPoint;
  final double apexDistance;
  final double dangerRadius;
  final bool showTrajectory;
  final bool showApex;
  final bool showDangerZone;
  final bool showGrid;
  final Map<String, Color> colors;

  _TrajectoryPainter({
    required this.maxHeight,
    required this.impactPoint,
    required this.apexDistance,
    required this.dangerRadius,
    required this.showTrajectory,
    required this.showApex,
    required this.showDangerZone,
    required this.showGrid,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 2;
    final textPainter = TextPainter(textDirection: TextDirection.rtl);
    
    // رسم الشبكة
    if (showGrid) {
      paint.color = colors['border']!.withOpacity(0.3);
      paint.strokeWidth = 1;
      for (int i = 1; i < 10; i++) {
        final x = size.width * i / 10;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (int i = 1; i < 5; i++) {
        final y = size.height * i / 5;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }

    // حساب النقاط
    final startX = size.width * 0.1;
    final endX = size.width * 0.9;
    final groundY = size.height * 0.85;
    final apexY = size.height * 0.15;
    
    final scaleX = (endX - startX) / (impactPoint * 1.2);
    final scaleY = (groundY - apexY) / (maxHeight * 1.3);

    // رسم منطقة الخطر
    if (showDangerZone) {
      paint.color = Colors.red.withOpacity(0.1);
      paint.style = PaintingStyle.fill;
      final dangerWidth = dangerRadius * scaleX;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(endX, groundY),
          width: dangerWidth * 2,
          height: size.height * 0.3,
        ),
        paint,
      );
      
      paint.color = Colors.red.withOpacity(0.5);
      paint.strokeWidth = 2;
      paint.style = PaintingStyle.stroke;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(endX, groundY),
          width: dangerWidth * 2,
          height: size.height * 0.3,
        ),
        paint,
      );
    }

    // رسم المسار
    if (showTrajectory) {
      paint.color = colors['primary']!;
      paint.strokeWidth = 3;
      paint.style = PaintingStyle.stroke;
      
      final path = Path();
      path.moveTo(startX, groundY);
      
      for (double t = 0; t <= 1; t += 0.01) {
        final x = startX + (endX - startX) * t;
        final y = groundY - 4 * (groundY - apexY) * t * (1 - t);
        path.lineTo(x, y);
      }
      
      canvas.drawPath(path, paint);
    }

    // رسم نقطة المدفع
    paint.color = colors['primary']!;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(startX, groundY), 8, paint);
    
    textPainter.text = TextSpan(
      text: 'المدفع',
      style: TextStyle(color: colors['text'], fontSize: 12, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(startX - 20, groundY + 12));

    // رسم نقطة الهدف
    paint.color = Colors.red;
    canvas.drawCircle(Offset(endX, groundY), 8, paint);
    
    textPainter.text = TextSpan(
      text: 'الهدف',
      style: TextStyle(color: colors['text'], fontSize: 12, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(endX - 20, groundY + 12));

    // رسم نقطة الذروة
    if (showApex) {
      final apexX = startX + (apexDistance / impactPoint) * (endX - startX);
      final apexYPos = groundY - (maxHeight * scaleY);
      
      paint.color = Colors.orange;
      canvas.drawCircle(Offset(apexX, apexYPos), 6, paint);
      
      // خط عمودي للذروة
      paint.color = Colors.orange.withOpacity(0.5);
      paint.strokeWidth = 1;
      paint.style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(apexX, apexYPos),
        Offset(apexX, groundY),
        paint,
      );
      
      textPainter.text = TextSpan(
        text: 'الذروة: ${maxHeight.toStringAsFixed(0)}م',
        style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(apexX - 40, apexYPos - 20));
    }

    // رسم الأرض
    paint.color = colors['text']!.withOpacity(0.3);
    paint.strokeWidth = 2;
    paint.style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, groundY), Offset(size.width, groundY), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}