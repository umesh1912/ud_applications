import fs from 'node:fs';
import path from 'node:path';
import { DATA_DIR, Db } from './db.js';
import { seedDemo } from './seed.js';

// `npm run seed -- --reset` wipes the database first, then adds the demo society.
const file = process.env.DB_FILE ?? path.join(DATA_DIR, 'society.db');
if (process.argv.includes('--reset')) for (const f of [file, file + '-wal', file + '-shm']) fs.rmSync(f, { force: true });
console.log(seedDemo(new Db(file)) ? `Seeded the demo society into ${file}` : `${file} already has societies (use --reset to start over)`);
