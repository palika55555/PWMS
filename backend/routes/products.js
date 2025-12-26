const express = require('express');
const router = express.Router();
const pool = require('../config/database');

// Get all products
router.get('/', async (req, res) => {
  try {
    const { batch_id } = req.query;
    let query = 'SELECT * FROM products';
    const params = [];
    
    if (batch_id) {
      query += ' WHERE batch_id = $1';
      params.push(batch_id);
    }
    
    query += ' ORDER BY created_at DESC';
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching products:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get product by QR code
router.get('/qr/:qrCode', async (req, res) => {
  try {
    const { qrCode } = req.params;
    const result = await pool.query('SELECT * FROM products WHERE qr_code = $1', [qrCode]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching product:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create product
router.post('/', async (req, res) => {
  try {
    const { batch_id, product_code, qr_code, status, location } = req.body;
    
    const result = await pool.query(
      `INSERT INTO products (batch_id, product_code, qr_code, status, location, created_at)
       VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)
       RETURNING *`,
      [batch_id, product_code, qr_code, status || 'produced', location]
    );
    
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creating product:', error);
    if (error.code === '23505') { // Unique violation
      return res.status(409).json({ error: 'Product code or QR code already exists' });
    }
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;







