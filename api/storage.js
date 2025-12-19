// Storage helper pre Railway backend s PostgreSQL
const { Pool } = require('pg');

// Inicializácia PostgreSQL connection pool
let pool = null;

function getPool() {
  if (!pool) {
    const connectionString = process.env.DATABASE_URL;
    
    if (!connectionString) {
      console.warn('DATABASE_URL not set, using in-memory storage (data will be lost on restart)');
      return null;
    }

    pool = new Pool({
      connectionString: connectionString,
      ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
    });

    pool.on('error', (err) => {
      console.error('Unexpected error on idle client', err);
    });

    // Inicializovať databázu pri prvom pripojení
    initializeDatabase();
  }
  
  return pool;
}

// Export getPool pre použitie v sync.js
module.exports.getPool = getPool;

// Inicializácia databázových tabuliek
async function initializeDatabase() {
  const db = getPool();
  if (!db) return;

  try {
    // Tabuľka pre kvalitu
    await db.query(`
      CREATE TABLE IF NOT EXISTS quality (
        batch_number VARCHAR(255) PRIMARY KEY,
        status VARCHAR(50) NOT NULL,
        notes TEXT,
        checked_by VARCHAR(255),
        checked_date TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Tabuľka pre expedovanie
    await db.query(`
      CREATE TABLE IF NOT EXISTS shipments (
        batch_number VARCHAR(255) PRIMARY KEY,
        shipped BOOLEAN NOT NULL DEFAULT false,
        shipped_date TIMESTAMP,
        shipped_by VARCHAR(255),
        notes TEXT,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Tabuľka pre synchronizáciu zmien
    await db.query(`
      CREATE TABLE IF NOT EXISTS sync_changes (
        id SERIAL PRIMARY KEY,
        change_id VARCHAR(255) UNIQUE NOT NULL,
        type VARCHAR(50) NOT NULL,
        batch_number VARCHAR(255) NOT NULL,
        data JSONB,
        source VARCHAR(50),
        timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Index pre rýchle vyhľadávanie
    await db.query(`
      CREATE INDEX IF NOT EXISTS idx_sync_timestamp ON sync_changes(timestamp);
      CREATE INDEX IF NOT EXISTS idx_sync_batch ON sync_changes(batch_number);
    `);

    console.log('Database initialized successfully');
  } catch (error) {
    console.error('Error initializing database:', error);
  }
}

// Fallback in-memory storage (ak PostgreSQL nie je dostupný)
const memoryStorage = {
  quality: {},
  shipments: {},
  sync: {
    lastUpdate: new Date().toISOString(),
    changes: []
  }
};

// Helper funkcie pre úložisko
async function get(key) {
  const db = getPool();
  if (!db) {
    return memoryStorage[key] || null;
  }

  try {
    // Pre quality a shipments používame batch_number ako key
    // Pre sync používame špeciálnu logiku
    if (key === 'sync') {
      const result = await db.query(`
        SELECT 
          MAX(timestamp) as last_update,
          COUNT(*) as change_count
        FROM sync_changes
      `);
      
      const lastUpdate = result.rows[0]?.last_update || new Date().toISOString();
      return {
        lastUpdate: lastUpdate instanceof Date ? lastUpdate.toISOString() : lastUpdate,
        changes: []
      };
    }
    
    return null;
  } catch (e) {
    console.error('Error reading from database:', e);
    return memoryStorage[key] || null;
  }
}

async function set(key, value) {
  const db = getPool();
  if (!db) {
    memoryStorage[key] = value;
    return true;
  }

  // Pre quality a shipments sa používajú špecifické funkcie
  // Táto funkcia sa používa len pre sync
  return true;
}

// Špecifické funkcie pre kvalitu
async function getQuality() {
  const db = getPool();
  if (!db) {
    return memoryStorage.quality || {};
  }

  try {
    const result = await db.query('SELECT * FROM quality');
    const quality = {};
    
    result.rows.forEach(row => {
      quality[row.batch_number] = {
        status: row.status,
        notes: row.notes,
        checkedBy: row.checked_by,
        checkedDate: row.checked_date ? new Date(row.checked_date).toISOString() : null,
        updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
      };
    });
    
    return quality;
  } catch (e) {
    console.error('Error reading quality from database:', e);
    return memoryStorage.quality || {};
  }
}

async function setQuality(data) {
  const db = getPool();
  if (!db) {
    memoryStorage.quality = data;
    return true;
  }

  // Táto funkcia sa zvyčajne nepoužíva, lebo sa používa setQualityForBatch
  return true;
}

async function getQualityForBatch(batchNumber) {
  const db = getPool();
  if (!db) {
    return memoryStorage.quality[batchNumber] || null;
  }

  try {
    const result = await db.query(
      'SELECT * FROM quality WHERE batch_number = $1',
      [batchNumber]
    );

    if (result.rows.length === 0) {
      return null;
    }

    const row = result.rows[0];
    return {
      status: row.status,
      notes: row.notes,
      checkedBy: row.checked_by,
      checkedDate: row.checked_date ? new Date(row.checked_date).toISOString() : null,
      updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
    };
  } catch (e) {
    console.error('Error reading quality from database:', e);
    return memoryStorage.quality[batchNumber] || null;
  }
}

async function setQualityForBatch(batchNumber, qualityData) {
  const db = getPool();
  if (!db) {
    memoryStorage.quality[batchNumber] = qualityData;
    return true;
  }

  try {
    await db.query(`
      INSERT INTO quality (batch_number, status, notes, checked_by, checked_date, updated_at)
      VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)
      ON CONFLICT (batch_number) 
      DO UPDATE SET 
        status = EXCLUDED.status,
        notes = EXCLUDED.notes,
        checked_by = EXCLUDED.checked_by,
        checked_date = EXCLUDED.checked_date,
        updated_at = CURRENT_TIMESTAMP
    `, [
      batchNumber,
      qualityData.status,
      qualityData.notes || null,
      qualityData.checkedBy || null,
      qualityData.checkedDate ? new Date(qualityData.checkedDate) : new Date(),
    ]);

    return true;
  } catch (e) {
    console.error('Error writing quality to database:', e);
    // Fallback na memory
    memoryStorage.quality[batchNumber] = qualityData;
    return true;
  }
}

// Špecifické funkcie pre expedovanie
async function getShipments() {
  const db = getPool();
  if (!db) {
    return memoryStorage.shipments || {};
  }

  try {
    const result = await db.query('SELECT * FROM shipments');
    const shipments = {};
    
    result.rows.forEach(row => {
      shipments[row.batch_number] = {
        shipped: row.shipped,
        shippedDate: row.shipped_date ? new Date(row.shipped_date).toISOString() : null,
        shippedBy: row.shipped_by,
        notes: row.notes,
        updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
      };
    });
    
    return shipments;
  } catch (e) {
    console.error('Error reading shipments from database:', e);
    return memoryStorage.shipments || {};
  }
}

async function setShipments(data) {
  const db = getPool();
  if (!db) {
    memoryStorage.shipments = data;
    return true;
  }

  // Táto funkcia sa zvyčajne nepoužíva, lebo sa používa setShipmentForBatch
  return true;
}

async function getShipmentForBatch(batchNumber) {
  const db = getPool();
  if (!db) {
    return memoryStorage.shipments[batchNumber] || null;
  }

  try {
    const result = await db.query(
      'SELECT * FROM shipments WHERE batch_number = $1',
      [batchNumber]
    );

    if (result.rows.length === 0) {
      return null;
    }

    const row = result.rows[0];
    return {
      shipped: row.shipped,
      shippedDate: row.shipped_date ? new Date(row.shipped_date).toISOString() : null,
      shippedBy: row.shipped_by,
      notes: row.notes,
      updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
    };
  } catch (e) {
    console.error('Error reading shipment from database:', e);
    return memoryStorage.shipments[batchNumber] || null;
  }
}

async function setShipmentForBatch(batchNumber, shipmentData) {
  const db = getPool();
  if (!db) {
    memoryStorage.shipments[batchNumber] = shipmentData;
    return true;
  }

  try {
    await db.query(`
      INSERT INTO shipments (batch_number, shipped, shipped_date, shipped_by, notes, updated_at)
      VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)
      ON CONFLICT (batch_number) 
      DO UPDATE SET 
        shipped = EXCLUDED.shipped,
        shipped_date = EXCLUDED.shipped_date,
        shipped_by = EXCLUDED.shipped_by,
        notes = EXCLUDED.notes,
        updated_at = CURRENT_TIMESTAMP
    `, [
      batchNumber,
      shipmentData.shipped !== undefined ? shipmentData.shipped : true,
      shipmentData.shippedDate ? new Date(shipmentData.shippedDate) : new Date(),
      shipmentData.shippedBy || null,
      shipmentData.notes || null,
    ]);

    return true;
  } catch (e) {
    console.error('Error writing shipment to database:', e);
    // Fallback na memory
    memoryStorage.shipments[batchNumber] = shipmentData;
    return true;
  }
}

// Špecifické funkcie pre sync
async function getSyncData() {
  const db = getPool();
  if (!db) {
    return memoryStorage.sync || {
      lastUpdate: new Date().toISOString(),
      changes: []
    };
  }

  try {
    const result = await db.query(`
      SELECT 
        MAX(timestamp) as last_update,
        COUNT(*) as change_count
      FROM sync_changes
    `);
    
    const lastUpdate = result.rows[0]?.last_update 
      ? (result.rows[0].last_update instanceof Date 
          ? result.rows[0].last_update.toISOString() 
          : result.rows[0].last_update)
      : new Date().toISOString();
    
    return {
      lastUpdate,
      changes: []
    };
  } catch (e) {
    console.error('Error reading sync data from database:', e);
    return memoryStorage.sync || {
      lastUpdate: new Date().toISOString(),
      changes: []
    };
  }
}

async function setSyncData(data) {
  const db = getPool();
  if (!db) {
    memoryStorage.sync = data;
    return true;
  }

  // Sync data sa ukladá cez addSyncChange
  return true;
}

async function addSyncChange(change) {
  const db = getPool();
  if (!db) {
    const sync = memoryStorage.sync || {
      lastUpdate: new Date().toISOString(),
      changes: []
    };
    sync.changes.push(change);
    sync.lastUpdate = new Date().toISOString();
    
    // Zachovať len posledných 1000 zmien
    if (sync.changes.length > 1000) {
      sync.changes = sync.changes.slice(-1000);
    }
    
    memoryStorage.sync = sync;
    return true;
  }

  try {
    await db.query(`
      INSERT INTO sync_changes (change_id, type, batch_number, data, source, timestamp)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (change_id) DO NOTHING
    `, [
      change.id,
      change.type,
      change.batchNumber,
      JSON.stringify(change.data),
      change.source || 'unknown',
      change.timestamp ? new Date(change.timestamp) : new Date(),
    ]);

    // Odstrániť staré záznamy (zachovať len posledných 1000)
    await db.query(`
      DELETE FROM sync_changes
      WHERE id NOT IN (
        SELECT id FROM sync_changes
        ORDER BY timestamp DESC
        LIMIT 1000
      )
    `).catch(() => {
      // Ignorovať chyby pri mazaní starých záznamov
    });

    return true;
  } catch (e) {
    console.error('Error writing sync change to database:', e);
    // Fallback na memory
    const sync = memoryStorage.sync || {
      lastUpdate: new Date().toISOString(),
      changes: []
    };
    sync.changes.push(change);
    sync.lastUpdate = new Date().toISOString();
    if (sync.changes.length > 1000) {
      sync.changes = sync.changes.slice(-1000);
    }
    memoryStorage.sync = sync;
    return true;
  }
}

// Export funkcií
module.exports = {
  getQuality,
  setQuality,
  getQualityForBatch,
  setQualityForBatch,
  getShipments,
  setShipments,
  getShipmentForBatch,
  setShipmentForBatch,
  getSyncData,
  setSyncData,
  addSyncChange,
};
