import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/app_localizations.dart';
import 'theme/app_theme.dart';
import 'theme/avatar_helper.dart';

// Notifiers Global
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<bool> hapticNotifier = ValueNotifier(true);
final ValueNotifier<Locale> languageNotifier = ValueNotifier(const Locale('en'));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // [OPTIMIZATION 4] Only initialize core Firebase, the rest in background/MyApp
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Flag for non-critical assets/config initialization status
  bool _isConfigLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAppConfig();
  }

  // Load config in background so UI doesn't freeze on native splash
  Future<void> _loadAppConfig() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint("WARNING: Failed to load .env file: $e");
    }

    final prefs = await SharedPreferences.getInstance();

    final bool isDark = prefs.getBool('is_dark_mode') ?? false;
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

    final String? savedLang = prefs.getString('language_code');
    if (savedLang != null) {
      languageNotifier.value = Locale(savedLang);
    }

    if (mounted) {
      setState(() {
        _isConfigLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show Splash Screen while config is loading
    // This is better than a blank native screen
    if (!_isConfigLoaded) {
      return MaterialApp(
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()), // Or Custom Splash Screen
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    return ValueListenableBuilder<Locale>(
      valueListenable: languageNotifier,
      builder: (context, currentLocale, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, currentMode, child) {
            return MaterialApp(
              // Use onGenerateTitle so title changes with language
              onGenerateTitle: (context) => AppLocalizations.of(context)?.translate('app_name') ?? 'Sapa PNJ',

              theme: SisapaTheme.lightTheme,
              darkTheme: SisapaTheme.darkTheme,
              themeMode: currentMode,

              locale: currentLocale,
              supportedLocales: const [
                Locale('en', 'US'),
                Locale('id', 'ID'),
              ],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              localeResolutionCallback: (locale, supportedLocales) {
                for (var supportedLocale in supportedLocales) {
                  if (supportedLocale.languageCode == locale?.languageCode) {
                    return supportedLocale;
                  }
                }
                return supportedLocales.first;
              },
              home: const SplashScreen(),
              debugShowCheckedModeBanner: false,
            );
          },
        );
      }
    );
  }
}
