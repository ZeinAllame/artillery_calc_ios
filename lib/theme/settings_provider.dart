import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  int _directionUnit = 6400;
  int _elevationUnit = 6400;
  double _gMAngle = 0.0;
  int _gunNumber = 1;

  int get directionUnit => _directionUnit;
  int get elevationUnit => _elevationUnit;
  double get gMAngle => _gMAngle;
  int get gunNumber => _gunNumber;

  SettingsProvider() { _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _directionUnit = p.getInt('dir_unit') ?? 6400;
    _elevationUnit = p.getInt('elv_unit') ?? 6400;
    _gMAngle = p.getDouble('g_m_angle') ?? 0.0;
    _gunNumber = p.getInt('gun_number') ?? 1;
    notifyListeners();
  }

  Future<void> setDirectionUnit(int v) async {
    _directionUnit = v; notifyListeners();
    (await SharedPreferences.getInstance()).setInt('dir_unit', v);
  }
  Future<void> setElevationUnit(int v) async {
    _elevationUnit = v; notifyListeners();
    (await SharedPreferences.getInstance()).setInt('elv_unit', v);
  }
  Future<void> setGMAngle(double v) async {
    _gMAngle = v; notifyListeners();
    (await SharedPreferences.getInstance()).setDouble('g_m_angle', v);
  }
  Future<void> setGunNumber(int v) async {
    _gunNumber = v; notifyListeners();
    (await SharedPreferences.getInstance()).setInt('gun_number', v);
  }
}