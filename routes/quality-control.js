import express from 'express';
import { getLocalDb, getRemotePool } from '../config/database.js';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();

// Get quality tests for a batch
router.get('/batch/:batchId', async (req, res) => {
  try {
    const pool = getRemotePool();
    if (pool) {
      const client = await pool.connect();
      try {
        const result = await client.query(
          'SELECT * FROM quality_control WHERE batch_id = $1 ORDER BY tested_at DESC',
          [req.params.batchId]
        );
        res.json(result.rows);
      } finally {
        client.release();
      }
    } else {
      const db = getLocalDb();
      const tests = db.exec(
        `SELECT * FROM quality_control WHERE batch_id = '${req.params.batchId}' ORDER BY tested_at DESC`
      );
      res.json(tests);
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create quality test
router.post('/', async (req, res) => {
  try {
    const {
      batch_id,
      test_type,
      test_name,
      result_value,
      result_text,
      passed,
      tested_by,
      notes,
    } = req.body;

    if (!batch_id || !test_type || !test_name) {
      return res.status(400).json({
        error: 'Batch ID, test type, and test name are required',
      });
    }

    const id = uuidv4();
    const pool = getRemotePool();

    if (pool) {
      const client = await pool.connect();
      try {
        await client.query(
          `INSERT INTO quality_control 
           (id, batch_id, test_type, test_name, result_value, result_text, passed, tested_by, notes)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
          [
            id,
            batch_id,
            test_type,
            test_name,
            result_value || null,
            result_text || null,
            passed ? 1 : 0,
            tested_by || null,
            notes || null,
          ]
        );

        const result = await client.query('SELECT * FROM quality_control WHERE id = $1', [id]);
        res.status(201).json(result.rows[0]);
      } finally {
        client.release();
      }
    } else {
      const db = getLocalDb();
      db.exec(`
        INSERT INTO quality_control 
        (id, batch_id, test_type, test_name, result_value, result_text, passed, tested_by, notes)
        VALUES ('${id}', '${batch_id}', '${test_type}', '${test_name}', 
                ${result_value || 'NULL'}, 
                ${result_text ? `'${result_text}'` : 'NULL'}, 
                ${passed ? 1 : 0},
                ${tested_by ? `'${tested_by}'` : 'NULL'}, 
                ${notes ? `'${notes}'` : 'NULL'})
      `);
      const test = db.exec(`SELECT * FROM quality_control WHERE id = '${id}'`);
      res.status(201).json(test[0]);
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;

