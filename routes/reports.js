import express from 'express';
import { getLocalDb, getRemotePool } from '../config/database.js';

const router = express.Router();

// Get report
router.get('/', async (req, res) => {
  try {
    const { period, date } = req.query;
    
    if (!period || !date) {
      return res.status(400).json({ error: 'Period and date are required' });
    }

    const startDate = new Date(date);
    let endDate = new Date(date);

    // Calculate date range based on period
    if (period === 'weekly') {
      endDate = new Date(startDate);
      endDate.setDate(endDate.getDate() + 6);
    } else if (period === 'monthly') {
      endDate = new Date(startDate.getFullYear(), startDate.getMonth() + 1, 0);
    }

    const pool = getRemotePool();
    
    if (pool) {
      const client = await pool.connect();
      try {
        // Get productions in date range
        const productionsResult = await client.query(
          `SELECT p.*, pt.name as production_type_name
           FROM production p
           LEFT JOIN production_types pt ON p.production_type_id = pt.id
           WHERE DATE(p.production_date) BETWEEN $1 AND $2
           ORDER BY p.production_date DESC`,
          [startDate.toISOString().split('T')[0], endDate.toISOString().split('T')[0]]
        );

        // Calculate totals
        const totalProductions = productionsResult.rows.length;
        const totalQuantity = productionsResult.rows.reduce(
          (sum, p) => sum + parseFloat(p.quantity || 0),
          0
        );

        // Get material consumption
        const materialsResult = await client.query(
          `SELECT pm.material_id, m.name as material_name, SUM(pm.quantity) as total_quantity
           FROM production_materials pm
           LEFT JOIN materials m ON pm.material_id = m.id
           LEFT JOIN production p ON pm.production_id = p.id
           WHERE DATE(p.production_date) BETWEEN $1 AND $2
           GROUP BY pm.material_id, m.name`,
          [startDate.toISOString().split('T')[0], endDate.toISOString().split('T')[0]]
        );

        res.json({
          period,
          start_date: startDate.toISOString().split('T')[0],
          end_date: endDate.toISOString().split('T')[0],
          total_productions: totalProductions,
          total_quantity: totalQuantity,
          total_material_consumption: materialsResult.rows,
          productions: productionsResult.rows,
        });
      } finally {
        client.release();
      }
    } else {
      // SQLite implementation would go here
      res.json({
        period,
        start_date: startDate.toISOString().split('T')[0],
        end_date: endDate.toISOString().split('T')[0],
        total_productions: 0,
        total_quantity: 0,
        total_material_consumption: [],
        productions: [],
      });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;

