import pg from 'pg';
import Database from 'better-sqlite3';
import dotenv from 'dotenv';

dotenv.config();

const { Pool } = pg;

// Local SQLite database for offline storage
let localDb = null;

export const getLocalDb = () => {
  if (!localDb) {
    localDb = new Database('local.db');
    // Enable foreign keys
    localDb.pragma('foreign_keys = ON');
  }
  return localDb;
};

// Remote PostgreSQL connection pool (Railway)
let remotePool = null;

export const getRemotePool = () => {
  if (!remotePool && process.env.DATABASE_URL) {
    remotePool = new Pool({
      connectionString: process.env.DATABASE_URL,
      ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
    });

    remotePool.on('error', (err) => {
      console.error('Unexpected error on idle remote client', err);
    });
  }
  return remotePool;
};

// Check if remote database is available
export const isRemoteAvailable = async () => {
  const pool = getRemotePool();
  if (!pool) return false;
  
  try {
    const client = await pool.connect();
    client.release();
    return true;
  } catch (error) {
    console.error('Remote database not available:', error.message);
    return false;
  }
};

// Close connections
export const closeConnections = () => {
  if (localDb) {
    localDb.close();
    localDb = null;
  }
  if (remotePool) {
    remotePool.end();
    remotePool = null;
  }
};

