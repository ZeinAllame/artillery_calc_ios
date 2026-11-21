import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/theme_provider.dart';

class VoiceCommandScreen extends StatefulWidget {
  const VoiceCommandScreen({Key? key}) : super(key: key);
  @override
  State<VoiceCommandScreen> createState() => _VoiceCommandScreenState();
}

class _VoiceCommandScreenState extends State<VoiceCommandScreen> {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  double _speechRate = 0.5;
  double _pitch = 1.0;
  double _volume = 1.0;
  
  String _gunName = "مدفع واحد";
  String _charge = "---";
  String _azimuth = "---";
  String _elevation = "---";
  String _target = "---";
  String _shellType = "مهداد";
  String _distance = "---";
  String _tof = "---";

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadLastFireData();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("ar-IQ");
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(_pitch);
    await _tts.setVolume(_volume);
    
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  Future<void> _loadLastFireData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _charge = prefs.getString('last_charge') ?? "---";
        _azimuth = prefs.getString('last_azimuth') ?? "---";
        _elevation = prefs.getString('last_elevation') ?? "---";
        _distance = prefs.getString('last_distance') ?? "---";
        _tof = prefs.getString('last_tof') ?? "---";
        final shell = prefs.getString('last_shell_type') ?? 'he';
        _shellType = shell == 'he' ? 'مهداد' : shell == 'smoke' ? 'دخان' : shell == 'illum' ? 'تنوير' : 'مهداد';
        final tgt = prefs.getString('last_tgt_mgrs') ?? '';
        _target = tgt.isNotEmpty ? tgt : '---';
      });
    }
  }

  String _numberToIraqiText(String number) {
    if (number == "---") return "غير محدد";
    number = number.replaceAll('.', ' فاصلة ');
    final words = number.split(' ');
    final iraqiWords = words.map((word) {
      switch (word) {
        case '0': return 'صفر';
        case '1': return 'واحد';
        case '2': return 'اثنين';
        case '3': return 'ثلاثة';
        case '4': return 'أربعة';
        case '5': return 'خمسة';
        case '6': return 'ستة';
        case '7': return 'سبعة';
        case '8': return 'ثمانية';
        case '9': return 'تسعة';
        case 'فاصلة': return 'فاصلة';
        default: return word;
      }
    }).toList();
    return iraqiWords.join(' ');
  }

  Future<void> _speakCommand() async {
    if (_isSpeaking) {
      await _tts.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }

    String command = "";
    command += "أمر رمي. ";
    command += "$_gunName. ";
    if (_charge != "---") command += "حشوة $_charge. ";
    if (_azimuth != "---") command += "اتجاه ${_numberToIraqiText(_azimuth)}. ";
    if (_elevation != "---") command += "ارتفاع ${_numberToIraqiText(_elevation)}. ";
    command += "عتاد $_shellType. ";
    if (_target != "---") command += "هدف: $_target. ";
    command += "نار!";

    if (mounted) setState(() => _isSpeaking = true);
    await _tts.speak(command);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors['surface'],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors['primary']!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الأمر الحالي:', 
                  style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildCommandRow('المدفع', _gunName, colors),
              _buildCommandRow('الحشوة', _charge, colors),
              _buildCommandRow('الاتجاه', _azimuth, colors),
              _buildCommandRow('الارتفاع', _elevation, colors),
              _buildCommandRow('العتاد', _shellType, colors),
              _buildCommandRow('المسافة', _distance, colors),
              _buildCommandRow('زمن الطيران', _tof, colors),
              _buildCommandRow('الهدف', _target, colors),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _speakCommand,
          icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up, size: 28),
          label: Text(_isSpeaking ? 'إيقاف' : 'نطق الأمر', 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isSpeaking ? Colors.red : colors['primary'],
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors['surface'],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إعدادات الصوت', 
                  style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildSlider('سرعة الكلام', _speechRate, 0.3, 1.0, (val) {
                setState(() => _speechRate = val);
                _tts.setSpeechRate(val);
              }, colors),
              _buildSlider('حدة الصوت', _pitch, 0.5, 2.0, (val) {
                setState(() => _pitch = val);
                _tts.setPitch(val);
              }, colors),
              _buildSlider('مستوى الصوت', _volume, 0.0, 1.0, (val) {
                setState(() => _volume = val);
                _tts.setVolume(val);
              }, colors),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors['warning']!.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors['warning']!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: colors['warning']),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '💡 ملاحظة: يجب إجراء عملية حساب في "حاسبة الرمي" أولاً حتى تظهر البيانات هنا. البيانات تُحدّث تلقائياً بعد كل عملية حساب.',
                  style: TextStyle(color: colors['text']?.withOpacity(0.8), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommandRow(String label, String value, Map<String, Color> colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 14)),
          Expanded(
            child: Text(value, 
                style: TextStyle(color: colors['text'], fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, 
      Function(double) onChanged, Map<String, Color> colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: colors['text'], fontSize: 14)),
            Text(value.toStringAsFixed(2), 
                style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: colors['primary'],
          inactiveColor: colors['text']?.withOpacity(0.3),
          onChanged: onChanged,
        ),
      ],
    );
  }
}