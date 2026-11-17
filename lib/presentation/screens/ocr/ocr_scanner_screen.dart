import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../theme/theme_provider.dart';

class OcrScannerScreen extends StatefulWidget {
  const OcrScannerScreen({Key? key}) : super(key: key);
  @override
  State<OcrScannerScreen> createState() => _OcrScannerScreenState();
}

class _OcrScannerScreenState extends State<OcrScannerScreen> {
  File? _image;
  bool _isProcessing = false;
  List<List<String>> _tableData = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndProcessImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 100);
    if (image == null) return;

    setState(() {
      _image = File(image.path);
      _isProcessing = true;
      _tableData.clear();
    });

    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      // خوارزمية ترتيب النصوص في جدول
      List<TextElement> elements = [];
      for (var block in recognizedText.blocks) {
        for (var line in block.lines) {
          for (var element in line.elements) {
            if (element.text.isNotEmpty) elements.add(element);
          }
        }
      }

      // ترتيب حسب الإحداثي Y (الصفوف)
      elements.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

      List<List<String>> rows = [];
      List<TextElement> currentRow = [];
      double currentY = elements.isNotEmpty ? elements.first.boundingBox.center.dy : 0;

      for (var element in elements) {
        // إذا كان الفرق في Y أكبر من 15 بكسل، فهذا صف جديد
        if ((element.boundingBox.center.dy - currentY).abs() > 15) {
          if (currentRow.isNotEmpty) {
            // ترتيب الأعمدة حسب X
            currentRow.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
            rows.add(currentRow.map((e) => e.text).toList());
            currentRow = [];
          }
          currentY = element.boundingBox.center.dy;
        }
        currentRow.add(element);
      }
      if (currentRow.isNotEmpty) {
        currentRow.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
        rows.add(currentRow.map((e) => e.text).toList());
      }

      textRecognizer.close();

      if (mounted) {
        setState(() {
          _tableData = rows;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _saveTable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_firing_table', json.encode(_tableData));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الجدول بنجاح!'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('قارئ الجداول (OCR)'),
        backgroundColor: colors['surface'],
        actions: [
          if (_tableData.isNotEmpty)
            IconButton(icon: const Icon(Icons.save, color: Colors.green), onPressed: _saveTable),
        ],
      ),
      body: Column(
        children: [
          if (_image != null)
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors['border']!))),
              child: Image.file(_image!, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickAndProcessImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('كاميرا'),
                  style: ElevatedButton.styleFrom(backgroundColor: colors['primary'], foregroundColor: Colors.black),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickAndProcessImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('معرض'),
                  style: ElevatedButton.styleFrom(backgroundColor: colors['secondary'], foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
          if (_isProcessing)
            const Expanded(child: Center(child: CircularProgressIndicator())),
          if (!_isProcessing && _tableData.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(colors['surfaceLight']),
                    columns: List.generate(
                      _tableData.first.length,
                      (i) => DataColumn(label: Text('عمود ${i + 1}', style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold))),
                    ),
                    rows: _tableData.map((row) {
                      return DataRow(
                        cells: List.generate(
                          _tableData.first.length,
                          (i) => DataCell(
                            Text(i < row.length ? row[i] : '', style: TextStyle(color: colors['text'])),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}