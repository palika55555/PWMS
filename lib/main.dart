import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/app_state.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const PWMSApp());
}

class PWMSApp extends StatelessWidget {
  const PWMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: MaterialApp(
        title: 'PWMS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
