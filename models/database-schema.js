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

  // Recipes (recepty pre výrobu)
  db.exec(`
    CREATE TABLE IF NOT EXISTS recipes (
      id TEXT PRIMARY KEY,
      production_type_id TEXT NOT NULL,
      name TEXT NOT NULL,
      description TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      synced INTEGER DEFAULT 0,
      FOREIGN KEY (production_type_id) REFERENCES production_types(id)
    )
  `);

  // Recipe materials (materiály v recepte)
  db.exec(`
    CREATE TABLE IF NOT EXISTS recipe_materials (
      id TEXT PRIMARY KEY,
      recipe_id TEXT NOT NULL,
      material_id TEXT NOT NULL,
      quantity_per_unit REAL NOT NULL,
      synced INTEGER DEFAULT 0,
      FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE,
      FOREIGN KEY (material_id) REFERENCES materials(id)
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
      status TEXT DEFAULT 'completed',
      recipe_id TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      synced INTEGER DEFAULT 0,
      FOREIGN KEY (production_type_id) REFERENCES production_types(id),
      FOREIGN KEY (recipe_id) REFERENCES recipes(id)
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

  // Batches (šarže) - rozšírenie production tabuľky
  db.exec(`
    CREATE TABLE IF NOT EXISTS batches (
      id TEXT PRIMARY KEY,
      production_id TEXT NOT NULL,
      batch_number TEXT UNIQUE NOT NULL,
      qr_code TEXT,
      quantity REAL NOT NULL,
      status TEXT DEFAULT 'pending', -- pending, in_progress, completed, shipped
      warehouse_location TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      shipped_at DATETIME,
      synced INTEGER DEFAULT 0,
      FOREIGN KEY (production_id) REFERENCES production(id) ON DELETE CASCADE
    )
  `);

  // Recipe versions (verzie receptúr)
  db.exec(`
    CREATE TABLE IF NOT EXISTS recipe_versions (
      id TEXT PRIMARY KEY,
      recipe_id TEXT NOT NULL,
      version_number INTEGER NOT NULL,
      name TEXT NOT NULL,
      description TEXT,
      is_active INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      created_by TEXT,
      synced INTEGER DEFAULT 0,
      FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
    )
  `);

  // Recipe version materials
  db.exec(`
    CREATE TABLE IF NOT EXISTS recipe_version_materials (
      id TEXT PRIMARY KEY,
      recipe_version_id TEXT NOT NULL,
      material_id TEXT NOT NULL,
      quantity_per_unit REAL NOT NULL,
      synced INTEGER DEFAULT 0,
      FOREIGN KEY (recipe_version_id) REFERENCES recipe_versions(id) ON DELETE CASCADE,
      FOREIGN KEY (material_id) REFERENCES materials(id)
    )
  `);

  // Quality control (kontrola kvality)
  db.exec(`
    CREATE TABLE IF NOT EXISTS quality_control (
      id TEXT PRIMARY KEY,
      batch_id TEXT NOT NULL,
      test_type TEXT NOT NULL, -- strength, resistance, dimensions, etc.
      test_name TEXT NOT NULL,
      result_value REAL,
      result_text TEXT,
      passed INTEGER DEFAULT 0,
      tested_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      tested_by TEXT,
      notes TEXT,
      synced INTEGER DEFAULT 0,
      FOREIGN KEY (batch_id) REFERENCES batches(id) ON DELETE CASCADE
    )
  `);

  // Defective pieces (nekvalitné kusy)
  db.exec(`
    CREATE TABLE IF NOT EXISTS defective_pieces (
      id TEXT PRIMARY KEY,
      batch_id TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      reason TEXT NOT NULL,
      recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      recorded_by TEXT,
      synced INTEGER DEFAULT 0,
      FOREIGN KEY (batch_id) REFERENCES batches(id) ON DELETE CASCADE
    )
  `);

  // Production plans (výrobné plány)
  db.exec(`
    CREATE TABLE IF NOT EXISTS production_plans (
      id TEXT PRIMARY KEY,
      production_type_id TEXT NOT NULL,
      planned_quantity REAL NOT NULL,
      planned_date DATE NOT NULL,
      priority TEXT DEFAULT 'normal', -- urgent, normal, low
      status TEXT DEFAULT 'planned', -- planned, in_progress, completed, cancelled
      assigned_recipe_id TEXT,
      notes TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      synced INTEGER DEFAULT 0,
      FOREIGN KEY (production_type_id) REFERENCES production_types(id),
      FOREIGN KEY (assigned_recipe_id) REFERENCES recipes(id)
    )
  `);

  // Machines (stroje a zariadenia)
  db.exec(`
    CREATE TABLE IF NOT EXISTS machines (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT,
      status TEXT DEFAULT 'operational', -- operational, maintenance, breakdown
      last_maintenance_date DATETIME,
      next_maintenance_date DATETIME,
      notes TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      synced INTEGER DEFAULT 0
    )
  `);

  // Machine maintenance (údržba strojov)
  db.exec(`
    CREATE TABLE IF NOT EXISTS machine_maintenance (
      id TEXT PRIMARY KEY,
      machine_id TEXT NOT NULL,
      maintenance_type TEXT NOT NULL, -- planned, unplanned
      description TEXT,
      performed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      performed_by TEXT,
      duration_minutes INTEGER,
      cost REAL,
      synced INTEGER DEFAULT 0,
      FOREIGN KEY (machine_id) REFERENCES machines(id) ON DELETE CASCADE
    )
  `);

  // Workers (pracovníci)
  db.exec(`
    CREATE TABLE IF NOT EXISTS workers (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      position TEXT,
      shift TEXT, -- morning, afternoon, night
      active INTEGER DEFAULT 1,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      synced INTEGER DEFAULT 0
    )
  `);

  // Production assignments (pridelenie pracovníkov)
  db.exec(`
    CREATE TABLE IF NOT EXISTS production_assignments (
      id TEXT PRIMARY KEY,
      production_id TEXT NOT NULL,
      worker_id TEXT NOT NULL,
      shift TEXT,
      start_time DATETIME,
      end_time DATETIME,
      synced INTEGER DEFAULT 0,
      FOREIGN KEY (production_id) REFERENCES production(id) ON DELETE CASCADE,
      FOREIGN KEY (worker_id) REFERENCES workers(id)
    )
  `);

  // Material suppliers (dodávatelia materiálov)
  db.exec(`
    CREATE TABLE IF NOT EXISTS suppliers (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      contact_info TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      synced INTEGER DEFAULT 0
    )
  `);

  // Material supplier links (prepojenie materiálov s dodávateľmi)
  db.exec(`
    CREATE TABLE IF NOT EXISTS material_suppliers (
      id TEXT PRIMARY KEY,
      material_id TEXT NOT NULL,
      supplier_id TEXT NOT NULL,
      is_primary INTEGER DEFAULT 0,
      synced INTEGER DEFAULT 0,
      FOREIGN KEY (material_id) REFERENCES materials(id) ON DELETE CASCADE,
      FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE
    )
  `);

  // Notifications (notifikácie a varovania)
  db.exec(`
    CREATE TABLE IF NOT EXISTS notifications (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL, -- low_stock, maintenance_due, quality_issue, etc.
      title TEXT NOT NULL,
      message TEXT NOT NULL,
      severity TEXT DEFAULT 'info', -- info, warning, critical
      read INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      related_id TEXT, -- ID related entity (material_id, batch_id, etc.)
      synced INTEGER DEFAULT 0
    )
  `);

  // Warehouse minimum levels (minimálne úrovne zásob)
  db.exec(`
    CREATE TABLE IF NOT EXISTS warehouse_minimums (
      id TEXT PRIMARY KEY,
      material_id TEXT NOT NULL UNIQUE,
      minimum_quantity REAL NOT NULL,
      warning_quantity REAL,
      synced INTEGER DEFAULT 0,
      FOREIGN KEY (material_id) REFERENCES materials(id) ON DELETE CASCADE
    )
  `);

  // Create indexes
  db.exec(`
    CREATE INDEX IF NOT EXISTS idx_warehouse_material ON warehouse(material_id);
    CREATE INDEX IF NOT EXISTS idx_production_type ON production(production_type_id);
    CREATE INDEX IF NOT EXISTS idx_production_materials_prod ON production_materials(production_id);
    CREATE INDEX IF NOT EXISTS idx_production_materials_mat ON production_materials(material_id);
    CREATE INDEX IF NOT EXISTS idx_sync_queue_table ON sync_queue(table_name);
    CREATE INDEX IF NOT EXISTS idx_recipes_type ON recipes(production_type_id);
    CREATE INDEX IF NOT EXISTS idx_recipe_materials_recipe ON recipe_materials(recipe_id);
    CREATE INDEX IF NOT EXISTS idx_recipe_materials_mat ON recipe_materials(material_id);
    CREATE INDEX IF NOT EXISTS idx_batches_production ON batches(production_id);
    CREATE INDEX IF NOT EXISTS idx_batches_number ON batches(batch_number);
    CREATE INDEX IF NOT EXISTS idx_quality_control_batch ON quality_control(batch_id);
    CREATE INDEX IF NOT EXISTS idx_production_plans_date ON production_plans(planned_date);
    CREATE INDEX IF NOT EXISTS idx_production_plans_status ON production_plans(status);
    CREATE INDEX IF NOT EXISTS idx_machine_maintenance_machine ON machine_maintenance(machine_id);
    CREATE INDEX IF NOT EXISTS idx_production_assignments_prod ON production_assignments(production_id);
    CREATE INDEX IF NOT EXISTS idx_production_assignments_worker ON production_assignments(worker_id);
    CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read);
    CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
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

    // Recipes (recepty pre výrobu)
    await client.query(`
      CREATE TABLE IF NOT EXISTS recipes (
        id VARCHAR(255) PRIMARY KEY,
        production_type_id VARCHAR(255) NOT NULL,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 1,
        FOREIGN KEY (production_type_id) REFERENCES production_types(id)
      )
    `);

    // Recipe materials (materiály v recepte)
    await client.query(`
      CREATE TABLE IF NOT EXISTS recipe_materials (
        id VARCHAR(255) PRIMARY KEY,
        recipe_id VARCHAR(255) NOT NULL,
        material_id VARCHAR(255) NOT NULL,
        quantity_per_unit DECIMAL(15,2) NOT NULL,
        synced INTEGER DEFAULT 1,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE,
        FOREIGN KEY (material_id) REFERENCES materials(id)
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
        status VARCHAR(50) DEFAULT 'completed',
        recipe_id VARCHAR(255),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 1,
        FOREIGN KEY (production_type_id) REFERENCES production_types(id),
        FOREIGN KEY (recipe_id) REFERENCES recipes(id)
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

    // Batches (šarže)
    await client.query(`
      CREATE TABLE IF NOT EXISTS batches (
        id VARCHAR(255) PRIMARY KEY,
        production_id VARCHAR(255) NOT NULL,
        batch_number VARCHAR(255) UNIQUE NOT NULL,
        qr_code TEXT,
        quantity DECIMAL(15,2) NOT NULL,
        status VARCHAR(50) DEFAULT 'pending',
        warehouse_location VARCHAR(255),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        shipped_at TIMESTAMP,
        synced INTEGER DEFAULT 1,
        FOREIGN KEY (production_id) REFERENCES production(id) ON DELETE CASCADE
      )
    `);

    // Recipe versions
    await client.query(`
      CREATE TABLE IF NOT EXISTS recipe_versions (
        id VARCHAR(255) PRIMARY KEY,
        recipe_id VARCHAR(255) NOT NULL,
        version_number INTEGER NOT NULL,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        is_active INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_by VARCHAR(255),
        synced INTEGER DEFAULT 1,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
      )
    `);

    // Recipe version materials
    await client.query(`
      CREATE TABLE IF NOT EXISTS recipe_version_materials (
        id VARCHAR(255) PRIMARY KEY,
        recipe_version_id VARCHAR(255) NOT NULL,
        material_id VARCHAR(255) NOT NULL,
        quantity_per_unit DECIMAL(15,2) NOT NULL,
        synced INTEGER DEFAULT 1,
        FOREIGN KEY (recipe_version_id) REFERENCES recipe_versions(id) ON DELETE CASCADE,
        FOREIGN KEY (material_id) REFERENCES materials(id)
      )
    `);

    // Quality control
    await client.query(`
      CREATE TABLE IF NOT EXISTS quality_control (
        id VARCHAR(255) PRIMARY KEY,
        batch_id VARCHAR(255) NOT NULL,
        test_type VARCHAR(100) NOT NULL,
        test_name VARCHAR(255) NOT NULL,
        result_value DECIMAL(15,2),
        result_text TEXT,
        passed INTEGER DEFAULT 0,
        tested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        tested_by VARCHAR(255),
        notes TEXT,
        synced INTEGER DEFAULT 1,
        FOREIGN KEY (batch_id) REFERENCES batches(id) ON DELETE CASCADE
      )
    `);

    // Defective pieces
    await client.query(`
      CREATE TABLE IF NOT EXISTS defective_pieces (
        id VARCHAR(255) PRIMARY KEY,
        batch_id VARCHAR(255) NOT NULL,
        quantity INTEGER NOT NULL,
        reason TEXT NOT NULL,
        recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        recorded_by VARCHAR(255),
        synced INTEGER DEFAULT 1,
        FOREIGN KEY (batch_id) REFERENCES batches(id) ON DELETE CASCADE
      )
    `);

    // Production plans
    await client.query(`
      CREATE TABLE IF NOT EXISTS production_plans (
        id VARCHAR(255) PRIMARY KEY,
        production_type_id VARCHAR(255) NOT NULL,
        planned_quantity DECIMAL(15,2) NOT NULL,
        planned_date DATE NOT NULL,
        priority VARCHAR(50) DEFAULT 'normal',
        status VARCHAR(50) DEFAULT 'planned',
        assigned_recipe_id VARCHAR(255),
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 1,
        FOREIGN KEY (production_type_id) REFERENCES production_types(id),
        FOREIGN KEY (assigned_recipe_id) REFERENCES recipes(id)
      )
    `);

    // Machines
    await client.query(`
      CREATE TABLE IF NOT EXISTS machines (
        id VARCHAR(255) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        type VARCHAR(100),
        status VARCHAR(50) DEFAULT 'operational',
        last_maintenance_date TIMESTAMP,
        next_maintenance_date TIMESTAMP,
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 1
      )
    `);

    // Machine maintenance
    await client.query(`
      CREATE TABLE IF NOT EXISTS machine_maintenance (
        id VARCHAR(255) PRIMARY KEY,
        machine_id VARCHAR(255) NOT NULL,
        maintenance_type VARCHAR(50) NOT NULL,
        description TEXT,
        performed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        performed_by VARCHAR(255),
        duration_minutes INTEGER,
        cost DECIMAL(15,2),
        synced INTEGER DEFAULT 1,
        FOREIGN KEY (machine_id) REFERENCES machines(id) ON DELETE CASCADE
      )
    `);

    // Workers
    await client.query(`
      CREATE TABLE IF NOT EXISTS workers (
        id VARCHAR(255) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        position VARCHAR(100),
        shift VARCHAR(50),
        active INTEGER DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 1
      )
    `);

    // Production assignments
    await client.query(`
      CREATE TABLE IF NOT EXISTS production_assignments (
        id VARCHAR(255) PRIMARY KEY,
        production_id VARCHAR(255) NOT NULL,
        worker_id VARCHAR(255) NOT NULL,
        shift VARCHAR(50),
        start_time TIMESTAMP,
        end_time TIMESTAMP,
        synced INTEGER DEFAULT 1,
        FOREIGN KEY (production_id) REFERENCES production(id) ON DELETE CASCADE,
        FOREIGN KEY (worker_id) REFERENCES workers(id)
      )
    `);

    // Suppliers
    await client.query(`
      CREATE TABLE IF NOT EXISTS suppliers (
        id VARCHAR(255) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        contact_info TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 1
      )
    `);

    // Material suppliers
    await client.query(`
      CREATE TABLE IF NOT EXISTS material_suppliers (
        id VARCHAR(255) PRIMARY KEY,
        material_id VARCHAR(255) NOT NULL,
        supplier_id VARCHAR(255) NOT NULL,
        is_primary INTEGER DEFAULT 0,
        synced INTEGER DEFAULT 1,
        FOREIGN KEY (material_id) REFERENCES materials(id) ON DELETE CASCADE,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE
      )
    `);

    // Notifications
    await client.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id VARCHAR(255) PRIMARY KEY,
        type VARCHAR(100) NOT NULL,
        title VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        severity VARCHAR(50) DEFAULT 'info',
        read INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        related_id VARCHAR(255),
        synced INTEGER DEFAULT 1
      )
    `);

    // Warehouse minimums
    await client.query(`
      CREATE TABLE IF NOT EXISTS warehouse_minimums (
        id VARCHAR(255) PRIMARY KEY,
        material_id VARCHAR(255) NOT NULL UNIQUE,
        minimum_quantity DECIMAL(15,2) NOT NULL,
        warning_quantity DECIMAL(15,2),
        synced INTEGER DEFAULT 1,
        FOREIGN KEY (material_id) REFERENCES materials(id) ON DELETE CASCADE
      )
    `);

    // Create indexes
    await client.query(`CREATE INDEX IF NOT EXISTS idx_warehouse_material ON warehouse(material_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_production_type ON production(production_type_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_production_materials_prod ON production_materials(production_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_production_materials_mat ON production_materials(material_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_recipes_type ON recipes(production_type_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_recipe_materials_recipe ON recipe_materials(recipe_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_recipe_materials_mat ON recipe_materials(material_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_batches_production ON batches(production_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_batches_number ON batches(batch_number)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_quality_control_batch ON quality_control(batch_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_production_plans_date ON production_plans(planned_date)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_production_plans_status ON production_plans(status)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_machine_maintenance_machine ON machine_maintenance(machine_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_production_assignments_prod ON production_assignments(production_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_production_assignments_worker ON production_assignments(worker_id)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type)`);
  } finally {
    client.release();
  }
};

