import { v4 as uuidv4 } from 'uuid';
import { getLocalDb } from '../config/database.js';

export class Recipe {
  static getAll() {
    const db = getLocalDb();
    const recipes = db.prepare(`
      SELECT r.*, pt.name as production_type_name
      FROM recipes r
      JOIN production_types pt ON r.production_type_id = pt.id
      ORDER BY r.name
    `).all();
    
    // Pridáme materiály ku každému receptu
    return recipes.map(recipe => {
      recipe.materials = this.getMaterials(recipe.id);
      return recipe;
    });
  }

  static getById(id) {
    const db = getLocalDb();
    const recipe = db.prepare(`
      SELECT r.*, pt.name as production_type_name
      FROM recipes r
      JOIN production_types pt ON r.production_type_id = pt.id
      WHERE r.id = ?
    `).get(id);
    if (recipe) {
      recipe.materials = this.getMaterials(id);
    }
    return recipe;
  }

  static getByProductionTypeId(productionTypeId) {
    const db = getLocalDb();
    const recipes = db.prepare(`
      SELECT r.*, pt.name as production_type_name
      FROM recipes r
      LEFT JOIN production_types pt ON r.production_type_id = pt.id
      WHERE r.production_type_id = ?
      ORDER BY r.name
    `).all(productionTypeId);
    
    // Pridáme materiály ku každému receptu
    return recipes.map(recipe => {
      recipe.materials = this.getMaterials(recipe.id);
      return recipe;
    });
  }

  static getMaterials(recipeId) {
    const db = getLocalDb();
    return db.prepare(`
      SELECT rm.*, m.name as material_name, m.unit
      FROM recipe_materials rm
      JOIN materials m ON rm.material_id = m.id
      WHERE rm.recipe_id = ?
    `).all(recipeId);
  }

  static create({ productionTypeId, name, description, materials }) {
    const db = getLocalDb();
    const id = uuidv4();
    
    db.transaction(() => {
      // Create recipe
      db.prepare(`
        INSERT INTO recipes (id, production_type_id, name, description, synced)
        VALUES (?, ?, ?, ?, 0)
      `).run(id, productionTypeId, name, description || null);
      
      // Add materials
      if (materials && materials.length > 0) {
        const stmt = db.prepare(`
          INSERT INTO recipe_materials (id, recipe_id, material_id, quantity_per_unit, synced)
          VALUES (?, ?, ?, ?, 0)
        `);
        
        for (const material of materials) {
          const materialId = uuidv4();
          stmt.run(materialId, id, material.materialId || material.material_id, material.quantityPerUnit || material.quantity_per_unit);
        }
      }
      
      // Add to sync queue
      db.prepare(`
        INSERT INTO sync_queue (table_name, record_id, operation, data)
        VALUES (?, ?, ?, ?)
      `).run('recipes', id, 'INSERT', JSON.stringify({
        id, productionTypeId, name, description, materials
      }));
    })();
    
    return this.getById(id);
  }

  static update(id, { name, description, materials }) {
    const db = getLocalDb();
    
    db.transaction(() => {
      // Update recipe
      db.prepare(`
        UPDATE recipes 
        SET name = ?, description = ?, synced = 0
        WHERE id = ?
      `).run(name, description || null, id);
      
      // Delete existing materials
      db.prepare('DELETE FROM recipe_materials WHERE recipe_id = ?').run(id);
      
      // Add new materials
      if (materials && materials.length > 0) {
        const stmt = db.prepare(`
          INSERT INTO recipe_materials (id, recipe_id, material_id, quantity_per_unit, synced)
          VALUES (?, ?, ?, ?, 0)
        `);
        
        for (const material of materials) {
          const materialId = uuidv4();
          stmt.run(materialId, id, material.materialId || material.material_id, material.quantityPerUnit || material.quantity_per_unit);
        }
      }
      
      // Add to sync queue
      db.prepare(`
        INSERT INTO sync_queue (table_name, record_id, operation, data)
        VALUES (?, ?, ?, ?)
      `).run('recipes', id, 'UPDATE', JSON.stringify({
        id, name, description, materials
      }));
    })();
    
    return this.getById(id);
  }

  static delete(id) {
    const db = getLocalDb();
    
    // Add to sync queue
    db.prepare(`
      INSERT INTO sync_queue (table_name, record_id, operation, data)
      VALUES (?, ?, ?, ?)
    `).run('recipes', id, 'DELETE', JSON.stringify({ id }));
    
    // Delete recipe (materials will be deleted automatically due to CASCADE)
    db.prepare('DELETE FROM recipes WHERE id = ?').run(id);
    return true;
  }

  // Calculate materials needed for production quantity
  static calculateMaterials(recipeId, productionQuantity) {
    const materials = this.getMaterials(recipeId);
    return materials.map(m => ({
      materialId: m.material_id,
      quantity: m.quantity_per_unit * productionQuantity
    }));
  }
}

