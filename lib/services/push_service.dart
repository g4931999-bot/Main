import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';
import '../main.dart';
import '../widgets/common.dart';
import '../screens/notifications_screen.dart';

class PushService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;

  // NotificationsScreen listens to this (ValueListenableBuilder / addListener)
  // to refresh its list the instant a push arrives while the app is open,
  // instead of only updating on manual pull-to-refresh or re-opening the
  // screen. Bumped in the foreground onMessage handler below.
  static final ValueNotifier<int> newNotificationSignal = ValueNotifier<int>(0);

  /// Call once after a successful login (email, signup, or Google) so the
  /// backend has this device's token and can send real phone notifications
  /// (e.g. "your video just went public") even when the app is closed.
  static Future<void> initAfterLogin() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return; // user declined notification permission — nothing more to do
      }

      final token = await _messaging.getToken();
      if (token != null) {
        await ApiService.instance.registerDeviceToken(token);
      }

      // If the token rotates later (rare, but happens), keep the backend in sync
      _messaging.onTokenRefresh.listen((newToken) {
        ApiService.instance.registerDeviceToken(newToken).catchError((_) => <String, dynamic>{});
      });

      if (!_initialized) {
        _initialized = true;

        // Foreground: app is open right now. Show an in-app toast (the
        // system tray does NOT show a banner for a foreground FCM message
        // by default) and bump the signal so an open NotificationsScreen
        // updates immediately instead of looking like nothing arrived.
        FirebaseMessaging.onMessage.listen((message) {
          final ctx = navigatorKey.currentContext;
          final title = message.notification?.title;
          final body = message.notification?.body;
          if (ctx != null && title != null) {
            showToast(ctx, body != null ? '$title — $body' : title, isSuccess: true);
          }
          newNotificationSignal.value++;
        });

        // Background: app is alive but not in foreground, user taps the
        // system tray notification -> jump straight to Notifications.
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
        });

        // Terminated: app was fully closed, user taps the system tray
        // notification, which cold-starts the app. Checked once here,
        // right after Firebase/PushService are ready.
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          });
        }
      }
    } catch (e) {
      // Push notifications are a nice-to-have — never let a failure here break login
      // ignore: avoid_print
      print('PushService init failed: $e');
    }
  }
}