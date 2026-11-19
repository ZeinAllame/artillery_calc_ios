import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
// ★ تم إضافة hide State لمنع التضارب مع Flutter
import 'package:pointycastle/export.dart' hide State; 
import '../../../theme/theme_provider.dart';

class AdvancedEncryptionScreen extends StatefulWidget {
  const AdvancedEncryptionScreen({Key? key}) : super(key: key);
  @override
  State<AdvancedEncryptionScreen> createState() => _AdvancedEncryptionScreenState();
}

class _AdvancedEncryptionScreenState extends State<AdvancedEncryptionScreen> {
  final _plainTextCtrl = TextEditingController();
  final _encryptedTextCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  
  String _currentKey = '';
  DateTime _keyExpiry = DateTime.now();
  bool _isKeyValid = false;
  String _encryptionStatus = 'جاهز';

  @override
  void initState() {
    super.initState();
    _generateNewKey();
  }

  void _generateNewKey() {
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
    _currentKey = base64Encode(keyBytes);
    _keyCtrl.text = _currentKey;
    _keyExpiry = DateTime.now().add(const Duration(hours: 1));
    _isKeyValid = true;
    if (mounted) setState(() => _encryptionStatus = 'تم توليد مفتاح جديد (صالح لمدة ساعة)');
  }

  Uint8List _encryptAES(String plainText, String keyBase64) {
    final keyBytes = base64Decode(keyBase64);
    final iv = Uint8List(16);
    final random = Random.secure();
    for (int i = 0; i < 16; i++) iv[i] = random.nextInt(256);
    
    final params = PaddedBlockCipherParameters(
      ParametersWithIV(KeyParameter(keyBytes), iv), null,
    );
    final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
    cipher.init(true, params);
    
    final plainBytes = utf8.encode(plainText);
    final cipherText = cipher.process(Uint8List.fromList(plainBytes));
    
    final result = Uint8List(16 + cipherText.length);
    result.setRange(0, 16, iv);
    result.setRange(16, result.length, cipherText);
    return result;
  }

  String _decryptAES(String encryptedBase64, String keyBase64) {
    final encryptedBytes = base64Decode(encryptedBase64);
    final keyBytes = base64Decode(keyBase64);
    final iv = encryptedBytes.sublist(0, 16);
    final cipherText = encryptedBytes.sublist(16);
    
    final params = PaddedBlockCipherParameters(
      ParametersWithIV(KeyParameter(keyBytes), iv), null,
    );
    final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
    cipher.init(false, params);
    
    final plainBytes = cipher.process(cipherText);
    return utf8.decode(plainBytes);
  }

  void _encryptMessage() {
    if (_plainTextCtrl.text.isEmpty) {
      if (mounted) setState(() => _encryptionStatus = 'أدخل نصاً للتشفير');
      return;
    }
    if (!_isKeyValid || DateTime.now().isAfter(_keyExpiry)) {
      if (mounted) setState(() => _encryptionStatus = 'المفتاح منتهي - ولّد مفتاحاً جديداً');
      return;
    }
    try {
      final encrypted = _encryptAES(_plainTextCtrl.text, _currentKey);
      final encryptedBase64 = base64Encode(encrypted);
      if (mounted) {
        setState(() {
          _encryptedTextCtrl.text = encryptedBase64;
          _encryptionStatus = 'تم التشفير بنجاح (AES-256)';
        });
        Clipboard.setData(ClipboardData(text: encryptedBase64));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نسخ النص المشفر'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _encryptionStatus = 'خطأ في التشفير: $e');
    }
  }

  void _decryptMessage() {
    if (_encryptedTextCtrl.text.isEmpty) {
      if (mounted) setState(() => _encryptionStatus = 'أدخل نصاً مشفراً');
      return;
    }
    try {
      final decrypted = _decryptAES(_encryptedTextCtrl.text, _currentKey);
      if (mounted) {
        setState(() {
          _plainTextCtrl.text = decrypted;
          _encryptionStatus = 'تم فك التشفير بنجاح';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _encryptionStatus = 'فشل فك التشفير - مفتاح خاطئ أو نص تالف');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final bool isValid = _isKeyValid && DateTime.now().isBefore(_keyExpiry);

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(title: const Text('التشفير المتقدم'), backgroundColor: colors['surface']),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isValid ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isValid ? Colors.green : Colors.red),
              ),
              child: Row(
                children: [
                  Icon(isValid ? Icons.lock : Icons.lock_open, color: isValid ? Colors.green : Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isValid ? 'المفتاح نشط' : 'المفتاح منتهي', 
                            style: TextStyle(color: isValid ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                        Text('ينتهي: ${DateFormat('yyyy-MM-dd HH:mm').format(_keyExpiry)}', 
                            style: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(icon: Icon(Icons.refresh, color: colors['primary']), onPressed: _generateNewKey),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مفتاح التشفير (AES-256)', style: TextStyle(color: colors['primary'], fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _keyCtrl, readOnly: true,
                    style: TextStyle(color: colors['text'], fontSize: 10, fontFamily: 'monospace'), maxLines: 3,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.copy, color: colors['primary']),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _currentKey));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ المفتاح')));
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('النص الأصلي', style: TextStyle(color: colors['primary'], fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(controller: _plainTextCtrl, maxLines: 4, style: TextStyle(color: colors['text']),
                    decoration: InputDecoration(hintText: 'أدخل النص هنا...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: _encryptMessage, icon: const Icon(Icons.lock), label: const Text('تشفير النص'),
              style: ElevatedButton.styleFrom(backgroundColor: colors['primary'], foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('النص المشفر', style: TextStyle(color: colors['primary'], fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _encryptedTextCtrl, maxLines: 4,
                    style: TextStyle(color: colors['text'], fontSize: 10, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'النص المشفر سيظهر هنا...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.paste, color: colors['primary']),
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null && mounted) setState(() => _encryptedTextCtrl.text = data!.text!);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: _decryptMessage, icon: const Icon(Icons.lock_open), label: const Text('فك تشفير النص'),
              style: ElevatedButton.styleFrom(backgroundColor: colors['warning'], foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(Icons.info_outline, color: colors['primary']), const SizedBox(width: 8),
                Expanded(child: Text(_encryptionStatus, style: TextStyle(color: colors['text'], fontSize: 12))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}