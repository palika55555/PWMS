import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'screens/home_screen.dart';
import 'screens/production_details_web.dart';
import 'database/database_helper.dart';
import 'dart:convert';
import 'package:universal_html/html.dart' as html;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Potlačenie neškodných accessibility chýb na Windows
  FlutterError.onError = (FlutterErrorDetails details) {
    // Filtrovať accessibility chyby na Windows
    final errorString = details.exception.toString().toLowerCase();
    final stackString = details.stack?.toString().toLowerCase() ?? '';
    if (errorString.contains('accessibility_plugin') ||
        errorString.contains('viewid') ||
        errorString.contains('flutterviewid') ||
        stackString.contains('accessibility_plugin')) {
      // Tieto chyby nie sú kritické - len varovania z Windows accessibility API
      // Ignorovať ich, aby neobťažovali konzolu
      return;
    }
    
    // Pre ostatné chyby použiť default handling
    FlutterError.presentError(details);
  };
  
  // Inicializácia databázy (preskočiť na web - nie je potrebná pre production details view)
  if (!kIsWeb) {
    try {
      await DatabaseHelper.instance.database;
    } catch (e) {
      print('Error: Database initialization failed: $e');
      rethrow; // Na desktop/mobile musí databáza fungovať
    }
  } else {
    print('Skipping database initialization on web - not needed for production details view');
  }
  
  // Inicializácia lokalizácie pre formátovanie dátumov (s error handling)
  try {
    await initializeDateFormatting('sk_SK', null);
  } catch (e) {
    print('Warning: Failed to initialize date formatting: $e');
    // Pokračovať aj keď zlyhá - nie je kritické pre web
  }
  
  // Nastavenie default locale
  try {
    Intl.defaultLocale = 'sk_SK';
  } catch (e) {
    print('Warning: Failed to set locale: $e');
    // Použiť default locale ak zlyhá
    Intl.defaultLocale = 'en_US';
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PWMS - Production Management',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: _getInitialRoute(),
      routes: {
        '/production': (context) => const ProductionDetailsWebRoute(),
      },
      debugShowCheckedModeBanner: false,
    );
  }

  Widget _getInitialRoute() {
    if (kIsWeb) {
      // Na web skontrolovať URL parametre
      final uri = Uri.parse(html.window.location.href);
      if (uri.path == '/production' && uri.queryParameters.containsKey('data')) {
        return const ProductionDetailsWebRoute();
      }
    }
    return const HomeScreen();
  }
}

class ProductionDetailsWebRoute extends StatelessWidget {
  const ProductionDetailsWebRoute({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Scaffold(
        body: Center(child: Text('Táto stránka je dostupná len na web')),
      );
    }

    final uri = Uri.parse(html.window.location.href);
    final dataParam = uri.queryParameters['data'];
    
    if (dataParam == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chyba')),
        body: const Center(
          child: Text('Chýbajú dáta v URL'),
        ),
      );
    }

    try {
      // Dekódovať base64 dáta
      final decodedBytes = base64Decode(dataParam);
      final jsonString = utf8.decode(decodedBytes);
      final productionData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      print('Production data decoded successfully: ${productionData.keys}');
      
      return ProductionDetailsWeb(productionData: productionData);
    } catch (e, stackTrace) {
      print('Error decoding production data: $e');
      print('Stack trace: $stackTrace');
      return Scaffold(
        appBar: AppBar(title: const Text('Chyba')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Chyba pri dekódovaní dát: $e'),
              const SizedBox(height: 8),
              Text('URL parameter: ${dataParam.substring(0, dataParam.length > 50 ? 50 : dataParam.length)}...'),
            ],
          ),
        ),
      );
    }
  }
}
