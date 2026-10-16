import { test } from 'node:test';
import assert from 'node:assert/strict';
import { bootPlugin, hexToRgb, solid } from '../../shared/fake-figma.ts';

const CODE = new URL('../code.js', import.meta.url);
const text = (env: any, props: any) => env.make('TEXT', { x: 10, y: 10, width: 80, height: 20, characters: 'Hello', ...props });
const byText = (results: any[], t: string) => results.find((r) => r.text === t);

test('finds the real background: parent card, sibling button and a translucent overlay', async () => {
  const p = bootPlugin(CODE, (env) => {
    const grey = text(env, { characters: 'Muted', fills: [solid('#9CA3AF')] });
    const dark = text(env, { characters: 'Title', fills: [solid('#111111')] });
    const card = env.make('FRAME', { x: 0, y: 0, width: 200, height: 100, fills: [solid('#F4F4F5')] }, [grey, dark]);
    // White label drawn over a blue rectangle that is its sibling, not its parent.
    const btnBg = env.make('RECTANGLE', { x: 0, y: 120, width: 120, height: 40, fills: [solid('#2563EB')] });
    const label = text(env, { characters: 'Buy', x: 10, y: 130, fills: [solid('#FFFFFF')] });
    // Text on a 50% black scrim over white.
    const scrim = env.make('RECTANGLE', { x: 0, y: 200, width: 200, height: 60, fills: [solid('#000000', 0.5)] });
    const onScrim = text(env, { characters: 'Scrim', x: 10, y: 210, fills: [solid('#FFFFFF')] });
    const screen = env.place(env.make('FRAME', { width: 400, height: 400, fills: [solid('#FFFFFF')] }, [card, btnBg, label, scrim, onScrim]));
    env.page.selection = [screen];
  });
  await p.send({ type: 'scan', options: { scope: 'selection', level: 'AA', modes: {} } });
  const { results } = p.last('results');
  assert.equal(results.length, 4);
  assert.equal(byText(results, 'Muted').bg, '#F4F4F5');
  assert.ok(byText(results, 'Muted').ratio < 4.5);
  assert.ok(byText(results, 'Muted').fix, 'suggests a passing colour');
  assert.ok(byText(results, 'Title').ratio > 15);
  assert.equal(byText(results, 'Buy').bg, '#2563EB');
  assert.equal(byText(results, 'Scrim').bg, '#808080');
  assert.equal(results[0].text, 'Muted', 'worst first');
});

test('large text needs 3:1 at AA and 4.5:1 at AAA', async () => {
  const p = bootPlugin(CODE, (env) => {
    const big = text(env, { characters: 'Big', fontSize: 24, fills: [solid('#888888')] });
    const bold = text(env, { characters: 'Bold', fontSize: 19, fontWeight: 700, fills: [solid('#888888')] });
    const small = text(env, { characters: 'Small', fontSize: 19, fills: [solid('#888888')] });
    env.page.selection = [env.place(env.make('FRAME', { width: 300, height: 300, fills: [solid('#FFFFFF')] }, [big, bold, small]))];
  });
  await p.send({ type: 'scan', options: { scope: 'selection', level: 'AA', modes: {} } });
  let r = p.last('results').results;
  assert.equal(byText(r, 'Big').required, 3);
  assert.equal(byText(r, 'Bold').required, 3);
  assert.equal(byText(r, 'Small').required, 4.5);
  await p.send({ type: 'scan', options: { scope: 'selection', level: 'AAA', modes: {} } });
  r = p.last('results').results;
  assert.equal(byText(r, 'Big').required, 4.5);
  assert.equal(byText(r, 'Small').required, 7);
});

