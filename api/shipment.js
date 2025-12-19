// Vercel serverless function pre ukladanie a načítanie stavu expedovania
// POZNÁMKA: Toto používa in-memory storage, ktorý sa stratí po redeploy
// Pre produkciu odporúčame použiť Vercel KV, databázu alebo externý storage

// In-memory storage
let shipmentData = {};

// Načítanie dát
function loadData() {
  return shipmentData;
}

// Uloženie dát
function saveData(data) {
  shipmentData = data;
  return true;
}

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

      const data = loadData();
      if (!data.shipments) {
        data.shipments = {};
      }

      data.shipments[batchNumber] = {
        shipped: shipped !== undefined ? shipped : true,
        shippedDate: shippedDate || new Date().toISOString(),
        shippedBy: shippedBy || null,
        notes: notes || null,
        updatedAt: new Date().toISOString(),
      };

      if (saveData(data)) {
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
              data: data.shipments[batchNumber],
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
          data: data.shipments[batchNumber]
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

      const data = loadData();

      if (batchNumber) {
        // Konkrétna šarža
        const shipment = data.shipments?.[batchNumber] || null;
        return res.status(200).json({ 
          success: true, 
          batchNumber,
          shipment 
        });
      } else {
        // Všetky šarže
        return res.status(200).json({ 
          success: true, 
          shipments: data.shipments || {} 
        });
      }
    } catch (error) {
      console.error('Error in GET:', error);
      return res.status(500).json({ error: 'Internal server error', details: error.message });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}

