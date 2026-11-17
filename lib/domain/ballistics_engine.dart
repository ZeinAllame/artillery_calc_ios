import 'dart:math';

class BallisticsEngine {
  // حساب تصحيح السرعة بسبب تآكل السبطانة وحزمة الذخيرة
  static double calculateMuzzleVelocityCorrection({
    required double baseVelocity,
    required int roundsFired, // عدد القذائف المرمية من هذا المدفع
    required double barrelWearFactor, // معامل التآكل (مثلاً 0.1 م/ث لكل طلقة)
    required double lotVelocityVariance, // فرق سرعة الحزمة (LOT)
  }) {
    // التآكل يقلل السرعة، والحزمة قد تزيدها أو تقللها
    double wearLoss = roundsFired * barrelWearFactor;
    return baseVelocity - wearLoss + lotVelocityVariance;
  }

  // تصحيح الجو (ISA Model) + الرياح
  static double calculateAtmosphericCorrection({
    required double distance,
    required double tempC,
    required double pressureHPa,
    required double windSpeed,
    required double windDirection,
    required double firingAzimuth,
    required int milsFullCircle,
  }) {
    // 1. تصحيح الكثافة (الحرارة والضغط)
    const double stdTempK = 288.15;
    const double stdPressure = 1013.25;
    double tempK = tempC + 273.15;
    double densityRatio = (pressureHPa / stdPressure) * (stdTempK / tempK);
    double rangeCorrection = distance * (densityRatio - 1.0) * 0.5;

    // 2. تصحيح الرياح (Wind Drift)
    double crosswindAngle = (windDirection - firingAzimuth) * pi / 180.0;
    double crosswind = windSpeed * sin(crosswindAngle);
    double tof = distance / 300; // تقريب لزمن الطيران (يمكن حسابه بدقة من الجداول)
    double lateralDrift = crosswind * tof;
    double azimuthCorrection = (lateralDrift / max(distance, 1)) * milsFullCircle;

    return rangeCorrection; // نرجع تصحيح المسافة (ويمكن إرجاع object يحتوي على الاثنين)
  }
}