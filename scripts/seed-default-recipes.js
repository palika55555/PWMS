import { getLocalDb, getRemotePool } from '../config/database.js';
import { v4 as uuidv4 } from 'uuid';

/**
 * Seed script pre vytvorenie predvolených receptúr pre Dlažbu a Tvárnice
 * 
 * Spustenie:
 * node scripts/seed-default-recipes.js
 */

const DEFAULT_RECIPES = {
  dlažba: {
    name: 'Predvolená receptúra - Dlažba',
    description: 'Štandardná receptúra pre výrobu betónovej dlažby (na 1 m², hrúbka 6-8 cm). Pomery: 1 diel cementu, 3 diely piesku, 5 dielov štrku.',
    materials: [
      { name: 'Cement', quantityPerUnit: 18 }, // kg na m² (štandardný betón C20/25)
      { name: 'Piesok', quantityPerUnit: 55 }, // kg na m²
      { name: 'Štrk', quantityPerUnit: 90 }, // kg na m² (frakcia 4/8 mm)
      { name: 'Voda', quantityPerUnit: 9 }, // l na m²
      { name: 'Pigment', quantityPerUnit: 0.5 }, // kg na m² (voliteľné)
    ]
  },
  tvárnice: {
    name: 'Predvolená receptúra - Tvárnice',
    description: 'Štandardná receptúra pre výrobu betónových tvárnic (na 1 m²). Pomery: 1 diel cementu, 4.5 dielov piesku, 8 dielov štrku.',
    materials: [
      { name: 'Cement', quantityPerUnit: 14 }, // kg na m² (betón C16/20)
      { name: 'Piesok', quantityPerUnit: 65 }, // kg na m²
      { name: 'Štrk', quantityPerUnit: 110 }, // kg na m² (frakcia 8/16 mm)
      { name: 'Voda', quantityPerUnit: 11 }, // l na m²
    ]
  }
};

