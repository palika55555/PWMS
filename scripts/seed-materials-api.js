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

const DEFAULT_MATERIALS = [
  { name: 'Cement', unit: 'kg' },
  { name: 'Štrk 0/4', unit: 'kg' }, // Jemný štrk, frakcia 0-4 mm
  { name: 'Štrk 4/8', unit: 'kg' }, // Stredný štrk, frakcia 4-8 mm
  { name: 'Štrk 8/16', unit: 'kg' }, // Hrubý štrk, frakcia 8-16 mm
  { name: 'Štrk 16/32', unit: 'kg' }, // Veľmi hrubý štrk, frakcia 16-32 mm
  { name: 'Piesok', unit: 'kg' },
  { name: 'Voda', unit: 'l' },
  { name: 'Pigment', unit: 'kg' },
];

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

async function seedMaterials() {
  console.log('🌱 Začínam seed predvolených materiálov cez API...\n');
  console.log(`📡 Používam API: ${API_BASE_URL}\n`);

  try {
    // Najprv skontrolujeme, či API beží
    try {
      await makeRequest('GET', '/api/materials');
      console.log('✅ API je dostupné\n');
    } catch (error) {
      console.error('❌ API nie je dostupné!');
      console.error('   Uistite sa, že backend server beží na:', API_BASE_URL);
      console.error('   Spustite: npm start\n');
      process.exit(1);
    }

    // Vytvoríme materiály
    for (const material of DEFAULT_MATERIALS) {
      try {
        // Skontrolujeme, či už existuje
        const existing = await makeRequest('GET', `/api/materials`);
        const found = existing.find((m) => m.name.toLowerCase() === material.name.toLowerCase());

        if (found) {
          console.log(`⏭️  Materiál "${material.name}" už existuje, preskakujem...`);
          continue;
        }

        // Vytvoríme materiál
        await makeRequest('POST', '/api/materials', {
          name: material.name,
          unit: material.unit,
        });
        console.log(`✅ Vytvorený materiál: ${material.name} (${material.unit})`);

        // Počkáme chvíľu, aby sa databáza aktualizovala
        await new Promise((resolve) => setTimeout(resolve, 100));
      } catch (error) {
        if (error.message.includes('already exists') || error.message.includes('duplicate')) {
          console.log(`⏭️  Materiál "${material.name}" už existuje, preskakujem...`);
        } else {
          console.error(`❌ Chyba pri vytváraní materiálu "${material.name}":`, error.message);
        }
      }
    }

    console.log('\n✅ Seed predvolených materiálov dokončený!');
  } catch (error) {
    console.error('❌ Chyba pri seedovaní:', error.message);
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

