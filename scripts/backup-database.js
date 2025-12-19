import dotenv from 'dotenv';
import { getRemotePool } from '../config/database.js';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const pool = getRemotePool();

if (!pool) {
  console.error('Remote database not configured. Please set DATABASE_URL environment variable');
  process.exit(1);
}

async function backupDatabase() {
  const client = await pool.connect();
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupDir = join(__dirname, '../backups');
  
  // Create backups directory if it doesn't exist
  if (!fs.existsSync(backupDir)) {
    fs.mkdirSync(backupDir, { recursive: true });
  }

  try {
    console.log('Starting database backup...');
    
    // Get all tables
    const tablesResult = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_type = 'BASE TABLE'
      ORDER BY table_name;
    `);
    
    const tables = tablesResult.rows.map(row => row.table_name);
    const backup = {
      timestamp: new Date().toISOString(),
      tables: {}
    };
    
    // Backup each table
    for (const table of tables) {
      const data = await client.query(`SELECT * FROM ${table}`);
      backup.tables[table] = data.rows;
      console.log(`Backed up table: ${table} (${data.rows.length} rows)`);
    }
    
    // Save backup to file
    const backupFile = join(backupDir, `backup-${timestamp}.json`);
    fs.writeFileSync(backupFile, JSON.stringify(backup, null, 2));
    
    console.log(`\nBackup completed successfully!`);
    console.log(`Backup file: ${backupFile}`);
    console.log(`Total tables: ${tables.length}`);
    
    return backupFile;
  } catch (error) {
    console.error('Error backing up database:', error);
    throw error;
  } finally {
    client.release();
  }
}

backupDatabase()
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error('Backup failed:', error);
    process.exit(1);
  });

