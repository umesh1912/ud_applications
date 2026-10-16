// Spacing Tokens — main thread.
// Collects auto-layout padding and gaps and corner radii, snaps them onto a 4 or 8 point
// scale, creates number variables (spacing/16, radius/8 or spacing/md …) and binds them.

import { FULL, Kind, Naming, RADIUS_SCALE, SPACING_SCALES, isPill, snap, tokenNames } from './scale';

type Field =
  | 'paddingTop'
  | 'paddingRight'
  | 'paddingBottom'
  | 'paddingLeft'
  | 'itemSpacing'
  | 'counterAxisSpacing'
  | 'topLeftRadius'
  | 'topRightRadius'
  | 'bottomLeftRadius'
  | 'bottomRightRadius';

interface Usage {
  nodeId: string;
  field: Field;
}

interface Token {
  key: string;
  kind: Kind;
  value: number;
  name: string;
  from: Map<number, number>; // original value -> count
  usages: Usage[];
  existing?: { id: string; name: string };
}

interface ScanOptions {
  scope: 'selection' | 'page';
  base: 4 | 8;
  naming: Naming;
  snap: boolean;
}

const PADDING: Field[] = ['paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft'];
const CORNERS: Field[] = ['topLeftRadius', 'topRightRadius', 'bottomLeftRadius', 'bottomRightRadius'];
const SCOPES: Record<Kind, VariableScope[]> = { spacing: ['GAP'], radius: ['CORNER_RADIUS'] };

let tokens = new Map<string, Token>();

figma.showUI(__html__, { width: 420, height: 620, themeColors: true });
const post = (msg: unknown) => figma.ui.postMessage(msg);

// ---------- Scanning ----------

function nodesIn(scope: 'selection' | 'page'): SceneNode[] {
  const roots = scope === 'selection' ? figma.currentPage.selection : figma.currentPage.children;
  const out: SceneNode[] = [];
  for (const r of roots) {
    out.push(r);
    if ('findAll' in r) out.push(...r.findAll());
  }
  return out;
}

const bound = (node: SceneNode, field: Field) => {
  const b = (node as SceneNode & { boundVariables?: Record<string, unknown> }).boundVariables;
  return !!(b && b[field]);
};

async function scan(o: ScanOptions) {
  const found = new Map<string, Token>();
  const stats = { layers: 0, alreadyBound: 0, snapped: 0 };

  const add = (kind: Kind, raw: number, node: SceneNode, field: Field, target?: number) => {
    const value = target ?? (o.snap ? snap(raw, kind === 'spacing' ? SPACING_SCALES[o.base] : RADIUS_SCALE) : Math.round(raw * 100) / 100);
    if (target === undefined && value !== raw) stats.snapped++;
    const key = `${kind}|${value}`;
    let t = found.get(key);
    if (!t) {
      t = { key, kind, value, name: '', from: new Map(), usages: [] };
      found.set(key, t);
    }
    t.from.set(raw, (t.from.get(raw) ?? 0) + 1);
    t.usages.push({ nodeId: node.id, field });
  };

  for (const node of nodesIn(o.scope)) {
    let used = false;
    if ('layoutMode' in node && node.layoutMode !== 'NONE' && node.type !== 'INSTANCE') {
      const fields: Field[] = [...PADDING];
      // With "space between" the gap is worked out by Figma, so it is not a token.
      if (node.primaryAxisAlignItems !== 'SPACE_BETWEEN') fields.push('itemSpacing');
      if ('layoutWrap' in node && node.layoutWrap === 'WRAP' && node.counterAxisSpacing !== null) fields.push('counterAxisSpacing');
      for (const f of fields) {
        const v = (node as unknown as Record<Field, number>)[f];
        if (typeof v !== 'number' || v <= 0) continue;
        if (bound(node, f)) stats.alreadyBound++;
        else {
          add('spacing', v, node, f);
          used = true;
        }
      }
    }
    if ('topLeftRadius' in node && node.type !== 'INSTANCE') {
      for (const f of CORNERS) {
        const v = (node as unknown as Record<Field, number>)[f];
        if (typeof v !== 'number' || v <= 0) continue;
        if (bound(node, f)) stats.alreadyBound++;
        else {
          add('radius', v, node, f, isPill(v, node.width, node.height) ? FULL : undefined);
          used = true;
        }
      }
    }
    if (used) stats.layers++;
  }

  const all = [...found.values()];
  for (const kind of ['spacing', 'radius'] as Kind[]) {
    const ofKind = all.filter((t) => t.kind === kind);
    const names = tokenNames(kind, ofKind.map((t) => t.value), o.naming);
    for (const t of ofKind) t.name = names.get(t.value)!;
  }
  await matchExisting(all);
  tokens = found;
  post({ type: 'scan-result', rows: rows(), stats });
}