async function seedRecipes() {
  console.log('🌱 Začínam seed predvolených receptúr...\n');

  const pool = getRemotePool();
  const db = getLocalDb();

  try {
    // Najprv získame alebo vytvoríme typy výroby
    let dlažbaTypeId, tvárniceTypeId;

    if (pool) {
      const client = await pool.connect();
      try {
        // Skontrolujeme, či existujú typy výroby
        let result = await client.query("SELECT id, name FROM production_types WHERE LOWER(name) LIKE '%dlažba%' OR LOWER(name) LIKE '%dlazba%'");
        if (result.rows.length > 0) {
          dlažbaTypeId = result.rows[0].id;
        } else {
          // Vytvoríme typ "Dlažba"
          dlažbaTypeId = uuidv4();
          await client.query(
            "INSERT INTO production_types (id, name, description) VALUES ($1, $2, $3)",
            [dlažbaTypeId, 'Dlažba', 'Betónová dlažba']
          );
          console.log('✅ Vytvorený typ výroby: Dlažba');
        }

        result = await client.query("SELECT id, name FROM production_types WHERE LOWER(name) LIKE '%tvárnice%' OR LOWER(name) LIKE '%tvarnice%'");
        if (result.rows.length > 0) {
          tvárniceTypeId = result.rows[0].id;
        } else {
          // Vytvoríme typ "Tvárnice"
          tvárniceTypeId = uuidv4();
          await client.query(
            "INSERT INTO production_types (id, name, description) VALUES ($1, $2, $3)",
            [tvárniceTypeId, 'Tvárnice', 'Betónové tvárnice']
          );
          console.log('✅ Vytvorený typ výroby: Tvárnice');
        }

        // Získame alebo vytvoríme materiály
        const materialsMap = {};
        const materialNames = ['Cement', 'Štrk', 'Piesok', 'Voda', 'Pigment'];
        const materialUnits = {
          'Cement': 'kg',
          'Štrk': 'kg',
          'Piesok': 'kg',
          'Voda': 'l',
          'Pigment': 'kg'
        };

        for (const matName of materialNames) {
          result = await client.query("SELECT id FROM materials WHERE LOWER(name) = LOWER($1)", [matName]);
          if (result.rows.length > 0) {
            materialsMap[matName] = result.rows[0].id;
          } else {
            const materialId = uuidv4();
            await client.query(
              "INSERT INTO materials (id, name, unit) VALUES ($1, $2, $3)",
              [materialId, matName, materialUnits[matName]]
            );
            materialsMap[matName] = materialId;
            console.log(`✅ Vytvorený materiál: ${matName} (${materialUnits[matName]})`);
          }
        }

        // Vytvoríme receptúry
        for (const [typeKey, recipeData] of Object.entries(DEFAULT_RECIPES)) {
          const productionTypeId = typeKey === 'dlažba' ? dlažbaTypeId : tvárniceTypeId;
          
          // Skontrolujeme, či už existuje predvolená receptúra
          result = await client.query(
            "SELECT id FROM recipes WHERE production_type_id = $1 AND name = $2",
            [productionTypeId, recipeData.name]
          );

          if (result.rows.length > 0) {
            console.log(`⏭️  Receptúra "${recipeData.name}" už existuje, preskakujem...`);
            continue;
          }

          const recipeId = uuidv4();
          
          // Vytvoríme receptúru
          await client.query(
            "INSERT INTO recipes (id, production_type_id, name, description, synced) VALUES ($1, $2, $3, $4, 1)",
            [recipeId, productionTypeId, recipeData.name, recipeData.description]
          );

          // Pridáme materiály
          for (const material of recipeData.materials) {
            const materialId = materialsMap[material.name];
            if (!materialId) {
              console.warn(`⚠️  Materiál "${material.name}" nebol nájdený, preskakujem...`);
              continue;
            }

            const recipeMaterialId = uuidv4();
            await client.query(
              "INSERT INTO recipe_materials (id, recipe_id, material_id, quantity_per_unit, synced) VALUES ($1, $2, $3, $4, 1)",
              [recipeMaterialId, recipeId, materialId, material.quantityPerUnit]
            );
          }

          console.log(`✅ Vytvorená receptúra: ${recipeData.name}`);
        }

      } finally {
        client.release();
      }
    } else {
      // SQLite implementácia
      console.log('📦 Používam lokálnu SQLite databázu...\n');
      
      // Získame alebo vytvoríme typy výroby
      let dlažbaTypeId, tvárniceTypeId;
      
      let result = db.prepare("SELECT id, name FROM production_types WHERE LOWER(name) LIKE '%dlažba%' OR LOWER(name) LIKE '%dlazba%'").get();
      if (result) {
        dlažbaTypeId = result.id;
      } else {
        dlažbaTypeId = uuidv4();
        db.prepare("INSERT INTO production_types (id, name, description) VALUES (?, ?, ?)")
          .run(dlažbaTypeId, 'Dlažba', 'Betónová dlažba');
        console.log('✅ Vytvorený typ výroby: Dlažba');
      }

      result = db.prepare("SELECT id, name FROM production_types WHERE LOWER(name) LIKE '%tvárnice%' OR LOWER(name) LIKE '%tvarnice%'").get();
      if (result) {
        tvárniceTypeId = result.id;
      } else {
        tvárniceTypeId = uuidv4();
        db.prepare("INSERT INTO production_types (id, name, description) VALUES (?, ?, ?)")
          .run(tvárniceTypeId, 'Tvárnice', 'Betónové tvárnice');
        console.log('✅ Vytvorený typ výroby: Tvárnice');
      }

      // Získame alebo vytvoríme materiály
      const materialsMap = {};
      const materialNames = ['Cement', 'Štrk', 'Piesok', 'Voda', 'Pigment'];
      const materialUnits = {
        'Cement': 'kg',
        'Štrk': 'kg',
        'Piesok': 'kg',
        'Voda': 'l',
        'Pigment': 'kg'
      };

      for (const matName of materialNames) {
        result = db.prepare("SELECT id FROM materials WHERE LOWER(name) = LOWER(?)").get(matName);
        if (result) {
          materialsMap[matName] = result.id;
        } else {
          const materialId = uuidv4();
          db.prepare("INSERT INTO materials (id, name, unit) VALUES (?, ?, ?)")
            .run(materialId, matName, materialUnits[matName]);
          materialsMap[matName] = materialId;
          console.log(`✅ Vytvorený materiál: ${matName} (${materialUnits[matName]})`);
        }
      }

      // Vytvoríme receptúry
      for (const [typeKey, recipeData] of Object.entries(DEFAULT_RECIPES)) {
        const productionTypeId = typeKey === 'dlažba' ? dlažbaTypeId : tvárniceTypeId;
        
        // Skontrolujeme, či už existuje predvolená receptúra
        result = db.prepare("SELECT id FROM recipes WHERE production_type_id = ? AND name = ?")
          .get(productionTypeId, recipeData.name);

        if (result) {
          console.log(`⏭️  Receptúra "${recipeData.name}" už existuje, preskakujem...`);
          continue;
        }

        const recipeId = uuidv4();
        
        // Vytvoríme receptúru
        db.prepare("INSERT INTO recipes (id, production_type_id, name, description, synced) VALUES (?, ?, ?, ?, 0)")
          .run(recipeId, productionTypeId, recipeData.name, recipeData.description);

        // Pridáme materiály
        for (const material of recipeData.materials) {
          const materialId = materialsMap[material.name];
          if (!materialId) {
            console.warn(`⚠️  Materiál "${material.name}" nebol nájdený, preskakujem...`);
            continue;
          }

          const recipeMaterialId = uuidv4();
          db.prepare("INSERT INTO recipe_materials (id, recipe_id, material_id, quantity_per_unit, synced) VALUES (?, ?, ?, ?, 0)")
            .run(recipeMaterialId, recipeId, materialId, material.quantityPerUnit);
        }

        console.log(`✅ Vytvorená receptúra: ${recipeData.name}`);
      }
    }

    console.log('\n✅ Seed predvolených receptúr dokončený!');
  } catch (error) {
    console.error('❌ Chyba pri seedovaní:', error);
    process.exit(1);
  }
}

// Spustenie seed skriptu
seedRecipes()
  .then(() => {
    console.log('\n✨ Hotovo!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Kritická chyba:', error);
    process.exit(1);
  });

