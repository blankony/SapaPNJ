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
    scaffoldBackgroundColor: Color(0xFF15202B), 
    cardColor: Color(0xFF15202B), 
    primaryColor: blue,
    hintColor: darkGrey,
    dividerColor: Color(0xFF38444D), 
    
    appBarTheme: AppBarTheme(
      color: Color(0xFF15202B), 
      elevation: 0,
      iconTheme: IconThemeData(color: blue), 
      titleTextStyle: TextStyle(color: white, fontSize: 20, fontWeight: FontWeight.bold),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF192734), 
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
      backgroundColor: Color(0xFF15202B),
      selectedItemColor: blue,
      unselectedItemColor: darkGrey,
      showUnselectedLabels: false,
      showSelectedLabels: false,
      type: BottomNavigationBarType.fixed,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: blue,
      foregroundColor: white,
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
    scaffoldBackgroundColor: SisapaTheme.white, 
    cardColor: SisapaTheme.white, 
    primaryColor: blue,
    hintColor: darkGrey,
    dividerColor: extraLightGrey, 
    
    appBarTheme: AppBarTheme(
      color: SisapaTheme.white, 
      elevation: 0,
      iconTheme: IconThemeData(color: blue),
      titleTextStyle: TextStyle(color: black, fontSize: 20, fontWeight: FontWeight.bold), 
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: extraLightGrey, 
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
      backgroundColor: SisapaTheme.white,
      selectedItemColor: blue,
      unselectedItemColor: darkGrey,
      showUnselectedLabels: false,
      showSelectedLabels: false,
      type: BottomNavigationBarType.fixed,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: blue,
      foregroundColor: white,
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
