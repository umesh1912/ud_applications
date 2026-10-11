import { DatabaseSync, type SQLInputValue } from 'node:sqlite';
import fs from 'node:fs';
import path from 'node:path';
import { SCHEMA, type Row, type SqlValue, type Store } from './store.js';

export const DATA_DIR = process.env.DATA_DIR ?? path.resolve(process.cwd(), 'data');
export const UPLOAD_DIR = path.join(DATA_DIR, 'uploads');



export class Db implements Store {
  readonly raw: DatabaseSync;
  constructor(file: string) {
    if (file !== ':memory:') fs.mkdirSync(path.dirname(file), { recursive: true });
    this.raw = new DatabaseSync(file);
    this.raw.exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;');
    this.raw.exec(SCHEMA);
  }
  all<T = Row>(sql: string, ...params: SqlValue[]): T[] {
    return this.raw.prepare(sql).all(...params as SQLInputValue[]) as T[];
  }
  get<T = Row>(sql: string, ...params: SqlValue[]): T | undefined {
    return this.raw.prepare(sql).get(...params as SQLInputValue[]) as T | undefined;
  }
  run(sql: string, ...params: SqlValue[]) {
    const r = this.raw.prepare(sql).run(...params as SQLInputValue[]);
    return { changes: Number(r.changes), id: Number(r.lastInsertRowid) };
  }
  value<T = number>(sql: string, ...params: SqlValue[]): T {
    const row = this.raw.prepare(sql).get(...params as SQLInputValue[]) as Row | undefined;
    return (row ? Object.values(row)[0] : undefined) as T;
  }
  tx<T>(fn: () => T): T {
    this.raw.exec('BEGIN IMMEDIATE');
    try { const r = fn(); this.raw.exec('COMMIT'); return r; }
    catch (e) { this.raw.exec('ROLLBACK'); throw e; }
  }
  setting(key: string): string | undefined {
    return this.get<{ value: string }>('SELECT value FROM settings WHERE key = ?', key)?.value;
  }
}
