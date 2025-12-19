import { v4 as uuidv4 } from 'uuid';
import { getLocalDb } from '../config/database.js';
import QRCode from 'qrcode';
import { Warehouse } from './Warehouse.js';

export class ProductionType {
  static getAll() {
    const db = getLocalDb();
    return db.prepare('SELECT * FROM production_types ORDER BY name').all();
  }

  static getById(id) {
    const db = getLocalDb();
    return db.prepare('SELECT * FROM production_types WHERE id = ?').get(id);
  }

  static create({ name, description }) {
    const db = getLocalDb();
    const id = uuidv4();
    
    db.prepare(`
      INSERT INTO production_types (id, name, description, synced)
      VALUES (?, ?, ?, 0)
    `).run(id, name, description || null);
    
    // Add to sync queue
    db.prepare(`
      INSERT INTO sync_queue (table_name, record_id, operation, data)
      VALUES (?, ?, ?, ?)
    `).run('production_types', id, 'INSERT', JSON.stringify({ id, name, description }));
    
    return this.getById(id);
  }

  static update(id, { name, description }) {
    const db = getLocalDb();
    
    db.prepare(`
      UPDATE production_types 
      SET name = ?, description = ?, synced = 0
      WHERE id = ?
    `).run(name, description || null, id);
    
    // Add to sync queue
    db.prepare(`
      INSERT INTO sync_queue (table_name, record_id, operation, data)
      VALUES (?, ?, ?, ?)
    `).run('production_types', id, 'UPDATE', JSON.stringify({ id, name, description }));
    
    return this.getById(id);
  }

  static delete(id) {
    const db = getLocalDb();
    
    // Add to sync queue
    db.prepare(`
      INSERT INTO sync_queue (table_name, record_id, operation, data)
      VALUES (?, ?, ?, ?)
    `).run('production_types', id, 'DELETE', JSON.stringify({ id }));
    
    db.prepare('DELETE FROM production_types WHERE id = ?').run(id);
    return true;
  }
}

export class Production {
  static getAll() {
    const db = getLocalDb();
    return db.prepare(`
      SELECT p.*, pt.name as production_type_name
      FROM production p
      JOIN production_types pt ON p.production_type_id = pt.id
      ORDER BY p.production_date DESC
    `).all();
  }

  static getById(id) {
    const db = getLocalDb();
    const production = db.prepare(`
      SELECT p.*, pt.name as production_type_name
      FROM production p
      JOIN production_types pt ON p.production_type_id = pt.id
      WHERE p.id = ?
    `).get(id);
    
    if (production) {
      production.materials = this.getMaterials(id);
    }
    
    return production;
  }

  static getMaterials(productionId) {
    const db = getLocalDb();
    return db.prepare(`
      SELECT pm.*, m.name as material_name, m.unit
      FROM production_materials pm
      JOIN materials m ON pm.material_id = m.id
      WHERE pm.production_id = ?
    `).all(productionId);
  }

