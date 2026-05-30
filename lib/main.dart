import 'dart:ui';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_theme.dart';
import 'auth_gate.dart';
import 'firebase_service.dart';
import 'services/notification_service.dart';

// ---------------------------------------------------------------------------
// AppLocale — InheritedNotifier that provides locale state to the whole tree.
// Any screen can READ the current locale via AppLocale.of(context).value
// and CHANGE it via AppLocale.of(context).value = newLocale.
// No prop-drilling of setLocale callbacks needed anywhere.
// ---------------------------------------------------------------------------
class AppLocale extends InheritedNotifier<ValueNotifier<Locale>> {
  const AppLocale({
    super.key,
    required ValueNotifier<Locale> super.notifier,
    required super.child,
  });

  /// Returns the [ValueNotifier<Locale>] so callers can both read and write.
  static ValueNotifier<Locale> of(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<AppLocale>();
    assert(result != null, 'No AppLocale found in context');
    return result!.notifier!;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  // Crashlytics — must be wired AFTER Firebase.initializeApp() (handled inside
  // FirebaseService.initialize()) and BEFORE runApp() so the handlers are in
  // place before any frames build. Disabled in debug to keep the dashboard
  // free of dev-loop noise; enabled in profile/release.
  //
  // iOS handoff: the Mac partner needs to (a) `pod install` after pulling and
  // (b) confirm Crashlytics appears in Firebase Console after the first
  // forced crash on a release build. No iOS-side code changes are required —
  // the FlutterFire plugin self-registers via GeneratedPluginRegistrant.
  // Crashlytics has no web implementation — skip entirely on web.
  if (!kIsWeb) {
    if (kReleaseMode) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } else {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(false);
    }
  }
  // Notifications are non-critical — `initialize()` swallows failures
  // internally so a notification-plugin issue never blocks app start.
  await NotificationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _localeNotifier = ValueNotifier<Locale>(const Locale('en'));

  @override
  void initState() {
    super.initState();
    // Rebuild MaterialApp whenever the locale changes so that
    // MaterialApp.locale receives the new value immediately.
    _localeNotifier.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    _localeNotifier.removeListener(_onLocaleChanged);
    _localeNotifier.dispose();
    super.dispose();
  }

  void _onLocaleChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return AppLocale(
      notifier: _localeNotifier,
      child: MaterialApp(
        title: 'Syanat',
        debugShowCheckedModeBanner: false,
        theme: buildSyanatTheme(),

        // Multi-language support (English / Arabic)
        locale: _localeNotifier.value,
        supportedLocales: const [
          Locale('en'),
          Locale('ar'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        localeResolutionCallback: (locale, supported) {
          if (locale == null) return const Locale('en');
          return supported.contains(Locale(locale.languageCode))
              ? Locale(locale.languageCode)
              : const Locale('en');
        },

        home: const AuthGate(),
      ),
    );
  }
}
