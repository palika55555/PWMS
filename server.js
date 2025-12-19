// Express server pre Railway backend
const express = require('express');
const cors = require('cors');
const qualityRoutes = require('./api/quality');
const shipmentRoutes = require('./api/shipment');
const syncRoutes = require('./api/sync');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API routes
app.use('/api/quality', qualityRoutes);
app.use('/api/shipment', shipmentRoutes);
app.use('/api/sync', syncRoutes);

// Root endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'PWMS Backend API',
    version: '1.0.0',
    endpoints: {
      quality: '/api/quality',
      shipment: '/api/shipment',
      sync: '/api/sync',
      health: '/health'
    }
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ 
    error: 'Internal server error', 
    details: process.env.NODE_ENV === 'development' ? err.message : undefined 
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

