import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart'; // <--- تم إضافة هذا الاستيراد لحل المشكلة
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mgrs_dart/mgrs_dart.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'نظام القيادة - البث المباشر',
      initialNotificationContent: 'جاري إرسال الإحداثيات للقيادة...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 30), (timer) async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final point = [position.longitude, position.latitude];
      final mgrs = Mgrs.forward(point, 5);
      
      // حفظ الإحداثيات في الذاكرة
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('live_location', mgrs);

      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: "البث المباشر نشط",
            content: "الموقع الحالي: $mgrs",
          );
        }
      }
    } catch (e) {
      print("Live location error: $e");
    }
  });
}