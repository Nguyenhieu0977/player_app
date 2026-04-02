import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import 'theme/app_colors.dart';

class KioskPlayerApp extends StatelessWidget {
  const KioskPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kiosk Player',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.card,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.card,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
