import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF080A0F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const PulseStudioApp());
}

class PulseStudioApp extends StatelessWidget {
  const PulseStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PULSE Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080A0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFF4D6D),
          surface: Color(0xFF121622),
        ),
        useMaterial3: true,
        sliderTheme: SliderThemeData(
          activeTrackColor: const Color(0xFF00E5FF),
          inactiveTrackColor: Colors.white.withAlpha(30),
          thumbColor: Colors.white,
          overlayColor: const Color(0xFF00E5FF).withAlpha(45),
          trackHeight: 3,
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const HomeScreen(),
    );
  }
}
