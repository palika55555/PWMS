import dotenv from 'dotenv';
import { getRemotePool } from '../config/database.js';
import { createRemoteSchema, checkRemoteSchemaExists } from '../models/database-schema.js';

// Load .env file if it exists (for local development)
// In CI/CD, DATABASE_URL should be provided via environment variables
dotenv.config();

const pool = getRemotePool();

if (!pool) {
  console.error('Remote database not configured. Please set DATABASE_URL environment variable');
  console.error('In CI/CD: Set DATABASE_URL as a secret in GitHub Actions');
  console.error('Locally: Set DATABASE_URL in .env file or export it as environment variable');
  process.exit(1);
}

// Check if schema already exists
checkRemoteSchemaExists(pool)
  .then((schemaExists) => {
    if (schemaExists) {
      console.log('✓ Remote database schema already exists');
      console.log('  Skipping schema creation to preserve existing data');
      console.log('  If you need to recreate schema, set FORCE_MIGRATE=true');
      return Promise.resolve();
    } else {
      console.log('Remote database schema not found, creating...');
      return createRemoteSchema(pool);
    }
  })
  .then(() => {
    console.log('Remote database schema ready');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Error with remote schema:', error);
    process.exit(1);
  });

