// Express route pre ukladanie a načítanie stavu expedovania
// Používa PostgreSQL storage helper

const express = require('express');
const router = express.Router();
const storage = require('./storage');

// POST - Uloženie stavu expedovania
router.post('/', async (req, res) => {
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
        const baseUrl = process.env.RAILWAY_PUBLIC_DOMAIN 
          ? `https://${process.env.RAILWAY_PUBLIC_DOMAIN}`
          : req.protocol + '://' + req.get('host');
        
        await fetch(`${baseUrl}/api/sync`, {
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
});

// GET - Načítanie stavu expedovania
router.get('/', async (req, res) => {
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
});

module.exports = router;

