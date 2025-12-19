import dotenv from 'dotenv';
import { getRemotePool } from '../config/database.js';
import { createRemoteSchema } from '../models/database-schema.js';

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

createRemoteSchema(pool)
  .then(() => {
    console.log('Remote database schema created/updated successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Error creating remote schema:', error);
    process.exit(1);
  });

