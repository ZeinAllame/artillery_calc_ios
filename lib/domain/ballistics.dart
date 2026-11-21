import 'dart:math';

class Ballistics {
  // 1. حساب تصحيح المسافة (بسبب الحرارة والضغط)
  static double calculateRangeCorrection(double distance, double tempC, double pressureHPa) {
    const double stdTempK = 288.15;
    const double stdPressure = 1013.25;
    double tempK = tempC + 273.15;
    double densityRatio = (pressureHPa / stdPressure) * (stdTempK / tempK);
    return distance * (densityRatio - 1.0) * 0.5;
  }

  // 2. تصحيح الاتجاه (بسبب الرياح) - بالملات
  static double calculateWindCorrection(
      double distance,
      double timeOfFlight,
      double windSpeed,
      double windDirectionMils,
      double firingAzimuthMils,
      int milsFullCircle) {
    // الفرق بين اتجاه الرياح واتجاه الرمي (بالملات)
    double crosswindAngleMils = windDirectionMils - firingAzimuthMils;
    // تحويل الملات إلى راديان (الطريقة الصحيحة)
    double crosswindAngleRad = crosswindAngleMils * (2 * pi / milsFullCircle);
    
    double crosswind = windSpeed * sin(crosswindAngleRad);
    double lateralDrift = crosswind * timeOfFlight;
    
    if (distance == 0) return 0.0;
    return (lateralDrift / distance) * milsFullCircle;
  }

  // 3. تحويل الملات إلى درجات
  static double milsToDegrees(double mils, int milsFullCircle) {
    return mils * 360.0 / milsFullCircle;
  }

  // 4. زاوية الموقع (Site Angle) بالملات — موجبة إذا الهدف أعلى
  static double siteAngleMils(double deltaHeightMeters, double horizontalRangeMeters, int milsFullCircle) {
    if (horizontalRangeMeters <= 0) return 0;
    final double rad = atan(deltaHeightMeters / horizontalRangeMeters);
    return rad * (milsFullCircle / (2 * pi));
  }

  // 5. المسافة المائلة (Slant Range)
  static double slantRangeMeters(double horizontalRangeMeters, double deltaHeightMeters) {
    return sqrt(horizontalRangeMeters * horizontalRangeMeters + deltaHeightMeters * deltaHeightMeters);
  }

  // 6. المسافة بين نقطتين (Easting/Northing)
  static double distanceBetween(double e1, double n1, double e2, double n2) {
    return sqrt(pow(e2 - e1, 2) + pow(n2 - n1, 2));
  }

  // 7. حساب الاتجاه (Easting/Northing) بالملات
  static double azimuthMils(double e1, double n1, double e2, double n2, int milsFullCircle) {
    double dE = e2 - e1;
    double dN = n2 - n1;
    double angleRad = atan2(dE, dN);
    double angleMils = angleRad * (milsFullCircle / (2 * pi));
    if (angleMils < 0) angleMils += milsFullCircle;
    return angleMils;
  }
}