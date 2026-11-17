import 'dart:math';

class Ballistics {
  // حساب تصحيح المسافة (بسبب الحرارة والضغط)
  static double calculateRangeCorrection(double distance, double tempC, double pressureHPa) {
    const double stdTempK = 288.15;
    const double stdPressure = 1013.25;
    double tempK = tempC + 273.15;
    double densityRatio = (pressureHPa / stdPressure) * (stdTempK / tempK);
    return distance * (densityRatio - 1.0) * 0.5;
  }

  // حساب تصحيح الاتجاه (بسبب الرياح)
  static double calculateWindCorrection(
      double distance, double timeOfFlight, double windSpeed, double windDirection, double firingAzimuth, int milsFullCircle) {
    // زاوية الرياح بالنسبة لاتجاه الرمي
    double crosswindAngle = (windDirection - firingAzimuth) * pi / 180.0;
    double crosswind = windSpeed * sin(crosswindAngle);
    double lateralDrift = crosswind * timeOfFlight;
    if (distance == 0) return 0.0;
    return (lateralDrift / distance) * milsFullCircle;
  }

  static double milsToDegrees(double mils, int milsFullCircle) {
    return mils * 360.0 / milsFullCircle;
  }
}