import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// مستوى الوحدة في الهرمية
enum UnitLevel { division, brigade, regiment, battalion, company, point }

extension UnitLevelX on UnitLevel {
  String get labelAr {
    switch (this) {
      case UnitLevel.division: return 'فرقة';
      case UnitLevel.brigade: return 'لواء';
      case UnitLevel.regiment: return 'فوج';
      case UnitLevel.battalion: return 'كتيبة';
      case UnitLevel.company: return 'سرية';
      case UnitLevel.point: return 'نقطة';
    }
  }
  bool get isFolder => this != UnitLevel.point;
}

class FriendlyUnit {
  final String id;
  String name;
  UnitLevel level;
  double? utmE;
  double? utmN;
  double safetyRadiusM; // نصف قطر الأمان بالمتر
  List<FriendlyUnit> children;

  FriendlyUnit({
    required this.id,
    required this.name,
    required this.level,
    this.utmE,
    this.utmN,
    this.safetyRadiusM = 500,
    List<FriendlyUnit>? children,
  }) : children = children ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'level': level.name,
    'utmE': utmE,
    'utmN': utmN,
    'safetyRadiusM': safetyRadiusM,
    'children': children.map((c) => c.toJson()).toList(),
  };

  factory FriendlyUnit.fromJson(Map<String, dynamic> j) => FriendlyUnit(
    id: j['id'],
    name: j['name'],
    level: UnitLevel.values.firstWhere((e) => e.name == j['level'], orElse: () => UnitLevel.point),
    utmE: (j['utmE'] as num?)?.toDouble(),
    utmN: (j['utmN'] as num?)?.toDouble(),
    safetyRadiusM: (j['safetyRadiusM'] as num?)?.toDouble() ?? 500,
    children: (j['children'] as List?)?.map((e) => FriendlyUnit.fromJson(e)).toList() ?? [],
  );

  /// استخراج كل النقاط ذات الإحداثيات (عبر كل المستويات)
  List<FriendlyUnit> collectPoints() {
    final out = <FriendlyUnit>[];
    if (level == UnitLevel.point && utmE != null && utmN != null) out.add(this);
    for (final c in children) out.addAll(c.collectPoints());
    return out;
  }

  /// هل هذه الشجرة تحتوي على نقاط صالحة؟
  bool hasPoints() => collectPoints().isNotEmpty;
}

/// مخزن القوات الصديقة
class FriendlyForcesStore {
  static const _key = 'friendly_forces_tree';
  static List<FriendlyUnit> _roots = [];

  static List<FriendlyUnit> get roots => _roots;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final json = p.getString(_key);
    if (json == null) {
      _roots = [FriendlyUnit(id: 'root', name: 'القوات الصديقة', level: UnitLevel.division)];
      return;
    }
    try {
      final list = jsonDecode(json) as List;
      _roots = list.map((e) => FriendlyUnit.fromJson(e)).toList();
    } catch (_) {
      _roots = [FriendlyUnit(id: 'root', name: 'القوات الصديقة', level: UnitLevel.division)];
    }
  }

  static Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(_roots.map((e) => e.toJson()).toList()));
  }

  /// نصف قطر الأمان الافتراضي حسب السلاح
  static double defaultSafetyRadius(String weaponId) {
    if (weaponId.contains('60')) return 300;
    if (weaponId.contains('81')) return 400;
    if (weaponId.contains('120')) return 500;
    if (weaponId.contains('122')) return 600;
    if (weaponId.contains('130')) return 700;
    if (weaponId.contains('155')) return 800;
    if (weaponId.contains('grad') || weaponId.contains('rocket')) return 1000;
    return 500;
  }
}