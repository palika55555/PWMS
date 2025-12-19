import { v4 as uuidv4 } from 'uuid';
import { getLocalDb } from '../config/database.js';

export class Material {
  static getAll() {
    const db = getLocalDb();
    return db.prepare('SELECT * FROM materials ORDER BY name').all();
  }

  static getById(id) {
    const db = getLocalDb();
    return db.prepare('SELECT * FROM materials WHERE id = ?').get(id);
  }

  static create({ name, unit }) {
    const db = getLocalDb();
    const id = uuidv4();
    
    db.prepare(`
      INSERT INTO materials (id, name, unit, synced)
      VALUES (?, ?, ?, 0)
    `).run(id, name, unit);
    
    // Add to sync queue
    db.prepare(`
      INSERT INTO sync_queue (table_name, record_id, operation, data)
      VALUES (?, ?, ?, ?)
    `).run('materials', id, 'INSERT', JSON.stringify({ id, name, unit }));
    
    return this.getById(id);
  }

  static update(id, { name, unit }) {
    const db = getLocalDb();
    
    db.prepare(`
      UPDATE materials 
      SET name = ?, unit = ?, updated_at = CURRENT_TIMESTAMP, synced = 0
      WHERE id = ?
    `).run(name, unit, id);
    
    // Add to sync queue
    db.prepare(`
      INSERT INTO sync_queue (table_name, record_id, operation, data)
      VALUES (?, ?, ?, ?)
    `).run('materials', id, 'UPDATE', JSON.stringify({ id, name, unit }));
    
    return this.getById(id);
  }

  static delete(id) {
    const db = getLocalDb();
    
    // Add to sync queue
    db.prepare(`
      INSERT INTO sync_queue (table_name, record_id, operation, data)
      VALUES (?, ?, ?, ?)
    `).run('materials', id, 'DELETE', JSON.stringify({ id }));
    
    db.prepare('DELETE FROM materials WHERE id = ?').run(id);
    return true;
  }
}

