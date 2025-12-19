import express from 'express';
import { Recipe } from '../models/Recipe.js';

const router = express.Router();

// Get all recipes
router.get('/', (req, res) => {
  try {
    const recipes = Recipe.getAll();
    // Format materials for frontend
    const formattedRecipes = recipes.map(recipe => {
      if (recipe.materials) {
        recipe.materials = recipe.materials.map(m => ({
          materialId: m.material_id || m.materialId,
          quantityPerUnit: m.quantity_per_unit || m.quantityPerUnit,
        }));
      }
      return recipe;
    });
    res.json(formattedRecipes);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get recipe by ID
router.get('/:id', (req, res) => {
  try {
    const recipe = Recipe.getById(req.params.id);
    if (!recipe) {
      return res.status(404).json({ error: 'Recipe not found' });
    }
    // Format materials for frontend
    if (recipe.materials) {
      recipe.materials = recipe.materials.map(m => ({
        materialId: m.materialId || m.material_id,
        quantityPerUnit: m.quantityPerUnit || m.quantity_per_unit,
      }));
    }
    res.json(recipe);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get recipes by production type ID
router.get('/type/:productionTypeId', (req, res) => {
  try {
    const recipes = Recipe.getByProductionTypeId(req.params.productionTypeId);
    // Format materials for frontend
    const formattedRecipes = recipes.map(recipe => {
      if (recipe.materials) {
        recipe.materials = recipe.materials.map(m => ({
          materialId: m.materialId || m.material_id,
          quantityPerUnit: m.quantityPerUnit || m.quantity_per_unit,
        }));
      }
      return recipe;
    });
    res.json(formattedRecipes);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Calculate materials for production quantity
router.post('/:id/calculate', (req, res) => {
  try {
    const { quantity } = req.body;
    if (!quantity || quantity <= 0) {
      return res.status(400).json({ error: 'Quantity must be a positive number' });
    }
    const materials = Recipe.calculateMaterials(req.params.id, quantity);
    res.json({ materials });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create new recipe
router.post('/', (req, res) => {
  try {
    const { productionTypeId, name, description, materials } = req.body;
    if (!productionTypeId || !name) {
      return res.status(400).json({ error: 'Production type ID and name are required' });
    }
    const recipe = Recipe.create({ productionTypeId, name, description, materials });
    res.status(201).json(recipe);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Update recipe
router.put('/:id', (req, res) => {
  try {
    const { name, description, materials } = req.body;
    if (!name) {
      return res.status(400).json({ error: 'Name is required' });
    }
    const recipe = Recipe.update(req.params.id, { name, description, materials });
    if (!recipe) {
      return res.status(404).json({ error: 'Recipe not found' });
    }
    res.json(recipe);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Delete recipe
router.delete('/:id', (req, res) => {
  try {
    Recipe.delete(req.params.id);
    res.json({ message: 'Recipe deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;

