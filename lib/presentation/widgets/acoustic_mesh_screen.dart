import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:fftea/fftea.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../theme/theme_provider.dart';

class AcousticMeshScreen extends StatefulWidget {
  const AcousticMeshScreen({Key? key}) : super(key: key);
  @override
  State<AcousticMeshScreen> createState() => _AcousticMeshScreenState();
}

class _AcousticMeshScreenState extends State<AcousticMeshScreen> {
  final _msgCtrl = TextEditingController();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  bool _sending = false;
  bool _receiving = false;
  String _status = "جاهز";
  String _received = "";
  StreamSubscription? _recStream;

  // === إعدادات مُحسَّنة للمدى ===
  static const int _sampleRate = 44100;
  static const int _toneDurationMs = 400;   // أطول بكثير = مدى أكبر
  static const int _gapMs = 150;            // فاصل واضح لتمييز النغمات
  static const int _syncFreq = 400;         // تردد منخفض جداً = يصل بعيداً
  static const int _syncDurationMs = 800;
  static const int _baseFreq = 300;         // نطاق الترددات الجديد: 300-1200Hz
  static const int _freqStep = 60;
  static const int _maxNibble = 15;
  static const int _repetitions = 2;        // كل nibble يُرسل مرتين

  // === الإرسال ===
  Future<String> _generateWavTone(int freq, int durationMs) async {
    final numSamples = (_sampleRate * durationMs) ~/ 1000;
    final dataSize = numSamples * 2;
    final bd = ByteData(44 + dataSize);

    bd.setUint32(0, 0x52494646, Endian.big);
    bd.setUint32(4, 36 + dataSize, Endian.little);
    bd.setUint32(8, 0x57415645, Endian.big);
    bd.setUint32(12, 0x666d7420, Endian.big);
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little);
    bd.setUint16(22, 1, Endian.little);
    bd.setUint32(24, _sampleRate, Endian.little);
    bd.setUint32(28, _sampleRate * 2, Endian.little);
    bd.setUint16(32, 2, Endian.little);
    bd.setUint16(34, 16, Endian.little);
    bd.setUint32(36, 0x64617461, Endian.big);
    bd.setUint32(40, dataSize, Endian.little);

