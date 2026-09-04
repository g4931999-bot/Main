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
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack);
    _logoFade = CurvedAnimation(parent: _logoController, curve: Curves.easeIn);
    _logoController.forward();

    // ⚠️ Photos/Videos permission prompt — previously the app only
    // ever triggered this reactively, the first time a user tapped
    // "choose file" on the Upload screen. Requesting it here, during the
    // same 7s splash window, gives both system permission dialogs the
    // same upfront treatment. (Logic unchanged — UI only update.)
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
      backgroundColor: const Color(0xFFFBF9FC),
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative purple play-icon shapes scattered around the
            // frame, matching the brand splash design.
            Positioned(top: -18, left: -18, child: _decoTriangle(size: 96, rotation: -0.35)),
            Positioned(top: 40, left: -30, right: -30, child: _decoFrame(height: 230)),
            Positioned(bottom: -24, left: -24, child: _decoTriangle(size: 130, rotation: 0.15)),

            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo lockup: "Tube [icon] Pilot"
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => AppColors.gradient.createShader(bounds),
                            child: const Text(
                              'Tube',
                              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 40,
                            height: 40,
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.purple, width: 3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: AppColors.purple),
                          ),
                          ShaderMask(
                            shaderCallback: (bounds) => AppColors.gradient.createShader(bounds),
                            child: const Text(
                              'Pilot',
                              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 90),

                  // Large centered brand mark
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: Container(
                        width: 118,
                        height: 118,
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.purple, width: 4),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Image.asset(
                          'assets/splash.png',
                          fit: BoxFit.contain,
                          color: AppColors.purple,
                          errorBuilder: (_, __, ___) => const Icon(Icons.play_arrow_rounded, color: AppColors.purple, size: 56),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  FadeTransition(
                    opacity: _logoFade,
                    child: Text(
                      context.tr('splash_tagline'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.purple, letterSpacing: 0.2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decoTriangle({required double size, required double rotation}) {
    return Transform.rotate(
      angle: rotation,
      child: Opacity(
        opacity: 0.16,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.purple, width: 8),
            borderRadius: BorderRadius.circular(size * 0.32),
          ),
          padding: EdgeInsets.all(size * 0.28),
          child: const Icon(Icons.play_arrow_rounded, color: AppColors.purple),
        ),
      ),
    );
  }

  Widget _decoFrame({required double height}) {
    return Opacity(
      opacity: 0.14,
      child: Transform.rotate(
        angle: -0.06,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.purple, width: 26),
            borderRadius: BorderRadius.circular(70),
          ),
        ),
      ),
    );
  }
}
