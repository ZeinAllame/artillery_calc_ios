import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mgrs_dart/mgrs_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/theme_provider.dart';
import '../../widgets/app_drawer.dart' show rootScaffoldKey; // ← الاستيراد المهم
import '../../widgets/mgrs_grid_layer.dart'; // تأكد من وجود هذا الملف في مشروعك

enum MapStyle { googleRoads, googleSatellite, osm }

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? gunLatLng;
  LatLng? tgtLatLng;
  bool isLoading = true;
  MbTilesTileProvider? _offlineTileProvider;
  double currentZoom = 13.0;
  LatLng mapCenter = const LatLng(33.3152, 44.3661);
  MapStyle _currentStyle = MapStyle.googleRoads;
  bool _showMgrsGrid = true;

  @override
  void initState() {
    super.initState();
    _loadCoordinates();
    _checkOfflineMap();
  }

  @override
  void dispose() {
    _offlineTileProvider?.dispose();
    super.dispose();
  }

  Future<void> _checkOfflineMap() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/map.mbtiles');
      if (await file.exists()) {
        _offlineTileProvider = await MbTilesTileProvider.fromPath(path: file.path);
        if (mounted) setState(() {});
      }
    } catch (e) { debugPrint("Offline Map Error: $e"); }
  }

  Future<void> _loadCoordinates() async {
    final prefs = await SharedPreferences.getInstance();
    final gunMgrs = prefs.getString('last_gun_mgrs');
    final tgtMgrs = prefs.getString('last_tgt_mgrs');
    if (gunMgrs != null && tgtMgrs != null) {
      try {
        final gunPoint = Mgrs.toPoint(gunMgrs);
        final tgtPoint = Mgrs.toPoint(tgtMgrs);
        if (mounted) {
          setState(() {
            gunLatLng = LatLng(gunPoint[1], gunPoint[0]);
            tgtLatLng = LatLng(tgtPoint[1], tgtPoint[0]);
            mapCenter = gunLatLng!;
          });
        }
      } catch (e) { debugPrint("MGRS Error: $e"); }
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _sendSOS() async {
    if (gunLatLng == null) return;
    String mgrs = "غير معروف";
    try { mgrs = Mgrs.forward([gunLatLng!.longitude, gunLatLng!.latitude], 5); } catch (_) {}
    final msg = "🚨 نداء استغاثة 🚨\nMGRS: $mgrs\nLat: ${gunLatLng!.latitude}\nLng: ${gunLatLng!.longitude}";
    final url = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(msg)}");
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  String _getTileUrl() {
    switch (_currentStyle) {
      case MapStyle.googleRoads: return 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
      case MapStyle.googleSatellite: return 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}';
      case MapStyle.osm: return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    
    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        // ← إصلاح الشريط الجانبي هنا
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: colors['text']),
            onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
          ),
        ),
        title: const Text('الخريطة التكتيكية'),
        backgroundColor: colors['surface'],
        actions: [
          PopupMenuButton<MapStyle>(
            icon: Icon(Icons.layers, color: colors['primary']),
            onSelected: (v) => setState(() => _currentStyle = v),
            itemBuilder: (context) => const [
              PopupMenuItem(value: MapStyle.googleRoads, child: Text('خرائط جوجل (شوارع)')),
              PopupMenuItem(value: MapStyle.googleSatellite, child: Text('جوجل (أقمار صناعية)')),
              PopupMenuItem(value: MapStyle.osm, child: Text('خرائط OSM')),
            ],
          ),
          IconButton(
            icon: Icon(Icons.grid_on, color: _showMgrsGrid ? colors['primary'] : colors['text']?.withOpacity(0.3)),
            tooltip: 'شبكة MGRS',
            onPressed: () => setState(() => _showMgrsGrid = !_showMgrsGrid),
          ),
          IconButton(icon: const Icon(Icons.sos, color: Colors.red, size: 28), onPressed: _sendSOS),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: colors['primary']))
          : (gunLatLng == null || tgtLatLng == null)
              ? Center(child: Text('قم بحساب إحداثيات أولاً', style: TextStyle(color: colors['text'])))
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: currentZoom,
                    onPositionChanged: (pos, hasGesture) {
                      if (pos.center != null && pos.zoom != null) {
                        mapCenter = pos.center!;
                        currentZoom = pos.zoom!;
                      }
                    },
                  ),
                  children: [
                    if (_offlineTileProvider != null)
                      TileLayer(tileProvider: _offlineTileProvider!)
                    else
                      TileLayer(urlTemplate: _getTileUrl(), userAgentPackageName: 'com.artillery.calc'),
                    if (_showMgrsGrid)
                      MgrsGridLayer(lineColor: colors['primary']!.withOpacity(0.5), labelColor: Colors.white, labelFontSize: 9),
                    PolylineLayer(polylines: [Polyline(points: [gunLatLng!, tgtLatLng!], strokeWidth: 3.0, color: colors['warning']!)]),
                    CircleLayer(circles: [CircleMarker(point: tgtLatLng!, radius: 50, color: colors['danger']!.withOpacity(0.3), borderColor: colors['danger']!, borderStrokeWidth: 2)]),
                    MarkerLayer(markers: [
                      Marker(point: gunLatLng!, width: 40, height: 40, child: Icon(Icons.my_location, color: colors['primary'], size: 30)),
                      Marker(point: tgtLatLng!, width: 40, height: 40, child: Icon(Icons.gps_fixed, color: colors['danger'], size: 30)),
                    ]),
                  ],
                ),
    );
  }
}