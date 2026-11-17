import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_provider.dart';

class WeatherDialog extends StatefulWidget {
  final double initialTemp;
  final double initialPressure;
  final double initialWindSpeed;
  final double initialWindDir;
  final Function(double temp, double pressure, double windSpeed, double windDir) onSave;

  const WeatherDialog({
    Key? key,
    required this.initialTemp,
    required this.initialPressure,
    required this.initialWindSpeed,
    required this.initialWindDir,
    required this.onSave,
  }) : super(key: key);

  @override
  State<WeatherDialog> createState() => _WeatherDialogState();
}

class _WeatherDialogState extends State<WeatherDialog> {
  late TextEditingController tempCtrl;
  late TextEditingController pressCtrl;
  late TextEditingController windSpdCtrl;
  late TextEditingController windDirCtrl;

  @override
  void initState() {
    super.initState();
    tempCtrl = TextEditingController(text: widget.initialTemp.toString());
    pressCtrl = TextEditingController(text: widget.initialPressure.toString());
    windSpdCtrl = TextEditingController(text: widget.initialWindSpeed.toString());
    windDirCtrl = TextEditingController(text: widget.initialWindDir.toString());
  }

  @override
  void dispose() {
    tempCtrl.dispose();
    pressCtrl.dispose();
    windSpdCtrl.dispose();
    windDirCtrl.dispose();
    super.dispose();
  }

  void _setStandardISA() {
    setState(() {
      tempCtrl.text = "15"; // 15 درجة مئوية
      pressCtrl.text = "1013"; // 1013 هيكتوباسكال
      windSpdCtrl.text = "0";
      windDirCtrl.text = "0";
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    return AlertDialog(
      backgroundColor: colors['surface'],
      title: Text('البرقية الجوية (Weather)', style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildField("الحرارة (C°)", tempCtrl, colors),
            const SizedBox(height: 10),
            _buildField("الضغط (hPa)", pressCtrl, colors),
            const SizedBox(height: 10),
            _buildField("سرعة الريح (م/ث)", windSpdCtrl, colors),
            const SizedBox(height: 10),
            _buildField("اتجاه الريح (ملة/درجة)", windDirCtrl, colors),
            const SizedBox(height: 15),
            TextButton.icon(
              onPressed: _setStandardISA,
              icon: const Icon(Icons.restart_alt, color: Colors.orange),
              label: const Text("إعادة للظروف القياسية (ISA)", style: TextStyle(color: Colors.orange)),
            )
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: colors['primary']),
          onPressed: () {
            final t = double.tryParse(tempCtrl.text) ?? 15.0;
            final p = double.tryParse(pressCtrl.text) ?? 1013.0;
            final ws = double.tryParse(windSpdCtrl.text) ?? 0.0;
            final wd = double.tryParse(windDirCtrl.text) ?? 0.0;
            widget.onSave(t, p, ws, wd);
            Navigator.pop(context);
          },
          child: const Text('حفظ وتطبيق', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, Map<String, Color> colors) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors['text']?.withOpacity(0.7)),
      ),
      style: TextStyle(color: colors['text']),
    );
  }
}