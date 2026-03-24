import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_service.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

// ✅ Initialize Firebase + Firestore + Auth + Storage
  await FirebaseService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en');

  /// Allows any screen to switch the app language
  void setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Syanat',
      debugShowCheckedModeBanner: false,

      // 🌍 Multi-language support (English / Arabic)
      locale: _locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // 🧭 Auto-switch text direction (RTL for Arabic)
      localeResolutionCallback: (locale, supported) {
        if (locale == null) return const Locale('en');
        return supported.contains(Locale(locale.languageCode))
            ? Locale(locale.languageCode)
            : const Locale('en');
      },

      // 🚀 Start app with SplashScreen
      home: SplashScreen(setLocale: setLocale),
    );
  }
}
