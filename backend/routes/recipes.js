const express = require('express');
const router = express.Router();
const pool = require('../config/database');

// Get all recipes
router.get('/', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM recipes ORDER BY name');
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching recipes:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get recipe by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('SELECT * FROM recipes WHERE id = $1', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Recipe not found' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching recipe:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create recipe
router.post('/', async (req, res) => {
  try {
    const { name, product_type, description, cement_amount, water_amount, plasticizer_amount, wc_ratio } = req.body;
    
    const result = await pool.query(
      `INSERT INTO recipes (name, product_type, description, cement_amount, water_amount, plasticizer_amount, wc_ratio, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
       RETURNING *`,
      [name, product_type, description, cement_amount, water_amount, plasticizer_amount, wc_ratio]
    );
    
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creating recipe:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update recipe
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, product_type, description, cement_amount, water_amount, plasticizer_amount, wc_ratio } = req.body;
    
    const result = await pool.query(
      `UPDATE recipes 
       SET name = $1, product_type = $2, description = $3, cement_amount = $4, water_amount = $5, 
           plasticizer_amount = $6, wc_ratio = $7, updated_at = CURRENT_TIMESTAMP
       WHERE id = $8
       RETURNING *`,
      [name, product_type, description, cement_amount, water_amount, plasticizer_amount, wc_ratio, id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Recipe not found' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error updating recipe:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;







