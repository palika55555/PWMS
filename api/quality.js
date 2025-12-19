// Vercel serverless function pre ukladanie a načítanie kvality šarží
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
    // Uloženie kvality
    try {
      const { batchNumber, status, notes, checkedBy } = req.body;

      if (!batchNumber || !status) {
        return res.status(400).json({ 
          error: 'Missing required fields: batchNumber and status are required' 
        });
      }

      const qualityData = {
        status,
        notes: notes || null,
        checkedBy: checkedBy || null,
        checkedDate: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      if (await storage.setQualityForBatch(batchNumber, qualityData)) {
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
              data: qualityData,
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
          data: qualityData
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

      if (batchNumber) {
        // Konkrétna šarža
        const quality = await storage.getQualityForBatch(batchNumber);
        return res.status(200).json({ 
          success: true, 
          batchNumber,
          quality 
        });
      } else {
        // Všetky šarže
        const quality = await storage.getQuality();
        return res.status(200).json({ 
          success: true, 
          quality: quality || {} 
        });
      }
    } catch (error) {
      console.error('Error in GET:', error);
      return res.status(500).json({ error: 'Internal server error', details: error.message });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}

