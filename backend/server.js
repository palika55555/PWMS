const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
require('dotenv').config();

const { runMigrations } = require('./migrations/migrate');
const materialsRoutes = require('./routes/materials');
const recipesRoutes = require('./routes/recipes');
const batchesRoutes = require('./routes/batches');
const productsRoutes = require('./routes/products');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Routes
app.use('/api/materials', materialsRoutes);
app.use('/api/recipes', recipesRoutes);
app.use('/api/batches', batchesRoutes);
app.use('/api/products', productsRoutes);

// Run migrations on startup
runMigrations()
  .then(() => {
    console.log('Migrations completed successfully');
    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  })
  .catch((error) => {
    console.error('Migration error:', error);
    process.exit(1);
  });

module.exports = app;






