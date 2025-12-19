import dotenv from 'dotenv';
import { SyncService } from '../services/sync-service.js';

dotenv.config();

SyncService.syncToRemote()
  .then((result) => {
    console.log('Sync result:', result);
    process.exit(result.success ? 0 : 1);
  })
  .catch((error) => {
    console.error('Sync error:', error);
    process.exit(1);
  });

