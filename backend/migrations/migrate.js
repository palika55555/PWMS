const pool = require('../config/database');

async function checkTableExists(tableName) {
  const result = await pool.query(
    `SELECT EXISTS (
      SELECT FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = $1
    )`,
    [tableName]
  );
  return result.rows[0].exists;
}

async function runMigrations() {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');

    // Materials table
    const materialsExists = await checkTableExists('materials');
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
    }

    // Aggregate fractions table
    const fractionsExists = await checkTableExists('aggregate_fractions');
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
    const recipesExists = await checkTableExists('recipes');
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
    const recipeAggregatesExists = await checkTableExists('recipe_aggregates');
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
    const batchesExists = await checkTableExists('batches');
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
    const batchMaterialsExists = await checkTableExists('batch_materials');
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
    const qualityTestsExists = await checkTableExists('quality_tests');
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
    const productsExists = await checkTableExists('products');
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






