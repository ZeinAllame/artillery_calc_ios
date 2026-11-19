import 'dart:convert';
import 'package:http/http.dart' as http;

/// جلب الارتفاع من Open-Meteo Elevation API (مجاني، بلا مفتاح)
class ElevationService {
  static Future<double?> fetchElevation(double latitude, double longitude) async {
    try {
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/elevation?latitude=$latitude&longitude=$longitude');
      final res = await http.get(url).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final list = data['elevation'] as List;
        if (list.isNotEmpty) {
          return (list[0] as num).toDouble();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}