    final fadeSamples = (_sampleRate * 0.02).toInt();
    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      double env = 1.0;
      if (i < fadeSamples) {
        env = i / fadeSamples;
      } else if (i > numSamples - fadeSamples) {
        env = (numSamples - i) / fadeSamples;
      }
      // موجة مربعة (أكثر طاقة من الجيبية بنفس الذروة = مدى أطول)
      final s = (sin(2 * pi * freq * t) > 0 ? 1 : -1) * (13000 * env);
      bd.setInt16(44 + i * 2, s.toInt(), Endian.little);
    }

    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/t_${freq}_${DateTime.now().microsecondsSinceEpoch}.wav');
    await f.writeAsBytes(bd.buffer.asUint8List());
    return f.path;
  }

  Future<void> _sendSequence() async {
    if (_msgCtrl.text.isEmpty) return;
    setState(() {
      _sending = true;
      _status = "جاري البث...";
    });

    try {
      // مزامنة (تُكرر 3 مرات لضمان الالتقاط)
      for (int i = 0; i < 3; i++) {
        final p = await _generateWavTone(_syncFreq, _syncDurationMs);
        await _player.play(DeviceFileSource(p));
        await Future.delayed(Duration(milliseconds: _syncDurationMs + 100));
      }

      for (int i = 0; i < _msgCtrl.text.length; i++) {
        final code = _msgCtrl.text.codeUnitAt(i);
        final low = code & 0x0F;
        final high = (code >> 4) & 0x0F;

        // إرسال low nibble مرتين
        for (int r = 0; r < _repetitions; r++) {
          final p = await _generateWavTone(_baseFreq + low * _freqStep, _toneDurationMs);
          await _player.play(DeviceFileSource(p));
          await Future.delayed(Duration(milliseconds: _toneDurationMs + _gapMs));
        }
        // إرسال high nibble مرتين
        for (int r = 0; r < _repetitions; r++) {
          final p = await _generateWavTone(_baseFreq + high * _freqStep, _toneDurationMs);
          await _player.play(DeviceFileSource(p));
          await Future.delayed(Duration(milliseconds: _toneDurationMs + _gapMs));
        }
      }

      setState(() => _status = "تم إرسال ${_msgCtrl.text.length} حرفاً");
    } catch (e) {
      setState(() => _status = "خطأ: $e");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // === الاستقبال ===
  List<double> _pcmToDouble(Uint8List b) {
    final i16 = Int16List.view(b.buffer, b.offsetInBytes, b.length ~/ 2);
    return List<double>.generate(i16.length, (i) => i16[i] / 32768.0);
  }

  /// المرشح المطابق: يختبر كل الترددات الـ16 ويعيد الأقوى
  int _detectNibble(List<double> window) {
    int n = window.length;
    int pow2 = 1;
    while (pow2 * 2 <= n) pow2 *= 2;
    if (pow2 < 1024) return -1;

    final w = List<double>.from(window.sublist(0, pow2));
    for (int i = 0; i < pow2; i++) {
      w[i] *= 0.5 * (1 - cos(2 * pi * i / (pow2 - 1)));
    }

    final fft = FFT(pow2);
    final mags = fft.realFft(w).discardConjugates().magnitudes();

    int bestNibble = -1;
    double bestMag = 0;
    for (int nibble = 0; nibble <= _maxNibble; nibble++) {
      final freq = _baseFreq + nibble * _freqStep;
      final bin = (freq * pow2 / _sampleRate).round();
      double localMax = 0;
      for (int b = max(1, bin - 2); b <= min(mags.length - 1, bin + 2); b++) {
        if (mags[b] > localMax) localMax = mags[b];
      }
      if (localMax > bestMag) {
        bestMag = localMax;
        bestNibble = nibble;
      }
    }
    return bestNibble == -1 ? -1 : bestNibble;
  }

  double _windowEnergy(List<double> w) {
    double e = 0;
    for (final s in w) {
      e += s * s;
    }
    return sqrt(e / w.length);
  }

  Future<void> _receive() async {
    if (!await _recorder.hasPermission()) return;
    setState(() {
      _receiving = true;
      _status = "جاري الاستماع (60 ثانية)...";
      _received = "";
    });

    try {
      final stream = await _recorder.startStream(const RecordConfig(
        sampleRate: _sampleRate,
        numChannels: 1,
        encoder: AudioEncoder.pcm16bits,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ));

      const int windowSize = 4096;
      const int hopSize = 1024;

      List<double> buffer = [];
      List<int> rawNibbles = []; // النغمات المرشحة (غير مؤكدة)
      List<int> confirmedNibbles = []; // بعد التحقق من التكرار
      int? pendingNibble;
      int pendingCount = 0;
      bool syncFound = false;
      int syncCount = 0;
      double noiseFloor = 0.0;
      int calibrationWindows = 0;
      double calibrationSum = 0;
      int silenceCount = 0;

      _recStream = stream.listen((chunk) {
        buffer.addAll(_pcmToDouble(chunk));

        while (buffer.length >= windowSize) {
          final win = buffer.sublist(0, windowSize);
          buffer.removeRange(0, hopSize);

          // 1. قياس أرضية الضوضاء في أول ثانية
          if (calibrationWindows < 20) {
            calibrationSum += _windowEnergy(win);
            calibrationWindows++;
            noiseFloor = calibrationSum / calibrationWindows;
            continue;
          }

          final energy = _windowEnergy(win);
          if (energy < noiseFloor * 2) {
            // صمت — اسمح بالانتقال للنغمة التالية
            silenceCount++;
            if (silenceCount >= 2) {
              pendingNibble = null;
              pendingCount = 0;
            }
            continue;
          }
          silenceCount = 0;

          // 2. فحص المزامنة
          final nibble = _detectNibble(win);
          if (nibble == -1) continue;

          final detectedFreq = _baseFreq + nibble * _freqStep;
          final isSync = (detectedFreq - _syncFreq).abs() < 80;

          if (isSync) {
            syncCount++;
            if (syncCount >= 3) {
              syncFound = true;
              rawNibbles.clear();
              confirmedNibbles.clear();
            }
            continue;
          }
          syncCount = 0;

          if (!syncFound) continue;

          // 3. منطق التحقق: النغمة يجب أن تظهر مرتين متتاليتين
          if (pendingNibble == null) {
            pendingNibble = nibble;
            pendingCount = 1;
          } else if (pendingNibble == nibble) {
            pendingCount++;
            if (pendingCount >= _repetitions) {
              rawNibbles.add(nibble);
              pendingNibble = null;
              pendingCount = 0;
            }
          } else {
            pendingNibble = nibble;
            pendingCount = 1;
          }
        }

        // تحديث الواجهة عندما يكتمل حرف (nibbles زوجية)
        if (rawNibbles.length >= 2 && rawNibbles.length % 2 == 0) {
          String text = "";
          for (int i = 0; i < rawNibbles.length - 1; i += 2) {
            final low = rawNibbles[i];
            final high = rawNibbles[i + 1];
            final code = (high << 4) | low;
            if (code >= 32 && code <= 126) text += String.fromCharCode(code);
          }
          if (text.isNotEmpty && mounted) {
            setState(() => _received = text);
          }
        }
      });

      await Future.delayed(const Duration(seconds: 60));
      await _recorder.stop();
      _recStream?.cancel();

      if (mounted) {
        setState(() {
          _status = "انتهى (${rawNibbles.length} nibble، ضوضاء: ${noiseFloor.toStringAsFixed(4)})";
          _receiving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = "خطأ: $e";
          _receiving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _recStream?.cancel();
    _recorder.dispose();
    _player.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(title: const Text('النقل الصوتي (مدى مُحسَّن)'), backgroundColor: colors['surface']),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              Text(_status, textAlign: TextAlign.center,
                  style: TextStyle(color: colors['primary'], fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('ترددات 300-1200Hz | نغمات 400ms | تحقق مزدوج',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors['text']?.withOpacity(0.6), fontSize: 10)),
            ]),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _msgCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'النص أو الإحداثيات'),
          ),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            ElevatedButton.icon(
              onPressed: _sending ? null : _sendSequence,
              icon: Icon(_sending ? Icons.wifi_tethering : Icons.volume_up),
              label: Text(_sending ? 'جاري البث...' : 'إرسال'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors['primary'],
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _receiving ? null : _receive,
              icon: Icon(_receiving ? Icons.mic : Icons.mic_none),
              label: Text(_receiving ? 'يستمع (60ث)...' : 'استقبال'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors['danger'],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ]),
          if (_receiving) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(color: colors['primary']),
          ],
          const SizedBox(height: 20),
          if (_received.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors['surface'],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors['primary']!),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("النص المستخرج:", style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(),
                SelectableText(_received, style: TextStyle(color: colors['text'], fontSize: 18, height: 1.5)),
              ]),
            ),
        ]),
      ),
    );
  }
}