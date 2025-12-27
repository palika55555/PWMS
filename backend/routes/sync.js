const express = require('express');
const router = express.Router();
const pool = require('../config/database');

// Allowlist to avoid SQL injection on table name.
// Add more here as backend schema grows.
const ALLOWED_TABLES = new Set([
  'materials',
  'aggregate_fractions',
  'recipes',
  'recipe_aggregates',
  'batches',
  'batch_materials',
  'quality_tests',
  'products',
  // Optional future tables (will work once created in migrations):
  'stock_movements',
  'inventories',
  'inventory_items',
  'suppliers',
  'customers',
  'warehouses',
  'warehouse_locations',
  'unit_conversions',
  'product_variants',
  'product_accessories',
  'purchase_price_lists',
  'purchase_price_list_items',
  'price_history',
  'auto_orders',
  'warehouse_closings',
  'audit_logs',
  'pallet_movements',
]);

async function getTableColumns(table) {
  const result = await pool.query(
    `SELECT column_name
     FROM information_schema.columns
     WHERE table_schema='public' AND table_name=$1`,
    [table]
  );
  return new Set(result.rows.map((r) => r.column_name));
}

function pickAllowedColumns(data, columns) {
  const picked = {};
  for (const [k, v] of Object.entries(data || {})) {
    if (columns.has(k)) picked[k] = v;
  }
  return picked;
}

router.post('/:table', async (req, res) => {
  const table = req.params.table;
  if (!ALLOWED_TABLES.has(table)) {
    return res.status(400).json({ error: `Table not allowed: ${table}` });
  }

  const { operation, id, data } = req.body || {};
  if (!operation || typeof id !== 'number') {
    return res.status(400).json({ error: 'Missing operation or id' });
  }

  try {
    if (operation === 'delete') {
      await pool.query(`DELETE FROM ${table} WHERE id = $1`, [id]);
      return res.json({ ok: true });
    }

    if (operation !== 'upsert') {
      return res.status(400).json({ error: `Unsupported operation: ${operation}` });
    }

    const columns = await getTableColumns(table);
    if (!columns.has('id')) {
      return res.status(400).json({ error: `Table has no id column: ${table}` });
    }

    // Ensure id is present.
    const payload = { ...(data || {}), id };

    // Only allow columns that exist in the table.
    const filtered = pickAllowedColumns(payload, columns);
    const keys = Object.keys(filtered);
    if (keys.length === 0) {
      return res.status(400).json({ error: 'No valid columns to upsert' });
    }

    // Build INSERT ... ON CONFLICT (id) DO UPDATE
    const colNames = keys.map((k) => `"${k}"`).join(', ');
    const placeholders = keys.map((_, i) => `$${i + 1}`).join(', ');
    const values = keys.map((k) => filtered[k]);

    const updateAssignments = keys
      .filter((k) => k !== 'id')
      .map((k) => `"${k}" = EXCLUDED."${k}"`)
      .join(', ');

    const sql = `
      INSERT INTO ${table} (${colNames})
      VALUES (${placeholders})
      ON CONFLICT (id)
      DO UPDATE SET ${updateAssignments || '"id" = EXCLUDED."id"'}
      RETURNING *;
    `;

    const result = await pool.query(sql, values);
    return res.status(200).json(result.rows[0]);
  } catch (error) {
    console.error('Sync error:', error);
    // Return helpful diagnostics so the client can show the real reason (FK violation, missing column, etc.)
    // This service is typically used in a trusted environment; adjust if you need stricter security.
    return res.status(500).json({
      error: 'Internal server error',
      detail: error?.message,
      code: error?.code,
      constraint: error?.constraint,
      table: error?.table,
      column: error?.column,
    });
  }
});

// Snapshot: get all rows from a table (used for overwrite-local download).
router.get('/:table', async (req, res) => {
  const table = req.params.table;
  if (!ALLOWED_TABLES.has(table)) {
    return res.status(400).json({ error: `Table not allowed: ${table}` });
  }

  try {
    const result = await pool.query(`SELECT * FROM ${table} ORDER BY id ASC`);
    return res.json(result.rows);
  } catch (error) {
    console.error('Sync snapshot error:', error);
    return res.status(500).json({
      error: 'Internal server error',
      detail: error?.message,
      code: error?.code,
      constraint: error?.constraint,
      table: error?.table,
      column: error?.column,
    });
  }
});

module.exports = router;


