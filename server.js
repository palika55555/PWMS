import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { getLocalDb, getRemotePool, closeConnections } from './config/database.js';
import { createLocalSchema, createRemoteSchema } from './models/database-schema.js';
import { SyncService } from './services/sync-service.js';

import materialsRoutes from './routes/materials.js';
import warehouseRoutes from './routes/warehouse.js';
import productionRoutes from './routes/production.js';
import recipesRoutes from './routes/recipes.js';
import syncRoutes from './routes/sync.js';
import batchesRoutes from './routes/batches.js';
import qualityControlRoutes from './routes/quality-control.js';
import productionPlansRoutes from './routes/production-plans.js';
import reportsRoutes from './routes/reports.js';
import notificationsRoutes from './routes/notifications.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Initialize local database
const localDb = getLocalDb();
createLocalSchema(localDb);
console.log('Local database initialized');

// Initialize remote database if available
const remotePool = getRemotePool();
if (remotePool) {
  createRemoteSchema(remotePool)
    .then(() => {
      console.log('Remote database schema initialized');
    })
    .catch((error) => {
      console.error('Error initializing remote database:', error.message);
      console.log('Application will work in offline mode');
    });
}

// Routes
app.get('/', (req, res) => {
  res.json({
    message: 'PWMS Backend API',
    version: '1.0.0',
    endpoints: {
      materials: '/api/materials',
      warehouse: '/api/warehouse',
      production: '/api/production',
      recipes: '/api/recipes',
      sync: '/api/sync',
      batches: '/api/batches',
      qualityControl: '/api/quality-control',
      productionPlans: '/api/production-plans',
      reports: '/api/reports',
      notifications: '/api/notifications'
    }
  });
});

app.use('/api/materials', materialsRoutes);
app.use('/api/warehouse', warehouseRoutes);
app.use('/api/production', productionRoutes);
app.use('/api/recipes', recipesRoutes);
app.use('/api/sync', syncRoutes);
app.use('/api/batches', batchesRoutes);
app.use('/api/quality-control', qualityControlRoutes);
app.use('/api/production-plans', productionPlansRoutes);
app.use('/api/reports', reportsRoutes);
app.use('/api/notifications', notificationsRoutes);

// Auto-sync functionality
if (process.env.AUTO_SYNC === 'true') {
  const syncInterval = parseInt(process.env.SYNC_INTERVAL) || 300000; // 5 minutes default
  
  setInterval(async () => {
    try {
      const result = await SyncService.syncToRemote();
      if (result.success && result.synced > 0) {
        console.log(`Auto-sync completed: ${result.synced} items synced`);
      }
    } catch (error) {
      console.error('Auto-sync error:', error.message);
    }
  }, syncInterval);
  
  console.log(`Auto-sync enabled (interval: ${syncInterval}ms)`);
}

// Error handling
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\nShutting down gracefully...');
  closeConnections();
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\nShutting down gracefully...');
  closeConnections();
  process.exit(0);
});

app.listen(PORT, () => {
  console.log(`PWMS Backend server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Remote DB: ${remotePool ? 'Configured' : 'Not configured'}`);
});
