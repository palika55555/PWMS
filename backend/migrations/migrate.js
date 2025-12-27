const pool = require('../config/database');

async function checkTableExists(client, tableName) {
  const result = await client.query(
    `SELECT EXISTS (
      SELECT FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = $1
    )`,
    [tableName]
  );
  return result.rows[0].exists;
}

async function getColumnType(client, tableName, columnName) {
  const result = await client.query(
    `SELECT data_type
     FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = $1 AND column_name = $2`,
    [tableName, columnName]
  );
  return result.rows[0]?.data_type;
}

async function getExistingColumns(client, tableName) {
  const result = await client.query(
    `SELECT column_name
     FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = $1`,
    [tableName]
  );
  return new Set(result.rows.map((r) => r.column_name));
}

async function ensureMissingColumns(client, tableName, columns) {
  // columns: Array<{ name: string, sql: string }>
  const existing = await getExistingColumns(client, tableName);
  for (const col of columns) {
    if (existing.has(col.name)) continue;
    console.warn(`[migrate] Adding missing column ${tableName}.${col.name}`);
    await client.query(`ALTER TABLE ${tableName} ADD COLUMN ${col.sql}`);
  }
}

async function dropAllTables(client) {
  // Drop in child->parent order (CASCADE for safety)
  await client.query('DROP TABLE IF EXISTS audit_logs CASCADE');
  await client.query('DROP TABLE IF EXISTS warehouse_closings CASCADE');
  await client.query('DROP TABLE IF EXISTS auto_orders CASCADE');
  await client.query('DROP TABLE IF EXISTS purchase_price_list_items CASCADE');
  await client.query('DROP TABLE IF EXISTS purchase_price_lists CASCADE');
  await client.query('DROP TABLE IF EXISTS product_accessories CASCADE');
  await client.query('DROP TABLE IF EXISTS product_variants CASCADE');
  await client.query('DROP TABLE IF EXISTS unit_conversions CASCADE');
  await client.query('DROP TABLE IF EXISTS price_history CASCADE');
  await client.query('DROP TABLE IF EXISTS inventory_items CASCADE');
  await client.query('DROP TABLE IF EXISTS inventories CASCADE');
  await client.query('DROP TABLE IF EXISTS stock_movements CASCADE');
  await client.query('DROP TABLE IF EXISTS warehouse_locations CASCADE');
  await client.query('DROP TABLE IF EXISTS warehouses CASCADE');
  await client.query('DROP TABLE IF EXISTS customers CASCADE');
  await client.query('DROP TABLE IF EXISTS suppliers CASCADE');
  await client.query('DROP TABLE IF EXISTS products CASCADE');
  await client.query('DROP TABLE IF EXISTS quality_tests CASCADE');
  await client.query('DROP TABLE IF EXISTS batch_materials CASCADE');
  await client.query('DROP TABLE IF EXISTS batches CASCADE');
  await client.query('DROP TABLE IF EXISTS recipe_aggregates CASCADE');
  await client.query('DROP TABLE IF EXISTS recipes CASCADE');
  await client.query('DROP TABLE IF EXISTS aggregate_fractions CASCADE');
  await client.query('DROP TABLE IF EXISTS materials CASCADE');
}

async function ensureMaterialsIdIsInteger(client) {
  const type = await getColumnType(client, 'materials', 'id');
  if (!type) return;

  if (type === 'integer') return;

  // Common bad state: id is varchar/text from previous schema.
  if (type === 'character varying' || type === 'text') {
    const nonNumeric = await client.query(
      `SELECT COUNT(*)::int AS cnt
       FROM materials
       WHERE id IS NOT NULL AND id !~ '^[0-9]+$'`
    );

    if ((nonNumeric.rows[0]?.cnt ?? 0) > 0) {
      throw new Error(
        `[migrate] materials.id is ${type} but contains non-numeric values; cannot auto-convert to integer. ` +
          `Reset the Railway Postgres database or set PWMS_FORCE_RESET_DB=1 to drop tables.`
      );
    }

    console.warn(`[migrate] Converting materials.id from ${type} -> integer (numeric values detected)`);
    await client.query(`ALTER TABLE materials ALTER COLUMN id TYPE INTEGER USING id::integer`);

    // Ensure sequence exists and default is set, so inserts keep working.
    await client.query(`DO $$ BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'materials_id_seq') THEN
        CREATE SEQUENCE materials_id_seq;
      END IF;
    END $$;`);

    await client.query(`ALTER TABLE materials ALTER COLUMN id SET DEFAULT nextval('materials_id_seq')`);
    await client.query(
      `SELECT setval('materials_id_seq', GREATEST((SELECT COALESCE(MAX(id), 0) FROM materials), 1))`
    );
    return;
  }

  throw new Error(`[migrate] Unsupported materials.id type: ${type}`);
}

