import { Router } from "express";
import { z } from "zod";

import { pool } from "../../db";

export const router = Router();

// List batches (môže filtrovať podľa dátumu)
router.get("/", async (req, res) => {
  const dateParam = req.query.date as string | undefined;

  let query = `
    select
      b.id,
      b.batch_date as "batchDate",
      b.recipe_id as "recipeId",
      r.name as "recipeName",
      p.name as "productName",
      b.status,
      b.notes,
      b.created_at as "createdAt",
      b.updated_at as "updatedAt"
    from batches b
    left join recipes r on r.id = b.recipe_id
    left join products p on p.id = r.product_id
  `;
  const params: any[] = [];
  let paramIndex = 1;

  if (dateParam) {
    query += ` where b.batch_date = $${paramIndex}`;
    params.push(dateParam);
    paramIndex++;
  }

  query += ` order by b.batch_date desc, b.created_at desc`;

  const result = await pool.query(query, params);
  res.json({ items: result.rows });
});

// Get batch detail with recipe items and production entries
router.get("/:id", async (req, res) => {
  const id = req.params.id;

  const batchResult = await pool.query(
    `select
      b.id,
      b.batch_date as "batchDate",
      b.recipe_id as "recipeId",
      r.name as "recipeName",
      p.name as "productName",
      b.status,
      b.notes,
      b.created_at as "createdAt",
      b.updated_at as "updatedAt"
    from batches b
    left join recipes r on r.id = b.recipe_id
    left join products p on p.id = r.product_id
    where b.id = $1`,
    [id],
  );

  if (batchResult.rowCount === 0) {
    return res.status(404).json({ error: "NOT_FOUND" });
  }

  const batch = batchResult.rows[0];

  // Recipe items (materiály v receptúre)
  const recipeItemsResult = batch.recipeId
    ? await pool.query(
        `select
          ri.id,
          ri.material_id as "materialId",
          m.name as "materialName",
          m.category as "materialCategory",
          m.fraction as "materialFraction",
          ri.amount,
          ri.unit
        from recipe_items ri
        join materials m on m.id = ri.material_id
        where ri.recipe_id = $1
        order by m.category, m.name asc`,
        [batch.recipeId],
      )
    : { rows: [] };

  // Production entries
  const productionResult = await pool.query(
    `select
      id,
      quantity,
      unit,
      created_at as "createdAt"
    from production_entries
    where batch_id = $1
    order by created_at desc`,
    [id],
  );

  // Quality checks
  const qualityResult = await pool.query(
    `select
      id,
      approved,
      checked_by as "checkedBy",
      notes,
      created_at as "createdAt"
    from quality_checks
    where batch_id = $1
    order by created_at desc`,
    [id],
  );

  return res.json({
    ...batch,
    recipeItems: recipeItemsResult.rows,
    productionEntries: productionResult.rows,
    qualityChecks: qualityResult.rows,
  });
});

const createSchema = z.object({
  batchDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  recipeId: z.string().uuid().optional().nullable(),
  status: z
    .enum(["DRAFT", "PRODUCED", "QC_PENDING", "APPROVED", "REJECTED"])
    .optional()
    .default("DRAFT"),
  notes: z.string().optional().nullable(),
});

router.post("/", async (req, res) => {
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) {
    return res
      .status(400)
      .json({ error: "VALIDATION_ERROR", details: parsed.error.format() });
  }

  const b = parsed.data;
  const result = await pool.query(
    `insert into batches (batch_date, recipe_id, status, notes)
     values ($1, $2, $3, $4)
     returning 
       id, 
       batch_date as "batchDate",
       recipe_id as "recipeId",
       status,
       notes,
       created_at as "createdAt",
       updated_at as "updatedAt"`,
    [b.batchDate, b.recipeId ?? null, b.status, b.notes ?? null],
  );

  return res.status(201).json(result.rows[0]);
});

