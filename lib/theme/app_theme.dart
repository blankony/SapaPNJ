import 'package:flutter/material.dart';

class SisapaTheme {
  static const Color blue = Color(0xFF1DA1F2);
  static const Color black = Color(0xFF14171A);
  static const Color darkGrey = Color(0xFF657786);
  static const Color lightGrey = Color(0xFFAAB8C2);
  static const Color extraLightGrey = Color(0xFFE1E8ED);
  static const Color white = Color(0xFFFFFFFF);

  static ThemeData darkTheme = ThemeData(
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: blue,
      onPrimary: white,
      secondary: blue,
      onSecondary: white,
      error: Colors.redAccent,
      onError: white,
      background: Color(0xFF15202B),
      onBackground: white,
      surface: Color(0xFF192734),
      onSurface: white,
    ),
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent,
    cardColor: Colors.transparent,
    primaryColor: blue,
    hintColor: darkGrey,
    dividerColor: Color(0xFF38444D).withValues(alpha: 0.5),

    appBarTheme: AppBarTheme(
      color: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: blue),
      titleTextStyle: TextStyle(color: white, fontSize: 20, fontWeight: FontWeight.bold),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF192734).withValues(alpha: 0.5),
      hintStyle: TextStyle(color: darkGrey),
      labelStyle: TextStyle(color: darkGrey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: blue, width: 2),
      ),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      selectedItemColor: blue,
      unselectedItemColor: darkGrey,
      showUnselectedLabels: false,
      showSelectedLabels: false,
      type: BottomNavigationBarType.fixed,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: white,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),

    iconTheme: IconThemeData(
      color: lightGrey,
    ),

    textTheme: TextTheme(
      bodyLarge: TextStyle(color: white),
      bodyMedium: TextStyle(color: white),
      titleMedium: TextStyle(color: white, fontWeight: FontWeight.bold),
      titleSmall: TextStyle(color: darkGrey),
      headlineMedium: TextStyle(color: white, fontWeight: FontWeight.bold),
    ),
  );

  static ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: blue,
      onPrimary: white,
      secondary: blue,
      onSecondary: white,
      error: Colors.redAccent,
      onError: white,
      background: white,
      onBackground: black,
      surface: white,
      onSurface: black,
    ),
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.transparent,
    cardColor: Colors.transparent,
    primaryColor: blue,
    hintColor: darkGrey,
    dividerColor: extraLightGrey.withValues(alpha: 0.5),

    appBarTheme: AppBarTheme(
      color: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: blue),
      titleTextStyle: TextStyle(color: black, fontSize: 20, fontWeight: FontWeight.bold),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: extraLightGrey.withValues(alpha: 0.5),
      hintStyle: TextStyle(color: darkGrey),
      labelStyle: TextStyle(color: darkGrey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: blue, width: 2),
      ),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      selectedItemColor: blue,
      unselectedItemColor: darkGrey,
      showUnselectedLabels: false,
      showSelectedLabels: false,
      type: BottomNavigationBarType.fixed,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: white,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),

    iconTheme: IconThemeData(
      color: darkGrey,
    ),

    textTheme: TextTheme(
      bodyLarge: TextStyle(color: black),
      bodyMedium: TextStyle(color: black),
      titleMedium: TextStyle(color: black, fontWeight: FontWeight.bold),
      titleSmall: TextStyle(color: darkGrey),
      headlineMedium: TextStyle(color: black, fontWeight: FontWeight.bold),
    ),
  );
}
