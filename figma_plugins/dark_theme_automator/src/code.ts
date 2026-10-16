// Dark Theme Automator — main thread.
// Scans the colours of a design, proposes Light/Dark values, creates colour variables
// in a collection with Light and Dark modes, and binds every layer to them.

import {
  DEFAULT_DARK_BASE,
  RGBA,
  Role,
  darkVariant,
  hueName,
  isNeutral,
  ordinal,
  rgbToOklch,
  sanitizeName,
  toHex,
  fromHex,
} from '../../shared/color';
import { Row, UiMessage, CollectionInfo, ApplySettings, ScanStats } from './messages';

type UsageKind = 'fills' | 'strokes' | 'effects' | 'text';

interface Usage {
  nodeId: string;
  kind: UsageKind;
  index: number;
  // Character range, for text with several fills.
  start?: number;
  end?: number;
}

interface Group {
  key: string;
  role: Role;
  light: RGBA;
  usages: Usage[];
  name: string;
  existing?: { id: string; name: string; collection: string };
}

const SCOPES: Record<Role, VariableScope[]> = {
  background: ['FRAME_FILL', 'SHAPE_FILL'],
  text: ['TEXT_FILL'],
  icon: ['SHAPE_FILL', 'STROKE_COLOR'],
  border: ['STROKE_COLOR'],
  shadow: ['EFFECT_COLOR'],
};

const ROLE_WORDS: Record<Role, string[]> = {
  background: ['bg', 'background', 'surface', 'fill'],
  text: ['text', 'fg', 'foreground', 'content'],
  icon: ['icon', 'fg', 'foreground'],
  border: ['border', 'stroke', 'outline', 'divider'],
  shadow: ['shadow', 'elevation'],
};

const ICON_TYPES = new Set<NodeType>(['VECTOR', 'BOOLEAN_OPERATION', 'STAR', 'LINE', 'POLYGON']);
const SMALL_SHAPE = 24 * 24;

let groups = new Map<string, Group>();
let darkBase = DEFAULT_DARK_BASE;

figma.showUI(__html__, { width: 460, height: 720, themeColors: true });

const post = (msg: unknown) => figma.ui.postMessage(msg);

// ---------- Scanning ----------

function fillRole(node: SceneNode): Role {
  if (node.type === 'TEXT') return 'text';
  if (ICON_TYPES.has(node.type)) return 'icon';
  if ((node.type === 'RECTANGLE' || node.type === 'ELLIPSE') && node.width * node.height < SMALL_SHAPE) return 'icon';
  return 'background';
}

function strokeRole(node: SceneNode): Role {
  return ICON_TYPES.has(node.type) && node.type !== 'POLYGON' && node.type !== 'STAR' ? 'icon' : 'border';
}

function collectNodes(scope: 'selection' | 'page'): SceneNode[] {
  const roots: readonly SceneNode[] = scope === 'selection' ? figma.currentPage.selection : figma.currentPage.children;
  const out: SceneNode[] = [];
  for (const root of roots) {
    out.push(root);
    if ('findAll' in root) out.push(...root.findAll());
  }
  return out;
}

function hasStyle(id: string | symbol | undefined): boolean {
  return typeof id === 'string' ? id !== '' : id === figma.mixed;
}

