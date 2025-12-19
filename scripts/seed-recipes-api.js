import https from 'https';
import http from 'http';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { readFileSync } from 'fs';
import dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Načítame .env súbor
dotenv.config({ path: join(__dirname, '..', '.env') });

const API_BASE_URL = process.env.RAILWAY_URL || process.env.API_BASE_URL || process.argv[2] || 'http://localhost:3000';

const DEFAULT_RECIPES = {
  dlažba: {
    name: 'Predvolená receptúra - Dlažba',
    description: 'Štandardná receptúra pre výrobu betónovej dlažby (na 1 m², hrúbka 6-8 cm). Pomery: 1 diel cementu, 3 diely piesku, 5 dielov štrku.',
    materials: [
      { name: 'Cement', quantityPerUnit: 18 }, // kg na m²
      { name: 'Piesok', quantityPerUnit: 55 }, // kg na m²
      { name: 'Štrk 4/8', quantityPerUnit: 90 }, // kg na m²
      { name: 'Voda', quantityPerUnit: 9 }, // l na m²
      { name: 'Pigment', quantityPerUnit: 0.5 }, // kg na m²
    ]
  },
  tvárnice: {
    name: 'Predvolená receptúra - Tvárnice',
    description: 'Štandardná receptúra pre výrobu betónových tvárnic (na 1 m²). Pomery: 1 diel cementu, 4.5 dielov piesku, 8 dielov štrku.',
    materials: [
      { name: 'Cement', quantityPerUnit: 14 }, // kg na m²
      { name: 'Piesok', quantityPerUnit: 65 }, // kg na m²
      { name: 'Štrk 8/16', quantityPerUnit: 110 }, // kg na m²
      { name: 'Voda', quantityPerUnit: 11 }, // l na m²
    ]
  },
  tvárnice_hrubé: {
    name: 'Receptúra - Tvárnice (hrubý štrk)',
    description: 'Receptúra pre výrobu betónových tvárnic s hrubším štrkom (na 1 m²). Vhodné pre nosné tvárnice.',
    materials: [
      { name: 'Cement', quantityPerUnit: 16 }, // kg na m²
      { name: 'Piesok', quantityPerUnit: 60 }, // kg na m²
      { name: 'Štrk 16/32', quantityPerUnit: 120 }, // kg na m²
      { name: 'Voda', quantityPerUnit: 12 }, // l na m²
    ]
  },
  tvárnice_jemné: {
    name: 'Receptúra - Tvárnice (jemný štrk)',
    description: 'Receptúra pre výrobu betónových tvárnic s jemnejším štrkom (na 1 m²). Vhodné pre dekoratívne tvárnice.',
    materials: [
      { name: 'Cement', quantityPerUnit: 15 }, // kg na m²
      { name: 'Piesok', quantityPerUnit: 70 }, // kg na m²
      { name: 'Štrk 4/8', quantityPerUnit: 100 }, // kg na m²
      { name: 'Voda', quantityPerUnit: 10 }, // l na m²
    ]
  }
};

function makeRequest(method, path, data = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, API_BASE_URL);
    const isHttps = url.protocol === 'https:';
    const requestModule = isHttps ? https : http;
    
    const options = {
      method,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    const req = requestModule.request(url, options, (res) => {
      let body = '';
      res.on('data', (chunk) => {
        body += chunk;
      });
      res.on('end', () => {
        try {
          const parsed = body ? JSON.parse(body) : {};
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(parsed);
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${body}`));
          }
        } catch (e) {
          resolve(body);
        }
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    if (data) {
      req.write(JSON.stringify(data));
    }

    req.end();
  });
}

async function seedRecipes() {
  console.log('🌱 Začínam seed predvolených receptúr cez API...\n');
  console.log(`📡 Používam API: ${API_BASE_URL}\n`);

  try {
    // Najprv skontrolujeme, či API beží
    try {
      await makeRequest('GET', '/api/production/types');
      console.log('✅ API je dostupné\n');
    } catch (error) {
      console.error('❌ API nie je dostupné!');
      console.error('   Uistite sa, že backend server beží na:', API_BASE_URL);
      console.error('   Spustite: npm start\n');
      process.exit(1);
    }

    // Získame alebo vytvoríme typy výroby
    let dlažbaTypeId, tvárniceTypeId;
    
    const productionTypes = await makeRequest('GET', '/api/production/types');
    
    // Hľadáme typy výroby
    const dlažbaType = productionTypes.find(t => 
      t.name.toLowerCase().includes('dlažba') || t.name.toLowerCase().includes('dlazba')
    );
    const tvárniceType = productionTypes.find(t => 
      t.name.toLowerCase().includes('tvárnice') || t.name.toLowerCase().includes('tvarnice')
    );

    if (dlažbaType) {
      dlažbaTypeId = dlažbaType.id;
      console.log(`✅ Typ výroby "Dlažba" už existuje`);
    } else {
      const newType = await makeRequest('POST', '/api/production/types', {
        name: 'Dlažba',
        description: 'Betónová dlažba'
      });
      dlažbaTypeId = newType.id;
      console.log('✅ Vytvorený typ výroby: Dlažba');
    }

    if (tvárniceType) {
      tvárniceTypeId = tvárniceType.id;
      console.log(`✅ Typ výroby "Tvárnice" už existuje`);
    } else {
      const newType = await makeRequest('POST', '/api/production/types', {
        name: 'Tvárnice',
        description: 'Betónové tvárnice'
      });
      tvárniceTypeId = newType.id;
      console.log('✅ Vytvorený typ výroby: Tvárnice');
    }

    // Získame všetky materiály
    const materials = await makeRequest('GET', '/api/materials');
    const materialsMap = {};
    for (const material of materials) {
      materialsMap[material.name] = material.id;
    }

    // Vytvoríme receptúry
    for (const [typeKey, recipeData] of Object.entries(DEFAULT_RECIPES)) {
      let productionTypeId;
      if (typeKey === 'dlažba') {
        productionTypeId = dlažbaTypeId;
      } else if (typeKey.startsWith('tvárnice')) {
        productionTypeId = tvárniceTypeId;
      } else {
        console.warn(`⚠️  Neznámy typ výroby pre receptúru: ${typeKey}`);
        continue;
      }

      // Skontrolujeme, či už existuje receptúra
      const existingRecipes = await makeRequest('GET', `/api/recipes/type/${productionTypeId}`);
      const existing = existingRecipes.find(r => r.name === recipeData.name);

      if (existing) {
        console.log(`⏭️  Receptúra "${recipeData.name}" už existuje, preskakujem...`);
        continue;
      }

      // Vytvoríme receptúru
      const recipe = await makeRequest('POST', '/api/recipes', {
        productionTypeId: productionTypeId,
        name: recipeData.name,
        description: recipeData.description,
        materials: recipeData.materials.map(m => ({
          materialId: materialsMap[m.name],
          quantityPerUnit: m.quantityPerUnit
        })).filter(m => m.materialId) // Filtrujeme len existujúce materiály
      });

      if (recipe && recipe.id) {
        console.log(`✅ Vytvorená receptúra: ${recipeData.name}`);
      } else {
        console.warn(`⚠️  Chyba pri vytváraní receptúry: ${recipeData.name}`);
      }

      // Počkáme chvíľu, aby sa databáza aktualizovala
      await new Promise((resolve) => setTimeout(resolve, 200));
    }

    console.log('\n✅ Seed predvolených receptúr dokončený!');
  } catch (error) {
    console.error('❌ Chyba pri seedovaní:', error.message);
    if (error.stack) {
      console.error(error.stack);
    }
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

