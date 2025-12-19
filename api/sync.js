// Vercel serverless function pre real-time synchronizáciu
// Vracia timestamp poslednej zmeny a zmeny od určitého timestampu
// Používa storage helper, ktorý podporuje Vercel KV alebo fallback na in-memory

const storage = require('./storage');

module.exports = async function handler(req, res) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method === 'POST') {
    // Registrácia zmeny
    try {
      const { type, batchNumber, data: changeData, source } = req.body;

      if (!type || !batchNumber) {
        return res.status(400).json({ 
          error: 'Missing required fields: type and batchNumber are required' 
        });
      }

      // Pridať zmenu do histórie
      const change = {
        id: `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        type, // 'quality', 'shipment', 'production'
        batchNumber,
        data: changeData,
        source: source || 'unknown', // 'web' alebo 'app'
        timestamp: new Date().toISOString(),
      };

      await storage.addSyncChange(change);

      const sync = await storage.getSyncData();
      return res.status(200).json({ 
        success: true, 
        message: 'Change registered successfully',
        changeId: change.id,
        timestamp: sync.lastUpdate
      });
    } catch (error) {
      console.error('Error in POST:', error);
      return res.status(500).json({ error: 'Internal server error', details: error.message });
    }
  }

  if (req.method === 'GET') {
    // Načítanie zmien od určitého timestampu
    try {
      const { since, batchNumber } = req.query;

      const sync = await storage.getSyncData();

      let changes = sync.changes || [];

      // Filtrovať podľa timestampu
      if (since) {
        const sinceDate = new Date(since);
        changes = changes.filter(change => new Date(change.timestamp) > sinceDate);
      }

      // Filtrovať podľa batchNumber ak je zadaný
      if (batchNumber) {
        changes = changes.filter(change => change.batchNumber === batchNumber);
      }

      return res.status(200).json({ 
        success: true, 
        lastUpdate: sync.lastUpdate,
        changes: changes,
        count: changes.length
      });
    } catch (error) {
      console.error('Error in GET:', error);
      return res.status(500).json({ error: 'Internal server error', details: error.message });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}

