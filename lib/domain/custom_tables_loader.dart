import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'firing_table.dart';

/// يحمّل الجداول المعدّلة يدوياً إلى الذاكرة عند إقلاع التطبيق
/// حتى تتفوّق على الجداول المدمجة ولا تضيع التعديلات بعد إعادة التشغيل.
class CustomTablesLoader {
  static const String prefix = 'custom_table_';

  static Future<int> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    int count = 0;
    for (final k in prefs.getKeys().where((k) => k.startsWith(prefix))) {
      final tableKey = k.substring(prefix.length);
      final raw = prefs.getString(k);
      if (raw == null || raw.isEmpty) continue;
      try {
        final rows = (jsonDecode(raw) as List)
            .map((e) => FiringTableRow.fromJson(e as Map<String, dynamic>))
            .toList();
        if (rows.isEmpty) continue;
        rows.sort((a, b) => a.rangeMeters.compareTo(b.rangeMeters));
        // الاثنان معاً لضمان الإدراج مهما كانت دلالة كل دالة
        FiringTables.addCustomTable(tableKey, rows);
        FiringTables.updateTable(tableKey, rows);
        count++;
      } catch (_) {}
    }
    return count;
  }

  static Future<void> save(String tableKey, List<FiringTableRow> rows) async {
    final prefs = await SharedPreferences.getInstance();
    final sorted = List<FiringTableRow>.from(rows)
      ..sort((a, b) => a.rangeMeters.compareTo(b.rangeMeters));
    await prefs.setString(
        '$prefix$tableKey', jsonEncode(sorted.map((e) => e.toJson()).toList()));
    FiringTables.addCustomTable(tableKey, sorted);
    FiringTables.updateTable(tableKey, sorted);
  }
}