  static async create({ productionTypeId, quantity, materials, notes, productionDate, status, recipeId }) {
    const db = getLocalDb();
    const id = uuidv4();
    
    // Check material availability
    let hasInsufficientMaterials = false;
    if (materials && materials.length > 0) {
      for (const material of materials) {
        try {
          const warehouseItem = Warehouse.getByMaterialId(material.materialId);
          if (!warehouseItem || warehouseItem.quantity < material.quantity) {
            hasInsufficientMaterials = true;
            break;
          }
        } catch (error) {
          hasInsufficientMaterials = true;
          break;
        }
      }
    }
    
    // Set status: 'pending' if insufficient materials, otherwise 'completed'
    const productionStatus = hasInsufficientMaterials ? 'pending' : (status || 'completed');
    
    // Generate QR code for production
    const qrData = JSON.stringify({ id, productionTypeId, quantity, date: productionDate || new Date().toISOString() });
    const qrCode = await QRCode.toDataURL(qrData);
    
    // Generate batch number (format: BATCH-YYYYMMDD-XXX)
    const now = new Date();
    const dateStr = now.toISOString().split('T')[0].replace(/-/g, '');
    const batchCount = db.prepare(`
      SELECT COUNT(*) as count FROM batches 
      WHERE batch_number LIKE ?
    `).get(`BATCH-${dateStr}-%`);
    const batchNum = (batchCount?.count || 0) + 1;
    const batchNumber = `BATCH-${dateStr}-${String(batchNum).padStart(3, '0')}`;
    
    // Generate QR code for batch
    const batchQrData = JSON.stringify({ 
      batchNumber, 
      productionId: id, 
      quantity, 
      date: productionDate || new Date().toISOString() 
    });
    const batchQrCode = await QRCode.toDataURL(batchQrData);
    
    db.transaction(() => {
      // Create production record
      db.prepare(`
        INSERT INTO production (id, production_type_id, quantity, notes, qr_code, production_date, status, recipe_id, synced)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)
      `).run(id, productionTypeId, quantity, notes || null, qrCode, productionDate || new Date().toISOString(), productionStatus, recipeId || null);
      
      // Create batch automatically
      const batchId = uuidv4();
      const batchStatus = hasInsufficientMaterials ? 'pending' : 'completed';
      db.prepare(`
        INSERT INTO batches (id, production_id, batch_number, quantity, qr_code, status, created_at, synced)
        VALUES (?, ?, ?, ?, ?, ?, ?, 0)
      `).run(batchId, id, batchNumber, quantity, batchQrCode, batchStatus, new Date().toISOString());
      
      // Add materials used
      if (materials && materials.length > 0) {
        const stmt = db.prepare(`
          INSERT INTO production_materials (id, production_id, material_id, quantity, synced)
          VALUES (?, ?, ?, ?, 0)
        `);
        
        for (const material of materials) {
          const materialId = uuidv4();
          stmt.run(materialId, id, material.materialId, material.quantity);
          
          // Deduct from warehouse only if materials are sufficient
          if (!hasInsufficientMaterials) {
            try {
              Warehouse.adjustQuantity(material.materialId, -material.quantity);
            } catch (error) {
              console.error('Error adjusting warehouse quantity:', error);
            }
          }
        }
      }
      
      // Add to sync queue for production
      db.prepare(`
        INSERT INTO sync_queue (table_name, record_id, operation, data)
        VALUES (?, ?, ?, ?)
      `).run('production', id, 'INSERT', JSON.stringify({
        id, productionTypeId, quantity, materials, notes, productionDate, qrCode, status: productionStatus, recipeId
      }));
      
      // Add to sync queue for batch
      db.prepare(`
        INSERT INTO sync_queue (table_name, record_id, operation, data)
        VALUES (?, ?, ?, ?)
      `).run('batches', batchId, 'INSERT', JSON.stringify({
        id: batchId, production_id: id, batch_number: batchNumber, quantity, qr_code: batchQrCode, status: batchStatus
      }));
    })();
    
    const result = this.getById(id);
    result.status = productionStatus;
    result.hasInsufficientMaterials = hasInsufficientMaterials;
    return result;
  }

  static update(id, { quantity, notes }) {
    const db = getLocalDb();
    
    db.prepare(`
      UPDATE production 
      SET quantity = ?, notes = ?, synced = 0
      WHERE id = ?
    `).run(quantity, notes || null, id);
    
    const record = this.getById(id);
    
    // Add to sync queue
    db.prepare(`
      INSERT INTO sync_queue (table_name, record_id, operation, data)
      VALUES (?, ?, ?, ?)
    `).run('production', id, 'UPDATE', JSON.stringify({ id, quantity, notes }));
    
    return record;
  }

  static delete(id) {
    const db = getLocalDb();
    
    // Get materials to restore to warehouse
    const materials = this.getMaterials(id);
    
    db.transaction(() => {
      // Restore materials to warehouse
      for (const material of materials) {
        try {
          Warehouse.adjustQuantity(material.material_id, material.quantity);
        } catch (error) {
          console.error('Error restoring warehouse quantity:', error);
        }
      }
      
      // Delete production materials
      db.prepare('DELETE FROM production_materials WHERE production_id = ?').run(id);
      
      // Delete production record
      db.prepare('DELETE FROM production WHERE id = ?').run(id);
      
      // Add to sync queue
      db.prepare(`
        INSERT INTO sync_queue (table_name, record_id, operation, data)
        VALUES (?, ?, ?, ?)
      `).run('production', id, 'DELETE', JSON.stringify({ id }));
    })();
    
    return true;
  }
}

