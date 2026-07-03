import { promises as fs } from "fs";
import path from "path";
import { Db, DbSchema, EMPTY_DB } from "./schemas";

const DB_PATH = path.join(process.cwd(), "data", "db.json");

// Simple in-process write queue so concurrent API calls don't clobber each other.
let queue: Promise<unknown> = Promise.resolve();
function serialize<T>(fn: () => Promise<T>): Promise<T> {
  const result = queue.then(fn, fn);
  queue = result.catch(() => {});
  return result;
}

async function ensureDbFile(): Promise<void> {
  await fs.mkdir(path.dirname(DB_PATH), { recursive: true });
  try {
    await fs.access(DB_PATH);
  } catch {
    await fs.writeFile(DB_PATH, JSON.stringify(EMPTY_DB, null, 2));
  }
}

export async function readDb(): Promise<Db> {
  await ensureDbFile();
  const raw = await fs.readFile(DB_PATH, "utf-8");
  return DbSchema.parse(JSON.parse(raw));
}

async function writeDb(db: Db): Promise<void> {
  const validated = DbSchema.parse(db);
  await fs.writeFile(DB_PATH, JSON.stringify(validated, null, 2));
}

export function mutateDb<T>(fn: (db: Db) => T): Promise<T> {
  return serialize(async () => {
    const db = await readDb();
    const result = fn(db);
    await writeDb(db);
    return result;
  });
}
