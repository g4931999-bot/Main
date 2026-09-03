import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_provider.dart';
import '../services/storage_service.dart';
import '../services/push_service.dart';
import '../theme/app_theme.dart';
import '../providers/language_provider.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Splash visible for 7 seconds
  static const _minSplashDuration = Duration(seconds: 7);

  late final AnimationController _logoController; // scale/fade-in for the logo
  late final AnimationController _ringController; // continuous orbit spinner
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack);
    _logoFade = CurvedAnimation(parent: _logoController, curve: Curves.easeIn);
    _logoController.forward();

    _ringController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

    // ⚠️ ADD: Photos/Videos permission prompt — previously the app only
    // ever triggered this reactively, the first time a user tapped
    // "choose file" on the Upload screen. That's why it never showed up
    // here on the splash screen the way the notification permission does
    // (PushService.initAfterLogin(), called below in _decideNextScreen()).
    // Requesting it here, during the same 7s splash window, gives both
    // system permission dialogs the same upfront treatment.
    _requestMediaPermissions();

    _decideNextScreen();
  }

  Future<void> _requestMediaPermissions() async {
    try {
      // Permission.photos / Permission.videos map to READ_MEDIA_IMAGES /
      // READ_MEDIA_VIDEO on Android 13+ (API 33+) and to the legacy
      // READ_EXTERNAL_STORAGE permission automatically on older Android
      // versions — matches exactly what's declared in AndroidManifest.xml.
      await [Permission.photos, Permission.videos].request();
    } catch (_) {
      // Non-fatal — image_picker will still prompt reactively later if
      // this fails to fire for any reason (e.g. platform not supported).
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  Future<void> _decideNextScreen() async {
    final auth = context.read<AuthProvider>();

    await Future.wait([
      auth.loadSession(),
      Future.delayed(_minSplashDuration),
    ]);

    if (!mounted) return;

    Widget next;

    if (auth.isLoggedIn) {
      next = const DashboardScreen();
      PushService.initAfterLogin();
    } else {
      final onboarded = await StorageService.isOnboarded();
      next = onboarded ? const LoginScreen() : const OnboardingScreen();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Soft gradient glow behind everything, for a bit of depth
            // instead of a flat white background.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [AppColors.purple.withOpacity(0.06), Colors.white],
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Orbit spinner ring around the logo, built from the app's
                  // own gradient so it reads as branded rather than a
                  // generic platform spinner.
                  SizedBox(
                    width: 168,
                    height: 168,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _ringController,
                          builder: (_, child) => Transform.rotate(
                            angle: _ringController.value * 6.28319,
                            child: child,
                          ),
                          child: SizedBox(
                            width: 168,
                            height: 168,
                            child: CustomPaint(painter: _OrbitRingPainter()),
                          ),
                        ),
                        ScaleTransition(
                          scale: _logoScale,
                          child: FadeTransition(
                            opacity: _logoFade,
                            child: Container(
                              width: 118,
                              height: 118,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [
                                BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, 8)),
                              ]),
                              padding: const EdgeInsets.all(18),
                              child: Image.asset(
                                'assets/splash.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => ShaderMask(
                                  shaderCallback: (bounds) => AppColors.gradient.createShader(bounds),
                                  child: const Icon(Icons.play_circle_fill, size: 78, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  FadeTransition(
                    opacity: _logoFade,
                    child: ShaderMask(
                      shaderCallback: (bounds) => AppColors.gradient.createShader(bounds),
                      child: const Text(
                        'Tube Pilot',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white, // masked by the gradient shader above
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Small pulsing status row so the wait doesn't feel dead —
                  // reassures the person something is actually happening
                  // during the 7s minimum splash window.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.purple.withOpacity(0.7))),
                      ),
                      const SizedBox(width: 10),
                      Text(context.tr('setting_things_up'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black45)),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Text
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Center(
                child: Text(
                  context.tr('powered_by'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws a partial gradient ring (not a full circle) with rounded caps, so
/// the rotation animation reads as an orbiting arc rather than a plain
/// spinning donut — a bit more distinctive than a default spinner.
class _OrbitRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    final paint = Paint()
      ..shader = AppColors.gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Two short arcs on opposite sides of the ring for a lighter, more
    // "orbiting particle" look than a single continuous circle.
    canvas.drawArc(rect, 0, 1.9, false, paint);
    canvas.drawArc(rect, 3.14159, 1.9, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}