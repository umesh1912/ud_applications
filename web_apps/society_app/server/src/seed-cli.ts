import fs from 'node:fs';
import path from 'node:path';
import { DATA_DIR, Db } from './db.js';
import { seed } from './seed.js';

// `npm run seed -- --reset` wipes the database first.
const file = process.env.DB_FILE ?? path.join(DATA_DIR, 'society.db');
if (process.argv.includes('--reset')) for (const f of [file, file + '-wal', file + '-shm']) fs.rmSync(f, { force: true });
console.log(seed(new Db(file)) ? `Seeded ${file}` : `${file} already has data (use --reset to start over)`);
