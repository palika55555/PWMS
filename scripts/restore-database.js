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

async function restoreDatabase(backupFile) {
  const client = await pool.connect();
  
  if (!fs.existsSync(backupFile)) {
    console.error(`Backup file not found: ${backupFile}`);
    process.exit(1);
  }
  
  try {
    console.log(`Loading backup from: ${backupFile}`);
    const backup = JSON.parse(fs.readFileSync(backupFile, 'utf8'));
    
    console.log(`Backup timestamp: ${backup.timestamp}`);
    console.log(`Tables to restore: ${Object.keys(backup.tables).length}`);
    
    // Ask for confirmation
    console.log('\n⚠️  WARNING: This will overwrite existing data in the database!');
    console.log('Press Ctrl+C to cancel, or wait 5 seconds to continue...');
    
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    await client.query('BEGIN');
    
    try {
      // Disable foreign key checks temporarily (PostgreSQL doesn't have this, but we'll handle it)
      // Clear existing data (optional - comment out if you want to merge instead of replace)
      for (const tableName of Object.keys(backup.tables)) {
        console.log(`Clearing table: ${tableName}`);
        await client.query(`TRUNCATE TABLE ${tableName} CASCADE`);
      }
      
      // Restore data
      for (const [tableName, rows] of Object.entries(backup.tables)) {
        if (rows.length === 0) {
          console.log(`Skipping empty table: ${tableName}`);
          continue;
        }
        
        console.log(`Restoring table: ${tableName} (${rows.length} rows)`);
        
        // Get column names from first row
        const columns = Object.keys(rows[0]);
        const placeholders = columns.map((_, i) => `$${i + 1}`).join(', ');
        const columnNames = columns.join(', ');
        
        // Insert rows in batches
        const batchSize = 100;
        for (let i = 0; i < rows.length; i += batchSize) {
          const batch = rows.slice(i, i + batchSize);
          
          for (const row of batch) {
            const values = columns.map(col => row[col]);
            await client.query(
              `INSERT INTO ${tableName} (${columnNames}) VALUES (${placeholders}) ON CONFLICT DO NOTHING`,
              values
            );
          }
        }
        
        console.log(`  ✓ Restored ${rows.length} rows`);
      }
      
      await client.query('COMMIT');
      console.log('\n✓ Database restore completed successfully!');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    }
  } catch (error) {
    console.error('Error restoring database:', error);
    throw error;
  } finally {
    client.release();
  }
}

// Get backup file from command line argument
const backupFile = process.argv[2];

if (!backupFile) {
  console.error('Usage: node scripts/restore-database.js <backup-file>');
  console.error('\nAvailable backups:');
  const backupDir = join(__dirname, '../backups');
  if (fs.existsSync(backupDir)) {
    const files = fs.readdirSync(backupDir)
      .filter(f => f.startsWith('backup-') && f.endsWith('.json'))
      .sort()
      .reverse();
    
    if (files.length === 0) {
      console.error('  No backup files found');
    } else {
      files.forEach((f, i) => {
        console.error(`  ${i + 1}. ${f}`);
      });
    }
  } else {
    console.error('  Backup directory does not exist');
  }
  process.exit(1);
}

restoreDatabase(backupFile)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error('Restore failed:', error);
    process.exit(1);
  });

