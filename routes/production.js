import express from 'express';
import { Production, ProductionType } from '../models/Production.js';

const router = express.Router();

// Production Types Routes
router.get('/types', (req, res) => {
  try {
    const types = ProductionType.getAll();
    res.json(types);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.get('/types/:id', (req, res) => {
  try {
    const type = ProductionType.getById(req.params.id);
    if (!type) {
      return res.status(404).json({ error: 'Production type not found' });
    }
    res.json(type);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/types', (req, res) => {
  try {
    const { name, description } = req.body;
    if (!name) {
      return res.status(400).json({ error: 'Name is required' });
    }
    const type = ProductionType.create({ name, description });
    res.status(201).json(type);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.put('/types/:id', (req, res) => {
  try {
    const { name, description } = req.body;
    if (!name) {
      return res.status(400).json({ error: 'Name is required' });
    }
    const type = ProductionType.update(req.params.id, { name, description });
    if (!type) {
      return res.status(404).json({ error: 'Production type not found' });
    }
    res.json(type);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.delete('/types/:id', (req, res) => {
  try {
    ProductionType.delete(req.params.id);
    res.json({ message: 'Production type deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Production Routes
router.get('/', async (req, res) => {
  try {
    const productions = Production.getAll();
    res.json(productions);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.get('/:id', (req, res) => {
  try {
    const production = Production.getById(req.params.id);
    if (!production) {
      return res.status(404).json({ error: 'Production not found' });
    }
    res.json(production);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const { productionTypeId, quantity, materials, notes, productionDate, status, recipeId } = req.body;
    if (!productionTypeId || !quantity) {
      return res.status(400).json({ error: 'Production type ID and quantity are required' });
    }
    const production = await Production.create({
      productionTypeId,
      quantity,
      materials,
      notes,
      productionDate,
      status,
      recipeId
    });
    res.status(201).json(production);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.put('/:id', (req, res) => {
  try {
    const { quantity, notes } = req.body;
    if (quantity === undefined) {
      return res.status(400).json({ error: 'Quantity is required' });
    }
    const production = Production.update(req.params.id, { quantity, notes });
    if (!production) {
      return res.status(404).json({ error: 'Production not found' });
    }
    res.json(production);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.delete('/:id', (req, res) => {
  try {
    Production.delete(req.params.id);
    res.json({ message: 'Production deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;

