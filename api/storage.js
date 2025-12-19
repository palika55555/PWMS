// Storage helper pre Vercel serverless functions
// Podporuje Vercel KV (ak je dostupné) alebo fallback na in-memory

// Skúsiť použiť Vercel KV
let kv = null;
try {
  // @vercel/kv je dostupný len ak je nastavený v projekte
  const { kv: vercelKv } = require('@vercel/kv');
  kv = vercelKv;
  console.log('Using Vercel KV for storage');
} catch (e) {
  console.log('Vercel KV not available, using in-memory storage (data will be lost on redeploy)');
}

// Fallback in-memory storage
const memoryStorage = {
  quality: {},
  shipments: {},
  sync: {
    lastUpdate: new Date().toISOString(),
    changes: []
  }
};

// Helper funkcie pre úložisko
async function get(key) {
  if (kv) {
    try {
      const data = await kv.get(key);
      return data || null;
    } catch (e) {
      console.error('Error reading from KV:', e);
      return memoryStorage[key] || null;
    }
  }
  return memoryStorage[key] || null;
}

async function set(key, value) {
  if (kv) {
    try {
      await kv.set(key, value);
      return true;
    } catch (e) {
      console.error('Error writing to KV:', e);
      // Fallback na memory
      memoryStorage[key] = value;
      return true;
    }
  }
  memoryStorage[key] = value;
  return true;
}

// Špecifické funkcie pre kvalitu
async function getQuality() {
  const data = await get('quality');
  return data || {};
}

async function setQuality(data) {
  return await set('quality', data);
}

async function getQualityForBatch(batchNumber) {
  const quality = await getQuality();
  return quality[batchNumber] || null;
}

async function setQualityForBatch(batchNumber, qualityData) {
  const quality = await getQuality();
  quality[batchNumber] = qualityData;
  return await setQuality(quality);
}

// Špecifické funkcie pre expedovanie
async function getShipments() {
  const data = await get('shipments');
  return data || {};
}

async function setShipments(data) {
  return await set('shipments', data);
}

async function getShipmentForBatch(batchNumber) {
  const shipments = await getShipments();
  return shipments[batchNumber] || null;
}

async function setShipmentForBatch(batchNumber, shipmentData) {
  const shipments = await getShipments();
  shipments[batchNumber] = shipmentData;
  return await setShipments(shipments);
}

// Špecifické funkcie pre sync
async function getSyncData() {
  const data = await get('sync');
  return data || {
    lastUpdate: new Date().toISOString(),
    changes: []
  };
}

async function setSyncData(data) {
  return await set('sync', data);
}

async function addSyncChange(change) {
  const sync = await getSyncData();
  sync.changes.push(change);
  sync.lastUpdate = new Date().toISOString();
  
  // Zachovať len posledných 1000 zmien
  if (sync.changes.length > 1000) {
    sync.changes = sync.changes.slice(-1000);
  }
  
  return await setSyncData(sync);
}

module.exports = {
  getQuality,
  setQuality,
  getQualityForBatch,
  setQualityForBatch,
  getShipments,
  setShipments,
  getShipmentForBatch,
  setShipmentForBatch,
  getSyncData,
  setSyncData,
  addSyncChange,
};

