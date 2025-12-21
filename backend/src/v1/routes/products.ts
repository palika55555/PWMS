import { Router } from "express";
import { z } from "zod";

import { pool } from "../../db";

export const router = Router();

router.get("/", async (_req, res) => {
  const result = await pool.query(
    `select id, name, description, active, created_at as "createdAt", updated_at as "updatedAt"
     from products
     order by name asc`,
  );
  res.json({ items: result.rows });
});

const createSchema = z.object({
  name: z.string().min(1),
  description: z.string().optional().nullable(),
  active: z.boolean().optional().default(true),
});

router.post("/", async (req, res) => {
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) {
    return res
      .status(400)
      .json({ error: "VALIDATION_ERROR", details: parsed.error.format() });
  }

  const p = parsed.data;
  const result = await pool.query(
    `insert into products (name, description, active)
     values ($1, $2, $3)
     returning id, name, description, active, created_at as "createdAt", updated_at as "updatedAt"`,
    [p.name, p.description ?? null, p.active],
  );

  return res.status(201).json(result.rows[0]);
});


