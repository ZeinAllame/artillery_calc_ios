class Weapon {
  final String id;
  final String name;
  final String nameEn;
  final String caliber;
  final String category;
  final int milsFullCircle;
  final double minRange;
  final double maxRange;
  final String country;

  Weapon(this.id, this.name, this.nameEn, this.caliber, this.category,
      this.milsFullCircle, this.minRange, this.maxRange, this.country);
}

class Shell {
  final String id;
  final String name;
  final String nameEn;
  final String type;

  Shell(this.id, this.name, this.nameEn, this.type);
}

class WeatherData {
  String temperature;
  String pressure;
  String windSpeed;
  String windDirection;
  bool rain;
  String humidity;

  WeatherData({
    this.temperature = "15",
    this.pressure = "1013",
    this.windSpeed = "0",
    this.windDirection = "0",
    this.rain = false,
    this.humidity = "50",
  });
}

class FireRecord {
  final int id;
  final int timestamp;
  final String weaponName;
  final String shellName;
  final String gunMgrs;
  final String targetMgrs;
  final double distance;
  final double azimuthMils;
  final double elevationMils;
  final int charge;
  final double tof;
  final int milsFullCircle;

  FireRecord({
    required this.id,
    required this.timestamp,
    required this.weaponName,
    required this.shellName,
    required this.gunMgrs,
    required this.targetMgrs,
    required this.distance,
    required this.azimuthMils,
    required this.elevationMils,
    required this.charge,
    required this.tof,
    required this.milsFullCircle,
  });

  // للتحويل إلى JSON للحفظ
  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp,
        'weaponName': weaponName,
        'shellName': shellName,
        'gunMgrs': gunMgrs,
        'targetMgrs': targetMgrs,
        'distance': distance,
        'azimuthMils': azimuthMils,
        'elevationMils': elevationMils,
        'charge': charge,
        'tof': tof,
        'milsFullCircle': milsFullCircle,
      };

  factory FireRecord.fromJson(Map<String, dynamic> json) => FireRecord(
        id: json['id'],
        timestamp: json['timestamp'],
        weaponName: json['weaponName'],
        shellName: json['shellName'],
        gunMgrs: json['gunMgrs'],
        targetMgrs: json['targetMgrs'],
        distance: json['distance'],
        azimuthMils: json['azimuthMils'],
        elevationMils: json['elevationMils'],
        charge: json['charge'],
        tof: json['tof'],
        milsFullCircle: json['milsFullCircle'],
      );
}

class AdjustmentEntry {
  final int index;
  final double rangeDelta;
  final double azimuthDelta;
  final double cumulativeRange;
  final double cumulativeAzimuth;

  AdjustmentEntry({
    required this.index,
    required this.rangeDelta,
    required this.azimuthDelta,
    required this.cumulativeRange,
    required this.cumulativeAzimuth,
  });
}