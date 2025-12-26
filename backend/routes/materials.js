const express = require('express');
const router = express.Router();
const pool = require('../config/database');

// Get all materials
router.get('/', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM materials ORDER BY name');
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching materials:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get material by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('SELECT * FROM materials WHERE id = $1', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Material not found' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching material:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create material
router.post('/', async (req, res) => {
  try {
    const { name, type, unit, current_stock, min_stock } = req.body;
    
    const result = await pool.query(
      `INSERT INTO materials (name, type, unit, current_stock, min_stock, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
       RETURNING *`,
      [name, type, unit, current_stock || 0, min_stock || 0]
    );
    
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creating material:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update material
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, type, unit, current_stock, min_stock } = req.body;
    
    const result = await pool.query(
      `UPDATE materials 
       SET name = $1, type = $2, unit = $3, current_stock = $4, min_stock = $5, updated_at = CURRENT_TIMESTAMP
       WHERE id = $6
       RETURNING *`,
      [name, type, unit, current_stock, min_stock, id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Material not found' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error updating material:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete material
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('DELETE FROM materials WHERE id = $1 RETURNING *', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Material not found' });
    }
    
    res.json({ message: 'Material deleted successfully' });
  } catch (error) {
    console.error('Error deleting material:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;






