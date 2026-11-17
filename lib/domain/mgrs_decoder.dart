import 'dart:math';

class UtmCoord {
  final double easting;
  final double northing;
  final int zone;
  final String band;
  final String square;
  UtmCoord(this.easting, this.northing, this.zone, this.band, this.square);
}

class MgrsDecoder {
  static UtmCoord? decode(String mgrs) {
    final clean = mgrs.trim().toUpperCase().replaceAll(" ", "");
    int idx = 0;
    String zoneStr = "";
    while (idx < clean.length && RegExp(r'[0-9]').hasMatch(clean[idx])) {
      zoneStr += clean[idx];
      idx++;
    }
    if (zoneStr.isEmpty) return null;
    final zone = int.tryParse(zoneStr) ?? 0;
    if (zone < 1 || zone > 60) return null;

    if (idx >= clean.length) return null;
    final band = clean[idx];
    idx++;

    if (idx + 2 > clean.length) return null;
    final square = clean.substring(idx, idx + 2);
    idx += 2;

    final digits = clean.substring(idx);
    if (digits.length < 2 || digits.length % 2 != 0) return null;

    final half = digits.length ~/ 2;
    final eStr = digits.substring(0, half);
    final nStr = digits.substring(half);

    double precision = 1.0;
    switch (half) {
      case 1: precision = 10000.0; break;
      case 2: precision = 1000.0; break;
      case 3: precision = 100.0; break;
      case 4: precision = 10.0; break;
      case 5: precision = 1.0; break;
      default: return null;
    }

    final easting = (double.tryParse(eStr) ?? 0) * precision;
    final northing = (double.tryParse(nStr) ?? 0) * precision;

    return UtmCoord(easting, northing, zone, band, square);
  }

  static Map<String, double> calculateGrid(double dE, double dN) {
    final distance = sqrt(dE * dE + dN * dN);
    double azimuthRad = atan2(dE, dN);
    if (azimuthRad < 0) azimuthRad += 2 * pi;
    final azimuthMils = azimuthRad * (6400.0 / (2 * pi));
    return {'distance': distance, 'azimuth': azimuthMils};
  }
}