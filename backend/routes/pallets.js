const express = require('express');
const router = express.Router();
const pool = require('../config/database');

function mapPalletRow(r) {
  return {
    id: r.id,
    palletId: r.pallet_id,
    productCode: r.product_code,
    status: r.status, // in_stock | issued
    firstSeenAt: r.first_seen_at,
    lastSeenAt: r.last_seen_at,
    lastRaw: r.last_raw,
    source: r.source,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

function mapEventRow(r) {
  return {
    id: r.id,
    palletId: r.pallet_id,
    productCode: r.product_code,
    mode: r.mode, // receive | issue
    raw: r.raw,
    source: r.source,
    createdAt: r.created_at,
  };
}

// Summary counts by product
router.get('/summary', async (req, res) => {
  try {
    const byProduct = await pool.query(
      `
      SELECT
        product_code,
        COUNT(*) FILTER (WHERE status = 'in_stock')::int AS in_stock,
        COUNT(*) FILTER (WHERE status = 'issued')::int AS issued,
        COUNT(*)::int AS total
      FROM product_pallets
      GROUP BY product_code
      ORDER BY product_code ASC
      `
    );

    const totals = await pool.query(
      `
      SELECT
        COUNT(*) FILTER (WHERE status = 'in_stock')::int AS in_stock,
        COUNT(*) FILTER (WHERE status = 'issued')::int AS issued,
        COUNT(*)::int AS total
      FROM product_pallets
      `
    );

    return res.json({
      totals: totals.rows[0],
      byProduct: byProduct.rows.map((r) => ({
        productCode: r.product_code,
        inStock: r.in_stock,
        issued: r.issued,
        total: r.total,
      })),
    });
  } catch (error) {
    console.error('Error fetching pallet summary:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// List pallets (with basic filtering)
router.get('/', async (req, res) => {
  try {
    const { status, product, q, limit } = req.query;
    const params = [];
    let sql = `SELECT * FROM product_pallets`;
    const where = [];

    if (status && (status === 'in_stock' || status === 'issued')) {
      params.push(status);
      where.push(`status = $${params.length}`);
    }
    if (product && typeof product === 'string' && product.trim()) {
      params.push(product.trim());
      where.push(`product_code = $${params.length}`);
    }
    if (q && typeof q === 'string' && q.trim()) {
      params.push(`%${q.trim()}%`);
      where.push(`(pallet_id ILIKE $${params.length} OR product_code ILIKE $${params.length} OR COALESCE(last_raw,'') ILIKE $${params.length})`);
    }

    if (where.length) sql += ` WHERE ` + where.join(' AND ');
    sql += ` ORDER BY last_seen_at DESC`;

    const lim = Math.min(Math.max(parseInt(String(limit || '500'), 10) || 500, 1), 2000);
    params.push(lim);
    sql += ` LIMIT $${params.length}`;

    const result = await pool.query(sql, params);
    return res.json(result.rows.map(mapPalletRow));
  } catch (error) {
    console.error('Error fetching pallets:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// Recent events
router.get('/events', async (req, res) => {
  try {
    const lim = Math.min(Math.max(parseInt(String(req.query.limit || '50'), 10) || 50, 1), 500);
    const result = await pool.query(
      `SELECT * FROM product_pallet_events ORDER BY created_at DESC LIMIT $1`,
      [lim]
    );
    return res.json(result.rows.map(mapEventRow));
  } catch (error) {
    console.error('Error fetching pallet events:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// Scan endpoint (upsert pallet state + write event)
router.post('/scan', async (req, res) => {
  const { mode, palletId, productCode, raw, source } = req.body || {};
  if (!mode || (mode !== 'receive' && mode !== 'issue')) {
    return res.status(400).json({ error: 'Invalid mode (receive|issue)' });
  }
  if (!palletId || typeof palletId !== 'string' || !palletId.trim()) {
    return res.status(400).json({ error: 'Missing palletId' });
  }
  if (!productCode || typeof productCode !== 'string' || !productCode.trim()) {
    return res.status(400).json({ error: 'Missing productCode' });
  }

  const status = mode === 'receive' ? 'in_stock' : 'issued';
  const pallet_id = palletId.trim();
  const product_code = productCode.trim();

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const upsert = await client.query(
      `
      INSERT INTO product_pallets (pallet_id, product_code, status, first_seen_at, last_seen_at, last_raw, source, created_at, updated_at)
      VALUES ($1, $2, $3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, $4, $5, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT (pallet_id)
      DO UPDATE SET
        product_code = EXCLUDED.product_code,
        status = EXCLUDED.status,
        last_seen_at = CURRENT_TIMESTAMP,
        last_raw = EXCLUDED.last_raw,
        source = EXCLUDED.source,
        updated_at = CURRENT_TIMESTAMP
      RETURNING *;
      `,
      [pallet_id, product_code, status, raw || null, source || 'qr-web']
    );

    const ev = await client.query(
      `
      INSERT INTO product_pallet_events (pallet_id, product_code, mode, raw, source, created_at)
      VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)
      RETURNING *;
      `,
      [pallet_id, product_code, mode, raw || null, source || 'qr-web']
    );

    await client.query('COMMIT');
    return res.json({ item: mapPalletRow(upsert.rows[0]), event: mapEventRow(ev.rows[0]) });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error scanning pallet:', error);
    return res.status(500).json({ error: 'Internal server error', detail: error?.message });
  } finally {
    client.release();
  }
});

module.exports = router;