// Reuse number variables that already hold the same value for the same use.
async function matchExisting(list: Token[]) {
  const cols = new Map((await figma.variables.getLocalVariableCollectionsAsync()).map((c) => [c.id, c]));
  const vars = await figma.variables.getLocalVariablesAsync('FLOAT');
  for (const t of list) {
    const match = vars.find((v) => {
      const col = cols.get(v.variableCollectionId);
      if (!col || v.valuesByMode[col.defaultModeId] !== t.value) return false;
      return v.scopes.includes('ALL_SCOPES') || SCOPES[t.kind].some((s) => v.scopes.includes(s)) || v.name.toLowerCase().includes(t.kind === 'spacing' ? 'spac' : 'radi');
    });
    if (match) t.existing = { id: match.id, name: match.name };
  }
}

function rows() {
  return [...tokens.values()]
    .sort((a, b) => (a.kind === b.kind ? a.value - b.value : a.kind === 'spacing' ? -1 : 1))
    .map((t) => ({
      key: t.key,
      kind: t.kind,
      value: t.value,
      name: t.name,
      count: t.usages.length,
      from: [...t.from.entries()].sort((a, b) => a[0] - b[0]).map(([value, count]) => ({ value, count })),
      existing: t.existing,
    }));
}

// ---------- Applying ----------

interface ApplySettings {
  collectionId: string;
  collectionName: string;
  rows: Array<{ key: string; name: string; value: number; enabled: boolean; link: boolean }>;
}

async function apply(s: ApplySettings) {
  let col = s.collectionId ? await figma.variables.getVariableCollectionByIdAsync(s.collectionId) : null;
  if (!col) col = figma.variables.createVariableCollection(s.collectionName.trim() || 'Spacing');
  const local = (await figma.variables.getLocalVariablesAsync('FLOAT')).filter((v) => v.variableCollectionId === col!.id);
  const byName = new Map(local.map((v) => [v.name, v]));
  const summary = { created: 0, updated: 0, linked: 0, bound: 0, failed: 0 };
  const taken = new Set<string>();

  for (const row of s.rows) {
    const t = tokens.get(row.key);
    if (!t || !row.enabled) continue;
    let v: Variable | null = null;
    if (row.link && t.existing) {
      v = await figma.variables.getVariableByIdAsync(t.existing.id);
      if (v) summary.linked++;
    }
    if (!v) {
      const base = (row.name || t.name).replace(/[.{}]/g, '-').trim() || `${t.kind}/${row.value}`;
      let name = base;
      for (let i = 2; taken.has(name); i++) name = `${base}-${i}`;
      taken.add(name);
      v = byName.get(name) ?? null;
      if (v) summary.updated++;
      else {
        v = figma.variables.createVariable(name, col, 'FLOAT');
        summary.created++;
      }
      const value = Number.isFinite(row.value) && row.value >= 0 ? row.value : t.value;
      for (const m of col.modes) v.setValueForMode(m.modeId, value);
      v.scopes = SCOPES[t.kind];
    }
    for (const u of t.usages) {
      const node = await figma.getNodeByIdAsync(u.nodeId);
      try {
        (node as FrameNode).setBoundVariable(u.field, v);
        summary.bound++;
      } catch {
        summary.failed++;
      }
    }
  }
  tokens = new Map();
  post({ type: 'applied', summary, collections: await collectionInfos(), collectionId: col.id });
  figma.notify(`Bound ${summary.bound} values to ${summary.created + summary.updated + summary.linked} tokens`);
}

async function collectionInfos() {
  return (await figma.variables.getLocalVariableCollectionsAsync()).map((c) => ({ id: c.id, name: c.name }));
}

async function select(key: string, from?: number) {
  const t = tokens.get(key);
  if (!t) return;
  const nodes: SceneNode[] = [];
  const seen = new Set<string>();
  for (const u of t.usages) {
    if (seen.has(u.nodeId)) continue;
    const n = (await figma.getNodeByIdAsync(u.nodeId)) as SceneNode | null;
    if (!n) continue;
    if (from !== undefined && (n as unknown as Record<Field, number>)[u.field] !== from) continue;
    seen.add(u.nodeId);
    nodes.push(n);
  }
  figma.currentPage.selection = nodes;
  if (nodes.length) figma.viewport.scrollAndZoomIntoView(nodes);
}

figma.ui.onmessage = async (msg: any) => {
  try {
    switch (msg.type) {
      case 'ready':
        post({ type: 'init', collections: await collectionInfos(), selection: figma.currentPage.selection.length });
        break;
      case 'scan':
        await scan(msg.options);
        break;
      case 'apply':
        await apply(msg.settings);
        break;
      case 'select':
        await select(msg.key, msg.from);
        break;
    }
  } catch (e) {
    post({ type: 'error', message: e instanceof Error ? e.message : String(e) });
  }
};

figma.on('selectionchange', () => post({ type: 'selection', count: figma.currentPage.selection.length }));
