import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PhotoCuratorApp());
}

class PhotoCuratorApp extends StatelessWidget {
  const PhotoCuratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhotoCurator AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF39735B),
          onPrimary: Colors.white,
          secondary: Color(0xFF315E80),
          onSecondary: Colors.white,
          error: Color(0xFFB6413C),
          surface: Color(0xFFF7F9F8),
          onSurface: Color(0xFF172126),
          outline: Color(0xFFB9C4C8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9F8),
        dividerColor: const Color(0xFFDDE3E8),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontSize: 28, letterSpacing: 0),
          headlineSmall: TextStyle(fontSize: 23, letterSpacing: 0),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          bodyLarge: TextStyle(letterSpacing: 0),
          bodyMedium: TextStyle(letterSpacing: 0),
          bodySmall: TextStyle(color: Color(0xFF647178), letterSpacing: 0),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFDDE3E8)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Color(0xFFF7F9F8),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: Color(0xFF172126),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        chipTheme: const ChipThemeData(shape: StadiumBorder()),
      ),
      home: const HomeScreen(),
    );
  }
}
