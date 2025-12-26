import 'dart:io' show Platform;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

// Conditional imports for different platforms
import 'database_stub.dart'
    if (dart.library.io) 'database_ffi.dart'
    if (dart.library.html) 'database_stub.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('problock.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    String dbPath;
    
    // Get database path based on platform
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // For desktop platforms, use application support directory
      final appDir = await getApplicationSupportDirectory();
      dbPath = appDir.path;
    } else {
      // For mobile platforms, use the standard databases path
      dbPath = await getDatabasesPath();
    }
    
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 19, // Add warehouse_id to stock_movements
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> deleteDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    
    String dbPath;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final appDir = await getApplicationSupportDirectory();
      dbPath = appDir.path;
    } else {
      dbPath = await getDatabasesPath();
    }
    
    final path = join(dbPath, 'problock.db');
    await databaseFactory.deleteDatabase(path);
    
    // Reinitialize database
    _database = await _initDB('problock.db');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns for drying and production conditions
      try {
        await db.execute('ALTER TABLE batches ADD COLUMN drying_days INTEGER');
        await db.execute('ALTER TABLE batches ADD COLUMN curing_start_date TEXT');
        await db.execute('ALTER TABLE batches ADD COLUMN curing_end_date TEXT');
        await db.execute('ALTER TABLE batches ADD COLUMN production_temperature REAL');
        await db.execute('ALTER TABLE batches ADD COLUMN production_humidity REAL');
      } catch (e) {
        // Columns might already exist, ignore error
        print('Migration note: $e');
      }
    }
    
    if (oldVersion < 3) {
      // Add stock movements tables
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS stock_movements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            movement_type TEXT NOT NULL,
            material_id INTEGER,
            quantity REAL NOT NULL,
            unit TEXT NOT NULL,
            document_number TEXT,
            supplier_name TEXT,
            recipient_name TEXT,
            reason TEXT,
            location TEXT,
            notes TEXT,
            product_note TEXT,
            expiration_date TEXT,
            purchase_price_without_vat REAL,
            purchase_price_with_vat REAL,
          vat_rate REAL,
          supplier_id INTEGER,
          warehouse_id INTEGER,
          movement_date TEXT NOT NULL,
          created_by TEXT NOT NULL,
            synced INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            FOREIGN KEY (material_id) REFERENCES materials(id)
          )
        ''');
        
        await db.execute('''
          CREATE TABLE IF NOT EXISTS inventories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            inventory_date TEXT NOT NULL,
            status TEXT DEFAULT 'planned',
            location TEXT,
            notes TEXT,
            created_by TEXT NOT NULL,
            synced INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        
        await db.execute('''
          CREATE TABLE IF NOT EXISTS inventory_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            inventory_id INTEGER NOT NULL,
            material_id INTEGER NOT NULL,
            recorded_quantity REAL NOT NULL,
            actual_quantity REAL NOT NULL,
            difference REAL NOT NULL,
            unit TEXT NOT NULL,
            notes TEXT,
            synced INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            FOREIGN KEY (inventory_id) REFERENCES inventories(id),
            FOREIGN KEY (material_id) REFERENCES materials(id)
          )
        ''');
        
        // Create indexes
        await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_movements_date ON stock_movements(movement_date)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_movements_type ON stock_movements(movement_type)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_movements_material ON stock_movements(material_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_inventory_items_inventory ON inventory_items(inventory_id)');
      } catch (e) {
        print('Migration note: $e');
      }
    }
    
    if (oldVersion < 4) {
      // Add suppliers, price history, and extend materials table
      try {
        // Add new columns to materials table
        await db.execute('ALTER TABLE materials ADD COLUMN plu_code TEXT');
        await db.execute('ALTER TABLE materials ADD COLUMN ean_code TEXT');
        await db.execute('ALTER TABLE materials ADD COLUMN average_purchase_price_without_vat REAL');
        await db.execute('ALTER TABLE materials ADD COLUMN average_purchase_price_with_vat REAL');
        await db.execute('ALTER TABLE materials ADD COLUMN sale_price REAL');
        await db.execute('ALTER TABLE materials ADD COLUMN vat_rate REAL DEFAULT 20.0');
        await db.execute('ALTER TABLE materials ADD COLUMN default_supplier_id INTEGER');
        
        // Create suppliers table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS suppliers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            company_id TEXT,
            tax_id TEXT,
            vat_id TEXT,
            address TEXT,
            city TEXT,
            zip_code TEXT,
            country TEXT,
            phone TEXT,
            email TEXT,
            website TEXT,
            contact_person TEXT,
            payment_terms TEXT,
            notes TEXT,
            synced INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        
        // Create price_history table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS price_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            material_id INTEGER NOT NULL,
            supplier_id INTEGER,
            quantity REAL NOT NULL,
            purchase_price_without_vat REAL NOT NULL,
            purchase_price_with_vat REAL NOT NULL,
            sale_price REAL,
            vat_rate REAL DEFAULT 20.0,
            price_date TEXT NOT NULL,
            document_number TEXT,
            notes TEXT,
            synced INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            FOREIGN KEY (material_id) REFERENCES materials(id),
            FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
          )
        ''');
        
        // Create indexes
        await db.execute('CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_price_history_material ON price_history(material_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_price_history_date ON price_history(price_date)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_materials_plu ON materials(plu_code)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_materials_ean ON materials(ean_code)');
      } catch (e) {
        print('Migration note: $e');
      }
    }
    
    if (oldVersion < 5) {
      // Add category to materials and prices to stock_movements
      try {
        await db.execute('ALTER TABLE materials ADD COLUMN category TEXT DEFAULT "warehouse"');
        await db.execute('ALTER TABLE stock_movements ADD COLUMN purchase_price_without_vat REAL');
        await db.execute('ALTER TABLE stock_movements ADD COLUMN purchase_price_with_vat REAL');
        await db.execute('ALTER TABLE stock_movements ADD COLUMN vat_rate REAL');
        await db.execute('ALTER TABLE stock_movements ADD COLUMN supplier_id INTEGER');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_materials_category ON materials(category)');
      } catch (e) {
        print('Migration note: $e');
      }
    }
    
    if (oldVersion < 6) {
      // Add advanced features: unit conversions, variants, accessories, customers, warehouses, price lists
      try {
        // Add columns to products
        await db.execute('ALTER TABLE products ADD COLUMN serial_number TEXT');
        await db.execute('ALTER TABLE products ADD COLUMN production_number TEXT');
        await db.execute('ALTER TABLE products ADD COLUMN expiration_date TEXT');
        await db.execute('ALTER TABLE products ADD COLUMN warehouse_location_id INTEGER');
        
        // Unit conversions
        await db.execute('''
          CREATE TABLE IF NOT EXISTS unit_conversions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            material_id INTEGER NOT NULL,
            from_unit TEXT NOT NULL,
            to_unit TEXT NOT NULL,
            conversion_factor REAL NOT NULL,
            is_default INTEGER DEFAULT 0,
            synced INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (material_id) REFERENCES materials(id)
          )
        ''');
        
        // Product variants
        await db.execute('''
          CREATE TABLE IF NOT EXISTS product_variants (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            material_id INTEGER NOT NULL,
            variant_type TEXT NOT NULL,
            variant_value TEXT NOT NULL,
            variant_code TEXT,
            ean_code TEXT,
            additional_price REAL,
            is_active INTEGER DEFAULT 1,
            synced INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (material_id) REFERENCES materials(id)
          )
        ''');
        
        // Product accessories
        await db.execute('''
          CREATE TABLE IF NOT EXISTS product_accessories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            material_id INTEGER NOT NULL,
            accessory_material_id INTEGER NOT NULL,
            relation_type TEXT NOT NULL,
            quantity INTEGER,
            notes TEXT,
            synced INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (material_id) REFERENCES materials(id),
            FOREIGN KEY (accessory_material_id) REFERENCES materials(id)
          )
        ''');
        
        // Customers
        await db.execute('''
          CREATE TABLE IF NOT EXISTS customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            company_id TEXT,
            tax_id TEXT,
            vat_id TEXT,
            address TEXT,
            city TEXT,
            zip_code TEXT,
            country TEXT,
            phone TEXT,
            email TEXT,
            website TEXT,
            contact_person TEXT,
            payment_terms TEXT,
            credit_limit REAL,
            price_list TEXT,
            notes TEXT,
            is_active INTEGER DEFAULT 1,
            synced INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        
        // Warehouse locations
        await db.execute('''
          CREATE TABLE IF NOT EXISTS warehouse_locations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            code TEXT,
            address TEXT,
            city TEXT,
            zip_code TEXT,
            country TEXT,
            contact_person TEXT,
            phone TEXT,
            email TEXT,
            is_active INTEGER DEFAULT 1,
            is_default INTEGER DEFAULT 0,
            notes TEXT,
            synced INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        
        // Purchase price lists
        await db.execute('''
          CREATE TABLE IF NOT EXISTS purchase_price_lists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            supplier_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            code TEXT,
            valid_from TEXT NOT NULL,
            valid_to TEXT,
            is_active INTEGER DEFAULT 1,
            notes TEXT,
            synced INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
          )
        ''');
        
        // Purchase price list items
        await db.execute('''
          CREATE TABLE IF NOT EXISTS purchase_price_list_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            price_list_id INTEGER NOT NULL,
            material_id INTEGER NOT NULL,
            price_without_vat REAL NOT NULL,
            price_with_vat REAL NOT NULL,
            vat_rate REAL DEFAULT 20.0,
            min_quantity REAL,
            notes TEXT,
            synced INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (price_list_id) REFERENCES purchase_price_lists(id),
            FOREIGN KEY (material_id) REFERENCES materials(id)
          )
        ''');
        
        // Create indexes
        await db.execute('CREATE INDEX IF NOT EXISTS idx_unit_conversions_material ON unit_conversions(material_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_product_variants_material ON product_variants(material_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_product_accessories_material ON product_accessories(material_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_warehouse_locations_code ON warehouse_locations(code)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_price_lists_supplier ON purchase_price_lists(supplier_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_price_list_items_price_list ON purchase_price_list_items(price_list_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_products_expiration ON products(expiration_date)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_products_serial ON products(serial_number)');
        
        // Auto orders
        await db.execute('''
          CREATE TABLE IF NOT EXISTS auto_orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            material_id INTEGER NOT NULL,
            supplier_id INTEGER NOT NULL,
            suggested_quantity REAL NOT NULL,
            current_stock REAL NOT NULL,
            min_stock REAL NOT NULL,
            max_stock REAL DEFAULT 0,
            reason TEXT NOT NULL,
            status TEXT DEFAULT 'pending',
            notes TEXT,
            synced INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            ordered_at TEXT,
            FOREIGN KEY (material_id) REFERENCES materials(id),
            FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_auto_orders_status ON auto_orders(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_auto_orders_material ON auto_orders(material_id)');
        
        // Warehouse closings
        await db.execute('''
          CREATE TABLE IF NOT EXISTS warehouse_closings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            closing_date TEXT NOT NULL,
            period_from TEXT NOT NULL,
            period_to TEXT NOT NULL,
            status TEXT DEFAULT 'open',
            notes TEXT,
            created_by TEXT NOT NULL,
            synced INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            closed_at TEXT
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_warehouse_closings_date ON warehouse_closings(closing_date)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_warehouse_closings_status ON warehouse_closings(status)');
      } catch (e) {
        print('Migration note: $e');
      }
    }
    
    if (oldVersion < 7) {
      // Add audit log table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS audit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_type TEXT NOT NULL,
            entity_id INTEGER,
            action TEXT NOT NULL,
            old_value TEXT,
            new_value TEXT,
            user_id TEXT NOT NULL,
            user_name TEXT NOT NULL,
            ip_address TEXT,
            user_agent TEXT,
            notes TEXT,
            synced INTEGER DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_logs_date ON audit_logs(created_at)');
      } catch (e) {
        print('Migration note: $e');
      }
    }
    
    if (oldVersion < 8) {
      // Add approval status to stock movements
      try {
        await db.execute('ALTER TABLE stock_movements ADD COLUMN status TEXT DEFAULT \'pending\'');
        await db.execute('ALTER TABLE stock_movements ADD COLUMN approved_by TEXT');
        await db.execute('ALTER TABLE stock_movements ADD COLUMN approved_at TEXT');
        await db.execute('ALTER TABLE stock_movements ADD COLUMN rejection_reason TEXT');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_movements_status ON stock_movements(status)');
        // Update existing movements to approved status
        await db.execute('UPDATE stock_movements SET status = \'approved\' WHERE status IS NULL');
      } catch (e) {
        print('Migration note: $e');
      }
    }
    
    if (oldVersion < 9) {
      // Add receipt number to stock movements
      try {
        await db.execute('ALTER TABLE stock_movements ADD COLUMN receipt_number TEXT');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_movements_receipt_number ON stock_movements(receipt_number)');
      } catch (e) {
        print('Migration note: $e');
      }
    }
    
    if (oldVersion < 10) {
      // Add delivery date to stock movements
      try {
        await db.execute('ALTER TABLE stock_movements ADD COLUMN delivery_date TEXT');
      } catch (e) {
        print('Migration note: $e');
      }
    }
    
    if (oldVersion < 11) {
      // Add product note and expiration date to stock movements
      try {
        await db.execute('ALTER TABLE stock_movements ADD COLUMN product_note TEXT');
        await db.execute('ALTER TABLE stock_movements ADD COLUMN expiration_date TEXT');
      } catch (e) {
        print('Migration note: $e');
      }
    }
    
    if (oldVersion < 13) {
      // Add mixer capacity and products per mixer to recipes
      try {
        await db.execute('ALTER TABLE recipes ADD COLUMN mixer_capacity REAL');
        await db.execute('ALTER TABLE recipes ADD COLUMN products_per_mixer INTEGER');
      } catch (e) {
        print('Migration note: $e');
      }
    }
    
    if (oldVersion < 14) {
      // Add vat_id column to customers table if it doesn't exist
      try {
        // Check if column exists by trying to query it
        final result = await db.rawQuery('PRAGMA table_info(customers)');
        final hasVatId = result.any((column) => column['name'] == 'vat_id');
        
        if (!hasVatId) {
          await db.execute('ALTER TABLE customers ADD COLUMN vat_id TEXT');
          print('Migration: Added vat_id column to customers table');
        }
      } catch (e) {
        // If table doesn't exist or other error, try to add column anyway
        try {
          await db.execute('ALTER TABLE customers ADD COLUMN vat_id TEXT');
          print('Migration: Added vat_id column to customers table');
        } catch (e2) {
          print('Migration note: Could not add vat_id column: $e2');
        }
      }
    }
    
    if (oldVersion < 15) {
      // Add recycling fee columns to materials table
      try {
        // Check if columns exist
        final result = await db.rawQuery('PRAGMA table_info(materials)');
        final hasRecyclingFee = result.any((column) => column['name'] == 'has_recycling_fee');
        final hasRecyclingFeeValue = result.any((column) => column['name'] == 'recycling_fee');
        
        if (!hasRecyclingFee) {
          await db.execute('ALTER TABLE materials ADD COLUMN has_recycling_fee INTEGER DEFAULT 0');
          print('Migration: Added has_recycling_fee column to materials table');
        }
        
        if (!hasRecyclingFeeValue) {
          await db.execute('ALTER TABLE materials ADD COLUMN recycling_fee REAL');
          print('Migration: Added recycling_fee column to materials table');
        }
      } catch (e) {
        // If table doesn't exist or other error, try to add columns anyway
        try {
          await db.execute('ALTER TABLE materials ADD COLUMN has_recycling_fee INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE materials ADD COLUMN recycling_fee REAL');
          print('Migration: Added recycling fee columns to materials table');
        } catch (e2) {
          print('Migration note: Could not add recycling fee columns: $e2');
        }
      }
    }
    
    if (oldVersion < 16) {
      // Ensure stock_movements table has price columns (fix for databases created with version 15)
      try {
        // Check if columns exist
        final result = await db.rawQuery('PRAGMA table_info(stock_movements)');
        final hasPurchasePriceWithoutVat = result.any((column) => column['name'] == 'purchase_price_without_vat');
        final hasPurchasePriceWithVat = result.any((column) => column['name'] == 'purchase_price_with_vat');
        final hasVatRate = result.any((column) => column['name'] == 'vat_rate');
        final hasSupplierId = result.any((column) => column['name'] == 'supplier_id');
        
        if (!hasPurchasePriceWithoutVat) {
          await db.execute('ALTER TABLE stock_movements ADD COLUMN purchase_price_without_vat REAL');
          print('Migration: Added purchase_price_without_vat column to stock_movements table');
        }
        
        if (!hasPurchasePriceWithVat) {
          await db.execute('ALTER TABLE stock_movements ADD COLUMN purchase_price_with_vat REAL');
          print('Migration: Added purchase_price_with_vat column to stock_movements table');
        }
        
        if (!hasVatRate) {
          await db.execute('ALTER TABLE stock_movements ADD COLUMN vat_rate REAL');
          print('Migration: Added vat_rate column to stock_movements table');
        }
        
        if (!hasSupplierId) {
          await db.execute('ALTER TABLE stock_movements ADD COLUMN supplier_id INTEGER');
          print('Migration: Added supplier_id column to stock_movements table');
        }
      } catch (e) {
        print('Migration note: Could not add price columns to stock_movements: $e');
      }
    }
    
    if (oldVersion < 17) {
      // Add warehouse_number to materials table
      try {
        final result = await db.rawQuery('PRAGMA table_info(materials)');
        final hasWarehouseNumber = result.any((column) => column['name'] == 'warehouse_number');
        
        if (!hasWarehouseNumber) {
          await db.execute('ALTER TABLE materials ADD COLUMN warehouse_number TEXT');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_materials_warehouse_number ON materials(warehouse_number)');
          print('Migration: Added warehouse_number column to materials table');
        }
      } catch (e) {
        print('Migration note: Could not add warehouse_number column: $e');
      }
    }
    
    if (oldVersion < 18) {
      // Add warehouses table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS warehouses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            code TEXT,
            address TEXT,
            city TEXT,
            zip_code TEXT,
            country TEXT,
            phone TEXT,
            email TEXT,
            manager TEXT,
            notes TEXT,
            is_active INTEGER DEFAULT 1,
            synced INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        
        await db.execute('CREATE INDEX IF NOT EXISTS idx_warehouses_name ON warehouses(name)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_warehouses_code ON warehouses(code)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_warehouses_active ON warehouses(is_active)');
        print('Migration: Created warehouses table');
      } catch (e) {
        print('Migration note: Could not create warehouses table: $e');
      }
    }
    
    if (oldVersion < 19) {
      // Add warehouse_id to stock_movements table
      try {
        final result = await db.rawQuery('PRAGMA table_info(stock_movements)');
        final hasWarehouseId = result.any((column) => column['name'] == 'warehouse_id');
        
        if (!hasWarehouseId) {
          await db.execute('ALTER TABLE stock_movements ADD COLUMN warehouse_id INTEGER');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_movements_warehouse ON stock_movements(warehouse_id)');
          print('Migration: Added warehouse_id column to stock_movements table');
        }
      } catch (e) {
        print('Migration note: Could not add warehouse_id column: $e');
      }
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Materials table
    await db.execute('''
      CREATE TABLE materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        category TEXT DEFAULT 'warehouse',
        unit TEXT NOT NULL,
        current_stock REAL DEFAULT 0,
        min_stock REAL DEFAULT 0,
        plu_code TEXT,
        ean_code TEXT,
        average_purchase_price_without_vat REAL,
        average_purchase_price_with_vat REAL,
        sale_price REAL,
        vat_rate REAL DEFAULT 20.0,
        has_recycling_fee INTEGER DEFAULT 0,
        recycling_fee REAL,
        default_supplier_id INTEGER,
        warehouse_number TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (default_supplier_id) REFERENCES suppliers(id)
      )
    ''');

    // Aggregate fractions table
    await db.execute('''
      CREATE TABLE aggregate_fractions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        material_id INTEGER NOT NULL,
        fraction_name TEXT NOT NULL,
        size_min REAL,
        size_max REAL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (material_id) REFERENCES materials(id)
      )
    ''');

    // Recipes table
    await db.execute('''
      CREATE TABLE recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        product_type TEXT NOT NULL,
        description TEXT,
        cement_amount REAL NOT NULL,
        water_amount REAL NOT NULL,
        plasticizer_amount REAL,
        wc_ratio REAL,
        mixer_capacity REAL,
        products_per_mixer INTEGER,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Recipe aggregates table (many-to-many)
    await db.execute('''
      CREATE TABLE recipe_aggregates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        material_id INTEGER NOT NULL,
        fraction_id INTEGER,
        amount REAL NOT NULL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id),
        FOREIGN KEY (material_id) REFERENCES materials(id),
        FOREIGN KEY (fraction_id) REFERENCES aggregate_fractions(id)
      )
    ''');

    // Batches table
    await db.execute('''
      CREATE TABLE batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_number TEXT NOT NULL UNIQUE,
        recipe_id INTEGER NOT NULL,
        production_date TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        quality_status TEXT DEFAULT 'pending',
        quality_approved_by TEXT,
        quality_approved_at TEXT,
        notes TEXT,
        drying_days INTEGER,
        curing_start_date TEXT,
        curing_end_date TEXT,
        production_temperature REAL,
        production_humidity REAL,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id)
      )
    ''');

    // Batch materials table (actual materials used)
    await db.execute('''
      CREATE TABLE batch_materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        material_id INTEGER NOT NULL,
        fraction_id INTEGER,
        planned_amount REAL NOT NULL,
        actual_amount REAL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (batch_id) REFERENCES batches(id),
        FOREIGN KEY (material_id) REFERENCES materials(id),
        FOREIGN KEY (fraction_id) REFERENCES aggregate_fractions(id)
      )
    ''');

    // Quality tests table
    await db.execute('''
      CREATE TABLE quality_tests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        test_type TEXT NOT NULL,
        test_value REAL,
        test_unit TEXT,
        test_result TEXT,
        test_date TEXT NOT NULL,
        tested_by TEXT,
        notes TEXT,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (batch_id) REFERENCES batches(id)
      )
    ''');

    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        product_code TEXT UNIQUE,
        qr_code TEXT UNIQUE,
        serial_number TEXT,
        production_number TEXT,
        expiration_date TEXT,
        status TEXT DEFAULT 'produced',
        location TEXT,
        warehouse_location_id INTEGER,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (batch_id) REFERENCES batches(id)
      )
    ''');

    // Sync queue table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        operation TEXT NOT NULL,
        data TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Stock movements table
    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        movement_type TEXT NOT NULL,
        material_id INTEGER,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        document_number TEXT,
        supplier_name TEXT,
        recipient_name TEXT,
        reason TEXT,
        location TEXT,
        notes TEXT,
        product_note TEXT,
        expiration_date TEXT,
        purchase_price_without_vat REAL,
        purchase_price_with_vat REAL,
        vat_rate REAL,
        supplier_id INTEGER,
        warehouse_id INTEGER,
        movement_date TEXT NOT NULL,
        delivery_date TEXT,
        created_by TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        approved_by TEXT,
        approved_at TEXT,
        rejection_reason TEXT,
        receipt_number TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (material_id) REFERENCES materials(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_stock_movements_status ON stock_movements(status)');
    await db.execute('CREATE INDEX idx_stock_movements_receipt_number ON stock_movements(receipt_number)');

    // Inventories table
    await db.execute('''
      CREATE TABLE inventories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inventory_date TEXT NOT NULL,
        status TEXT DEFAULT 'planned',
        location TEXT,
        notes TEXT,
        created_by TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Inventory items table
    await db.execute('''
      CREATE TABLE inventory_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inventory_id INTEGER NOT NULL,
        material_id INTEGER NOT NULL,
        recorded_quantity REAL NOT NULL,
        actual_quantity REAL NOT NULL,
        difference REAL NOT NULL,
        unit TEXT NOT NULL,
        notes TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (inventory_id) REFERENCES inventories(id),
        FOREIGN KEY (material_id) REFERENCES materials(id)
      )
    ''');

    // Suppliers table
    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        company_id TEXT,
        tax_id TEXT,
        vat_id TEXT,
        address TEXT,
        city TEXT,
        zip_code TEXT,
        country TEXT,
        phone TEXT,
        email TEXT,
        website TEXT,
        contact_person TEXT,
        payment_terms TEXT,
        notes TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Price history table
    await db.execute('''
      CREATE TABLE price_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        material_id INTEGER NOT NULL,
        supplier_id INTEGER,
        quantity REAL NOT NULL,
        purchase_price_without_vat REAL NOT NULL,
        purchase_price_with_vat REAL NOT NULL,
        sale_price REAL,
        vat_rate REAL DEFAULT 20.0,
        price_date TEXT NOT NULL,
        document_number TEXT,
        notes TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (material_id) REFERENCES materials(id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_batches_date ON batches(production_date)');
    await db.execute('CREATE INDEX idx_batches_status ON batches(quality_status)');
    await db.execute('CREATE INDEX idx_products_batch ON products(batch_id)');
    await db.execute('CREATE INDEX idx_sync_queue ON sync_queue(table_name, record_id)');
    await db.execute('CREATE INDEX idx_stock_movements_date ON stock_movements(movement_date)');
    await db.execute('CREATE INDEX idx_stock_movements_type ON stock_movements(movement_type)');
    await db.execute('CREATE INDEX idx_stock_movements_material ON stock_movements(material_id)');
    await db.execute('CREATE INDEX idx_inventory_items_inventory ON inventory_items(inventory_id)');
    await db.execute('CREATE INDEX idx_suppliers_name ON suppliers(name)');
    await db.execute('CREATE INDEX idx_warehouses_name ON warehouses(name)');
    await db.execute('CREATE INDEX idx_warehouses_code ON warehouses(code)');
    await db.execute('CREATE INDEX idx_warehouses_active ON warehouses(is_active)');
    await db.execute('CREATE INDEX idx_price_history_material ON price_history(material_id)');
    await db.execute('CREATE INDEX idx_price_history_date ON price_history(price_date)');
    await db.execute('CREATE INDEX idx_materials_plu ON materials(plu_code)');
    await db.execute('CREATE INDEX idx_materials_ean ON materials(ean_code)');
    await db.execute('CREATE INDEX idx_materials_category ON materials(category)');
    await db.execute('CREATE INDEX idx_materials_warehouse_number ON materials(warehouse_number)');
    
    // Unit conversions
    await db.execute('''
      CREATE TABLE unit_conversions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        material_id INTEGER NOT NULL,
        from_unit TEXT NOT NULL,
        to_unit TEXT NOT NULL,
        conversion_factor REAL NOT NULL,
        is_default INTEGER DEFAULT 0,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (material_id) REFERENCES materials(id)
      )
    ''');
    
    // Product variants
    await db.execute('''
      CREATE TABLE product_variants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        material_id INTEGER NOT NULL,
        variant_type TEXT NOT NULL,
        variant_value TEXT NOT NULL,
        variant_code TEXT,
        ean_code TEXT,
        additional_price REAL,
        is_active INTEGER DEFAULT 1,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (material_id) REFERENCES materials(id)
      )
    ''');
    
    // Product accessories
    await db.execute('''
      CREATE TABLE product_accessories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        material_id INTEGER NOT NULL,
        accessory_material_id INTEGER NOT NULL,
        relation_type TEXT NOT NULL,
        quantity INTEGER,
        notes TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (material_id) REFERENCES materials(id),
        FOREIGN KEY (accessory_material_id) REFERENCES materials(id)
      )
    ''');
    
    // Customers
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        company_id TEXT,
        tax_id TEXT,
        vat_id TEXT,
        address TEXT,
        city TEXT,
        zip_code TEXT,
        country TEXT,
        phone TEXT,
        email TEXT,
        website TEXT,
        contact_person TEXT,
        payment_terms TEXT,
        credit_limit REAL,
        price_list TEXT,
        notes TEXT,
        is_active INTEGER DEFAULT 1,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    // Warehouses table
    await db.execute('''
      CREATE TABLE warehouses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT,
        address TEXT,
        city TEXT,
        zip_code TEXT,
        country TEXT,
        phone TEXT,
        email TEXT,
        manager TEXT,
        notes TEXT,
        is_active INTEGER DEFAULT 1,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    // Warehouse locations
    await db.execute('''
      CREATE TABLE warehouse_locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT,
        address TEXT,
        city TEXT,
        zip_code TEXT,
        country TEXT,
        contact_person TEXT,
        phone TEXT,
        email TEXT,
        is_active INTEGER DEFAULT 1,
        is_default INTEGER DEFAULT 0,
        notes TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    // Purchase price lists
    await db.execute('''
      CREATE TABLE purchase_price_lists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        code TEXT,
        valid_from TEXT NOT NULL,
        valid_to TEXT,
        is_active INTEGER DEFAULT 1,
        notes TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');
    
    // Purchase price list items
    await db.execute('''
      CREATE TABLE purchase_price_list_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        price_list_id INTEGER NOT NULL,
        material_id INTEGER NOT NULL,
        price_without_vat REAL NOT NULL,
        price_with_vat REAL NOT NULL,
        vat_rate REAL DEFAULT 20.0,
        min_quantity REAL,
        notes TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (price_list_id) REFERENCES purchase_price_lists(id),
        FOREIGN KEY (material_id) REFERENCES materials(id)
      )
    ''');
    
    // Create indexes
    await db.execute('CREATE INDEX idx_unit_conversions_material ON unit_conversions(material_id)');
    await db.execute('CREATE INDEX idx_product_variants_material ON product_variants(material_id)');
    await db.execute('CREATE INDEX idx_product_accessories_material ON product_accessories(material_id)');
    await db.execute('CREATE INDEX idx_customers_name ON customers(name)');
    await db.execute('CREATE INDEX idx_warehouse_locations_code ON warehouse_locations(code)');
    await db.execute('CREATE INDEX idx_price_lists_supplier ON purchase_price_lists(supplier_id)');
    await db.execute('CREATE INDEX idx_price_list_items_price_list ON purchase_price_list_items(price_list_id)');
    await db.execute('CREATE INDEX idx_products_expiration ON products(expiration_date)');
    await db.execute('CREATE INDEX idx_products_serial ON products(serial_number)');
    
    // Auto orders
    await db.execute('''
      CREATE TABLE auto_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        material_id INTEGER NOT NULL,
        supplier_id INTEGER NOT NULL,
        suggested_quantity REAL NOT NULL,
        current_stock REAL NOT NULL,
        min_stock REAL NOT NULL,
        max_stock REAL DEFAULT 0,
        reason TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        notes TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        ordered_at TEXT,
        FOREIGN KEY (material_id) REFERENCES materials(id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_auto_orders_status ON auto_orders(status)');
    await db.execute('CREATE INDEX idx_auto_orders_material ON auto_orders(material_id)');
    
    // Warehouse closings
    await db.execute('''
      CREATE TABLE warehouse_closings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        closing_date TEXT NOT NULL,
        period_from TEXT NOT NULL,
        period_to TEXT NOT NULL,
        status TEXT DEFAULT 'open',
        notes TEXT,
        created_by TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        closed_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_warehouse_closings_date ON warehouse_closings(closing_date)');
    await db.execute('CREATE INDEX idx_warehouse_closings_status ON warehouse_closings(status)');
    
    // Audit log
    await db.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER,
        action TEXT NOT NULL,
        old_value TEXT,
        new_value TEXT,
        user_id TEXT NOT NULL,
        user_name TEXT NOT NULL,
        ip_address TEXT,
        user_agent TEXT,
        notes TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id)');
    await db.execute('CREATE INDEX idx_audit_logs_action ON audit_logs(action)');
    await db.execute('CREATE INDEX idx_audit_logs_date ON audit_logs(created_at)');
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}
