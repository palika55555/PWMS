import { Router } from "express";
import { z } from "zod";

import { pool } from "../../db";

export const router = Router();

router.get("/", async (_req, res) => {
  const result = await pool.query(
    `select id, name, category, fraction, unit, current_stock as "currentStock", min_stock as "minStock", created_at as "createdAt", updated_at as "updatedAt"
     from materials
     order by name asc`,
  );
  res.json({ items: result.rows });
});

const createSchema = z.object({
  name: z.string().min(1),
  category: z
    .enum(["CEMENT", "WATER", "PLASTICIZER", "GRAVEL", "OTHER"])
    .default("OTHER"),
  fraction: z.string().min(1).optional().nullable(),
  unit: z.string().min(1).default("kg"),
  currentStock: z.number().finite().default(0),
  minStock: z.number().finite().default(0),
});

router.post("/", async (req, res) => {
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: "VALIDATION_ERROR", details: parsed.error.format() });
  }

  const m = parsed.data;
  const result = await pool.query(
    `insert into materials (name, category, fraction, unit, current_stock, min_stock)
     values ($1, $2, $3, $4, $5, $6)
     returning id, name, category, fraction, unit, current_stock as "currentStock", min_stock as "minStock", created_at as "createdAt", updated_at as "updatedAt"`,
    [m.name, m.category, m.fraction ?? null, m.unit, m.currentStock, m.minStock],
  );

  return res.status(201).json(result.rows[0]);
});



