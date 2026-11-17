import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mgrs_dart/mgrs_dart.dart';

class WeatherData {
  final double temperature;
  final double pressure;
  final double windSpeed;
  final double windDirection;

  WeatherData(this.temperature, this.pressure, this.windSpeed, this.windDirection);
}

class WeatherService {
  static Future<WeatherData?> fetchWeatherByMgrs(String mgrsString) async {
    try {
      // 1. تحويل MGRS إلى إحداثيات خط الطول والعرض
      // في الإصدار 2.0.0 نستخدم toPoint التي ترجع قائمة [lon, lat]
      final point = Mgrs.toPoint(mgrsString);
      if (point.isEmpty) return null;

      final lon = point[0];
      final lat = point[1];

      // 2. استدعاء Open-Meteo API لجلب الطقس
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,surface_pressure,wind_speed_10m,wind_direction_10m,wind_speed_80m,wind_direction_80m&wind_speed_unit=ms');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current'];

        final windSpeed10 = (current['wind_speed_10m'] as num).toDouble();
        final windSpeed80 = (current['wind_speed_80m'] as num).toDouble();
        final windDir10 = (current['wind_direction_10m'] as num).toDouble();
        final windDir80 = (current['wind_direction_80m'] as num).toDouble();

        // حساب متوسط الرياح بين 10m و 80m
        final avgWindSpeed = (windSpeed10 + windSpeed80) / 2;
        final avgWindDir = (windDir10 + windDir80) / 2;

        return WeatherData(
          (current['temperature_2m'] as num).toDouble(),
          (current['surface_pressure'] as num).toDouble(),
          avgWindSpeed,
          avgWindDir,
        );
      }
      return null;
    } catch (e) {
      print("خطأ في جلب الطقس: $e");
      return null;
    }
  }
}