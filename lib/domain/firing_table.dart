class FiringTableRow {
  final int charge;             
  final int rangeMeters;        
  final int elevationMils;      
  final double timeOfFlightSec; 
  final int heightMeters;       

  const FiringTableRow({
    required this.charge,
    required this.rangeMeters,
    required this.elevationMils,
    required this.timeOfFlightSec,
    this.heightMeters = 0,
  });

  factory FiringTableRow.fromJson(Map<String, dynamic> json) {
    return FiringTableRow(
      charge: json['charge'] ?? 1,
      rangeMeters: json['rangeMeters'] ?? 0,
      elevationMils: json['elevationMils'] ?? 0,
      timeOfFlightSec: (json['timeOfFlightSec'] ?? 0.0).toDouble(),
      heightMeters: json['heightMeters'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'charge': charge,
      'rangeMeters': rangeMeters,
      'elevationMils': elevationMils,
      'timeOfFlightSec': timeOfFlightSec,
      'heightMeters': heightMeters,
    };
  }
}

class FiringTables {
  static final Map<String, List<FiringTableRow>> _tables = {
    'mortar60_he_usa': const [
      FiringTableRow(charge: 1, rangeMeters: 400, elevationMils: 1343, timeOfFlightSec: 34.3),
      FiringTableRow(charge: 1, rangeMeters: 500, elevationMils: 1264, timeOfFlightSec: 30.8),
      FiringTableRow(charge: 1, rangeMeters: 600, elevationMils: 1182, timeOfFlightSec: 28.8),
      FiringTableRow(charge: 1, rangeMeters: 700, elevationMils: 1101, timeOfFlightSec: 26.6),
      FiringTableRow(charge: 1, rangeMeters: 800, elevationMils: 1008, timeOfFlightSec: 24.6),
      FiringTableRow(charge: 1, rangeMeters: 900, elevationMils: 902, timeOfFlightSec: 23.0),
      FiringTableRow(charge: 1, rangeMeters: 1000, elevationMils: 795, timeOfFlightSec: 22.3),
      FiringTableRow(charge: 1, rangeMeters: 1100, elevationMils: 692, timeOfFlightSec: 22.0),
      FiringTableRow(charge: 1, rangeMeters: 1200, elevationMils: 585, timeOfFlightSec: 22.0),
      FiringTableRow(charge: 1, rangeMeters: 1300, elevationMils: 480, timeOfFlightSec: 22.8),
      FiringTableRow(charge: 2, rangeMeters: 700, elevationMils: 1343, timeOfFlightSec: 34.3),
      FiringTableRow(charge: 2, rangeMeters: 900, elevationMils: 1182, timeOfFlightSec: 28.8),
      FiringTableRow(charge: 2, rangeMeters: 1100, elevationMils: 1008, timeOfFlightSec: 24.6),
      FiringTableRow(charge: 2, rangeMeters: 1300, elevationMils: 795, timeOfFlightSec: 22.3),
      FiringTableRow(charge: 2, rangeMeters: 1500, elevationMils: 585, timeOfFlightSec: 22.0),
      FiringTableRow(charge: 3, rangeMeters: 1100, elevationMils: 1343, timeOfFlightSec: 34.3),
      FiringTableRow(charge: 3, rangeMeters: 1400, elevationMils: 1101, timeOfFlightSec: 26.6),
      FiringTableRow(charge: 3, rangeMeters: 1700, elevationMils: 795, timeOfFlightSec: 22.3),
    ],
    'mortar81_he_china': const [
      FiringTableRow(charge: 0, rangeMeters: 300, elevationMils: 1487, timeOfFlightSec: 0),
      FiringTableRow(charge: 0, rangeMeters: 500, elevationMils: 1377, timeOfFlightSec: 0),
      FiringTableRow(charge: 0, rangeMeters: 800, elevationMils: 1245, timeOfFlightSec: 0),
      FiringTableRow(charge: 0, rangeMeters: 1200, elevationMils: 1075, timeOfFlightSec: 0),
      FiringTableRow(charge: 0, rangeMeters: 1600, elevationMils: 924, timeOfFlightSec: 0),
      FiringTableRow(charge: 0, rangeMeters: 2000, elevationMils: 780, timeOfFlightSec: 0),
      FiringTableRow(charge: 1, rangeMeters: 800, elevationMils: 1486, timeOfFlightSec: 0),
      FiringTableRow(charge: 1, rangeMeters: 1200, elevationMils: 1302, timeOfFlightSec: 0),
      FiringTableRow(charge: 1, rangeMeters: 1600, elevationMils: 1121, timeOfFlightSec: 0),
      FiringTableRow(charge: 1, rangeMeters: 2000, elevationMils: 948, timeOfFlightSec: 0),
      FiringTableRow(charge: 1, rangeMeters: 2400, elevationMils: 764, timeOfFlightSec: 0),
      FiringTableRow(charge: 2, rangeMeters: 1200, elevationMils: 1468, timeOfFlightSec: 0),
      FiringTableRow(charge: 2, rangeMeters: 1800, elevationMils: 1230, timeOfFlightSec: 0),
      FiringTableRow(charge: 2, rangeMeters: 2400, elevationMils: 990, timeOfFlightSec: 0),
      FiringTableRow(charge: 2, rangeMeters: 3000, elevationMils: 742, timeOfFlightSec: 0),
      FiringTableRow(charge: 3, rangeMeters: 2000, elevationMils: 1428, timeOfFlightSec: 0),
      FiringTableRow(charge: 3, rangeMeters: 2800, elevationMils: 1148, timeOfFlightSec: 0),
      FiringTableRow(charge: 3, rangeMeters: 3600, elevationMils: 861, timeOfFlightSec: 0),
      FiringTableRow(charge: 3, rangeMeters: 4000, elevationMils: 713, timeOfFlightSec: 0),
      FiringTableRow(charge: 4, rangeMeters: 2800, elevationMils: 1454, timeOfFlightSec: 0),
      FiringTableRow(charge: 4, rangeMeters: 3600, elevationMils: 1113, timeOfFlightSec: 0),
      FiringTableRow(charge: 4, rangeMeters: 4400, elevationMils: 795, timeOfFlightSec: 0),
      FiringTableRow(charge: 4, rangeMeters: 5200, elevationMils: 466, timeOfFlightSec: 0),
    ],
    'mortar82_he_russia': const [
      FiringTableRow(charge: 0, rangeMeters: 300, elevationMils: 1480, timeOfFlightSec: 0),
      FiringTableRow(charge: 0, rangeMeters: 1000, elevationMils: 1150, timeOfFlightSec: 0),
      FiringTableRow(charge: 0, rangeMeters: 2000, elevationMils: 770, timeOfFlightSec: 0),
      FiringTableRow(charge: 1, rangeMeters: 1000, elevationMils: 1350, timeOfFlightSec: 0),
      FiringTableRow(charge: 1, rangeMeters: 2000, elevationMils: 940, timeOfFlightSec: 0),
      FiringTableRow(charge: 1, rangeMeters: 2400, elevationMils: 760, timeOfFlightSec: 0),
      FiringTableRow(charge: 3, rangeMeters: 2000, elevationMils: 1420, timeOfFlightSec: 0),
      FiringTableRow(charge: 3, rangeMeters: 4000, elevationMils: 710, timeOfFlightSec: 0),
    ],
    'mortar120_he_usa': const [
      FiringTableRow(charge: 0, rangeMeters: 500, elevationMils: 1371, timeOfFlightSec: 21, heightMeters: 551),
      FiringTableRow(charge: 0, rangeMeters: 900, elevationMils: 1145, timeOfFlightSec: 20, heightMeters: 832),
      FiringTableRow(charge: 1, rangeMeters: 500, elevationMils: 1371, timeOfFlightSec: 21, heightMeters: 551),
      FiringTableRow(charge: 1, rangeMeters: 1000, elevationMils: 1040, timeOfFlightSec: 29, heightMeters: 986),
      FiringTableRow(charge: 2, rangeMeters: 850, elevationMils: 1274, timeOfFlightSec: 26, heightMeters: 859),
      FiringTableRow(charge: 2, rangeMeters: 1400, elevationMils: 1119, timeOfFlightSec: 37, heightMeters: 1344),
      FiringTableRow(charge: 2, rangeMeters: 2500, elevationMils: 852, timeOfFlightSec: 51, heightMeters: 2525),
      FiringTableRow(charge: 3, rangeMeters: 1200, elevationMils: 1200, timeOfFlightSec: 31, heightMeters: 1191),
      FiringTableRow(charge: 3, rangeMeters: 2000, elevationMils: 1040, timeOfFlightSec: 41, heightMeters: 1900),
      FiringTableRow(charge: 4, rangeMeters: 1450, elevationMils: 1166, timeOfFlightSec: 34, heightMeters: 1429),
      FiringTableRow(charge: 4, rangeMeters: 2400, elevationMils: 994, timeOfFlightSec: 45, heightMeters: 2450),
      FiringTableRow(charge: 5, rangeMeters: 1750, elevationMils: 1145, timeOfFlightSec: 38, heightMeters: 1734),
      FiringTableRow(charge: 5, rangeMeters: 3000, elevationMils: 889, timeOfFlightSec: 51, heightMeters: 3780),
      FiringTableRow(charge: 6, rangeMeters: 2050, elevationMils: 1135, timeOfFlightSec: 39, heightMeters: 2076),
      FiringTableRow(charge: 6, rangeMeters: 3800, elevationMils: 750, timeOfFlightSec: 56, heightMeters: 5030),
      FiringTableRow(charge: 7, rangeMeters: 2300, elevationMils: 1134, timeOfFlightSec: 39, heightMeters: 2280),
      FiringTableRow(charge: 7, rangeMeters: 4400, elevationMils: 684, timeOfFlightSec: 59, heightMeters: 5970),
      FiringTableRow(charge: 8, rangeMeters: 2550, elevationMils: 1130, timeOfFlightSec: 39, heightMeters: 2385),
      FiringTableRow(charge: 8, rangeMeters: 4700, elevationMils: 664, timeOfFlightSec: 60, heightMeters: 6010),
    ],
    'howitzer122_he_russia': const [
      FiringTableRow(charge: 1, rangeMeters: 1500, elevationMils: 1200, timeOfFlightSec: 28),
      FiringTableRow(charge: 1, rangeMeters: 4000, elevationMils: 800, timeOfFlightSec: 50),
      FiringTableRow(charge: 1, rangeMeters: 7000, elevationMils: 400, timeOfFlightSec: 80),
      FiringTableRow(charge: 2, rangeMeters: 4000, elevationMils: 900, timeOfFlightSec: 45),
      FiringTableRow(charge: 2, rangeMeters: 10000, elevationMils: 350, timeOfFlightSec: 90),
      FiringTableRow(charge: 3, rangeMeters: 8000, elevationMils: 600, timeOfFlightSec: 70),
      FiringTableRow(charge: 3, rangeMeters: 15300, elevationMils: 150, timeOfFlightSec: 130),
    ],
    'howitzer155_he_usa': const [
      FiringTableRow(charge: 1, rangeMeters: 1000, elevationMils: 1250, timeOfFlightSec: 25),
      FiringTableRow(charge: 1, rangeMeters: 4000, elevationMils: 600, timeOfFlightSec: 70),
      FiringTableRow(charge: 2, rangeMeters: 1000, elevationMils: 1200, timeOfFlightSec: 22),
      FiringTableRow(charge: 2, rangeMeters: 5000, elevationMils: 550, timeOfFlightSec: 65),
      FiringTableRow(charge: 5, rangeMeters: 3000, elevationMils: 1050, timeOfFlightSec: 35),
      FiringTableRow(charge: 5, rangeMeters: 9000, elevationMils: 350, timeOfFlightSec: 85),
      FiringTableRow(charge: 8, rangeMeters: 9000, elevationMils: 750, timeOfFlightSec: 50),
      FiringTableRow(charge: 8, rangeMeters: 18000, elevationMils: 150, timeOfFlightSec: 140),
      FiringTableRow(charge: 8, rangeMeters: 24000, elevationMils: 100, timeOfFlightSec: 160),
    ],
  };

  // دالة الحصول على كل الجداول (لشاشة الإدارة)
  static Map<String, List<FiringTableRow>> getAllTables() {
    return _tables;
  }

  // دالة تحديث جدول معين (من شاشة الإدارة)
  static void updateTable(String tableKey, List<FiringTableRow> rows) {
    _tables[tableKey] = rows;
  }

  static void addCustomTable(String tableKey, List<FiringTableRow> rows) {
    _tables[tableKey] = rows;
  }

  static List<FiringTableRow> getTableForWeapon(String tableKey) {
    return _tables[tableKey] ?? [];
  }

  static List<FiringTableRow> findRowsForRange(String tableKey, int targetRange) {
    final table = getTableForWeapon(tableKey);
    if (table.isEmpty) return [];

    Map<int, List<FiringTableRow>> byCharge = {};
    for (var row in table) {
      byCharge.putIfAbsent(row.charge, () => []).add(row);
    }

    List<FiringTableRow> results = [];
    for (var charge in byCharge.keys) {
      final rows = byCharge[charge]!;
      if (rows.isEmpty) continue;
      
      final minRange = rows.map((r) => r.rangeMeters).reduce((a, b) => a < b ? a : b);
      final maxRange = rows.map((r) => r.rangeMeters).reduce((a, b) => a > b ? a : b);

      if (targetRange >= minRange && targetRange <= maxRange) {
        FiringTableRow closest = rows.first;
        int minDiff = 999999;
        for (var row in rows) {
          int diff = (row.rangeMeters - targetRange).abs();
          if (diff < minDiff) {
            minDiff = diff;
            closest = row;
          }
        }
        results.add(closest);
      }
    }
    
    results.sort((a, b) => a.charge.compareTo(b.charge));
    return results;
  }

  static FiringTableRow? getClosestFiringData(String tableKey, int targetRange) {
    final table = getTableForWeapon(tableKey);
    if (table.isEmpty) return null;

    FiringTableRow? closest;
    int minDifference = 999999;

    for (var row in table) {
      final difference = (row.rangeMeters - targetRange).abs();
      if (difference < minDifference) {
        minDifference = difference;
        closest = row;
      }
    }
    return closest;
  }
}