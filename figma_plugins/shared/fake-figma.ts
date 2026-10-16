// A small in-memory stand-in for the Figma plugin API, enough to run a built code.js
// in Node tests. Only what the plugins use is implemented.
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

export const hexToRgb = (h: string) => ({
  r: parseInt(h.slice(1, 3), 16) / 255,
  g: parseInt(h.slice(3, 5), 16) / 255,
  b: parseInt(h.slice(5, 7), 16) / 255,
});
export const solid = (h: string, opacity = 1) => ({ type: 'SOLID', visible: true, opacity, color: hexToRgb(h) });

export function createFakeFigma() {
  const mixed = Symbol('mixed');
  const byId = new Map<string, any>();
  const loadedFonts = new Set<string>();
  const fontKey = (f: any) => `${f.family}|${f.style}`;
  const collections: any[] = [];
  const variables: any[] = [];
  const messages: any[] = [];
  const notes: string[] = [];
  const storage: Record<string, unknown> = {};
  let nextId = 1;

  const page: any = {
    type: 'PAGE', id: '0:1', name: 'Page', children: [] as any[], selection: [] as any[], parent: null,
    backgrounds: [solid('#FFFFFF')], explicitModes: {},
  };
  page.setExplicitVariableModeForCollection = (c: any, m: string) => (page.explicitModes[c.id] = m);

  function attach(parent: any, child: any, index = parent.children.length) {
    if (child.parent) child.parent.children.splice(child.parent.children.indexOf(child), 1);
    parent.children.splice(index, 0, child);
    child.parent = parent;
  }

  function make(type: string, props: any = {}, children: any[] = []): any {
    const n: any = {
      id: `${nextId++}:1`, type, name: props.name ?? type, x: 0, y: 0, width: 100, height: 100,
      visible: true, opacity: 1, fills: [], strokes: [], effects: [],
      fillStyleId: '', strokeStyleId: '', effectStyleId: '', boundVariables: {},
      explicitModes: {}, resolvedVariableModes: {}, children: [], parent: null,
      ...props,
    };
    Object.defineProperty(n, 'absoluteBoundingBox', {
      get() {
        let x = n.x, y = n.y, p = n.parent;
        while (p && p.type !== 'PAGE') { x += p.x; y += p.y; p = p.parent; }
        return { x, y, width: n.width, height: n.height };
      },
    });
    n.setExplicitVariableModeForCollection = (c: any, m: string) => (n.explicitModes[c.id] = m);
    n.setBoundVariable = (field: string, v: any) => {
      n.boundVariables = { ...n.boundVariables, [field]: { type: 'VARIABLE_ALIAS', id: v.id } };
      const col = collections.find((c) => c.id === v.variableCollectionId);
      n[field] = v.valuesByMode[col.defaultModeId];
    };
    n.remove = () => { if (n.parent) n.parent.children.splice(n.parent.children.indexOf(n), 1); n.parent = null; };
    if (type !== 'TEXT' && type !== 'RECTANGLE' && type !== 'VECTOR' && type !== 'ELLIPSE') {
      n.findAll = (cb?: (x: any) => boolean) => {
        const out: any[] = [];
        const walk = (c: any) => { if (!cb || cb(c)) out.push(c); (c.children || []).forEach(walk); };
        n.children.forEach(walk);
        return out;
      };
      n.insertChild = (i: number, c: any) => attach(n, c, i);
      n.appendChild = (c: any) => attach(n, c);
    }
    // Deep copy; like Figma, the copy goes right after the original in the same parent.
    n._copy = () => {
      const { id, parent, children: kids, ...rest } = n;
      const data = JSON.parse(JSON.stringify(rest));
      if (type === 'TEXT') data.characters = n.characters;
      return make(type, data, [...kids].map((k: any) => k._copy()));
    };
    n.clone = () => {
      const copy = n._copy();
      if (n.parent) attach(n.parent, copy, n.parent.children.indexOf(n) + 1);
      return copy;
    };
    if (type === 'TEXT') {
      let chars = props.characters ?? 'Text';
      Object.defineProperty(n, 'characters', {
        get: () => chars,
        set: (v: string) => {
          if (!loadedFonts.has(fontKey(n.fontName))) throw new Error(`font not loaded: ${fontKey(n.fontName)}`);
          chars = v;
        },
      });
      n.fontName ??= { family: 'Inter', style: 'Regular' };
      n.fontSize ??= 14;
      n.fontWeight ??= 400;
      n.hasMissingFont ??= false;
      n.getRangeAllFontNames = () => [n.fontName];
      n.getStyledTextSegments = (fields: string[]) => {
        const seg: any = { start: 0, end: chars.length, characters: chars };
        for (const f of fields) seg[f] = n[f];
        return [seg];
      };
      n.getRangeFills = () => n.fills;
      n.setRangeFills = (_s: number, _e: number, v: any) => (n.fills = v);
    }
    if (type === 'INSTANCE') {
      n.componentProperties ??= {};
      n.setProperties = (p: Record<string, unknown>) => {
        for (const [k, v] of Object.entries(p)) {
          if (!(k in n.componentProperties)) throw new Error(`no property ${k}`);
          n.componentProperties[k].value = v;
        }
      };
    }
    children.forEach((c) => attach(n, c));
    byId.set(n.id, n);
    return n;
  }

  function createVariableCollection(name: string) {
    const col: any = { id: `col${collections.length}`, name, modes: [{ modeId: `c${collections.length}m0`, name: 'Mode 1' }] };
    col.defaultModeId = col.modes[0].modeId;
    col.renameMode = (id: string, nm: string) => (col.modes.find((m: any) => m.modeId === id).name = nm);
    col.addMode = (nm: string) => {
      const modeId = `${col.id}m${col.modes.length}`;
      col.modes.push({ modeId, name: nm });
      for (const v of variables.filter((x) => x.variableCollectionId === col.id)) v.valuesByMode[modeId] = v.valuesByMode[col.defaultModeId];
      return modeId;
    };
    collections.push(col);
    return col;
  }

  function createVariable(name: string, col: any, type: string) {
    if (typeof col !== 'object') throw new Error('pass the collection object');
    const v: any = { id: `VariableID:${variables.length}`, name, variableCollectionId: col.id, resolvedType: type, valuesByMode: {}, scopes: ['ALL_SCOPES'] };
    v.setValueForMode = (m: string, val: any) => (v.valuesByMode[m] = val);
    variables.push(v);
    return v;
  }

  const figma: any = {
    mixed,
    currentPage: page,
    root: { _d: {} as Record<string, string>, setPluginData(k: string, v: string) { this._d[k] = v; }, getPluginData(k: string) { return this._d[k] ?? ''; } },
    showUI() {},
    notify: (m: string) => notes.push(m),
    on() {},
    ui: { postMessage: (m: any) => messages.push(m), onmessage: null as any, resize() {} },
    viewport: { scrollAndZoomIntoView() {} },
    clientStorage: {
      getAsync: async (k: string) => storage[k],
      setAsync: async (k: string, v: unknown) => void (storage[k] = v),
    },
    getNodeByIdAsync: async (id: string) => byId.get(id) ?? null,
    loadFontAsync: async (f: any) => void loadedFonts.add(fontKey(f)),
    createImageAsync: async (url: string) => {
      if (url.includes('broken')) throw new Error('Image could not be loaded');
      return { hash: `hash:${url}` };
    },
    variables: {
      getLocalVariableCollectionsAsync: async () => collections,
      getLocalVariablesAsync: async (type?: string) => variables.filter((v) => !type || v.resolvedType === type),
      getVariableCollectionByIdAsync: async (id: string) => collections.find((c) => c.id === id) ?? null,
      getVariableByIdAsync: async (id: string) => variables.find((v) => v.id === id) ?? null,
      createVariableCollection,
      createVariable,
      setBoundVariableForPaint: (p: any, _f: string, v: any) => ({ ...p, boundVariables: { color: { type: 'VARIABLE_ALIAS', id: v.id } } }),
      setBoundVariableForEffect: (e: any, _f: string, v: any) => ({ ...e, boundVariables: { color: { type: 'VARIABLE_ALIAS', id: v.id } } }),
    },
  };

  // Puts a top-level layer on the page.
  const place = (n: any) => { attach(page, n); return n; };

  return { figma, make, place, page, messages, notes, variables, collections, storage };
}

// Loads a built plugin into a fake Figma and returns a helper to send it UI messages.
export function bootPlugin(codeJsUrl: URL, setup: (env: ReturnType<typeof createFakeFigma>) => void = () => {}) {
  const env = createFakeFigma();
  setup(env);
  runInNewContext(readFileSync(codeJsUrl, 'utf8'), { figma: env.figma, __html__: '', console, setTimeout });
  const send = async (msg: any) => {
    await env.figma.ui.onmessage(msg);
  };
  const last = (type: string) => [...env.messages].reverse().find((m) => m.type === type);
  return { ...env, send, last };
}
