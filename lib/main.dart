import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; 
import 'firebase_options.dart'; 
import 'screens/splash_screen.dart'; 
import 'services/app_localizations.dart'; 

// Notifiers Global
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<bool> hapticNotifier = ValueNotifier(true);
final ValueNotifier<Locale> languageNotifier = ValueNotifier(const Locale('en'));

import 'theme/app_theme.dart';
import 'theme/avatar_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // [OPTIMASI 4] Hanya inisialisasi core Firebase, sisanya di background/MyApp
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
  // Flag untuk status inisialisasi aset/config non-kritis
  bool _isConfigLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAppConfig();
  }

  // Load config di background agar UI tidak nge-freeze di splash native
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
    // Tampilkan Splash Screen sementara config di-load
    // Ini lebih baik daripada blank screen native
    if (!_isConfigLoaded) {
      return MaterialApp(
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()), // Atau Custom Splash Screen
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
              // Menggunakan onGenerateTitle agar judul ikut berubah bahasa
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