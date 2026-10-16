// Runs the built code.js against a small fake of the Figma API:
// scan a screen, create the variables, and check every layer got bound.
// Build first: npm run build && npm test
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const hexToRgb = (h: string) => ({
  r: parseInt(h.slice(1, 3), 16) / 255,
  g: parseInt(h.slice(3, 5), 16) / 255,
  b: parseInt(h.slice(5, 7), 16) / 255,
});
const solid = (h: string) => ({ type: 'SOLID', visible: true, opacity: 1, color: hexToRgb(h) });

function fakeFigma() {
  const mixed = Symbol('mixed');
  const nodes = new Map<string, any>();
  let nextId = 1;
  const make = (type: string, props: any, children: any[] = []) => {
    const n: any = {
      id: `${nextId++}:1`, type, name: type, x: 0, y: 0, width: 100, height: 100,
      fills: [], strokes: [], effects: [], fillStyleId: '', strokeStyleId: '', effectStyleId: '',
      visible: true, children, explicitModes: {} as Record<string, string>, ...props,
    };
    n.setExplicitVariableModeForCollection = (col: any, mode: string) => (n.explicitModes[col.id] = mode);
    n.clone = () => make(type, { ...props, name: n.name }, []);
    if (type !== 'TEXT' && type !== 'RECTANGLE' && type !== 'VECTOR') {
      n.findAll = () => {
        const out: any[] = [];
        const walk = (c: any) => { out.push(c); (c.children || []).forEach(walk); };
        children.forEach(walk);
        return out;
      };
    }
    children.forEach((c) => (c.parent = n));
    nodes.set(n.id, n);
    return n;
  };

  const collections: any[] = [];
  const variables: any[] = [];
  const page: any = { type: 'PAGE', id: '0:1', children: [] as any[], selection: [] as any[] };
  page.setExplicitVariableModeForCollection = () => {};
  const messages: any[] = [];
  const pluginData: Record<string, string> = {};

  const figma: any = {
    mixed,
    currentPage: page,
    root: { setPluginData: (k: string, v: string) => (pluginData[k] = v), getPluginData: (k: string) => pluginData[k] ?? '' },
    showUI() {},
    notify() {},
    on() {},
    ui: { postMessage: (m: any) => messages.push(m), onmessage: null as any, resize() {} },
    viewport: { scrollAndZoomIntoView() {} },
    getNodeByIdAsync: async (id: string) => nodes.get(id) ?? null,
    loadFontAsync: async () => {},
    variables: {
      getLocalVariableCollectionsAsync: async () => collections,
      getLocalVariablesAsync: async () => variables,
      getVariableCollectionByIdAsync: async (id: string) => collections.find((c) => c.id === id) ?? null,
      getVariableByIdAsync: async (id: string) => variables.find((v) => v.id === id) ?? null,
      createVariableCollection(name: string) {
        const col: any = { id: `col${collections.length}`, name, modes: [{ modeId: 'm0', name: 'Mode 1' }], defaultModeId: 'm0' };
        col.renameMode = (id: string, nm: string) => (col.modes.find((m: any) => m.modeId === id).name = nm);
        col.addMode = (nm: string) => {
          const modeId = `m${col.modes.length}`;
          col.modes.push({ modeId, name: nm });
          return modeId;
        };
        collections.push(col);
        return col;
      },
      createVariable(name: string, col: any, type: string) {
        assert.equal(typeof col, 'object', 'must pass the collection object');
        const v: any = { id: `var${variables.length}`, name, variableCollectionId: col.id, resolvedType: type, valuesByMode: {}, scopes: ['ALL_SCOPES'] };
        v.setValueForMode = (m: string, val: any) => (v.valuesByMode[m] = val);
        variables.push(v);
        return v;
      },
      setBoundVariableForPaint: (p: any, _f: string, v: any) => ({ ...p, boundVariables: { color: { type: 'VARIABLE_ALIAS', id: v.id } } }),
      setBoundVariableForEffect: (e: any, _f: string, v: any) => ({ ...e, boundVariables: { color: { type: 'VARIABLE_ALIAS', id: v.id } } }),
    },
  };

  // A small light-theme screen.
  const title = make('TEXT', { fills: [solid('#111111')] });
  const body = make('TEXT', { fills: [solid('#666666')] });
  const btnLabel = make('TEXT', { fills: [solid('#FFFFFF')] });
  const button = make('FRAME', { fills: [solid('#2563EB')] }, [btnLabel]);
  const icon = make('VECTOR', { fills: [], strokes: [solid('#111111')] });
  const card = make('FRAME', {
    fills: [solid('#F4F4F5')],
    strokes: [solid('#E4E4E7')],
    effects: [{ type: 'DROP_SHADOW', visible: true, color: { r: 0, g: 0, b: 0, a: 0.1 } }],
  }, [title, body, icon, button]);
  const styled = make('RECTANGLE', { fills: [solid('#FF0000')], fillStyleId: 'S:abc', width: 200, height: 200 });
  const screen = make('FRAME', { fills: [solid('#FFFFFF')], name: 'Home' }, [card, styled]);
  screen.parent = page;
  page.children.push(screen);
  page.selection = [screen];

  return { figma, messages, variables, collections, nodes: { screen, card, title, body, btnLabel, button, icon, styled } };
}

