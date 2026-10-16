import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isTruthy, lookup, parseLayerName, parseTable, rowOrder, sampleRows } from '../src/data.ts';
import { bootPlugin, solid } from '../../shared/fake-figma.ts';

const CODE = new URL('../code.js', import.meta.url);

test('CSV with quotes, commas and escaped quotes', () => {
  const t = parseTable('name,quote\n"Shah, Aarav","He said ""hi"""\nMeera,ok\n');
  assert.deepEqual(t.columns, ['name', 'quote']);
  assert.equal(t.rows[0].name, 'Shah, Aarav');
  assert.equal(t.rows[0].quote, 'He said "hi"');
  assert.equal(t.rows.length, 2);
});

test('TSV pasted from Google Sheets and semicolon CSV', () => {
  assert.equal(parseTable('Name\tPrice\nKurta\t₹899').rows[0].Price, '₹899');
  assert.equal(parseTable('a;b\n1;2').rows[0].b, '2');
});

test('JSON lists, wrapped lists and nested objects', () => {
  const t = parseTable('{"users":[{"name":"A","address":{"city":"Pune"}}]}');
  assert.deepEqual(t.columns, ['name', 'address.city']);
  assert.equal(lookup(t.rows[0], 'address.city'), 'Pune');
});

test('column names ignore case, spaces and underscores', () => {
  assert.equal(lookup({ 'First Name': 'Diya' }, 'first_name'), 'Diya');
  assert.equal(lookup({ firstName: 'Diya' }, 'FirstName'), 'Diya');
});

test('layer names', () => {
  assert.deepEqual(parseLayerName('#badge?'), { field: 'badge', toggle: true });
  assert.deepEqual(parseLayerName('#price | big'), { field: 'price', toggle: false });
  assert.equal(parseLayerName('Title'), null);
  assert.equal(parseLayerName('#'), null);
});

test('truthy values', () => {
  for (const v of ['yes', 'true', '1', 'Y', 'Active']) assert.ok(isTruthy(v), v);
  for (const v of ['', 'no', '0', 'false', null, undefined, 'hidden']) assert.ok(!isTruthy(v), String(v));
});

test('sample data and row order', () => {
  const t = sampleRows(5, 1);
  assert.equal(t.rows.length, 5);
  assert.ok(String(t.rows[0].email).endsWith('@example.com'));
  assert.deepEqual(rowOrder(3, 5, 1, false), [1, 2, 0, 1, 2]);
  assert.deepEqual([...rowOrder(4, 4, 0, true, 3)].sort(), [0, 1, 2, 3]);
});

function card(env: any) {
  const name = env.make('TEXT', { name: '#name', characters: 'Name' });
  const price = env.make('TEXT', { name: '#price', characters: '₹0' });
  const photo = env.make('RECTANGLE', { name: '#photo', fills: [solid('#CCCCCC')] });
  const badge = env.make('FRAME', { name: '#verified?' }, [env.make('TEXT', { characters: 'Verified' })]);
  const tag = env.make('INSTANCE', {
    name: 'Tag',
    componentProperties: { 'Label#1:2': { type: 'TEXT', value: 'Tag' }, 'Status': { type: 'VARIANT', value: 'Draft' }, 'Icon#3:4': { type: 'BOOLEAN', value: true } },
  });
  return env.make('FRAME', { name: 'Card', height: 120 }, [photo, name, price, badge, tag]);
}

test('fills one selected card per row and repeats it in auto layout', async () => {
  let list: any;
  const p = bootPlugin(CODE, (env) => {
    const c = card(env);
    list = env.place(env.make('FRAME', { name: 'List', layoutMode: 'VERTICAL' }, [c]));
    env.page.selection = [c];
  });
  await p.send({ type: 'ready' });
  assert.deepEqual([...p.last('selection').fields].sort(), ['Icon', 'Label', 'Status', 'name', 'photo', 'price', 'verified']);

  const csv = 'Name,Price,Photo,Verified,Label,Status,Icon\nKurta,₹899,https://img.test/a.jpg,yes,New,Paid,no\nWatch,₹2499,https://img.test/b.jpg,no,Sale,Shipped,yes\nLamp,₹499,https://broken/c.jpg,1,Hot,Paid,1';
  await p.send({ type: 'data', text: csv });
  assert.equal(p.last('table').total, 3);
  assert.equal(p.last('table').matched.length, 7);

  await p.send({ type: 'apply', options: { repeat: true, shuffle: false, start: 0, gap: 16 } });
  assert.equal(p.last('error'), undefined, p.last('error')?.message);
  const s = p.last('applied').summary;
  assert.equal(list.children.length, 3);
  assert.equal(s.created, 2);
  const [a, b, c] = list.children;
  const field = (n: any, name: string) => n.children.find((x: any) => x.name === name);
  assert.equal(field(a, '#name').characters, 'Kurta');
  assert.equal(field(b, '#price').characters, '₹2499');
  assert.equal(field(a, '#photo').fills[0].imageHash, 'hash:https://img.test/a.jpg');
  assert.equal(field(a, '#verified?').visible, true);
  assert.equal(field(b, '#verified?').visible, false);
  assert.equal(field(a, 'Tag').componentProperties['Label#1:2'].value, 'New');
  assert.equal(field(b, 'Tag').componentProperties['Status'].value, 'Shipped');
  assert.equal(field(a, 'Tag').componentProperties['Icon#3:4'].value, false);
  // The broken image is reported, not fatal.
  assert.equal(field(c, '#name').characters, 'Lamp');
  assert.equal(s.errors.length, 1);
  assert.match(s.errors[0], /could not be loaded/);
});

test('fills several selected items in visual order and reports missing columns', async () => {
  let items: any[] = [];
  const p = bootPlugin(CODE, (env) => {
    const mk = (y: number) => env.place(env.make('FRAME', { name: 'Row', y }, [env.make('TEXT', { name: '#title' }), env.make('TEXT', { name: '#subtitle' })]));
    items = [mk(200), mk(0), mk(100)];
    env.page.selection = items;
  });
  await p.send({ type: 'data', text: '[{"title":"A"},{"title":"B"},{"title":"C"}]' });
  await p.send({ type: 'apply', options: { repeat: true, shuffle: false, start: 0, gap: 0 } });
  const s = p.last('applied').summary;
  assert.equal(s.items, 3);
  assert.equal(s.created, 0);
  assert.deepEqual([...s.missing], ['subtitle']);
  assert.equal(items[1].children[0].characters, 'A'); // top-most first
  assert.equal(items[2].children[0].characters, 'B');
  assert.equal(items[0].children[0].characters, 'C');
});

test('data is remembered between runs', async () => {
  const p = bootPlugin(CODE);
  await p.send({ type: 'sample', count: 4, seed: 2 });
  assert.equal(p.last('table').total, 4);
  assert.ok(typeof p.storage['last-data'] === 'string');
});
