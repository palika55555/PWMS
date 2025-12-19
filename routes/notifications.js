import express from 'express';
import { getLocalDb, getRemotePool } from '../config/database.js';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();

// Get all notifications
router.get('/', async (req, res) => {
  try {
    const pool = getRemotePool();
    if (pool) {
      const client = await pool.connect();
      try {
        const result = await client.query(
          'SELECT * FROM notifications ORDER BY created_at DESC'
        );
        res.json(result.rows);
      } finally {
        client.release();
      }
    } else {
      const db = getLocalDb();
      const notifications = db.exec(
        'SELECT * FROM notifications ORDER BY created_at DESC'
      );
      res.json(notifications);
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Mark notification as read
router.put('/:id/read', async (req, res) => {
  try {
    const pool = getRemotePool();
    if (pool) {
      const client = await pool.connect();
      try {
        await client.query(
          'UPDATE notifications SET read = 1 WHERE id = $1',
          [req.params.id]
        );
        const result = await client.query('SELECT * FROM notifications WHERE id = $1', [req.params.id]);
        res.json(result.rows[0]);
      } finally {
        client.release();
      }
    } else {
      const db = getLocalDb();
      db.exec(`UPDATE notifications SET read = 1 WHERE id = '${req.params.id}'`);
      const notification = db.exec(`SELECT * FROM notifications WHERE id = '${req.params.id}'`);
      res.json(notification[0]);
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create notification (for system use)
router.post('/', async (req, res) => {
  try {
    const { type, title, message, severity, related_id } = req.body;

    if (!type || !title || !message) {
      return res.status(400).json({
        error: 'Type, title, and message are required',
      });
    }

    const id = uuidv4();
    const pool = getRemotePool();

    if (pool) {
      const client = await pool.connect();
      try {
        await client.query(
          `INSERT INTO notifications (id, type, title, message, severity, related_id)
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [id, type, title, message, severity || 'info', related_id || null]
        );

        const result = await client.query('SELECT * FROM notifications WHERE id = $1', [id]);
        res.status(201).json(result.rows[0]);
      } finally {
        client.release();
      }
    } else {
      const db = getLocalDb();
      db.exec(`
        INSERT INTO notifications (id, type, title, message, severity, related_id)
        VALUES ('${id}', '${type}', '${title}', '${message}', 
                '${severity || 'info'}', 
                ${related_id ? `'${related_id}'` : 'NULL'})
      `);
      const notification = db.exec(`SELECT * FROM notifications WHERE id = '${id}'`);
      res.status(201).json(notification[0]);
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;