const updateSchema = z.object({
  batchDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  recipeId: z.string().uuid().optional().nullable(),
  status: z
    .enum(["DRAFT", "PRODUCED", "QC_PENDING", "APPROVED", "REJECTED"])
    .optional(),
  notes: z.string().optional().nullable(),
});

router.patch("/:id", async (req, res) => {
  const id = req.params.id;
  const parsed = updateSchema.safeParse(req.body);
  if (!parsed.success) {
    return res
      .status(400)
      .json({ error: "VALIDATION_ERROR", details: parsed.error.format() });
  }

  const updates = parsed.data;
  const setParts: string[] = [];
  const params: any[] = [];
  let paramIndex = 1;

  if (updates.batchDate !== undefined) {
    setParts.push(`batch_date = $${paramIndex}`);
    params.push(updates.batchDate);
    paramIndex++;
  }
  if (updates.recipeId !== undefined) {
    setParts.push(`recipe_id = $${paramIndex}`);
    params.push(updates.recipeId);
    paramIndex++;
  }
  if (updates.status !== undefined) {
    setParts.push(`status = $${paramIndex}`);
    params.push(updates.status);
    paramIndex++;
  }
  if (updates.notes !== undefined) {
    setParts.push(`notes = $${paramIndex}`);
    params.push(updates.notes);
    paramIndex++;
  }

  if (setParts.length === 0) {
    return res.status(400).json({ error: "NO_UPDATES" });
  }

  params.push(id);
  const result = await pool.query(
    `update batches
     set ${setParts.join(", ")}
     where id = $${paramIndex}
     returning 
       id,
       batch_date as "batchDate",
       recipe_id as "recipeId",
       status,
       notes,
       created_at as "createdAt",
       updated_at as "updatedAt"`,
    params,
  );

  if (result.rowCount === 0) {
    return res.status(404).json({ error: "NOT_FOUND" });
  }

  return res.json(result.rows[0]);
});

router.delete("/:id", async (req, res) => {
  const id = req.params.id;
  const result = await pool.query("delete from batches where id = $1", [id]);
  if (result.rowCount === 0) {
    return res.status(404).json({ error: "NOT_FOUND" });
  }
  return res.status(204).send();
});

// Production entries
const productionEntrySchema = z.object({
  quantity: z.number().positive(),
  unit: z.string().min(1).default("ks"),
});

router.post("/:id/production-entries", async (req, res) => {
  const batchId = req.params.id;
  const parsed = productionEntrySchema.safeParse(req.body);
  if (!parsed.success) {
    return res
      .status(400)
      .json({ error: "VALIDATION_ERROR", details: parsed.error.format() });
  }

  const p = parsed.data;
  const result = await pool.query(
    `insert into production_entries (batch_id, quantity, unit)
     values ($1, $2, $3)
     returning id, quantity, unit, created_at as "createdAt"`,
    [batchId, p.quantity, p.unit],
  );

  return res.status(201).json(result.rows[0]);
});

// Quality checks
const qualityCheckSchema = z.object({
  approved: z.boolean(),
  checkedBy: z.string().min(1).optional().nullable(),
  notes: z.string().optional().nullable(),
});

router.post("/:id/quality-checks", async (req, res) => {
  const batchId = req.params.id;
  const parsed = qualityCheckSchema.safeParse(req.body);
  if (!parsed.success) {
    return res
      .status(400)
      .json({ error: "VALIDATION_ERROR", details: parsed.error.format() });
  }

  const q = parsed.data;
  const result = await pool.query(
    `insert into quality_checks (batch_id, approved, checked_by, notes)
     values ($1, $2, $3, $4)
     returning id, approved, checked_by as "checkedBy", notes, created_at as "createdAt"`,
    [batchId, q.approved, q.checkedBy ?? null, q.notes ?? null],
  );

  // Aktualizuj status šarže podľa výsledku kontroly
  const newStatus = q.approved ? "APPROVED" : "REJECTED";
  await pool.query(`update batches set status = $1 where id = $2`, [
    newStatus,
    batchId,
  ]);

  return res.status(201).json(result.rows[0]);
});


