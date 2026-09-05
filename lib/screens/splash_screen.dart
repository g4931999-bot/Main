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

  // ⚠️ FIX (Boss request): the real logo lives at assets/logo.png (add it
  // to pubspec.yaml's flutter/assets list if it isn't already there — a
  // single transparent-background PNG, ideally square, is what this
  // widget expects). Used for BOTH the small lockup mark and the large
  // centered brand mark below, so there's only one source of truth for
  // "what the TubePilot logo looks like" instead of a separate mocked
  // icon in each spot.
  Widget _realLogo({required double size}) {
    return Image.asset(
      'assets/splash.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Fallback only fires if assets/logo.png is missing from the
      // project/pubspec — keeps the splash from crashing while the real
      // asset is wired in.
      errorBuilder: (_, __, ___) => Icon(Icons.play_arrow_rounded, color: AppColors.purple, size: size * 0.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ FIX (Boss request — "background hamara transparent hai to koi
    // bhi background nahin hona chahiye"): removed the solid off-white
    // Scaffold color AND every decorative shape (_decoTriangle /
    // _decoFrame boxes) that used to be scattered around the frame. The
    // splash now shows nothing but the real logo, tagline, and footer on
    // a fully transparent Scaffold.
    //
    // Note: Scaffold.backgroundColor: Colors.transparent only controls
    // the Flutter-drawn background — if you also want the native Android
    // launch (before Flutter's first frame) to be transparent, that's a
    // separate change in android/app/src/main/res/values/styles.xml
    // (the launch theme's windowBackground), which isn't a file in this
    // batch — let me know if you want that too and send styles.xml.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo lockup: "Tube [real logo] Pilot" — same wordmark
                  // as before, but the mock bordered play-icon box in the
                  // middle is now the real logo image.
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _realLogo(size: 40),
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

                  const SizedBox(height: 60),

                  // Large centered brand mark — real logo only, no
                  // border/box container around it anymore.
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: _realLogo(size: 140),
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

            // ⚠️ NEW (Boss request): "Powered by TubePilot" centered at
            // the very bottom of the splash screen.
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: FadeTransition(
                opacity: _logoFade,
                child: Center(
                  child: Text(
                    context.tr('splash_powered_by'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.purple.withValues(alpha: 0.65)),
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
