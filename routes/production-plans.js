import express from 'express';
import { getLocalDb, getRemotePool } from '../config/database.js';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();

// Get all production plans
router.get('/', async (req, res) => {
  try {
    const pool = getRemotePool();
    if (pool) {
      const client = await pool.connect();
      try {
        const result = await client.query(`
          SELECT pp.*, pt.name as production_type_name, r.name as assigned_recipe_name
          FROM production_plans pp
          LEFT JOIN production_types pt ON pp.production_type_id = pt.id
          LEFT JOIN recipes r ON pp.assigned_recipe_id = r.id
          ORDER BY pp.planned_date ASC
        `);
        res.json(result.rows);
      } finally {
        client.release();
      }
    } else {
      const db = getLocalDb();
      const plans = db.exec(`
        SELECT pp.*, pt.name as production_type_name, r.name as assigned_recipe_name
        FROM production_plans pp
        LEFT JOIN production_types pt ON pp.production_type_id = pt.id
        LEFT JOIN recipes r ON pp.assigned_recipe_id = r.id
        ORDER BY pp.planned_date ASC
      `);
      res.json(plans);
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create production plan
router.post('/', async (req, res) => {
  try {
    const {
      production_type_id,
      planned_quantity,
      planned_date,
      priority,
      assigned_recipe_id,
      notes,
    } = req.body;

    if (!production_type_id || !planned_quantity || !planned_date) {
      return res.status(400).json({
        error: 'Production type ID, planned quantity, and planned date are required',
      });
    }

    const id = uuidv4();
    const pool = getRemotePool();

    if (pool) {
      const client = await pool.connect();
      try {
        await client.query(
          `INSERT INTO production_plans 
           (id, production_type_id, planned_quantity, planned_date, priority, assigned_recipe_id, notes)
           VALUES ($1, $2, $3, $4, $5, $6, $7)`,
          [
            id,
            production_type_id,
            planned_quantity,
            planned_date,
            priority || 'normal',
            assigned_recipe_id || null,
            notes || null,
          ]
        );

        const result = await client.query(
          `SELECT pp.*, pt.name as production_type_name, r.name as assigned_recipe_name
           FROM production_plans pp
           LEFT JOIN production_types pt ON pp.production_type_id = pt.id
           LEFT JOIN recipes r ON pp.assigned_recipe_id = r.id
           WHERE pp.id = $1`,
          [id]
        );
        res.status(201).json(result.rows[0]);
      } finally {
        client.release();
      }
    } else {
      const db = getLocalDb();
      db.exec(`
        INSERT INTO production_plans 
        (id, production_type_id, planned_quantity, planned_date, priority, assigned_recipe_id, notes)
        VALUES ('${id}', '${production_type_id}', ${planned_quantity}, '${planned_date}', 
                '${priority || 'normal'}', 
                ${assigned_recipe_id ? `'${assigned_recipe_id}'` : 'NULL'}, 
                ${notes ? `'${notes}'` : 'NULL'})
      `);
      const plan = db.exec(`SELECT * FROM production_plans WHERE id = '${id}'`);
      res.status(201).json(plan[0]);
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Delete production plan
router.delete('/:id', async (req, res) => {
  try {
    const pool = getRemotePool();
    if (pool) {
      const client = await pool.connect();
      try {
        await client.query('DELETE FROM production_plans WHERE id = $1', [req.params.id]);
        res.json({ message: 'Production plan deleted successfully' });
      } finally {
        client.release();
      }
    } else {
      const db = getLocalDb();
      db.exec(`DELETE FROM production_plans WHERE id = '${req.params.id}'`);
      res.json({ message: 'Production plan deleted successfully' });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;

