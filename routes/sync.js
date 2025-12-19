import express from 'express';
import { SyncService } from '../services/sync-service.js';

const router = express.Router();

// Get sync status
router.get('/status', (req, res) => {
  try {
    const status = SyncService.getSyncStatus();
    res.json(status);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Manual sync to remote
router.post('/', async (req, res) => {
  try {
    const result = await SyncService.syncToRemote();
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;

