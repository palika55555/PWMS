import { Router } from "express";
import { z } from "zod";

import { pool } from "../../db";

export const router = Router();

router.get("/", async (_req, res) => {
  const result = await pool.query(
    `select
        r.id,
        r.name,
        r.product_id as "productId",
        p.name as "productName",
        r.created_at as "createdAt",
        r.updated_at as "updatedAt"
     from recipes r
     left join products p on p.id = r.product_id
     order by r.name asc`,
  );
  res.json({ items: result.rows });
});

router.get("/:id", async (req, res) => {
  const id = req.params.id;

  const recipeResult = await pool.query(
    `select
        r.id,
        r.name,
        r.product_id as "productId",
        p.name as "productName",
        r.created_at as "createdAt",
        r.updated_at as "updatedAt"
     from recipes r
     left join products p on p.id = r.product_id
     where r.id = $1`,
    [id],
  );
  if (recipeResult.rowCount === 0) {
    return res.status(404).json({ error: "NOT_FOUND" });
  }

  const itemsResult = await pool.query(
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
     order by m.name asc`,
    [id],
  );

  return res.json({ ...recipeResult.rows[0], items: itemsResult.rows });
});

const createSchema = z.object({
  name: z.string().min(1),
  productId: z.string().uuid().optional().nullable(),
});

router.post("/", async (req, res) => {
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) {
    return res
      .status(400)
      .json({ error: "VALIDATION_ERROR", details: parsed.error.format() });
  }

  const r = parsed.data;
  const result = await pool.query(
    `insert into recipes (name, product_id)
     values ($1, $2)
     returning id, name, product_id as "productId", created_at as "createdAt", updated_at as "updatedAt"`,
    [r.name, r.productId ?? null],
  );

  return res.status(201).json(result.rows[0]);
});

// Recipe items (pridanie materiálov do receptúry)
const recipeItemSchema = z.object({
  materialId: z.string().uuid(),
  amount: z.number().positive(),
  unit: z.string().min(1).default("kg"),
});

router.post("/:recipeId/items", async (req, res) => {
  const recipeId = req.params.recipeId;
  const parsed = recipeItemSchema.safeParse(req.body);
  if (!parsed.success) {
    return res
      .status(400)
      .json({ error: "VALIDATION_ERROR", details: parsed.error.format() });
  }

  const item = parsed.data;
  const result = await pool.query(
    `insert into recipe_items (recipe_id, material_id, amount, unit)
     values ($1, $2, $3, $4)
     on conflict (recipe_id, material_id) do update
     set amount = excluded.amount, unit = excluded.unit
     returning 
       id,
       material_id as "materialId",
       amount,
       unit`,
    [recipeId, item.materialId, item.amount, item.unit],
  );

  return res.status(201).json(result.rows[0]);
});

router.delete("/:recipeId/items/:itemId", async (req, res) => {
  const itemId = req.params.itemId;
  const result = await pool.query("delete from recipe_items where id = $1", [
    itemId,
  ]);
  if (result.rowCount === 0) {
    return res.status(404).json({ error: "NOT_FOUND" });
  }
  return res.status(204).send();
});


