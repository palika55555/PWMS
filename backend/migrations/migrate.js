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

async function dropAllTables(client) {
  // Drop in child->parent order (CASCADE for safety)
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
          unit VARCHAR(20) NOT NULL,
          current_stock DECIMAL(10, 2) DEFAULT 0,
          min_stock DECIMAL(10, 2) DEFAULT 0,
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
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created recipes table');
    } else {
      console.log('Recipes table already exists');
    }

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
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created batches table');
    } else {
      console.log('Batches table already exists');
    }

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
          status VARCHAR(50) DEFAULT 'produced',
          location VARCHAR(255),
          synced BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Created products table');
    } else {
      console.log('Products table already exists');
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









