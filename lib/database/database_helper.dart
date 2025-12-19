import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as desktop;

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static dynamic _database; // Database z sqflite alebo sqflite_common_ffi

  DatabaseHelper._init();

  Future<dynamic> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pwms.db');
    return _database!;
  }

  Future<dynamic> _initDB(String filePath) async {
    String dbPath;
    
    if (kIsWeb) {
      // Web - sqflite na web nefunguje dobre, použijeme jednoduchšie riešenie
      // Pre web použijeme sqflite_common_ffi_web alebo in-memory databázu
      try {
        // Skúsiť použiť sqflite (môže zlyhať na web)
        final databasesPath = await mobile.getDatabasesPath();
        dbPath = join(databasesPath, filePath);
        
        return await mobile.openDatabase(
          dbPath,
          version: 4,
          onCreate: _createDB,
          onUpgrade: _upgradeDB,
        );
      } catch (e) {
        // Ak sqflite zlyhá na web, vyhodíme chybu
        throw Exception('Database initialization failed on web: $e. Web platform may not support SQLite.');
      }
    } else if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      // Desktop - použiť sqflite_common_ffi
      desktop.sqfliteFfiInit();
      desktop.databaseFactory = desktop.databaseFactoryFfi;
      
      final appDocumentsDir = await getApplicationDocumentsDirectory();
      dbPath = join(appDocumentsDir.path, filePath);
      
      return await desktop.openDatabase(
        dbPath,
        version: 4,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    } else {
      // Mobile - použiť sqflite
      final databasesPath = await mobile.getDatabasesPath();
      dbPath = join(databasesPath, filePath);
      
      return await mobile.openDatabase(
        dbPath,
        version: 4,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    }
  }

  Future _createDB(dynamic db, int version) async {
    // Tabuľka pre materiály
    await db.execute('''
      CREATE TABLE materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        unit TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 0,
        min_quantity REAL NOT NULL DEFAULT 10,
        created_at TEXT NOT NULL
      )
    ''');

    // Tabuľka pre produkty
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Tabuľka pre výrobné záznamy
    await db.execute('''
      CREATE TABLE production_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        batch_number TEXT NOT NULL UNIQUE,
        quantity INTEGER NOT NULL,
        production_date TEXT NOT NULL,
        notes TEXT,
        quality_status TEXT DEFAULT 'pending',
        quality_notes TEXT,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // Tabuľka pre receptúry produktov
    await db.execute('''
      CREATE TABLE recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        material_id INTEGER NOT NULL,
        quantity_per_unit REAL NOT NULL,
        unit TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (id),
        FOREIGN KEY (material_id) REFERENCES materials (id),
        UNIQUE(product_id, material_id)
      )
    ''');

    // Tabuľka pre kontrolu kvality
    await db.execute('''
      CREATE TABLE quality_checks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        check_type TEXT NOT NULL,
        result TEXT NOT NULL,
        value REAL,
        unit TEXT,
        notes TEXT,
        checked_date TEXT NOT NULL,
        checked_by TEXT,
        FOREIGN KEY (batch_id) REFERENCES production_batches (id)
      )
    ''');

    // Tabuľka pre spotrebu materiálov pri výrobe
    await db.execute('''
      CREATE TABLE production_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        material_id INTEGER NOT NULL,
        quantity_used REAL NOT NULL,
        FOREIGN KEY (batch_id) REFERENCES production_batches (id),
        FOREIGN KEY (material_id) REFERENCES materials (id)
      )
    ''');

    // Inicializácia základných materiálov
    await _initDefaultMaterials(db);
  }

  Future _upgradeDB(dynamic db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS production_batches (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          production_date TEXT NOT NULL,
          notes TEXT,
          FOREIGN KEY (product_id) REFERENCES products (id)
        )
      ''');
      await _initDefaultMaterials(db);
    }
    
    if (oldVersion < 3) {
      // Pridať min_quantity do materials
      try {
        await db.execute('ALTER TABLE materials ADD COLUMN min_quantity REAL NOT NULL DEFAULT 10');
      } catch (e) {
        // Stĺpec už môže existovať
      }
      
      // Pridať batch_number, quality_status, quality_notes do production_batches
      try {
        await db.execute('ALTER TABLE production_batches ADD COLUMN batch_number TEXT');
        await db.execute('ALTER TABLE production_batches ADD COLUMN quality_status TEXT DEFAULT "pending"');
        await db.execute('ALTER TABLE production_batches ADD COLUMN quality_notes TEXT');
        
        // Vygenerovať batch_number pre existujúce záznamy
        final batches = await db.query('production_batches');
        for (var batch in batches) {
          final batchNumber = 'BATCH-${batch['id']}-${DateTime.now().millisecondsSinceEpoch}';
          await db.update(
            'production_batches',
            {'batch_number': batchNumber},
            where: 'id = ?',
            whereArgs: [batch['id']],
          );
        }
        
        // Vytvoriť UNIQUE constraint na batch_number
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_batch_number ON production_batches(batch_number)');
      } catch (e) {
        // Stĺpce už môžu existovať
      }
      
      // Vytvoriť tabuľky pre receptúry a kontrolu kvality
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recipes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          material_id INTEGER NOT NULL,
          quantity_per_unit REAL NOT NULL,
          unit TEXT NOT NULL,
          FOREIGN KEY (product_id) REFERENCES products (id),
          FOREIGN KEY (material_id) REFERENCES materials (id),
          UNIQUE(product_id, material_id)
        )
      ''');
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quality_checks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          batch_id INTEGER NOT NULL,
          check_type TEXT NOT NULL,
          result TEXT NOT NULL,
          value REAL,
          unit TEXT,
          notes TEXT,
          checked_date TEXT NOT NULL,
          checked_by TEXT,
          FOREIGN KEY (batch_id) REFERENCES production_batches (id)
        )
      ''');
      
      // Inicializovať základné receptúry
      await _initDefaultRecipes(db);
    }
    
    if (oldVersion < 4) {
      // Opraviť production_logs - pridať batch_id ak chýba
      try {
        // Skontrolovať, či existuje stĺpec batch_id
        final tableInfo = await db.rawQuery('PRAGMA table_info(production_logs)');
        final hasBatchId = tableInfo.any((column) => column['name'] == 'batch_id');
        
        if (!hasBatchId) {
          // Vytvoriť novú tabuľku s správnou štruktúrou
          await db.execute('''
            CREATE TABLE production_logs_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              batch_id INTEGER NOT NULL,
              material_id INTEGER NOT NULL,
              quantity_used REAL NOT NULL,
              FOREIGN KEY (batch_id) REFERENCES production_batches (id),
              FOREIGN KEY (material_id) REFERENCES materials (id)
            )
          ''');
          
          // Skopírovať dáta ak existujú (ak stará tabuľka mala iný formát)
          try {
            final oldData = await db.query('production_logs');
            for (var row in oldData) {
              // Pokúsiť sa skopírovať dáta, ak existuje product_id, použijeme ho
              if (row.containsKey('product_id')) {
                // Nájsť najnovšiu šaržu pre tento produkt
                final batches = await db.query(
                  'production_batches',
                  where: 'product_id = ?',
                  whereArgs: [row['product_id']],
                  orderBy: 'id DESC',
                  limit: 1,
                );
                if (batches.isNotEmpty) {
                  await db.insert('production_logs_new', {
                    'batch_id': batches.first['id'],
                    'material_id': row['material_id'],
                    'quantity_used': row['quantity_used'],
                  });
                }
              }
            }
          } catch (e) {
            // Ignorovať chyby pri kopírovaní - možno stará tabuľka má inú štruktúru
          }
          
          // Odstrániť starú tabuľku a premenovať novú
          await db.execute('DROP TABLE IF EXISTS production_logs');
          await db.execute('ALTER TABLE production_logs_new RENAME TO production_logs');
        }
      } catch (e) {
        // Ak tabuľka neexistuje vôbec, vytvoriť ju
        await db.execute('''
          CREATE TABLE IF NOT EXISTS production_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            batch_id INTEGER NOT NULL,
            material_id INTEGER NOT NULL,
            quantity_used REAL NOT NULL,
            FOREIGN KEY (batch_id) REFERENCES production_batches (id),
            FOREIGN KEY (material_id) REFERENCES materials (id)
          )
        ''');
      }
    }
  }

  Future _initDefaultMaterials(dynamic db) async {
    final now = DateTime.now().toIso8601String();
    
    final defaultMaterials = [
      {'name': 'Štrk 0-4 mm', 'unit': 't', 'quantity': 0.0, 'min_quantity': 10.0},
      {'name': 'Štrk 4-8 mm', 'unit': 't', 'quantity': 0.0, 'min_quantity': 10.0},
      {'name': 'Štrk 8-16 mm', 'unit': 't', 'quantity': 0.0, 'min_quantity': 10.0},
      {'name': 'Štrk 16-32 mm', 'unit': 't', 'quantity': 0.0, 'min_quantity': 10.0},
      {'name': 'Cement', 'unit': 'kg', 'quantity': 0.0, 'min_quantity': 500.0},
      {'name': 'Plastifikátor', 'unit': 'l', 'quantity': 0.0, 'min_quantity': 50.0},
      {'name': 'Voda', 'unit': 'l', 'quantity': 0.0, 'min_quantity': 100.0},
    ];

    for (var material in defaultMaterials) {
      try {
        if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
          await db.insert(
            'materials',
            {
              'name': material['name'],
              'unit': material['unit'],
              'quantity': material['quantity'],
              'min_quantity': material['min_quantity'],
              'created_at': now,
            },
            conflictAlgorithm: desktop.ConflictAlgorithm.ignore,
          );
        } else {
          await db.insert(
            'materials',
            {
              'name': material['name'],
              'unit': material['unit'],
              'quantity': material['quantity'],
              'min_quantity': material['min_quantity'],
              'created_at': now,
            },
            conflictAlgorithm: mobile.ConflictAlgorithm.ignore,
          );
        }
      } catch (e) {
        // Ignorovať chyby pri vkladaní - možno už existujú
        print('Warning: Failed to insert material ${material['name']}: $e');
      }
    }

    // Inicializácia základných produktov
    final defaultProducts = [
      {'name': 'Dlažba', 'quantity': 0},
      {'name': 'Tvárnice', 'quantity': 0},
    ];

    for (var product in defaultProducts) {
      try {
        if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
          await db.insert(
            'products',
            {
              'name': product['name'],
              'quantity': product['quantity'],
              'created_at': now,
            },
            conflictAlgorithm: desktop.ConflictAlgorithm.ignore,
          );
        } else {
          await db.insert(
            'products',
            {
              'name': product['name'],
              'quantity': product['quantity'],
              'created_at': now,
            },
            conflictAlgorithm: mobile.ConflictAlgorithm.ignore,
          );
        }
      } catch (e) {
        // Ignorovať chyby pri vkladaní - možno už existujú
        print('Warning: Failed to insert product ${product['name']}: $e');
      }
    }
  }

  Future _initDefaultRecipes(dynamic db) async {
    // Získanie ID produktov a materiálov
    final products = await db.query('products');
    final materials = await db.query('materials');
    
    final productMap = <String, int>{};
    final materialMap = <String, int>{};
    
    for (var product in products) {
      productMap[product['name'] as String] = product['id'] as int;
    }
    
    for (var material in materials) {
      materialMap[material['name'] as String] = material['id'] as int;
    }
    
    // Receptúra pre Dlažbu (príklad: na 1 m² dlažby)
    final dlazbaId = productMap['Dlažba'];
    if (dlazbaId != null) {
      final dlazbaRecipe = [
        {'material': 'Štrk 0-4 mm', 'quantity': 0.15, 'unit': 't'}, // 150 kg na m²
        {'material': 'Cement', 'quantity': 25.0, 'unit': 'kg'}, // 25 kg na m²
        {'material': 'Plastifikátor', 'quantity': 0.5, 'unit': 'l'}, // 0.5 l na m²
        {'material': 'Voda', 'quantity': 12.0, 'unit': 'l'}, // 12 l na m²
      ];
      
      for (var item in dlazbaRecipe) {
        final materialId = materialMap[item['material'] as String];
        if (materialId != null) {
          try {
            if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
              await db.insert(
                'recipes',
                {
                  'product_id': dlazbaId,
                  'material_id': materialId,
                  'quantity_per_unit': item['quantity'] as double,
                  'unit': item['unit'] as String,
                },
                conflictAlgorithm: desktop.ConflictAlgorithm.ignore,
              );
            } else {
              await db.insert(
                'recipes',
                {
                  'product_id': dlazbaId,
                  'material_id': materialId,
                  'quantity_per_unit': item['quantity'] as double,
                  'unit': item['unit'] as String,
                },
                conflictAlgorithm: mobile.ConflictAlgorithm.ignore,
              );
            }
          } catch (e) {
            print('Warning: Failed to insert recipe: $e');
          }
        }
      }
    }
    
    // Receptúra pre Tvárnice (príklad: na 1 m² tvárnic)
    final tvarniceId = productMap['Tvárnice'];
    if (tvarniceId != null) {
      final tvarniceRecipe = [
        {'material': 'Štrk 4-8 mm', 'quantity': 0.12, 'unit': 't'}, // 120 kg na m²
        {'material': 'Štrk 8-16 mm', 'quantity': 0.08, 'unit': 't'}, // 80 kg na m²
        {'material': 'Cement', 'quantity': 20.0, 'unit': 'kg'}, // 20 kg na m²
        {'material': 'Plastifikátor', 'quantity': 0.4, 'unit': 'l'}, // 0.4 l na m²
        {'material': 'Voda', 'quantity': 10.0, 'unit': 'l'}, // 10 l na m²
      ];
      
      for (var item in tvarniceRecipe) {
        final materialId = materialMap[item['material'] as String];
        if (materialId != null) {
          try {
            if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
              await db.insert(
                'recipes',
                {
                  'product_id': tvarniceId,
                  'material_id': materialId,
                  'quantity_per_unit': item['quantity'] as double,
                  'unit': item['unit'] as String,
                },
                conflictAlgorithm: desktop.ConflictAlgorithm.ignore,
              );
            } else {
              await db.insert(
                'recipes',
                {
                  'product_id': tvarniceId,
                  'material_id': materialId,
                  'quantity_per_unit': item['quantity'] as double,
                  'unit': item['unit'] as String,
                },
                conflictAlgorithm: mobile.ConflictAlgorithm.ignore,
              );
            }
          } catch (e) {
            print('Warning: Failed to insert recipe: $e');
          }
        }
      }
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
