/**
 * node-pg-migrate migration (CommonJS).
 * NOTE: We keep this as .js so Railway can run migrations without needing ts-node in production.
 */

exports.up = async (pgm) => {
  // extensions
  pgm.createExtension("pgcrypto", { ifNotExists: true });

  // enums (Postgres)
  pgm.createType(
    "material_category",
    ["CEMENT", "WATER", "PLASTICIZER", "GRAVEL", "OTHER"],
    { ifNotExists: true },
  );
  pgm.createType(
    "batch_status",
    ["DRAFT", "PRODUCED", "QC_PENDING", "APPROVED", "REJECTED"],
    { ifNotExists: true },
  );
  pgm.createType("movement_type", ["IN", "OUT", "ADJUST"], { ifNotExists: true });

  pgm.createTable(
    "materials",
    {
      id: { type: "uuid", primaryKey: true, default: pgm.func("gen_random_uuid()") },
      name: { type: "text", notNull: true },
      category: { type: "material_category", notNull: true, default: "OTHER" },
      fraction: { type: "text", notNull: false },
      unit: { type: "text", notNull: true, default: "kg" },
      current_stock: { type: "numeric", notNull: true, default: 0 },
      min_stock: { type: "numeric", notNull: true, default: 0 },
      created_at: { type: "timestamptz", notNull: true, default: pgm.func("now()") },
      updated_at: { type: "timestamptz", notNull: true, default: pgm.func("now()") },
    },
    { ifNotExists: true },
  );
  pgm.createIndex("materials", ["name"], { ifNotExists: true });

  pgm.createTable(
    "products",
    {
      id: { type: "uuid", primaryKey: true, default: pgm.func("gen_random_uuid()") },
      name: { type: "text", notNull: true },
      description: { type: "text" },
      active: { type: "boolean", notNull: true, default: true },
      created_at: { type: "timestamptz", notNull: true, default: pgm.func("now()") },
      updated_at: { type: "timestamptz", notNull: true, default: pgm.func("now()") },
    },
    { ifNotExists: true },
  );
  pgm.createIndex("products", ["name"], { ifNotExists: true });

  pgm.createTable(
    "recipes",
    {
      id: { type: "uuid", primaryKey: true, default: pgm.func("gen_random_uuid()") },
      name: { type: "text", notNull: true },
      product_id: { type: "uuid", references: "products", onDelete: "set null" },
      created_at: { type: "timestamptz", notNull: true, default: pgm.func("now()") },
      updated_at: { type: "timestamptz", notNull: true, default: pgm.func("now()") },
    },
    { ifNotExists: true },
  );
  pgm.createIndex("recipes", ["name"], { ifNotExists: true });

  pgm.createTable(
    "recipe_items",
    {
      id: { type: "uuid", primaryKey: true, default: pgm.func("gen_random_uuid()") },
      recipe_id: { type: "uuid", notNull: true, references: "recipes", onDelete: "cascade" },
      material_id: { type: "uuid", notNull: true, references: "materials", onDelete: "restrict" },
      amount: { type: "numeric", notNull: true },
      unit: { type: "text", notNull: true, default: "kg" },
    },
    { ifNotExists: true },
  );
  pgm.createIndex("recipe_items", ["recipe_id", "material_id"], {
    unique: true,
    ifNotExists: true,
  });

  pgm.createTable(
    "batches",
    {
      id: { type: "uuid", primaryKey: true, default: pgm.func("gen_random_uuid()") },
      batch_date: { type: "date", notNull: true },
      recipe_id: { type: "uuid", references: "recipes", onDelete: "set null" },
      status: { type: "batch_status", notNull: true, default: "DRAFT" },
      notes: { type: "text" },
      created_at: { type: "timestamptz", notNull: true, default: pgm.func("now()") },
      updated_at: { type: "timestamptz", notNull: true, default: pgm.func("now()") },
    },
    { ifNotExists: true },
  );
  pgm.createIndex("batches", ["batch_date"], { ifNotExists: true });

  pgm.createTable(
    "production_entries",
    {
      id: { type: "uuid", primaryKey: true, default: pgm.func("gen_random_uuid()") },
      batch_id: { type: "uuid", notNull: true, references: "batches", onDelete: "cascade" },
      quantity: { type: "numeric", notNull: true, default: 0 },
      unit: { type: "text", notNull: true, default: "ks" },
      created_at: { type: "timestamptz", notNull: true, default: pgm.func("now()") },
    },
    { ifNotExists: true },
  );
  pgm.createIndex("production_entries", ["batch_id"], { ifNotExists: true });

  pgm.createTable(
    "quality_checks",
    {
      id: { type: "uuid", primaryKey: true, default: pgm.func("gen_random_uuid()") },
      batch_id: { type: "uuid", notNull: true, references: "batches", onDelete: "cascade" },
      approved: { type: "boolean", notNull: true },
      checked_by: { type: "text" },
      notes: { type: "text" },
      created_at: { type: "timestamptz", notNull: true, default: pgm.func("now()") },
    },
    { ifNotExists: true },
  );
  pgm.createIndex("quality_checks", ["batch_id"], { ifNotExists: true });

  pgm.createTable(
    "material_movements",
    {
      id: { type: "uuid", primaryKey: true, default: pgm.func("gen_random_uuid()") },
      material_id: { type: "uuid", notNull: true, references: "materials", onDelete: "cascade" },
      type: { type: "movement_type", notNull: true },
      amount: { type: "numeric", notNull: true },
      unit: { type: "text", notNull: true, default: "kg" },
      note: { type: "text" },
      created_at: { type: "timestamptz", notNull: true, default: pgm.func("now()") },
    },
    { ifNotExists: true },
  );
  pgm.createIndex("material_movements", ["material_id"], { ifNotExists: true });

  // updated_at trigger
  pgm.sql(`
    create or replace function set_updated_at()
    returns trigger as $$
    begin
      new.updated_at = now();
      return new;
    end;
    $$ language plpgsql;
  `);

  for (const t of ["materials", "products", "recipes", "batches"]) {
    pgm.sql(`
      do $$
      begin
        if not exists (
          select 1 from pg_trigger where tgname = '${t}_set_updated_at'
        ) then
          create trigger ${t}_set_updated_at
          before update on ${t}
          for each row execute function set_updated_at();
        end if;
      end $$;
    `);
  }
};

exports.down = async (pgm) => {
  pgm.dropTable("material_movements", { ifExists: true });
  pgm.dropTable("quality_checks", { ifExists: true });
  pgm.dropTable("production_entries", { ifExists: true });
  pgm.dropTable("batches", { ifExists: true });
  pgm.dropTable("recipe_items", { ifExists: true });
  pgm.dropTable("recipes", { ifExists: true });
  pgm.dropTable("products", { ifExists: true });
  pgm.dropTable("materials", { ifExists: true });

  pgm.dropType("movement_type", { ifExists: true });
  pgm.dropType("batch_status", { ifExists: true });
  pgm.dropType("material_category", { ifExists: true });
  pgm.sql(`drop function if exists set_updated_at();`);
};



