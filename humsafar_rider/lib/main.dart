import 'package:flutter/material.dart';
import 'config.dart';
import 'services/api.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.I.init();
  runApp(const HumsafarRiderApp());
}

class HumsafarRiderApp extends StatelessWidget {
  const HumsafarRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(AppConfig.brandGreen);
    return MaterialApp(
      title: 'Humsafar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: green, primary: green),
        appBarTheme: const AppBarTheme(
          backgroundColor: green,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: green,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: green, width: 2),
          ),
        ),
      ),
      home: Api.I.isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
