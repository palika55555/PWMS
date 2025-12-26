import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';
import 'providers/database_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/zoom_provider.dart';
import 'database/local_database.dart';
import 'database/database_stub.dart'
    if (dart.library.io) 'database/database_ffi.dart'
    if (dart.library.html) 'database/database_stub.dart';

class _ZoomInIntent extends Intent {
  const _ZoomInIntent();
}

class _ZoomOutIntent extends Intent {
  const _ZoomOutIntent();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize date formatting for Slovak locale
  await initializeDateFormatting('sk_SK', null);
  
  // Initialize FFI database for desktop platforms (Windows, Linux, macOS)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    initDatabase();
  }
  
  // Initialize local database
  await LocalDatabase.instance.database;
  
  runApp(const ProBlockApp());
}

class ProBlockApp extends StatelessWidget {
  const ProBlockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DatabaseProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => ZoomProvider()),
      ],
      child: Consumer<ZoomProvider>(
        builder: (context, zoomProvider, child) {
          return Shortcuts(
            shortcuts: {
              // Ctrl + + (na hlavnej klávesnici je to Shift + =, alebo numerická klávesnica +)
              LogicalKeySet(
                LogicalKeyboardKey.control,
                LogicalKeyboardKey.shift,
                LogicalKeyboardKey.equal,
              ): const _ZoomInIntent(),
              // Ctrl + + na numerickej klávesnici
              LogicalKeySet(
                LogicalKeyboardKey.control,
                LogicalKeyboardKey.numpadAdd,
              ): const _ZoomInIntent(),
              // Ctrl + - (na hlavnej klávesnici)
              LogicalKeySet(
                LogicalKeyboardKey.control,
                LogicalKeyboardKey.minus,
              ): const _ZoomOutIntent(),
              // Ctrl + - na numerickej klávesnici
              LogicalKeySet(
                LogicalKeyboardKey.control,
                LogicalKeyboardKey.numpadSubtract,
              ): const _ZoomOutIntent(),
            },
            child: Actions(
              actions: {
                _ZoomInIntent: CallbackAction<_ZoomInIntent>(
                  onInvoke: (_) {
                    zoomProvider.zoomIn();
                    return null;
                  },
                ),
                _ZoomOutIntent: CallbackAction<_ZoomOutIntent>(
                  onInvoke: (_) {
                    zoomProvider.zoomOut();
                    return null;
                  },
                ),
              },
              child: Focus(
                autofocus: true,
                child: MaterialApp(
                  title: 'ProBlock PWMS',
                  theme: ThemeData(
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: Colors.blue,
                      brightness: Brightness.light,
                    ),
                    useMaterial3: true,
                    cardTheme: CardThemeData(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  builder: (context, child) {
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaleFactor: zoomProvider.zoomLevel,
                      ),
                      child: child!,
                    );
                  },
                  home: const HomeScreen(),
                  debugShowCheckedModeBanner: false,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
