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

// استدعاء الثيم
import '../../../theme/theme_provider.dart';

// استدعاء مفتاح الـ Drawer الرئيسي
import '../../widgets/app_drawer.dart' show rootScaffoldKey;

// استدعاء ملف شبكة MGRS
import '../../widgets/mgrs_grid_layer.dart';

// 🗺️ أنماط الخرائط (تم إضافة الطبوغرافي)
enum MapStyle { googleRoads, googleSatellite, osm, topographic }

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
  LatLng mapCenter = const LatLng(33.3152, 44.3661); // بغداد كافتراضي
  MapStyle _currentStyle = MapStyle.topographic; // 🆕 الطبوغرافي هو الافتراضي

  // التحكم في إظهار شبكة MGRS
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

  // التحقق من وجود خريطة أوفلاين
  Future<void> _checkOfflineMap() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/map.mbtiles');
      if (await file.exists()) {
        _offlineTileProvider = await MbTilesTileProvider.fromPath(path: file.path);
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Offline Map Error: $e");
    }
  }

  // تحميل إحداثيات المدفع والهدف من الذاكرة
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
      } catch (e) {
        debugPrint("MGRS Error: $e");
      }
    }
    if (mounted) setState(() => isLoading = false);
  }

  // إرسال نداء استغاثة عبر واتساب
  Future<void> _sendSOS() async {
    if (gunLatLng == null) return;
    String mgrs = "غير معروف";
    try {
      mgrs = Mgrs.forward([gunLatLng!.longitude, gunLatLng!.latitude], 5);
    } catch (_) {}
    final msg =
        "🚨 نداء استغاثة 🚨\nMGRS: $mgrs\nLat: ${gunLatLng!.latitude}\nLng: ${gunLatLng!.longitude}";
    final url = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(msg)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // 🗺️ تحديد رابط الخريطة حسب النمط المختار
  String _getTileUrl() {
    switch (_currentStyle) {
      case MapStyle.googleRoads:
        return 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
      case MapStyle.googleSatellite:
        return 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}';
      case MapStyle.osm:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapStyle.topographic:
        // 🆕 خريطة طبوغرافية مجانية من OpenTopoMap (خطوط كنتورية + ارتفاعات)
        return 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png';
    }
  }

  // اسم النمط الحالي (لعرضه في الواجهة)
  String _getMapStyleName() {
    switch (_currentStyle) {
      case MapStyle.googleRoads:
        return 'شوارع';
      case MapStyle.googleSatellite:
        return 'أقمار صناعية';
      case MapStyle.osm:
        return 'OpenStreetMap';
      case MapStyle.topographic:
        return 'طبوغرافي (كنتوري)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        // زر القائمة الجانبية
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: colors['text']),
            onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
          ),
        ),
        title: const Text('الخريطة التكتيكية'),
        backgroundColor: colors['surface'],
        actions: [
          // 🆕 عرض النمط الحالي
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Text(
                _getMapStyleName(),
                style: TextStyle(
                  color: colors['primary'],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // قائمة تبديل أنماط الخرائط
          PopupMenuButton<MapStyle>(
            icon: Icon(Icons.layers, color: colors['primary']),
            onSelected: (v) => setState(() => _currentStyle = v),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: MapStyle.googleRoads,
                child: Row(
                  children: [
                    Icon(Icons.map, size: 20),
                    SizedBox(width: 8),
                    Text('خرائط جوجل (شوارع)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: MapStyle.googleSatellite,
                child: Row(
                  children: [
                    Icon(Icons.satellite, size: 20),
                    SizedBox(width: 8),
                    Text('جوجل (أقمار صناعية)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: MapStyle.osm,
                child: Row(
                  children: [
                    Icon(Icons.public, size: 20),
                    SizedBox(width: 8),
                    Text('خرائط OSM'),
                  ],
                ),
              ),
              // 🆕 الخيار الطبوغرافي الجديد
              PopupMenuItem(
                value: MapStyle.topographic,
                child: Row(
                  children: [
                    Icon(Icons.terrain, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text('طبوغرافي (خطوط كنتورية)'),
                  ],
                ),
              ),
            ],
          ),
          // زر تفعيل/إلغاء شبكة MGRS
          IconButton(
            icon: Icon(
              Icons.grid_on,
              color: _showMgrsGrid
                  ? colors['primary']
                  : colors['text']?.withOpacity(0.3),
            ),
            tooltip: 'شبكة MGRS',
            onPressed: () {
              setState(() {
                _showMgrsGrid = !_showMgrsGrid;
              });
            },
          ),
          // زر نداء الاستغاثة
          IconButton(
            icon: const Icon(Icons.sos, color: Colors.red, size: 28),
            onPressed: _sendSOS,
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(color: colors['primary']))
          : (gunLatLng == null || tgtLatLng == null)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off,
                          size: 64, color: colors['text']?.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('قم بحساب إحداثيات المدفع والهدف أولاً',
                          style: TextStyle(
                              color: colors['text']?.withOpacity(0.7),
                              fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('من شاشة "حاسبة الرمي" أو "حاسبة الهدف"',
                          style: TextStyle(
                              color: colors['text']?.withOpacity(0.5),
                              fontSize: 12)),
                    ],
                  ),
                )
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
                    // طبقة الخريطة (أونلاين أو أوفلاين)
                    if (_offlineTileProvider != null)
                      TileLayer(tileProvider: _offlineTileProvider!)
                    else
                      TileLayer(
                        urlTemplate: _getTileUrl(),
                        userAgentPackageName: 'com.artillery.calc',
                      ),

                    // شبكة MGRS فوق الخريطة
                    if (_showMgrsGrid)
                      MgrsGridLayer(
                        lineColor: colors['primary']!.withOpacity(0.5),
                        labelColor: Colors.white,
                        labelFontSize: 9,
                      ),

                    // خط الرمي بين المدفع والهدف
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [gunLatLng!, tgtLatLng!],
                          strokeWidth: 3.0,
                          color: colors['warning']!,
                        ),
                      ],
                    ),

                    // دائرة حول الهدف
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: tgtLatLng!,
                          radius: 50,
                          color: colors['danger']!.withOpacity(0.3),
                          borderColor: colors['danger']!,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),

                    // أيقونات المدفع والهدف
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: gunLatLng!,
                          width: 40,
                          height: 40,
                          child: Icon(Icons.my_location,
                              color: colors['primary'], size: 30),
                        ),
                        Marker(
                          point: tgtLatLng!,
                          width: 40,
                          height: 40,
                          child: Icon(Icons.gps_fixed,
                              color: colors['danger'], size: 30),
                        ),
                      ],
                    ),
                  ],
                ),
      // 🆕 زر عائم للعودة إلى موقع المدفع بسرعة
      floatingActionButton: gunLatLng != null
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  mapCenter = gunLatLng!;
                  currentZoom = 15.0;
                });
              },
              backgroundColor: colors['primary'],
              foregroundColor: Colors.black,
              tooltip: 'العودة إلى المدفع',
              child: const Icon(Icons.my_location),
            )
          : null,
    );
  }
}