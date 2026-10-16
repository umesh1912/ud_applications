import { test } from 'node:test';
import assert from 'node:assert/strict';
import { FULL, RADIUS_SCALE, SPACING_SCALES, isPill, snap, tokenNames } from '../src/scale.ts';
import { bootPlugin } from '../../shared/fake-figma.ts';

const CODE = new URL('../code.js', import.meta.url);

test('snapping onto the 4 and 8 point scales', () => {
  assert.equal(snap(13, SPACING_SCALES[4]), 12);
  assert.equal(snap(14, SPACING_SCALES[4]), 16); // tie goes up
  assert.equal(snap(13, SPACING_SCALES[8]), 16);
  assert.equal(snap(1, SPACING_SCALES[4]), 2);
  assert.equal(snap(200, SPACING_SCALES[4]), 200, 'big values are kept');
  assert.equal(snap(7, RADIUS_SCALE), 8);
});

test('pills', () => {
  assert.ok(isPill(20, 120, 40));
  assert.ok(!isPill(8, 120, 40));
});

test('token names', () => {
  const n = tokenNames('spacing', [4, 8, 16, 24, 32], 'tshirt');
  assert.deepEqual([...n.values()], ['spacing/xs', 'spacing/sm', 'spacing/md', 'spacing/lg', 'spacing/xl']);
  const r = tokenNames('radius', [4, 8, FULL], 'number');
  assert.equal(r.get(8), 'radius/8');
  assert.equal(r.get(FULL), 'radius/full');
});

function screen(env: any) {
  const card = env.make('FRAME', {
    name: 'Card', layoutMode: 'VERTICAL', primaryAxisAlignItems: 'MIN', layoutWrap: 'NO_WRAP',
    paddingTop: 16, paddingRight: 15, paddingBottom: 16, paddingLeft: 17, itemSpacing: 8, counterAxisSpacing: null,
    topLeftRadius: 12, topRightRadius: 12, bottomLeftRadius: 12, bottomRightRadius: 12, width: 300, height: 200,
  });
  const pill = env.make('RECTANGLE', { name: 'Pill', topLeftRadius: 20, topRightRadius: 20, bottomLeftRadius: 20, bottomRightRadius: 20, width: 100, height: 40 });
  const toolbar = env.make('FRAME', {
    name: 'Toolbar', layoutMode: 'HORIZONTAL', primaryAxisAlignItems: 'SPACE_BETWEEN', layoutWrap: 'NO_WRAP',
    paddingTop: 0, paddingRight: 24, paddingBottom: 0, paddingLeft: 24, itemSpacing: 37, counterAxisSpacing: null,
    topLeftRadius: 0, topRightRadius: 0, bottomLeftRadius: 0, bottomRightRadius: 0,
  });
  const inst = env.make('INSTANCE', { name: 'Button', layoutMode: 'HORIZONTAL', paddingTop: 10, paddingRight: 10, paddingBottom: 10, paddingLeft: 10, itemSpacing: 4, topLeftRadius: 6 });
  return env.place(env.make('FRAME', { name: 'Screen' }, [card, pill, toolbar, inst]));
}

test('scans, snaps, creates FLOAT variables and binds them', async () => {
  let s: any;
  const p = bootPlugin(CODE, (env) => {
    s = screen(env);
    env.page.selection = [s];
  });
  await p.send({ type: 'scan', options: { scope: 'selection', base: 4, naming: 'number', snap: true } });
  const res = p.last('scan-result');
  const keys = res.rows.map((r: any) => r.key);
  assert.deepEqual([...keys], ['spacing|8', 'spacing|16', 'spacing|24', 'radius|12', `radius|${FULL}`]);
  const sixteen = res.rows.find((r: any) => r.key === 'spacing|16');
  assert.equal(sixteen.count, 4); // 16, 15, 16, 17
  assert.equal(res.stats.snapped, 2);
  assert.ok(!keys.includes('spacing|37'), 'space-between gap skipped');
  assert.ok(!keys.includes('spacing|10'), 'instances skipped');

  await p.send({ type: 'apply', settings: { collectionId: '', collectionName: 'Spacing', rows: res.rows.map((r: any) => ({ key: r.key, name: r.name, value: r.value, enabled: true, link: false })) } });
  assert.equal(p.last('error'), undefined, p.last('error')?.message);
  const sum = p.last('applied').summary;
  assert.equal(sum.created, 5);
  assert.equal(sum.bound, 4 + 1 + 2 + 4 + 4);
  const card = s.children[0];
  const v = p.variables.find((x: any) => x.id === card.boundVariables.paddingRight.id);
  assert.equal(v.name, 'spacing/16');
  assert.equal(v.resolvedType, 'FLOAT');
  assert.deepEqual([...v.scopes], ['GAP']);
  assert.equal(card.paddingRight, 16, 'snapped value applied');
  const pill = p.variables.find((x: any) => x.id === s.children[1].boundVariables.topLeftRadius.id);
  assert.equal(pill.name, 'radius/full');

  // Nothing left the second time.
  await p.send({ type: 'scan', options: { scope: 'selection', base: 4, naming: 'number', snap: true } });
  assert.equal(p.last('scan-result').rows.length, 0);
  assert.equal(p.last('scan-result').stats.alreadyBound, 15);
});

test('without snapping each value keeps its own token; existing variables are reused', async () => {
  const p = bootPlugin(CODE, (env) => {
    const col = env.figma.variables.createVariableCollection('Tokens');
    const v = env.figma.variables.createVariable('space/medium', col, 'FLOAT');
    v.setValueForMode(col.defaultModeId, 16);
    v.scopes = ['GAP'];
    env.page.selection = [screen(env)];
  });
  await p.send({ type: 'scan', options: { scope: 'selection', base: 4, naming: 'tshirt', snap: false } });
  const rows = p.last('scan-result').rows;
  assert.ok(rows.some((r: any) => r.key === 'spacing|15'));
  assert.equal(rows.find((r: any) => r.key === 'spacing|16').existing.name, 'space/medium');
  assert.equal(rows.find((r: any) => r.key === 'spacing|16').name, 'spacing/md');
});
