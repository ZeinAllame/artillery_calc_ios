import 'dart:convert';

// ==== الأنواع والدول للعتاد ====
enum ShellType { he, smoke, illumination, airburst }
enum ShellCountry { usa, russia, china, iran, serbia, yugoslavia, iraq, other }

// ==== كلاس السلاح ====
class Weapon {
  final String id;
  final String nameAr;
  final String nameEn;
  final String caliber;
  final String category;
  final int maxMils;
  final double minRange;
  final double maxRange;
  final String origin;
  final bool supportsHighAngle;
  final bool supportsLowAngle;
  final double burstRadiusMeters;

  Weapon(
    this.id,
    this.nameAr,
    this.nameEn,
    this.caliber,
    this.category,
    this.maxMils,
    this.minRange,
    this.maxRange,
    this.origin, {
    this.supportsHighAngle = true,
    this.supportsLowAngle = false,
    this.burstRadiusMeters = 15.0,
  });
}

// ==== كلاس الذخيرة (العتاد) ====
class Shell {
  final String id;
  final String name;
  final String nameEn;
  final String typeStr;
  final ShellType type;
  final ShellCountry country;
  final String caliber;
  final int quantity;
  final double descentVelocityMs;

  Shell(
    this.id,
    this.name,
    this.nameEn,
    this.typeStr, {
    this.type = ShellType.he,
    this.country = ShellCountry.usa,
    this.caliber = '',
    this.quantity = 0,
    this.descentVelocityMs = 180.0,
  });

  Shell copyWith({int? quantity}) {
    return Shell(
      id, name, nameEn, typeStr,
      type: type,
      country: country,
      caliber: caliber,
      quantity: quantity ?? this.quantity,
      descentVelocityMs: descentVelocityMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nameEn': nameEn,
        'typeStr': typeStr,
        'type': type.index,
        'country': country.index,
        'caliber': caliber,
        'quantity': quantity,
        'descentVelocityMs': descentVelocityMs,
      };

  factory Shell.fromJson(Map<String, dynamic> json) {
    return Shell(
      json['id'] ?? '',
      json['name'] ?? 'غير معروف',
      json['nameEn'] ?? 'Unknown',
      json['typeStr'] ?? 'HE',
      type: ShellType.values[json['type'] ?? 0],
      country: ShellCountry.values[json['country'] ?? 7],
      caliber: json['caliber'] ?? '',
      quantity: json['quantity'] ?? 0,
      descentVelocityMs: (json['descentVelocityMs'] ?? 180.0).toDouble(),
    );
  }
}

// ==== كلاس مهام الرمي ====
class FireMission {
  final String id;
  final String name;
  final String date;
  final String gunMgrs;
  final String targetMgrs;
  final String weaponName;
  final String shellName;
  final String distance;
  final String azimuth;
  final String elevation;
  final String charge;
  final String tof;

  FireMission({
    required this.id, required this.name, required this.date,
    required this.gunMgrs, required this.targetMgrs, required this.weaponName,
    required this.shellName, required this.distance, required this.azimuth,
    required this.elevation, required this.charge, required this.tof,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'date': date, 'gunMgrs': gunMgrs,
    'targetMgrs': targetMgrs, 'weaponName': weaponName, 'shellName': shellName,
    'distance': distance, 'azimuth': azimuth, 'elevation': elevation,
    'charge': charge, 'tof': tof,
  };

  factory FireMission.fromJson(Map<String, dynamic> json) => FireMission(
    id: json['id'], name: json['name'], date: json['date'],
    gunMgrs: json['gunMgrs'], targetMgrs: json['targetMgrs'],
    weaponName: json['weaponName'], shellName: json['shellName'],
    distance: json['distance'], azimuth: json['azimuth'],
    elevation: json['elevation'], charge: json['charge'], tof: json['tof'],
  );
}

// ==== كلاس الأهداف المحفوظة (تمت إضافة الحقول الناقصة) ====
class SavedTarget {
  final String id;
  final String name;
  final String targetNumber;
  final String targetNature;
  final String date;
  final String observerMgrs;
  final String targetMgrs;
  final double distance;
  final double azimuth;

  SavedTarget({
    required this.id,
    required this.name,
    this.targetNumber = '',
    this.targetNature = '',
    this.date = '',
    this.observerMgrs = '',
    required this.targetMgrs,
    this.distance = 0.0,
    this.azimuth = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'targetNumber': targetNumber,
    'targetNature': targetNature, 'date': date, 'observerMgrs': observerMgrs,
    'targetMgrs': targetMgrs, 'distance': distance, 'azimuth': azimuth,
  };

  factory SavedTarget.fromJson(Map<String, dynamic> json) => SavedTarget(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    targetNumber: json['targetNumber'] ?? '',
    targetNature: json['targetNature'] ?? '',
    date: json['date'] ?? '',
    observerMgrs: json['observerMgrs'] ?? '',
    targetMgrs: json['targetMgrs'] ?? '',
    distance: (json['distance'] ?? 0.0).toDouble(),
    azimuth: (json['azimuth'] ?? 0.0).toDouble(),
  );
}