async function runMigrations() {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');

    // Optional safety hatch: wipe schema then recreate cleanly.
    if (process.env.PWMS_FORCE_RESET_DB === '1') {
      console.warn('[migrate] PWMS_FORCE_RESET_DB=1 -> dropping existing tables (destructive)');
      await dropAllTables(client);
    }

    // Materials table
    const materialsExists = await checkTableExists(client, 'materials');
    if (!materialsExists) {
      await client.query(`
        CREATE TABLE materials (
          id SERIAL PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          type VARCHAR(50) NOT NULL,
          category TEXT DEFAULT 'warehouse',
          unit VARCHAR(20) NOT NULL,
          current_stock DECIMAL(10, 2) DEFAULT 0,
          min_stock DECIMAL(10, 2) DEFAULT 0,
          plu_code TEXT,
          ean_code TEXT,
          average_purchase_price_without_vat NUMERIC,
          average_purchase_price_with_vat NUMERIC,
          sale_price NUMERIC,
          vat_rate NUMERIC DEFAULT 20.0,
          has_recycling_fee BOOLEAN DEFAULT FALSE,
          recycling_fee NUMERIC,
          default_supplier_id INTEGER,
          warehouse_number TEXT,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created materials table');
    } else {
      console.log('Materials table already exists');
      // Repair legacy schemas where materials.id is not integer.
      await ensureMaterialsIdIsInteger(client);
    }
    await ensureMissingColumns(client, 'materials', [
      { name: 'category', sql: "category TEXT DEFAULT 'warehouse'" },
      { name: 'plu_code', sql: 'plu_code TEXT' },
      { name: 'ean_code', sql: 'ean_code TEXT' },
      { name: 'average_purchase_price_without_vat', sql: 'average_purchase_price_without_vat NUMERIC' },
      { name: 'average_purchase_price_with_vat', sql: 'average_purchase_price_with_vat NUMERIC' },
      { name: 'sale_price', sql: 'sale_price NUMERIC' },
      { name: 'vat_rate', sql: 'vat_rate NUMERIC DEFAULT 20.0' },
      { name: 'has_recycling_fee', sql: 'has_recycling_fee BOOLEAN DEFAULT FALSE' },
      { name: 'recycling_fee', sql: 'recycling_fee NUMERIC' },
      { name: 'default_supplier_id', sql: 'default_supplier_id INTEGER' },
      { name: 'warehouse_number', sql: 'warehouse_number TEXT' },
    ]);

    // Aggregate fractions table
    const fractionsExists = await checkTableExists(client, 'aggregate_fractions');
    if (!fractionsExists) {
      await client.query(`
        CREATE TABLE aggregate_fractions (
          id SERIAL PRIMARY KEY,
          material_id INTEGER REFERENCES materials(id) ON DELETE CASCADE,
          fraction_name VARCHAR(100) NOT NULL,
          size_min DECIMAL(10, 2),
          size_max DECIMAL(10, 2),
          synced BOOLEAN DEFAULT TRUE
        )
      `);
      console.log('Created aggregate_fractions table');
    } else {
      console.log('Aggregate_fractions table already exists');
    }

    // Recipes table
    const recipesExists = await checkTableExists(client, 'recipes');
    if (!recipesExists) {
      await client.query(`
        CREATE TABLE recipes (
          id SERIAL PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          product_type VARCHAR(100) NOT NULL,
          description TEXT,
          cement_amount DECIMAL(10, 2) NOT NULL,
          water_amount DECIMAL(10, 2) NOT NULL,
          plasticizer_amount DECIMAL(10, 2),
          wc_ratio DECIMAL(5, 2),
          mixer_capacity NUMERIC,
          products_per_mixer INTEGER,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created recipes table');
    } else {
      console.log('Recipes table already exists');
    }
    await ensureMissingColumns(client, 'recipes', [
      { name: 'mixer_capacity', sql: 'mixer_capacity NUMERIC' },
      { name: 'products_per_mixer', sql: 'products_per_mixer INTEGER' },
    ]);

    // Recipe aggregates table
    const recipeAggregatesExists = await checkTableExists(client, 'recipe_aggregates');
    if (!recipeAggregatesExists) {
      await client.query(`
        CREATE TABLE recipe_aggregates (
          id SERIAL PRIMARY KEY,
          recipe_id INTEGER REFERENCES recipes(id) ON DELETE CASCADE,
          material_id INTEGER REFERENCES materials(id) ON DELETE CASCADE,
          fraction_id INTEGER REFERENCES aggregate_fractions(id) ON DELETE SET NULL,
          amount DECIMAL(10, 2) NOT NULL,
          synced BOOLEAN DEFAULT TRUE
        )
      `);
      console.log('Created recipe_aggregates table');
    } else {
      console.log('Recipe_aggregates table already exists');
    }

    // Batches table
    const batchesExists = await checkTableExists(client, 'batches');
    if (!batchesExists) {
      await client.query(`
        CREATE TABLE batches (
          id SERIAL PRIMARY KEY,
          batch_number VARCHAR(100) UNIQUE NOT NULL,
          recipe_id INTEGER REFERENCES recipes(id),
          production_date DATE NOT NULL,
          quantity INTEGER NOT NULL,
          quality_status VARCHAR(20) DEFAULT 'pending',
          quality_approved_by VARCHAR(255),
          quality_approved_at TIMESTAMP,
          notes TEXT,
          drying_days INTEGER,
          curing_start_date TEXT,
          curing_end_date TEXT,
          production_temperature NUMERIC,
          production_humidity NUMERIC,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created batches table');
    } else {
      console.log('Batches table already exists');
    }
    await ensureMissingColumns(client, 'batches', [
      { name: 'drying_days', sql: 'drying_days INTEGER' },
      { name: 'curing_start_date', sql: 'curing_start_date TEXT' },
      { name: 'curing_end_date', sql: 'curing_end_date TEXT' },
      { name: 'production_temperature', sql: 'production_temperature NUMERIC' },
      { name: 'production_humidity', sql: 'production_humidity NUMERIC' },
    ]);

    // Batch materials table
    const batchMaterialsExists = await checkTableExists(client, 'batch_materials');
    if (!batchMaterialsExists) {
      await client.query(`
        CREATE TABLE batch_materials (
          id SERIAL PRIMARY KEY,
          batch_id INTEGER REFERENCES batches(id) ON DELETE CASCADE,
          material_id INTEGER REFERENCES materials(id) ON DELETE CASCADE,
          fraction_id INTEGER REFERENCES aggregate_fractions(id) ON DELETE SET NULL,
          planned_amount DECIMAL(10, 2) NOT NULL,
          actual_amount DECIMAL(10, 2),
          synced BOOLEAN DEFAULT TRUE
        )
      `);
      console.log('Created batch_materials table');
    } else {
      console.log('Batch_materials table already exists');
    }

    // Quality tests table
    const qualityTestsExists = await checkTableExists(client, 'quality_tests');
    if (!qualityTestsExists) {
      await client.query(`
        CREATE TABLE quality_tests (
          id SERIAL PRIMARY KEY,
          batch_id INTEGER REFERENCES batches(id) ON DELETE CASCADE,
          test_type VARCHAR(100) NOT NULL,
          test_value DECIMAL(10, 2),
          test_unit VARCHAR(20),
          test_result VARCHAR(20),
          test_date TIMESTAMP NOT NULL,
          tested_by VARCHAR(255),
          notes TEXT,
          synced BOOLEAN DEFAULT TRUE
        )
      `);
      console.log('Created quality_tests table');
    } else {
      console.log('Quality_tests table already exists');
    }

    // Products table
    const productsExists = await checkTableExists(client, 'products');
    if (!productsExists) {
      await client.query(`
        CREATE TABLE products (
          id SERIAL PRIMARY KEY,
          batch_id INTEGER REFERENCES batches(id) ON DELETE CASCADE,
          product_code VARCHAR(100) UNIQUE,
          qr_code VARCHAR(255) UNIQUE,
          serial_number TEXT,
          production_number TEXT,
          expiration_date TEXT,
          status VARCHAR(50) DEFAULT 'produced',
          location VARCHAR(255),
          warehouse_location_id INTEGER,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created products table');
    } else {
      console.log('Products table already exists');
    }
    await ensureMissingColumns(client, 'products', [
      { name: 'serial_number', sql: 'serial_number TEXT' },
      { name: 'production_number', sql: 'production_number TEXT' },
      { name: 'expiration_date', sql: 'expiration_date TEXT' },
      { name: 'warehouse_location_id', sql: 'warehouse_location_id INTEGER' },
    ]);

    // Suppliers table
    const suppliersExists = await checkTableExists(client, 'suppliers');
    if (!suppliersExists) {
      await client.query(`
        CREATE TABLE suppliers (
          id SERIAL PRIMARY KEY,
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
          default_vat_rate NUMERIC,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created suppliers table');
    } else {
      console.log('Suppliers table already exists');
    }

    // Customers table
    const customersExists = await checkTableExists(client, 'customers');
    if (!customersExists) {
      await client.query(`
        CREATE TABLE customers (
          id SERIAL PRIMARY KEY,
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
          credit_limit NUMERIC,
          price_list TEXT,
          notes TEXT,
          is_active BOOLEAN DEFAULT TRUE,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created customers table');
    } else {
      console.log('Customers table already exists');
    }

    // Warehouses table
    const warehousesExists = await checkTableExists(client, 'warehouses');
    if (!warehousesExists) {
      await client.query(`
        CREATE TABLE warehouses (
          id SERIAL PRIMARY KEY,
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
          is_active BOOLEAN DEFAULT TRUE,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created warehouses table');
    } else {
      console.log('Warehouses table already exists');
    }

    // Warehouse locations table
    const warehouseLocationsExists = await checkTableExists(client, 'warehouse_locations');
    if (!warehouseLocationsExists) {
      await client.query(`
        CREATE TABLE warehouse_locations (
          id SERIAL PRIMARY KEY,
          name TEXT NOT NULL,
          code TEXT,
          address TEXT,
          city TEXT,
          zip_code TEXT,
          country TEXT,
          contact_person TEXT,
          phone TEXT,
          email TEXT,
          is_active BOOLEAN DEFAULT TRUE,
          is_default BOOLEAN DEFAULT FALSE,
          notes TEXT,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created warehouse_locations table');
    } else {
      console.log('Warehouse_locations table already exists');
    }

    // Stock movements table
    const stockMovementsExists = await checkTableExists(client, 'stock_movements');
    if (!stockMovementsExists) {
      await client.query(`
        CREATE TABLE stock_movements (
          id SERIAL PRIMARY KEY,
          movement_type TEXT NOT NULL,
          material_id INTEGER REFERENCES materials(id) ON DELETE SET NULL,
          quantity NUMERIC NOT NULL,
          unit TEXT NOT NULL,
          document_number TEXT,
          supplier_name TEXT,
          recipient_name TEXT,
          reason TEXT,
          location TEXT,
          notes TEXT,
          product_note TEXT,
          expiration_date TEXT,
          purchase_price_without_vat NUMERIC,
          purchase_price_with_vat NUMERIC,
          vat_rate NUMERIC,
          supplier_id INTEGER REFERENCES suppliers(id) ON DELETE SET NULL,
          warehouse_id INTEGER REFERENCES warehouses(id) ON DELETE SET NULL,
          movement_date TEXT NOT NULL,
          delivery_date TEXT,
          created_by TEXT NOT NULL,
          status TEXT DEFAULT 'pending',
          approved_by TEXT,
          approved_at TEXT,
          rejection_reason TEXT,
          receipt_number TEXT,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created stock_movements table');
    } else {
      console.log('Stock_movements table already exists');
    }

    // Inventories table
    const inventoriesExists = await checkTableExists(client, 'inventories');
    if (!inventoriesExists) {
      await client.query(`
        CREATE TABLE inventories (
          id SERIAL PRIMARY KEY,
          inventory_date TEXT NOT NULL,
          status TEXT DEFAULT 'planned',
          location TEXT,
          notes TEXT,
          created_by TEXT NOT NULL,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created inventories table');
    } else {
      console.log('Inventories table already exists');
    }

    // Inventory items table
    const inventoryItemsExists = await checkTableExists(client, 'inventory_items');
    if (!inventoryItemsExists) {
      await client.query(`
        CREATE TABLE inventory_items (
          id SERIAL PRIMARY KEY,
          inventory_id INTEGER REFERENCES inventories(id) ON DELETE CASCADE,
          material_id INTEGER REFERENCES materials(id) ON DELETE CASCADE,
          recorded_quantity NUMERIC NOT NULL,
          actual_quantity NUMERIC NOT NULL,
          difference NUMERIC NOT NULL,
          unit TEXT NOT NULL,
          notes TEXT,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created inventory_items table');
    } else {
      console.log('Inventory_items table already exists');
    }

    // Price history table
    const priceHistoryExists = await checkTableExists(client, 'price_history');
    if (!priceHistoryExists) {
      await client.query(`
        CREATE TABLE price_history (
          id SERIAL PRIMARY KEY,
          material_id INTEGER REFERENCES materials(id) ON DELETE CASCADE,
          supplier_id INTEGER REFERENCES suppliers(id) ON DELETE SET NULL,
          quantity NUMERIC NOT NULL,
          purchase_price_without_vat NUMERIC NOT NULL,
          purchase_price_with_vat NUMERIC NOT NULL,
          sale_price NUMERIC,
          vat_rate NUMERIC DEFAULT 20.0,
          price_date TEXT NOT NULL,
          document_number TEXT,
          notes TEXT,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created price_history table');
    } else {
      console.log('Price_history table already exists');
    }

    // Unit conversions table
    const unitConversionsExists = await checkTableExists(client, 'unit_conversions');
    if (!unitConversionsExists) {
      await client.query(`
        CREATE TABLE unit_conversions (
          id SERIAL PRIMARY KEY,
          material_id INTEGER REFERENCES materials(id) ON DELETE CASCADE,
          from_unit TEXT NOT NULL,
          to_unit TEXT NOT NULL,
          conversion_factor NUMERIC NOT NULL,
          is_default BOOLEAN DEFAULT FALSE,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created unit_conversions table');
    } else {
      console.log('Unit_conversions table already exists');
    }

    // Product variants table
    const productVariantsExists = await checkTableExists(client, 'product_variants');
    if (!productVariantsExists) {
      await client.query(`
        CREATE TABLE product_variants (
          id SERIAL PRIMARY KEY,
          material_id INTEGER REFERENCES materials(id) ON DELETE CASCADE,
          variant_type TEXT NOT NULL,
          variant_value TEXT NOT NULL,
          variant_code TEXT,
          ean_code TEXT,
          additional_price NUMERIC,
          is_active BOOLEAN DEFAULT TRUE,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created product_variants table');
    } else {
      console.log('Product_variants table already exists');
    }

    // Product accessories table
    const productAccessoriesExists = await checkTableExists(client, 'product_accessories');
    if (!productAccessoriesExists) {
      await client.query(`
        CREATE TABLE product_accessories (
          id SERIAL PRIMARY KEY,
          material_id INTEGER REFERENCES materials(id) ON DELETE CASCADE,
          accessory_material_id INTEGER REFERENCES materials(id) ON DELETE CASCADE,
          relation_type TEXT NOT NULL,
          quantity INTEGER,
          notes TEXT,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created product_accessories table');
    } else {
      console.log('Product_accessories table already exists');
    }

    // Purchase price lists table
    const purchasePriceListsExists = await checkTableExists(client, 'purchase_price_lists');
    if (!purchasePriceListsExists) {
      await client.query(`
        CREATE TABLE purchase_price_lists (
          id SERIAL PRIMARY KEY,
          supplier_id INTEGER REFERENCES suppliers(id) ON DELETE CASCADE,
          name TEXT NOT NULL,
          code TEXT,
          valid_from TEXT NOT NULL,
          valid_to TEXT,
          is_active BOOLEAN DEFAULT TRUE,
          notes TEXT,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created purchase_price_lists table');
    } else {
      console.log('Purchase_price_lists table already exists');
    }

    // Purchase price list items table
    const purchasePriceListItemsExists = await checkTableExists(client, 'purchase_price_list_items');
    if (!purchasePriceListItemsExists) {
      await client.query(`
        CREATE TABLE purchase_price_list_items (
          id SERIAL PRIMARY KEY,
          price_list_id INTEGER REFERENCES purchase_price_lists(id) ON DELETE CASCADE,
          material_id INTEGER REFERENCES materials(id) ON DELETE CASCADE,
          price_without_vat NUMERIC NOT NULL,
          price_with_vat NUMERIC NOT NULL,
          vat_rate NUMERIC DEFAULT 20.0,
          min_quantity NUMERIC,
          notes TEXT,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created purchase_price_list_items table');
    } else {
      console.log('Purchase_price_list_items table already exists');
    }

    // Auto orders table
    const autoOrdersExists = await checkTableExists(client, 'auto_orders');
    if (!autoOrdersExists) {
      await client.query(`
        CREATE TABLE auto_orders (
          id SERIAL PRIMARY KEY,
          material_id INTEGER REFERENCES materials(id) ON DELETE CASCADE,
          supplier_id INTEGER REFERENCES suppliers(id) ON DELETE CASCADE,
          suggested_quantity NUMERIC NOT NULL,
          current_stock NUMERIC NOT NULL,
          min_stock NUMERIC NOT NULL,
          max_stock NUMERIC DEFAULT 0,
          reason TEXT NOT NULL,
          status TEXT DEFAULT 'pending',
          notes TEXT,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          ordered_at TEXT
        )
      `);
      console.log('Created auto_orders table');
    } else {
      console.log('Auto_orders table already exists');
    }

    // Warehouse closings table
    const warehouseClosingsExists = await checkTableExists(client, 'warehouse_closings');
    if (!warehouseClosingsExists) {
      await client.query(`
        CREATE TABLE warehouse_closings (
          id SERIAL PRIMARY KEY,
          closing_date TEXT NOT NULL,
          period_from TEXT NOT NULL,
          period_to TEXT NOT NULL,
          status TEXT DEFAULT 'open',
          notes TEXT,
          created_by TEXT NOT NULL,
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          closed_at TEXT
        )
      `);
      console.log('Created warehouse_closings table');
    } else {
      console.log('Warehouse_closings table already exists');
    }

    // Audit logs table
    const auditLogsExists = await checkTableExists(client, 'audit_logs');
    if (!auditLogsExists) {
      await client.query(`
        CREATE TABLE audit_logs (
          id SERIAL PRIMARY KEY,
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
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created audit_logs table');
    } else {
      console.log('Audit_logs table already exists');
    }

    // Create indexes
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_batches_date ON batches(production_date)
    `);
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_batches_status ON batches(quality_status)
    `);
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_products_batch ON products(batch_id)
    `);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_warehouses_name ON warehouses(name)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_warehouses_code ON warehouses(code)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_stock_movements_date ON stock_movements(movement_date)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_stock_movements_type ON stock_movements(movement_type)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_stock_movements_material ON stock_movements(material_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_stock_movements_status ON stock_movements(status)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_stock_movements_receipt_number ON stock_movements(receipt_number)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_inventory_items_inventory ON inventory_items(inventory_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_price_history_material ON price_history(material_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_price_history_date ON price_history(price_date)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_unit_conversions_material ON unit_conversions(material_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_product_variants_material ON product_variants(material_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_product_accessories_material ON product_accessories(material_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_price_lists_supplier ON purchase_price_lists(supplier_id)`);
    await client.query(
      `CREATE INDEX IF NOT EXISTS idx_price_list_items_price_list ON purchase_price_list_items(price_list_id)`
    );
    await client.query(`CREATE INDEX IF NOT EXISTS idx_auto_orders_status ON auto_orders(status)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_auto_orders_material ON auto_orders(material_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_warehouse_closings_date ON warehouse_closings(closing_date)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_warehouse_closings_status ON warehouse_closings(status)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_audit_logs_date ON audit_logs(created_at)`);

    await client.query('COMMIT');
    console.log('All migrations completed successfully');
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Migration error:', error);
    throw error;
  } finally {
    client.release();
  }
}

module.exports = { runMigrations };









