import { Router } from "express";

import { router as materialsRouter } from "./routes/materials";

export const router = Router();

router.get("/", (_req, res) => {
  res.json({ ok: true, version: "v1" });
});

router.use("/materials", materialsRouter);