async function scan(scope: 'selection' | 'page', includeStyles: boolean) {
  const nodes = collectNodes(scope);
  const found = new Map<string, Group>();
  const stats: ScanStats = { layers: nodes.length, colors: 0, alreadyBound: 0, styled: 0, gradients: 0 };

  const add = (role: Role, color: RGBA, usage: Usage) => {
    const solid = role === 'shadow' ? color : { ...color, a: 1 };
    const key = `${role}|${toHex(solid, role === 'shadow')}`;
    let g = found.get(key);
    if (!g) {
      g = { key, role, light: solid, usages: [], name: '' };
      found.set(key, g);
    }
    g.usages.push(usage);
  };

  const readPaints = (node: SceneNode, kind: 'fills' | 'strokes', paints: readonly Paint[], role: Role, styled: boolean, range?: [number, number]) => {
    paints.forEach((p, index) => {
      if (p.visible === false) return;
      if (p.type !== 'SOLID') {
        if (p.type.startsWith('GRADIENT')) stats.gradients++;
        return;
      }
      if (p.boundVariables && p.boundVariables.color) {
        stats.alreadyBound++;
        return;
      }
      if (styled && !includeStyles) {
        stats.styled++;
        return;
      }
      const usage: Usage = range
        ? { nodeId: node.id, kind: 'text', index, start: range[0], end: range[1] }
        : { nodeId: node.id, kind, index };
      add(role, { ...p.color, a: 1 }, usage);
    });
  };

  for (const node of nodes) {
    if ('fills' in node) {
      if (node.type === 'TEXT' && node.fills === figma.mixed) {
        for (const seg of node.getStyledTextSegments(['fills', 'fillStyleId'])) {
          readPaints(node, 'fills', seg.fills, 'text', seg.fillStyleId !== '', [seg.start, seg.end]);
        }
      } else if (Array.isArray(node.fills)) {
        readPaints(node, 'fills', node.fills, fillRole(node), hasStyle(node.fillStyleId));
      }
    }
    if ('strokes' in node && Array.isArray(node.strokes)) {
      readPaints(node, 'strokes', node.strokes, strokeRole(node), hasStyle(node.strokeStyleId));
    }
    if ('effects' in node && Array.isArray(node.effects)) {
      const styled = hasStyle(node.effectStyleId);
      node.effects.forEach((e, index) => {
        if ((e.type !== 'DROP_SHADOW' && e.type !== 'INNER_SHADOW') || e.visible === false) return;
        if (e.boundVariables && e.boundVariables.color) return void stats.alreadyBound++;
        if (styled && !includeStyles) return void stats.styled++;
        add('shadow', { ...e.color }, { nodeId: node.id, kind: 'effects', index });
      });
    }
  }

  nameGroups([...found.values()]);
  await matchExisting([...found.values()]);
  groups = found;
  stats.colors = found.size;
  post({ type: 'scan-result', rows: rows(), stats });
}

// Most used colour of a role becomes "primary", the next "secondary", and so on.
// Coloured ones are named by hue, light text on colour is "on-color".
function nameGroups(list: Group[]) {
  const taken = new Set<string>();
  const unique = (base: string) => {
    let name = base;
    for (let i = 2; taken.has(name); i++) name = `${base}-${i}`;
    taken.add(name);
    return name;
  };
  const byUse = (a: Group, b: Group) => b.usages.length - a.usages.length;
  const roles: Role[] = ['background', 'text', 'icon', 'border', 'shadow'];
  for (const role of roles) {
    const ofRole = list.filter((g) => g.role === role).sort(byUse);
    let n = 0;
    for (const g of ofRole) {
      const l = rgbToOklch(g.light).l;
      if (role === 'shadow') g.name = unique(`shadow/${ordinal(n++)}`);
      else if (!isNeutral(g.light)) g.name = unique(`${role}/${hueName(g.light)}`);
      else if ((role === 'text' || role === 'icon') && l > 0.6) g.name = unique(`${role}/on-color`);
      else if (role === 'background' && l < 0.5) g.name = unique('background/inverse');
      else g.name = unique(`${role}/${ordinal(n++)}`);
    }
  }
}

function sameColor(a: RGBA, b: RGBA): boolean {
  return toHex(a, true) === toHex(b, true);
}

function isRGBA(v: VariableValue): v is RGBA {
  return typeof v === 'object' && v !== null && 'r' in v && 'g' in v && 'b' in v;
}

