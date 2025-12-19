// Database schema for both SQLite (local) and PostgreSQL (remote)

export const createLocalSchema = (db) => {
  // Materials table (materiály)
  db.exec(`
    CREATE TABLE IF NOT EXISTS materials (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      unit TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      synced INTEGER DEFAULT 0
    )
  `);

  // Warehouse/Inventory table (sklad)
  db.exec(`
    CREATE TABLE IF NOT EXISTS warehouse (
      id TEXT PRIMARY KEY,
      material_id TEXT NOT NULL,
      quantity REAL NOT NULL,
      last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
      synced INTEGER DEFAULT 0,
      FOREIGN KEY (material_id) REFERENCES materials(id)
    )
  `);

  // Production types (typy výroby - tvárnice, dlažba, atď)
  db.exec(`
    CREATE TABLE IF NOT EXISTS production_types (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      synced INTEGER DEFAULT 0
    )
  `);

  // Production records (záznamy výroby)
  db.exec(`
    CREATE TABLE IF NOT EXISTS production (
      id TEXT PRIMARY KEY,
      production_type_id TEXT NOT NULL,
      quantity REAL NOT NULL,
      production_date DATETIME DEFAULT CURRENT_TIMESTAMP,
      notes TEXT,
      qr_code TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      synced INTEGER DEFAULT 0,
      FOREIGN KEY (production_type_id) REFERENCES production_types(id)
    )
  `);

  // Production materials (materiály použité na výrobu)
  db.exec(`
    CREATE TABLE IF NOT EXISTS production_materials (
      id TEXT PRIMARY KEY,
      production_id TEXT NOT NULL,
      material_id TEXT NOT NULL,
      quantity REAL NOT NULL,
      synced INTEGER DEFAULT 0,
      FOREIGN KEY (production_id) REFERENCES production(id) ON DELETE CASCADE,
      FOREIGN KEY (material_id) REFERENCES materials(id)
    )
  `);

  // Sync queue for offline changes
  db.exec(`
    CREATE TABLE IF NOT EXISTS sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      table_name TEXT NOT NULL,
      record_id TEXT NOT NULL,
      operation TEXT NOT NULL,
      data TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // Create indexes
  db.exec(`
    CREATE INDEX IF NOT EXISTS idx_warehouse_material ON warehouse(material_id);
    CREATE INDEX IF NOT EXISTS idx_production_type ON production(production_type_id);
    CREATE INDEX IF NOT EXISTS idx_production_materials_prod ON production_materials(production_id);
    CREATE INDEX IF NOT EXISTS idx_production_materials_mat ON production_materials(material_id);
    CREATE INDEX IF NOT EXISTS idx_sync_queue_table ON sync_queue(table_name);
  `);
};

export const createRemoteSchema = async (pool) => {
  const client = await pool.connect();
  try {
    // Materials table
    await client.query(`
      CREATE TABLE IF NOT EXISTS materials (
        id VARCHAR(255) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        unit VARCHAR(50) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 1
      )
    `);

    // Warehouse/Inventory table
    await client.query(`
      CREATE TABLE IF NOT EXISTS warehouse (
        id VARCHAR(255) PRIMARY KEY,
        material_id VARCHAR(255) NOT NULL,
        quantity DECIMAL(15,2) NOT NULL,
        last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 1,
        FOREIGN KEY (material_id) REFERENCES materials(id)
      )
    `);

    // Production types
    await client.query(`
      CREATE TABLE IF NOT EXISTS production_types (
        id VARCHAR(255) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 1
      )
    `);

    // Production records
    await client.query(`
      CREATE TABLE IF NOT EXISTS production (
        id VARCHAR(255) PRIMARY KEY,
        production_type_id VARCHAR(255) NOT NULL,
        quantity DECIMAL(15,2) NOT NULL,
        production_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        notes TEXT,
        qr_code TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 1,
        FOREIGN KEY (production_type_id) REFERENCES production_types(id)
      )
    `);

    // Production materials
    await client.query(`
      CREATE TABLE IF NOT EXISTS production_materials (
        id VARCHAR(255) PRIMARY KEY,
        production_id VARCHAR(255) NOT NULL,
        material_id VARCHAR(255) NOT NULL,
        quantity DECIMAL(15,2) NOT NULL,
        synced INTEGER DEFAULT 1,
        FOREIGN KEY (production_id) REFERENCES production(id) ON DELETE CASCADE,
        FOREIGN KEY (material_id) REFERENCES materials(id)
      )
    `);

    // Create indexes
    await client.query(`CREATE INDEX IF NOT EXISTS idx_warehouse_material ON warehouse(material_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_production_type ON production(production_type_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_production_materials_prod ON production_materials(production_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_production_materials_mat ON production_materials(material_id)`);
  } finally {
    client.release();
  }
};

