import { getLocalDb, getRemotePool } from '../config/database.js';
import { v4 as uuidv4 } from 'uuid';

/**
 * Seed script pre vytvorenie predvolených materiálov
 * 
 * Spustenie:
 * node scripts/seed-materials.js
 */

const DEFAULT_MATERIALS = [
  { name: 'Cement', unit: 'kg' },
  { name: 'Štrk', unit: 'kg' },
  { name: 'Piesok', unit: 'kg' },
  { name: 'Voda', unit: 'l' },
  { name: 'Pigment', unit: 'kg' },
];

async function seedMaterials() {
  console.log('🌱 Začínam seed predvolených materiálov...\n');

  const pool = getRemotePool();
  const db = getLocalDb();

  try {
    if (pool) {
      // PostgreSQL implementácia
      const client = await pool.connect();
      try {
        for (const material of DEFAULT_MATERIALS) {
          // Skontrolujeme, či už existuje
          const result = await client.query(
            "SELECT id FROM materials WHERE LOWER(name) = LOWER($1)",
            [material.name]
          );

          if (result.rows.length > 0) {
            console.log(`⏭️  Materiál "${material.name}" už existuje, preskakujem...`);
            continue;
          }

          // Vytvoríme materiál
          const materialId = uuidv4();
          await client.query(
            "INSERT INTO materials (id, name, unit, synced) VALUES ($1, $2, $3, 1)",
            [materialId, material.name, material.unit]
          );
          console.log(`✅ Vytvorený materiál: ${material.name} (${material.unit})`);

          // Vytvoríme aj warehouse záznam s počiatočným množstvom 0
          const warehouseId = uuidv4();
          await client.query(
            "INSERT INTO warehouse (id, material_id, quantity, synced) VALUES ($1, $2, $3, 1)",
            [warehouseId, materialId, 0]
          );
        }
      } finally {
        client.release();
      }
    } else {
      // SQLite implementácia
      console.log('📦 Používam lokálnu SQLite databázu...\n');
      
      for (const material of DEFAULT_MATERIALS) {
        // Skontrolujeme, či už existuje
        const result = db.prepare("SELECT id FROM materials WHERE LOWER(name) = LOWER(?)").get(material.name);

        if (result) {
          console.log(`⏭️  Materiál "${material.name}" už existuje, preskakujem...`);
          continue;
        }

        // Vytvoríme materiál
        const materialId = uuidv4();
        db.prepare("INSERT INTO materials (id, name, unit, synced) VALUES (?, ?, ?, 0)")
          .run(materialId, material.name, material.unit);
        console.log(`✅ Vytvorený materiál: ${material.name} (${material.unit})`);

        // Vytvoríme aj warehouse záznam s počiatočným množstvom 0
        const warehouseId = uuidv4();
        db.prepare("INSERT INTO warehouse (id, material_id, quantity, synced) VALUES (?, ?, ?, 0)")
          .run(warehouseId, materialId, 0);
      }
    }

    console.log('\n✅ Seed predvolených materiálov dokončený!');
  } catch (error) {
    console.error('❌ Chyba pri seedovaní:', error);
    process.exit(1);
  }
}

// Spustenie seed skriptu
seedMaterials()
  .then(() => {
    console.log('\n✨ Hotovo!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Kritická chyba:', error);
    process.exit(1);
  });