// Links a colour to a local variable that already has exactly that value.
async function matchExisting(list: Group[]) {
  const collections = await figma.variables.getLocalVariableCollectionsAsync();
  const byId = new Map(collections.map((c) => [c.id, c]));
  const vars = await figma.variables.getLocalVariablesAsync('COLOR');
  for (const g of list) {
    let best: { v: Variable; score: number } | undefined;
    for (const v of vars) {
      const col = byId.get(v.variableCollectionId);
      if (!col) continue;
      const value = v.valuesByMode[col.defaultModeId];
      if (!isRGBA(value) || !sameColor({ ...value, a: 'a' in value ? value.a : 1 }, g.light)) continue;
      const scopes = v.scopes;
      let score = 0;
      if (scopes.includes('ALL_SCOPES') || SCOPES[g.role].some((s) => scopes.includes(s) || scopes.includes('ALL_FILLS'))) score += 2;
      if (ROLE_WORDS[g.role].some((w) => v.name.toLowerCase().includes(w))) score += 1;
      if (!best || score > best.score) best = { v, score };
    }
    if (best) g.existing = { id: best.v.id, name: best.v.name, collection: byId.get(best.v.variableCollectionId)!.name };
  }
}

function rows(): Row[] {
  return [...groups.values()].map((g) => ({
    key: g.key,
    role: g.role,
    name: g.name,
    lightHex: toHex(g.light, g.role === 'shadow'),
    darkHex: toHex(darkVariant(g.light, g.role, darkBase), g.role === 'shadow'),
    count: g.usages.length,
    existing: g.existing,
  }));
}

// ---------- Collections and modes ----------

async function collectionInfos(): Promise<CollectionInfo[]> {
  const cols = await figma.variables.getLocalVariableCollectionsAsync();
  return cols.map((c) => ({ id: c.id, name: c.name, modes: c.modes.map((m) => m.name) }));
}

const findMode = (col: VariableCollection, name: string) =>
  col.modes.find((m) => m.name.trim().toLowerCase() === name.trim().toLowerCase());

async function prepareCollection(s: ApplySettings) {
  let col = s.collectionId ? await figma.variables.getVariableCollectionByIdAsync(s.collectionId) : null;
  if (!col) {
    col = figma.variables.createVariableCollection(s.collectionName.trim() || 'Theme');
    col.renameMode(col.modes[0].modeId, s.lightName);
  }
  const light = findMode(col, s.lightName) ?? col.modes.find((m) => m.modeId === col!.defaultModeId)!;
  let darkId = findMode(col, s.darkName)?.modeId;
  if (!darkId) {
    try {
      darkId = col.addMode(s.darkName);
    } catch (e) {
      throw new Error(
        `Figma did not allow a second mode in "${col.name}". Multiple modes need a paid Figma plan (Professional or above). (${String(e)})`
      );
    }
  }
  figma.root.setPluginData('collectionId', col.id);
  return { col, lightId: light.modeId, darkId };
}

// ---------- Binding ----------

interface NodeEdits {
  fills: Map<number, Variable>;
  strokes: Map<number, Variable>;
  effects: Map<number, Variable>;
  text: Array<{ start: number; end: number; index: number; v: Variable }>;
}

function bindPaints(paints: readonly Paint[], edits: Map<number, Variable>): Paint[] {
  return paints.map((p, i) => {
    const v = edits.get(i);
    return v && p.type === 'SOLID' ? figma.variables.setBoundVariableForPaint(p, 'color', v) : p;
  });
}

async function applyEdits(node: SceneNode, e: NodeEdits) {
  if (e.fills.size && 'fills' in node && Array.isArray(node.fills)) node.fills = bindPaints(node.fills, e.fills);
  if (e.strokes.size && 'strokes' in node) node.strokes = bindPaints(node.strokes, e.strokes);
  if (e.effects.size && 'effects' in node) {
    node.effects = node.effects.map((fx, i) => {
      const v = e.effects.get(i);
      return v ? figma.variables.setBoundVariableForEffect(fx, 'color', v) : fx;
    });
  }
  if (e.text.length && node.type === 'TEXT') {
    try {
      for (const t of e.text) setRange(node, t);
    } catch {
      // Some files need the fonts loaded before ranges can change.
      const fonts = node.getRangeAllFontNames(0, node.characters.length);
      await Promise.all(fonts.map((f) => figma.loadFontAsync(f)));
      for (const t of e.text) setRange(node, t);
    }
  }
}

function setRange(node: TextNode, t: { start: number; end: number; index: number; v: Variable }) {
  const paints = node.getRangeFills(t.start, t.end);
  if (paints === figma.mixed) return;
  node.setRangeFills(t.start, t.end, bindPaints(paints, new Map([[t.index, t.v]])));
}