async function boot() {
  const env = fakeFigma();
  const code = readFileSync(new URL('../code.js', import.meta.url), 'utf8');
  runInNewContext(code, { figma: env.figma, __html__: '', console });
  const send = async (msg: any) => {
    await env.figma.ui.onmessage(msg);
  };
  return { ...env, send };
}

test('scan finds each colour per role and skips paint styles', async () => {
  const { send, messages } = await boot();
  await send({ type: 'scan', scope: 'selection', includeStyles: false });
  const res = messages.find((m) => m.type === 'scan-result');
  const names = Object.fromEntries(res.rows.map((r: any) => [r.key, r.name]));
  assert.equal(names['background|#FFFFFF'], 'background/primary');
  assert.equal(names['background|#2563EB'], 'background/blue');
  assert.equal(names['text|#FFFFFF'], 'text/on-color');
  assert.ok(names['text|#111111'].startsWith('text/'));
  assert.equal(names['icon|#111111'], 'icon/primary');
  assert.equal(names['border|#E4E4E7'], 'border/primary');
  assert.equal(names['shadow|#0000001A'], 'shadow/primary');
  assert.equal(res.stats.styled, 1);
  assert.equal(res.rows.length, 9);
  assert.equal(names['background|#F4F4F5'], 'background/secondary');
});

test('apply creates Light/Dark variables and binds every layer', async () => {
  const { send, messages, variables, collections, nodes } = await boot();
  await send({ type: 'scan', scope: 'selection', includeStyles: false });
  const res = messages.find((m) => m.type === 'scan-result');
  await send({
    type: 'apply',
    settings: {
      collectionId: '', collectionName: 'Theme', lightName: 'Light', darkName: 'Dark',
      rows: res.rows.map((r: any) => ({ key: r.key, name: r.name, darkHex: r.darkHex, enabled: true, link: false })),
    },
  });
  const err = messages.find((m) => m.type === 'error');
  assert.equal(err, undefined, err?.message);
  assert.equal(collections.length, 1);
  assert.deepEqual(collections[0].modes.map((m: any) => m.name), ['Light', 'Dark']);
  assert.equal(variables.length, 9);

  const bound = (p: any) => p.boundVariables?.color?.id;
  const byId = (id: string) => variables.find((v) => v.id === id);
  assert.equal(byId(bound(nodes.screen.fills[0])).name, 'background/primary');
  assert.equal(byId(bound(nodes.btnLabel.fills[0])).name, 'text/on-color');
  assert.ok(bound(nodes.card.strokes[0]));
  assert.ok(bound(nodes.card.effects[0]));
  assert.ok(bound(nodes.icon.strokes[0]));
  assert.equal(bound(nodes.styled.fills[0]), undefined, 'styled layer left alone');

  const page = byId(bound(nodes.screen.fills[0]));
  assert.notDeepEqual(page.valuesByMode.m0, page.valuesByMode.m1);
  const onColor = byId(bound(nodes.btnLabel.fills[0]));
  assert.equal(onColor.valuesByMode.m1.r, 1, 'white text on button stays white');
  assert.deepEqual([...byId(bound(nodes.title.fills[0])).scopes], ['TEXT_FILL']);

  // Dark mode switch and a dark copy.
  await send({ type: 'set-mode', mode: 'Dark' });
  assert.equal(nodes.screen.explicitModes[collections[0].id], 'm1');
  await send({ type: 'export' });
  const exp = messages.find((m) => m.type === 'export-data');
  const tokens = JSON.parse(exp.json);
  assert.equal(tokens.Light.background.primary.$value, '#FFFFFF');
  assert.ok(tokens.Dark.background.primary.$value !== '#FFFFFF');
});

test('rescan after apply finds nothing left to convert', async () => {
  const { send, messages } = await boot();
  await send({ type: 'scan', scope: 'selection', includeStyles: true });
  const res = messages.find((m) => m.type === 'scan-result');
  await send({
    type: 'apply',
    settings: {
      collectionId: '', collectionName: 'Theme', lightName: 'Light', darkName: 'Dark',
      rows: res.rows.map((r: any) => ({ key: r.key, name: r.name, darkHex: r.darkHex, enabled: true, link: false })),
    },
  });
  messages.length = 0;
  await send({ type: 'scan', scope: 'selection', includeStyles: true });
  const again = messages.find((m) => m.type === 'scan-result');
  assert.equal(again.rows.length, 0);
  assert.equal(again.stats.alreadyBound, 10);
});

test('a colour that already has a variable is reused', async () => {
  const { send, messages, figma, variables } = await boot();
  const col = figma.variables.createVariableCollection('Brand');
  const brand = figma.variables.createVariable('brand/primary', col, 'COLOR');
  brand.setValueForMode('m0', { ...hexToRgb('#2563EB'), a: 1 });
  await send({ type: 'scan', scope: 'selection', includeStyles: false });
  const res = messages.find((m) => m.type === 'scan-result');
  const row = res.rows.find((r: any) => r.key === 'background|#2563EB');
  assert.equal(row.existing.name, 'brand/primary');
  await send({
    type: 'apply',
    settings: {
      collectionId: col.id, collectionName: '', lightName: 'Mode 1', darkName: 'Dark',
      rows: res.rows.map((r: any) => ({ key: r.key, name: r.name, darkHex: r.darkHex, enabled: true, link: !!r.existing })),
    },
  });
  assert.equal(variables.filter((v) => v.name === 'background/blue').length, 0);
  assert.ok(brand.valuesByMode.m1, 'dark value filled in for the reused variable');
});
