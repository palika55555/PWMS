// Express route pre real-time synchronizáciu
// Vracia timestamp poslednej zmeny a zmeny od určitého timestampu
// Používa PostgreSQL storage helper

const express = require('express');
const router = express.Router();
const storage = require('./storage');
const { Pool } = require('pg');

// Helper na získanie zmien z databázy
async function getChangesFromDB(since, batchNumber) {
  const { getPool } = require('./storage');
  const pool = getPool();
  if (!pool) {
    const sync = await storage.getSyncData();
    let changes = sync.changes || [];
    
    if (since) {
      const sinceDate = new Date(since);
      changes = changes.filter(change => new Date(change.timestamp) > sinceDate);
    }
    
    if (batchNumber) {
      changes = changes.filter(change => change.batchNumber === batchNumber);
    }
    
    return changes;
  }

  try {
    let query = 'SELECT * FROM sync_changes WHERE 1=1';
    const params = [];
    let paramIndex = 1;

    if (since) {
      query += ` AND timestamp > $${paramIndex}`;
      params.push(new Date(since));
      paramIndex++;
    }

    if (batchNumber) {
      query += ` AND batch_number = $${paramIndex}`;
      params.push(batchNumber);
      paramIndex++;
    }

    query += ' ORDER BY timestamp DESC LIMIT 1000';

    const result = await pool.query(query, params);
    
    return result.rows.map(row => ({
      id: row.change_id,
      type: row.type,
      batchNumber: row.batch_number,
      data: row.data,
      source: row.source,
      timestamp: row.timestamp instanceof Date 
        ? row.timestamp.toISOString() 
        : row.timestamp,
    }));
  } catch (e) {
    console.error('Error reading changes from database:', e);
    return [];
  }
}

// POST - Registrácia zmeny
router.post('/', async (req, res) => {
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
});

// GET - Načítanie zmien od určitého timestampu
router.get('/', async (req, res) => {
  try {
    const { since, batchNumber } = req.query;

    const sync = await storage.getSyncData();
    const changes = await getChangesFromDB(since, batchNumber);

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
});

module.exports = router;