async function apply(s: ApplySettings) {
  const { col, lightId, darkId } = await prepareCollection(s);
  const local = await figma.variables.getLocalVariablesAsync('COLOR');
  const byName = new Map(local.filter((v) => v.variableCollectionId === col.id).map((v) => [v.name, v]));
  const usedNames = new Set<string>();
  const summary = { created: 0, updated: 0, linked: 0, layers: 0, failed: 0 };
  const edits = new Map<string, NodeEdits>();

  for (const row of s.rows) {
    const g = groups.get(row.key);
    if (!g || !row.enabled) continue;
    const dark = fromHex(row.darkHex) ?? darkVariant(g.light, g.role, darkBase);
    let v: Variable | null = null;

    if (row.link && g.existing) {
      v = await figma.variables.getVariableByIdAsync(g.existing.id);
      // Fill in the dark value only if the variable's dark mode is still an untouched copy of light.
      if (v && v.variableCollectionId === col.id) {
        const cur = v.valuesByMode[darkId];
        const base = v.valuesByMode[lightId];
        if (!cur || (isRGBA(cur) && isRGBA(base) && sameColor(cur, base))) {
          v.setValueForMode(darkId, g.role === 'shadow' ? dark : { ...dark, a: 1 });
        }
      }
      if (v) summary.linked++;
    }
    if (!v) {
      let name = sanitizeName(row.name || g.name);
      for (let i = 2; usedNames.has(name); i++) name = `${sanitizeName(row.name || g.name)}-${i}`;
      v = byName.get(name) ?? null;
      if (v) summary.updated++;
      else {
        v = figma.variables.createVariable(name, col, 'COLOR');
        summary.created++;
      }
      usedNames.add(name);
      v.setValueForMode(lightId, g.light);
      v.setValueForMode(darkId, g.role === 'shadow' ? dark : { ...dark, a: 1 });
      v.scopes = SCOPES[g.role];
    }

    for (const u of g.usages) {
      let e = edits.get(u.nodeId);
      if (!e) {
        e = { fills: new Map(), strokes: new Map(), effects: new Map(), text: [] };
        edits.set(u.nodeId, e);
      }
      if (u.kind === 'text') e.text.push({ start: u.start!, end: u.end!, index: u.index, v });
      else e[u.kind].set(u.index, v);
    }
  }

  for (const [id, e] of edits) {
    const node = await figma.getNodeByIdAsync(id);
    if (!node || !('visible' in node)) {
      summary.failed++;
      continue;
    }
    try {
      await applyEdits(node as SceneNode, e);
      summary.layers++;
    } catch {
      summary.failed++;
    }
  }

  groups = new Map();
  post({ type: 'applied', summary, collectionId: col.id, collections: await collectionInfos() });
  figma.notify(`Bound ${summary.layers} layers to ${summary.created + summary.updated + summary.linked} colour variables`);
}

// ---------- Mode switching, preview, export ----------

async function targetCollection(id?: string) {
  const colId = id || figma.root.getPluginData('collectionId');
  const col = colId ? await figma.variables.getVariableCollectionByIdAsync(colId) : null;
  if (!col) throw new Error('Create the variables first, or pick a collection.');
  return col;
}

async function setMode(collectionId: string | undefined, modeName: string) {
  const col = await targetCollection(collectionId);
  const mode = findMode(col, modeName);
  if (!mode) throw new Error(`"${col.name}" has no mode called "${modeName}".`);
  const sel = figma.currentPage.selection;
  const targets: Array<SceneNode | PageNode> = sel.length ? [...sel] : [figma.currentPage];
  for (const n of targets) n.setExplicitVariableModeForCollection(col, mode.modeId);
  figma.notify(`${mode.name} mode on ${sel.length ? `${sel.length} layer(s)` : 'this page'}`);
}

// The top-level frame a layer lives in, so the copy lands next to the screen.
function topLevel(node: SceneNode): SceneNode {
  let n: BaseNode = node;
  while (n.parent && n.parent.type !== 'PAGE' && n.parent.type !== 'SECTION') n = n.parent;
  return n as SceneNode;
}

