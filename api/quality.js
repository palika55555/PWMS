// Vercel serverless function pre ukladanie a načítanie kvality šarží
// POZNÁMKA: Toto používa in-memory storage, ktorý sa stratí po redeploy
// Pre produkciu odporúčame použiť Vercel KV, databázu alebo externý storage

// In-memory storage (pre jednoduchosť - v produkcii použiť databázu)
let qualityData = {};

// Načítanie dát (pre teraz z in-memory, neskôr z databázy)
function loadData() {
  return qualityData;
}

// Uloženie dát (pre teraz do in-memory, neskôr do databázy)
function saveData(data) {
  qualityData = data;
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
    // Uloženie kvality
    try {
      const { batchNumber, status, notes, checkedBy } = req.body;

      if (!batchNumber || !status) {
        return res.status(400).json({ 
          error: 'Missing required fields: batchNumber and status are required' 
        });
      }

      const data = loadData();
      if (!data.quality) {
        data.quality = {};
      }

      data.quality[batchNumber] = {
        status,
        notes: notes || null,
        checkedBy: checkedBy || null,
        checkedDate: new Date().toISOString(),
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
              type: 'quality',
              batchNumber: batchNumber,
              data: data.quality[batchNumber],
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
          message: 'Quality status saved successfully',
          data: data.quality[batchNumber]
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
    // Načítanie kvality
    try {
      const { batchNumber } = req.query;

      const data = loadData();

      if (batchNumber) {
        // Konkrétna šarža
        const quality = data.quality?.[batchNumber] || null;
        return res.status(200).json({ 
          success: true, 
          batchNumber,
          quality 
        });
      } else {
        // Všetky šarže
        return res.status(200).json({ 
          success: true, 
          quality: data.quality || {} 
        });
      }
    } catch (error) {
      console.error('Error in GET:', error);
      return res.status(500).json({ error: 'Internal server error', details: error.message });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}