test('checks Dark mode through variables and fixes the variable for that mode only', async () => {
  let ids: any = {};
  const p = bootPlugin(CODE, (env) => {
    const col = env.figma.variables.createVariableCollection('Theme');
    col.renameMode(col.defaultModeId, 'Light');
    const dark = col.addMode('Dark');
    const bg = env.figma.variables.createVariable('background/primary', col, 'COLOR');
    bg.setValueForMode(col.defaultModeId, { ...hexToRgb('#FFFFFF'), a: 1 });
    bg.setValueForMode(dark, { ...hexToRgb('#121212'), a: 1 });
    const fg = env.figma.variables.createVariable('text/secondary', col, 'COLOR');
    fg.setValueForMode(col.defaultModeId, { ...hexToRgb('#555555'), a: 1 });
    fg.setValueForMode(dark, { ...hexToRgb('#444444'), a: 1 }); // forgot to make it light
    const bound = (h: string, v: any) => ({ ...solid(h), boundVariables: { color: { type: 'VARIABLE_ALIAS', id: v.id } } });
    const t = text(env, { characters: 'Caption', fills: [bound('#555555', fg)] });
    const screen = env.place(env.make('FRAME', { width: 300, height: 300, fills: [bound('#FFFFFF', bg)] }, [t]));
    env.page.selection = [screen];
    ids = { col: col.id, dark, light: col.defaultModeId, fg };
  });
  await p.send({ type: 'ready' });
  assert.equal(p.last('init').collections[0].name, 'Theme');

  await p.send({ type: 'scan', options: { scope: 'selection', level: 'AA', modes: {} } });
  assert.ok(p.last('results').results[0].ratio >= 4.5, 'fine in Light');

  await p.send({ type: 'scan', options: { scope: 'selection', level: 'AA', modes: { [ids.col]: ids.dark } } });
  const r = p.last('results').results[0];
  assert.equal(r.bg, '#121212');
  assert.ok(r.ratio < 4.5, 'fails in Dark');
  assert.equal(r.variable.name, 'text/secondary');
  assert.equal(r.variable.modeName, 'Dark');

  await p.send({ type: 'fix', items: [{ variableId: r.variable.id, modeId: r.variable.modeId, fix: r.fix }] });
  const after = p.last('results').results[0];
  assert.ok(after.ratio >= 4.5, `passes after the fix (${after.ratio})`);
  assert.deepEqual({ ...ids.fg.valuesByMode[ids.light] }, { ...hexToRgb('#555555'), a: 1 }, 'Light value untouched');
});

test('fixing a layer makes it pass', async () => {
  let t: any;
  const p = bootPlugin(CODE, (env) => {
    t = text(env, { characters: 'Faint', fills: [solid('#BBBBBB')] });
    env.page.selection = [env.place(env.make('FRAME', { width: 300, height: 300, fills: [solid('#FFFFFF')] }, [t]))];
  });
  await p.send({ type: 'scan', options: { scope: 'selection', level: 'AA', modes: {} } });
  const r = p.last('results').results[0];
  await p.send({ type: 'fix', items: [{ id: r.id, start: r.start, end: r.end, fix: r.fix }] });
  assert.ok(p.last('results').results[0].ratio >= 4.5);
  assert.equal(t.fills.length, 1);
});

test('hidden text and text on images', async () => {
  const p = bootPlugin(CODE, (env) => {
    const hidden = text(env, { characters: 'Hidden', visible: false, fills: [solid('#EEEEEE')] });
    const photo = env.make('RECTANGLE', { x: 0, y: 0, width: 300, height: 100, fills: [{ type: 'IMAGE', visible: true, imageHash: 'x', scaleMode: 'FILL' }] });
    const caption = text(env, { characters: 'Caption', fills: [solid('#FFFFFF')] });
    env.page.selection = [env.place(env.make('FRAME', { width: 300, height: 300, fills: [solid('#FFFFFF')] }, [photo, caption, hidden]))];
  });
  await p.send({ type: 'scan', options: { scope: 'selection', level: 'AA', modes: {} } });
  const r = p.last('results').results;
  assert.equal(r.length, 1);
  assert.equal(r[0].unsure, true);
});
