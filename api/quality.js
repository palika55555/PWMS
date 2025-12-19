// Express route pre ukladanie a načítanie kvality šarží
// Používa PostgreSQL storage helper

const express = require('express');
const router = express.Router();
const storage = require('./storage');

// POST - Uloženie kvality
router.post('/', async (req, res) => {
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
        const baseUrl = process.env.RAILWAY_PUBLIC_DOMAIN 
          ? `https://${process.env.RAILWAY_PUBLIC_DOMAIN}`
          : req.protocol + '://' + req.get('host');
        
        await fetch(`${baseUrl}/api/sync`, {
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
});

// GET - Načítanie kvality
router.get('/', async (req, res) => {
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
});

module.exports = router;

