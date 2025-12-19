import { v4 as uuidv4 } from 'uuid';
import { getLocalDb } from '../config/database.js';

export class Warehouse {
  static getAll() {
    const db = getLocalDb();
    return db.prepare(`
      SELECT w.*, m.name as material_name, m.unit
      FROM warehouse w
      JOIN materials m ON w.material_id = m.id
      ORDER BY m.name
    `).all();
  }

  static getById(id) {
    const db = getLocalDb();
    return db.prepare(`
      SELECT w.*, m.name as material_name, m.unit
      FROM warehouse w
      JOIN materials m ON w.material_id = m.id
      WHERE w.id = ?
    `).get(id);
  }

  static getByMaterialId(materialId) {
    const db = getLocalDb();
    return db.prepare('SELECT * FROM warehouse WHERE material_id = ?').get(materialId);
  }

  static create({ materialId, quantity }) {
    const db = getLocalDb();
    
    // Check if warehouse entry exists for this material
    const existing = this.getByMaterialId(materialId);
    
    if (existing) {
      return this.update(existing.id, { quantity: existing.quantity + quantity });
    }
    
    const id = uuidv4();
    
    db.prepare(`
      INSERT INTO warehouse (id, material_id, quantity, synced)
      VALUES (?, ?, ?, 0)
    `).run(id, materialId, quantity);
    
    // Add to sync queue
    db.prepare(`
      INSERT INTO sync_queue (table_name, record_id, operation, data)
      VALUES (?, ?, ?, ?)
    `).run('warehouse', id, 'INSERT', JSON.stringify({ id, materialId, quantity }));
    
    return this.getById(id);
  }

  static update(id, { quantity }) {
    const db = getLocalDb();
    
    db.prepare(`
      UPDATE warehouse 
      SET quantity = ?, last_updated = CURRENT_TIMESTAMP, synced = 0
      WHERE id = ?
    `).run(quantity, id);
    
    const record = this.getById(id);
    
    // Add to sync queue
    db.prepare(`
      INSERT INTO sync_queue (table_name, record_id, operation, data)
      VALUES (?, ?, ?, ?)
    `).run('warehouse', id, 'UPDATE', JSON.stringify({ id, materialId: record.material_id, quantity }));
    
    return record;
  }

  static adjustQuantity(materialId, change) {
    const db = getLocalDb();
    const existing = this.getByMaterialId(materialId);
    
    if (!existing) {
      throw new Error('Warehouse entry not found for material');
    }
    
    const newQuantity = existing.quantity + change;
    if (newQuantity < 0) {
      throw new Error('Insufficient quantity in warehouse');
    }
    
    return this.update(existing.id, { quantity: newQuantity });
  }

  static delete(id) {
    const db = getLocalDb();
    const record = this.getById(id);
    
    // Add to sync queue
    db.prepare(`
      INSERT INTO sync_queue (table_name, record_id, operation, data)
      VALUES (?, ?, ?, ?)
    `).run('warehouse', id, 'DELETE', JSON.stringify({ id }));
    
    db.prepare('DELETE FROM warehouse WHERE id = ?').run(id);
    return true;
  }
}

