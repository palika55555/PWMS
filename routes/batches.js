import express from 'express';
import { getLocalDb, getRemotePool } from '../config/database.js';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();

// Get all batches
router.get('/', async (req, res) => {
  try {
    const pool = getRemotePool();
    if (pool) {
      const client = await pool.connect();
      try {
        const result = await client.query(`
          SELECT b.*, p.production_type_id, pt.name as production_type_name
          FROM batches b
          LEFT JOIN production p ON b.production_id = p.id
          LEFT JOIN production_types pt ON p.production_type_id = pt.id
          ORDER BY b.created_at DESC
        `);
        res.json(result.rows);
      } finally {
        client.release();
      }
    } else {
      const db = getLocalDb();
      const batches = db.exec(`
        SELECT b.*, p.production_type_id, pt.name as production_type_name
        FROM batches b
        LEFT JOIN production p ON b.production_id = p.id
        LEFT JOIN production_types pt ON p.production_type_id = pt.id
        ORDER BY b.created_at DESC
      `);
      res.json(batches);
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create batch
router.post('/', async (req, res) => {
  try {
    const { production_id, batch_number, quantity, qr_code, warehouse_location } = req.body;
    
    if (!production_id || !batch_number || !quantity) {
      return res.status(400).json({ error: 'Production ID, batch number, and quantity are required' });
    }

    const id = uuidv4();
    const pool = getRemotePool();
    
    if (pool) {
      const client = await pool.connect();
      try {
        await client.query(`
          INSERT INTO batches (id, production_id, batch_number, quantity, qr_code, warehouse_location)
          VALUES ($1, $2, $3, $4, $5, $6)
        `, [id, production_id, batch_number, quantity, qr_code || null, warehouse_location || null]);
        
        const result = await client.query('SELECT * FROM batches WHERE id = $1', [id]);
        res.status(201).json(result.rows[0]);
      } finally {
        client.release();
      }
    } else {
      const db = getLocalDb();
      db.exec(`
        INSERT INTO batches (id, production_id, batch_number, quantity, qr_code, warehouse_location)
        VALUES ('${id}', '${production_id}', '${batch_number}', ${quantity}, 
                ${qr_code ? `'${qr_code}'` : 'NULL'}, 
                ${warehouse_location ? `'${warehouse_location}'` : 'NULL'})
      `);
      const batch = db.exec(`SELECT * FROM batches WHERE id = '${id}'`);
      res.status(201).json(batch[0]);
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get batch by ID
router.get('/:id', async (req, res) => {
  try {
    const pool = getRemotePool();
    if (pool) {
      const client = await pool.connect();
      try {
        const result = await client.query('SELECT * FROM batches WHERE id = $1', [req.params.id]);
        if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Batch not found' });
        }
        res.json(result.rows[0]);
      } finally {
        client.release();
      }
    } else {
      const db = getLocalDb();
      const batch = db.exec(`SELECT * FROM batches WHERE id = '${req.params.id}'`);
      if (batch.length === 0) {
        return res.status(404).json({ error: 'Batch not found' });
      }
      res.json(batch[0]);
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;

