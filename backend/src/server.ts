import "dotenv/config";

import cors from "cors";
import express from "express";

import { router as apiRouter } from "./v1/router";

const app = express();

app.use(cors());
app.use(express.json({ limit: "2mb" }));

app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "problock-backend" });
});

app.use("/v1", apiRouter);

const port = Number(process.env.PORT ?? 3000);
app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`API listening on :${port}`);
});



