// ====================================================================
// PWMS BACKEND SERVER - Express.js API
// ====================================================================
// Tento server poskytuje REST API pre Flutter appku a QR web
// Beží na Railway a komunikuje s PostgreSQL databázou

const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
require('dotenv').config(); // Načítanie environment premenných (DATABASE_URL, PORT, NODE_ENV)

// Import route handlers - každý route spravuje inú časť systému
const { runMigrations } = require('./migrations/migrate'); // Databázové migrácie
const materialsRoutes = require('./routes/materials');      // Materiály (cement, voda, atď.)
const recipesRoutes = require('./routes/recipes');          // Receptúry na betón
const batchesRoutes = require('./routes/batches');          // Výrobné šarže
const productsRoutes = require('./routes/products');        // Hotové produkty
const syncRoutes = require('./routes/sync');                // Generická synchronizácia
const palletsRoutes = require('./routes/pallets');          // Produktové palety (QR web)

// Inicializácia Express aplikácie
const app = express();
const PORT = process.env.PORT || 3000; // Port z env alebo default 3000

// ====================================================================
// MIDDLEWARE - spracovanie requestov pred routes
// ====================================================================

// CORS nastavenie - povolí requesty len z povolených domén
// DÔLEŽITÉ: Bez tohto QR web nemôže volať backend (CORS error)
const corsOptions = {
  origin: [
    'http://localhost:3000',      // Lokálny development (Flutter appka)
    'https://pwms.vercel.app',   // Produkčný QR web na Verceli
    // Pridaj ďalšie domény podľa potreby (napr. iné Vercel projekty)
  ],
  credentials: true,             // Povolí cookies a auth hlavičky (budúce použitie)
  optionsSuccessStatus: 200     // Pre staršie prehliadače
};
app.use(cors(corsOptions));

// Body parser - spracovanie JSON a form dát
app.use(bodyParser.json());                    // Parse JSON body
app.use(bodyParser.urlencoded({ extended: true })); // Parse URL-encoded body

// ====================================================================
// HEALTH CHECK ENDPOINT - pre monitorovanie servera
// ====================================================================
// Používa sa Railway, Vercel a monitoring tools
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    service: 'pwms-backend',
    version: '1.0.0'
  });
});

// ====================================================================
// API ROUTES - mapovanie URL na route handlere
// ====================================================================
// Každý route handler spravuje inú doménu dát
app.use('/api/materials', materialsRoutes);  // CRUD pre materiály
app.use('/api/recipes', recipesRoutes);      // CRUD pre receptúry
app.use('/api/batches', batchesRoutes);      // CRUD pre šarže
app.use('/api/products', productsRoutes);    // CRUD pre produkty
app.use('/api/pallets', palletsRoutes);      // QR palety (scan, list, summary, events)
app.use('/api/sync', syncRoutes);            // Generická synchronizácia pre Flutter appku

// ====================================================================
// ŠTART SERVERA - spustenie po migráciách
// ====================================================================
// 1. Spustí databázové migrácie (vytvorenie tabuliek, indexy)
// 2. Ak migrácie zlyhajú, server sa neštartuje (chráni data integrity)
// 3. Ak migrácie prebehnú OK, server počúva na zadanom porte
runMigrations()
  .then(() => {
    console.log('✅ Migrations completed successfully');
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`📡 Health check: http://localhost:${PORT}/health`);
    
    app.listen(PORT, () => {
      console.log(`🌐 Ready to accept requests`);
    });
  })
  .catch((error) => {
    console.error('❌ Migration error:', error);
    console.error('🛑 Server startup aborted due to migration failure');
    process.exit(1); // Ukončenie procesu s error kódom
  });

// Export pre testovanie a možné budúce použitie
module.exports = app;









