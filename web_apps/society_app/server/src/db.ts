import { DatabaseSync, type SQLInputValue } from 'node:sqlite';
import fs from 'node:fs';
import path from 'node:path';
import { prepareSchema, type Row, type SqlValue, type Store } from './store.js';

export const DATA_DIR = process.env.DATA_DIR ?? path.resolve(process.cwd(), 'data');
export const UPLOAD_DIR = path.join(DATA_DIR, 'uploads');
export class Db implements Store {
  readonly raw: DatabaseSync;
  constructor(file: string) {
    if (file !== ':memory:') fs.mkdirSync(path.dirname(file), { recursive: true });
    this.raw = new DatabaseSync(file);
    this.raw.exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;');
    prepareSchema(this);
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
  private depth = 0;
  /** Runs fn atomically; nested calls become savepoints inside the outer transaction. */
  tx<T>(fn: () => T): T {
    const sp = `sp${this.depth}`;
    this.raw.exec(this.depth ? `SAVEPOINT ${sp}` : 'BEGIN IMMEDIATE');
    this.depth++;
    try {
      const r = fn();
      this.depth--;
      this.raw.exec(this.depth ? `RELEASE ${sp}` : 'COMMIT');
      return r;
    } catch (e) {
      this.depth--;
      this.raw.exec(this.depth ? `ROLLBACK TO ${sp}; RELEASE ${sp}` : 'ROLLBACK');
      throw e;
    }
  }}
