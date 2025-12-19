import { getLocalDb, getRemotePool, isRemoteAvailable } from '../config/database.js';
import { Material } from '../models/Material.js';
import { Warehouse } from '../models/Warehouse.js';
import { Production, ProductionType } from '../models/Production.js';
import { v4 as uuidv4 } from 'uuid';

export class SyncService {
  static async syncToRemote() {
    const db = getLocalDb();
    const pool = getRemotePool();
    
    if (!pool) {
      console.log('Remote database not configured');
      return { success: false, message: 'Remote database not configured' };
    }
    
    const available = await isRemoteAvailable();
    if (!available) {
      console.log('Remote database not available');
      return { success: false, message: 'Remote database not available' };
    }
    
    const client = await pool.connect();
    const results = {
      synced: 0,
      failed: 0,
      errors: []
    };
    
    try {
      // Get all unsynced records from sync queue
      const queue = db.prepare(`
        SELECT * FROM sync_queue 
        ORDER BY created_at ASC
      `).all();
      
      for (const item of queue) {
        try {
          await this.syncItem(client, item);
          
          // Mark as synced in local database
          db.prepare(`
            UPDATE ${item.table_name} 
            SET synced = 1 
            WHERE id = ?
          `).run(item.record_id);
          
          // Remove from sync queue
          db.prepare('DELETE FROM sync_queue WHERE id = ?').run(item.id);
          
          results.synced++;
        } catch (error) {
          console.error(`Error syncing ${item.table_name}:${item.record_id}`, error);
          results.failed++;
          results.errors.push({
            table: item.table_name,
            id: item.record_id,
            error: error.message
          });
        }
      }
      
      return { success: true, ...results };
    } finally {
      client.release();
    }
  }
  
  static async syncItem(client, item) {
    const data = JSON.parse(item.data || '{}');
    
    switch (item.table_name) {
      case 'materials':
        await this.syncMaterial(client, item.operation, data);
        break;
      case 'warehouse':
        await this.syncWarehouse(client, item.operation, data);
        break;
      case 'production_types':
        await this.syncProductionType(client, item.operation, data);
        break;
      case 'production':
        await this.syncProduction(client, item.operation, data);
        break;
      case 'production_materials':
        await this.syncProductionMaterial(client, item.operation, data);
        break;
      default:
        throw new Error(`Unknown table: ${item.table_name}`);
    }
  }
  
  static async syncMaterial(client, operation, data) {
    if (operation === 'INSERT' || operation === 'UPDATE') {
      await client.query(`
        INSERT INTO materials (id, name, unit, synced)
        VALUES ($1, $2, $3, 1)
        ON CONFLICT (id) 
        DO UPDATE SET name = $2, unit = $3, updated_at = CURRENT_TIMESTAMP, synced = 1
      `, [data.id, data.name, data.unit]);
    } else if (operation === 'DELETE') {
      await client.query('DELETE FROM materials WHERE id = $1', [data.id]);
    }
  }
  
  static async syncWarehouse(client, operation, data) {
    if (operation === 'INSERT' || operation === 'UPDATE') {
      await client.query(`
        INSERT INTO warehouse (id, material_id, quantity, synced)
        VALUES ($1, $2, $3, 1)
        ON CONFLICT (id) 
        DO UPDATE SET quantity = $3, last_updated = CURRENT_TIMESTAMP, synced = 1
      `, [data.id, data.materialId, data.quantity]);
    } else if (operation === 'DELETE') {
      await client.query('DELETE FROM warehouse WHERE id = $1', [data.id]);
    }
  }
  
  static async syncProductionType(client, operation, data) {
    if (operation === 'INSERT' || operation === 'UPDATE') {
      await client.query(`
        INSERT INTO production_types (id, name, description, synced)
        VALUES ($1, $2, $3, 1)
        ON CONFLICT (id) 
        DO UPDATE SET name = $2, description = $3, synced = 1
      `, [data.id, data.name, data.description || null]);
    } else if (operation === 'DELETE') {
      await client.query('DELETE FROM production_types WHERE id = $1', [data.id]);
    }
  }
  
  static async syncProduction(client, operation, data) {
    if (operation === 'INSERT' || operation === 'UPDATE') {
      await client.query(`
        INSERT INTO production (id, production_type_id, quantity, notes, qr_code, production_date, synced)
        VALUES ($1, $2, $3, $4, $5, $6, 1)
        ON CONFLICT (id) 
        DO UPDATE SET quantity = $3, notes = $4, synced = 1
      `, [
        data.id, 
        data.productionTypeId, 
        data.quantity, 
        data.notes || null, 
        data.qrCode || null,
        data.productionDate || new Date().toISOString()
      ]);
      
      // Sync production materials
      if (data.materials && Array.isArray(data.materials)) {
        for (const material of data.materials) {
          await client.query(`
            INSERT INTO production_materials (id, production_id, material_id, quantity, synced)
            VALUES ($1, $2, $3, $4, 1)
            ON CONFLICT (id) 
            DO UPDATE SET quantity = $4, synced = 1
          `, [material.id || uuidv4(), data.id, material.materialId, material.quantity]);
        }
      }
    } else if (operation === 'DELETE') {
      await client.query('DELETE FROM production_materials WHERE production_id = $1', [data.id]);
      await client.query('DELETE FROM production WHERE id = $1', [data.id]);
    }
  }
  
  static async syncProductionMaterial(client, operation, data) {
    if (operation === 'INSERT' || operation === 'UPDATE') {
      await client.query(`
        INSERT INTO production_materials (id, production_id, material_id, quantity, synced)
        VALUES ($1, $2, $3, $4, 1)
        ON CONFLICT (id) 
        DO UPDATE SET quantity = $4, synced = 1
      `, [data.id, data.productionId, data.materialId, data.quantity]);
    } else if (operation === 'DELETE') {
      await client.query('DELETE FROM production_materials WHERE id = $1', [data.id]);
    }
  }
  
  static getSyncStatus() {
    const db = getLocalDb();
    const queueCount = db.prepare('SELECT COUNT(*) as count FROM sync_queue').get().count;
    const unsyncedMaterials = db.prepare('SELECT COUNT(*) as count FROM materials WHERE synced = 0').get().count;
    const unsyncedWarehouse = db.prepare('SELECT COUNT(*) as count FROM warehouse WHERE synced = 0').get().count;
    const unsyncedProduction = db.prepare('SELECT COUNT(*) as count FROM production WHERE synced = 0').get().count;
    
    return {
      queueCount,
      unsynced: {
        materials: unsyncedMaterials,
        warehouse: unsyncedWarehouse,
        production: unsyncedProduction
      }
    };
  }
}

