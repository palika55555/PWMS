import express from 'express';
import { Material } from '../models/Material.js';

const router = express.Router();

// Get all materials
router.get('/', (req, res) => {
  try {
    const materials = Material.getAll();
    res.json(materials);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get material by ID
router.get('/:id', (req, res) => {
  try {
    const material = Material.getById(req.params.id);
    if (!material) {
      return res.status(404).json({ error: 'Material not found' });
    }
    res.json(material);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create new material
router.post('/', (req, res) => {
  try {
    const { name, unit } = req.body;
    if (!name || !unit) {
      return res.status(400).json({ error: 'Name and unit are required' });
    }
    const material = Material.create({ name, unit });
    res.status(201).json(material);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Update material
router.put('/:id', (req, res) => {
  try {
    const { name, unit } = req.body;
    if (!name || !unit) {
      return res.status(400).json({ error: 'Name and unit are required' });
    }
    const material = Material.update(req.params.id, { name, unit });
    if (!material) {
      return res.status(404).json({ error: 'Material not found' });
    }
    res.json(material);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Delete material
router.delete('/:id', (req, res) => {
  try {
    Material.delete(req.params.id);
    res.json({ message: 'Material deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;

