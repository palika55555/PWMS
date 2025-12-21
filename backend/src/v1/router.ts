import { Router } from "express";

import { router as batchesRouter } from "./routes/batches";
import { router as materialsRouter } from "./routes/materials";
import { router as productsRouter } from "./routes/products";
import { router as recipesRouter } from "./routes/recipes";

export const router = Router();

router.get("/", (_req, res) => {
  res.json({ ok: true, version: "v1" });
});

router.use("/batches", batchesRouter);
router.use("/materials", materialsRouter);
router.use("/products", productsRouter);
router.use("/recipes", recipesRouter);



