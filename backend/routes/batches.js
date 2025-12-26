const express = require('express');
const router = express.Router();
const pool = require('../config/database');

// Get all batches
router.get('/', async (req, res) => {
  try {
    const { date } = req.query;
    let query = 'SELECT * FROM batches';
    const params = [];
    
    if (date) {
      query += ' WHERE production_date = $1';
      params.push(date);
    }
    
    query += ' ORDER BY production_date DESC, created_at DESC';
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching batches:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get batch by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('SELECT * FROM batches WHERE id = $1', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Batch not found' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching batch:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create batch
router.post('/', async (req, res) => {
  try {
    const { batch_number, recipe_id, production_date, quantity, notes } = req.body;
    
    const result = await pool.query(
      `INSERT INTO batches (batch_number, recipe_id, production_date, quantity, notes, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
       RETURNING *`,
      [batch_number, recipe_id, production_date, quantity, notes]
    );
    
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creating batch:', error);
    if (error.code === '23505') { // Unique violation
      return res.status(409).json({ error: 'Batch number already exists' });
    }
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update batch
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { quality_status, quality_approved_by, quality_approved_at, notes } = req.body;
    
    const result = await pool.query(
      `UPDATE batches 
       SET quality_status = $1, quality_approved_by = $2, quality_approved_at = $3, 
           notes = $4, updated_at = CURRENT_TIMESTAMP
       WHERE id = $5
       RETURNING *`,
      [quality_status, quality_approved_by, quality_approved_at, notes, id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Batch not found' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error updating batch:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;







