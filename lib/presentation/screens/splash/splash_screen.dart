import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen; // المتغير الجديد لاستقبال الشاشة التالية

  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    
    // إخفاء شريط الحالة العلوي (لتكون الشاشة كاملة)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset('assets/video/intro.mp4');
      await _controller!.initialize();
      
      // ضبط الفيديو ليغطي الشاشة بالكامل
      _controller!.setLooping(false);
      _controller!.setVolume(1.0); // الصوت مفتوح
      _controller!.play();

      setState(() {});

      // الانتقال للشاشة التالية بعد 5 ثواني أو عند انتهاء الفيديو
      _navigationTimer = Timer(const Duration(seconds: 5), () {
        _goToHome();
      });

    } catch (e) {
      debugPrint("خطأ في تحميل الفيديو: $e");
      // إذا فشل الفيديو، ننتقل للشاشة التالية مباشرة
      _goToHome();
    }
  }

  void _goToHome() {
    if (mounted) {
      // إعادة شريط الحالة
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          // 👇 هنا ننتقل إلى الشاشة التي تم تمريرها من main.dart 👇
          pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller?.dispose(); // تحرير ذاكرة الفيديو
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // خلفية سوداء لكي لا تظهر حدود الفيديو
      body: Center(
        child: _controller != null && _controller!.value.isInitialized
            ? SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover, // يجعل الفيديو يملأ الشاشة بالكامل
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              )
            : const CircularProgressIndicator(color: Colors.greenAccent), // شاشة تحميل أثناء تجهيز الفيديو
      ),
    );
  }
}