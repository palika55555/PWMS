import express from 'express';
import { Warehouse } from '../models/Warehouse.js';

const router = express.Router();

// Get all warehouse entries
router.get('/', (req, res) => {
  try {
    const warehouse = Warehouse.getAll();
    res.json(warehouse);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get warehouse entry by ID
router.get('/:id', (req, res) => {
  try {
    const entry = Warehouse.getById(req.params.id);
    if (!entry) {
      return res.status(404).json({ error: 'Warehouse entry not found' });
    }
    res.json(entry);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get warehouse entry by material ID
router.get('/material/:materialId', (req, res) => {
  try {
    const entry = Warehouse.getByMaterialId(req.params.materialId);
    if (!entry) {
      return res.status(404).json({ error: 'Warehouse entry not found for this material' });
    }
    res.json(entry);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create or update warehouse entry
router.post('/', (req, res) => {
  try {
    const { materialId, quantity } = req.body;
    if (!materialId || quantity === undefined) {
      return res.status(400).json({ error: 'Material ID and quantity are required' });
    }
    const entry = Warehouse.create({ materialId, quantity });
    res.status(201).json(entry);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Update warehouse quantity
router.put('/:id', (req, res) => {
  try {
    const { quantity } = req.body;
    if (quantity === undefined) {
      return res.status(400).json({ error: 'Quantity is required' });
    }
    const entry = Warehouse.update(req.params.id, { quantity });
    if (!entry) {
      return res.status(404).json({ error: 'Warehouse entry not found' });
    }
    res.json(entry);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Adjust warehouse quantity (add/subtract)
router.patch('/material/:materialId/adjust', (req, res) => {
  try {
    const { change } = req.body;
    if (change === undefined) {
      return res.status(400).json({ error: 'Change value is required' });
    }
    const entry = Warehouse.adjustQuantity(req.params.materialId, change);
    res.json(entry);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Delete warehouse entry
router.delete('/:id', (req, res) => {
  try {
    Warehouse.delete(req.params.id);
    res.json({ message: 'Warehouse entry deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;

