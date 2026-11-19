import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/theme_provider.dart';
import 'theme/settings_provider.dart';
import 'theme/app_theme.dart';
import 'domain/custom_tables_loader.dart';
import 'presentation/widgets/app_drawer.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/calculator/calculator_screen.dart';
import 'presentation/screens/target_calc/target_calc_screen.dart';
import 'presentation/screens/ammo_tracker/ammo_tracker_screen.dart';
import 'presentation/screens/map/map_screen.dart';
import 'presentation/screens/firing_timer/firing_timer_screen.dart';
import 'presentation/screens/calculator/fire_mission_log_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await CustomTablesLoader.loadAll(); // تحميل الجداول المعدّلة قبل الإقلاع
  } catch (e) {
    debugPrint('custom tables load error: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const ArtilleryApp(),
    ),
  );
}

class ArtilleryApp extends StatelessWidget {
  const ArtilleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    Widget initialScreen = const SplashScreen(nextScreen: MainShell());
    if (kIsWeb) {
      initialScreen =
          const WebAuthGate(child: SplashScreen(nextScreen: MainShell()));
    }
    return MaterialApp(
      title: 'Artillery Fire Control',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(themeProvider.currentMode),
      home: initialScreen,
    );
  }
}

// ==========================================
// حماية كلمة المرور للويب فقط
// ==========================================
class WebAuthGate extends StatefulWidget {
  final Widget child;
  const WebAuthGate({super.key, required this.child});

  @override
  State<WebAuthGate> createState() => _WebAuthGateState();
}

class _WebAuthGateState extends State<WebAuthGate> {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  final TextEditingController _passController = TextEditingController();
  final String _correctPassword = "فن المدفعية ٢٩";

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  @override
  void dispose() {
    _passController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final auth = prefs.getBool('web_authenticated') ?? false;
    if (!mounted) return;
    setState(() {
      _isAuthenticated = auth;
      _isLoading = false;
    });
  }

  Future<void> _verifyPassword() async {
    if (_passController.text.trim() == _correctPassword) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('web_authenticated', true);
      if (!mounted) return;
      setState(() => _isAuthenticated = true);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('كلمة المرور غير صحيحة!'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isAuthenticated) return widget.child;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blueGrey.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.blueAccent),
                const SizedBox(height: 16),
                const Text('منطقة محمية',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('الرجاء إدخال رمز المرور للوصول إلى نسخة الويب',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 24),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    labelStyle: const TextStyle(color: Colors.white60),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.blueAccent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onSubmitted: (_) => _verifyPassword(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _verifyPassword,
                    child: const Text('دخول',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// الهيكل الرئيسي
// ==========================================
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _screens = const [
    CalculatorScreen(),
    TargetCalculatorScreen(),
    FiringTimerScreen(),
    AmmoTrackerScreen(),
    MapScreen(),
    FireMissionLogScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int i) {
    if (_pageController.hasClients) _pageController.jumpToPage(i);
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    return Scaffold(
      key: rootScaffoldKey, // ← المفتاح العام
      drawer: AppDrawer(onSelectTab: _goToPage),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => _pageController.animateToPage(
          i,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        ),
        type: BottomNavigationBarType.fixed,
        backgroundColor: colors['surface'],
        selectedItemColor: colors['primary'],
        unselectedItemColor: colors['text']?.withOpacity(0.5),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calculate), label: 'الحاسبة'),
          BottomNavigationBarItem(icon: Icon(Icons.gps_fixed), label: 'الهدف'),
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'الموقت'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'الذخيرة'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'الخريطة'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'السجل'),
        ],
      ),
    );
  }
}