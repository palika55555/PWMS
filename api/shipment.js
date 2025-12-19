// Vercel serverless function pre ukladanie a načítanie stavu expedovania
// Používa storage helper, ktorý podporuje Vercel KV alebo fallback na in-memory

const storage = require('./storage');

module.exports = async function handler(req, res) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method === 'POST') {
    // Uloženie stavu expedovania
    try {
      const { batchNumber, shipped, shippedDate, shippedBy, notes } = req.body;

      if (!batchNumber) {
        return res.status(400).json({ 
          error: 'Missing required field: batchNumber is required' 
        });
      }

      const shipmentData = {
        shipped: shipped !== undefined ? shipped : true,
        shippedDate: shippedDate || new Date().toISOString(),
        shippedBy: shippedBy || null,
        notes: notes || null,
        updatedAt: new Date().toISOString(),
      };

      if (await storage.setShipmentForBatch(batchNumber, shipmentData)) {
        // Registrovať zmenu v sync API
        try {
          const syncUrl = req.headers.host 
            ? `https://${req.headers.host}/api/sync`
            : 'http://localhost:3000/api/sync';
          
          await fetch(syncUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              type: 'shipment',
              batchNumber: batchNumber,
              data: shipmentData,
              source: 'web',
            }),
          }).catch(() => {
            // Ignorovať chyby sync API - nie je kritické
          });
        } catch (e) {
          // Ignorovať chyby sync API
        }

        return res.status(200).json({ 
          success: true, 
          message: 'Shipment status saved successfully',
          data: shipmentData
        });
      } else {
        return res.status(500).json({ error: 'Failed to save data' });
      }
    } catch (error) {
      console.error('Error in POST:', error);
      return res.status(500).json({ error: 'Internal server error', details: error.message });
    }
  }

  if (req.method === 'GET') {
    // Načítanie stavu expedovania
    try {
      const { batchNumber } = req.query;

      if (batchNumber) {
        // Konkrétna šarža
        const shipment = await storage.getShipmentForBatch(batchNumber);
        return res.status(200).json({ 
          success: true, 
          batchNumber,
          shipment 
        });
      } else {
        // Všetky šarže
        const shipments = await storage.getShipments();
        return res.status(200).json({ 
          success: true, 
          shipments: shipments || {} 
        });
      }
    } catch (error) {
      console.error('Error in GET:', error);
      return res.status(500).json({ error: 'Internal server error', details: error.message });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}