async function previewDark(collectionId: string | undefined, darkName: string) {
  const col = await targetCollection(collectionId);
  const mode = findMode(col, darkName);
  if (!mode) throw new Error(`"${col.name}" has no mode called "${darkName}".`);
  const roots = [...new Set(figma.currentPage.selection.map(topLevel))];
  if (!roots.length) throw new Error('Select the screens you want to preview.');
  const copies = roots.map((r) => {
    const copy = r.clone();
    copy.x = r.x + r.width + 120;
    copy.y = r.y;
    copy.name = `${r.name} — ${mode.name}`;
    copy.setExplicitVariableModeForCollection(col, mode.modeId);
    return copy;
  });
  figma.currentPage.selection = copies;
  figma.viewport.scrollAndZoomIntoView([...roots, ...copies]);
}

// Design tokens (W3C format), one set per mode; aliases become {group.name} references.
async function exportTokens(collectionId: string | undefined) {
  const col = await targetCollection(collectionId);
  const vars = (await figma.variables.getLocalVariablesAsync('COLOR')).filter((v) => v.variableCollectionId === col.id);
  const names = new Map(vars.map((v) => [v.id, v.name.split('/').join('.')]));
  const out: Record<string, unknown> = {};
  for (const mode of col.modes) {
    const tree: Record<string, any> = {};
    for (const v of vars) {
      const value = v.valuesByMode[mode.modeId];
      let $value: string;
      if (isRGBA(value)) $value = toHex(value as RGBA, true);
      else if (typeof value === 'object' && value && 'type' in value && value.type === 'VARIABLE_ALIAS')
        $value = `{${names.get(value.id) ?? value.id}}`;
      else continue;
      const parts = v.name.split('/');
      let node = tree;
      for (const p of parts.slice(0, -1)) node = node[p] ??= {};
      node[parts[parts.length - 1]] = { $type: 'color', $value };
    }
    out[mode.name] = tree;
  }
  post({ type: 'export-data', filename: `${col.name}.tokens.json`, json: JSON.stringify(out, null, 2) });
}

async function selectUsages(key: string) {
  const g = groups.get(key);
  if (!g) return;
  const ids = [...new Set(g.usages.map((u) => u.nodeId))];
  const nodes: SceneNode[] = [];
  for (const id of ids) {
    const n = await figma.getNodeByIdAsync(id);
    if (n && 'visible' in n) nodes.push(n as SceneNode);
  }
  const here = nodes.filter((n) => {
    let p: BaseNode | null = n;
    while (p && p.type !== 'PAGE') p = p.parent;
    return p === figma.currentPage;
  });
  figma.currentPage.selection = here;
  if (here.length) figma.viewport.scrollAndZoomIntoView(here);
}

// ---------- Messages ----------

figma.ui.onmessage = async (msg: UiMessage) => {
  try {
    switch (msg.type) {
      case 'ready':
        post({
          type: 'init',
          collections: await collectionInfos(),
          collectionId: figma.root.getPluginData('collectionId'),
          selection: figma.currentPage.selection.length,
        });
        break;
      case 'scan':
        await scan(msg.scope, msg.includeStyles);
        break;
      case 'dark-base':
        darkBase = msg.value;
        post({ type: 'regenerated', rows: rows() });
        break;
      case 'apply':
        await apply(msg.settings);
        break;
      case 'set-mode':
        await setMode(msg.collectionId, msg.mode);
        break;
      case 'preview-dark':
        await previewDark(msg.collectionId, msg.darkName);
        break;
      case 'export':
        await exportTokens(msg.collectionId);
        break;
      case 'select':
        await selectUsages(msg.key);
        break;
      case 'resize':
        figma.ui.resize(msg.width, msg.height);
        break;
    }
  } catch (e) {
    post({ type: 'error', message: e instanceof Error ? e.message : String(e) });
  }
};

figma.on('selectionchange', () => post({ type: 'selection', count: figma.currentPage.selection.length }));
