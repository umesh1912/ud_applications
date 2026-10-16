// Contrast Checker — main thread.
// For every text layer, works out the colour actually behind it (layers below it,
// its frames, the page), resolves colour variables in any mode (e.g. Dark), and
// checks the WCAG 2 contrast ratio. Failing text can be fixed with the nearest
// colour that passes, or by changing the variable's value for that mode.

import { RGBA, blend, contrast, fixContrast, fromHex, toHex } from '../../shared/color';

type Level = 'AA' | 'AAA';
type RGB = { r: number; g: number; b: number };

interface ScanOptions {
  scope: 'selection' | 'page';
  level: Level;
  // collectionId -> modeId to check in, e.g. the Dark mode of "Theme".
  modes: Record<string, string>;
}

interface Result {
  id: string;
  name: string;
  text: string;
  start: number;
  end: number;
  ratio: number;
  required: number;
  large: boolean;
  fg: string;
  bg: string;
  // Background is an image or gradient: the ratio is a rough guess.
  unsure: boolean;
  fix: string | null;
  variable?: { id: string; name: string; modeId: string; modeName: string };
}

const WHITE: RGB = { r: 1, g: 1, b: 1 };
let lastOptions: ScanOptions | null = null;

figma.showUI(__html__, { width: 420, height: 640, themeColors: true });
const post = (msg: unknown) => figma.ui.postMessage(msg);

// ---------- Variables ----------

const varCache = new Map<string, Variable | null>();
const colCache = new Map<string, VariableCollection | null>();

async function getVar(id: string) {
  if (!varCache.has(id)) varCache.set(id, await figma.variables.getVariableByIdAsync(id));
  return varCache.get(id)!;
}
async function getCol(id: string) {
  if (!colCache.has(id)) colCache.set(id, await figma.variables.getVariableCollectionByIdAsync(id));
  return colCache.get(id)!;
}

function isColor(v: VariableValue): v is RGBA {
  return typeof v === 'object' && v !== null && 'r' in v;
}

// Which mode a layer shows for a collection: the one being checked, else what the layer resolves to.
async function modeFor(node: SceneNode, col: VariableCollection, modes: Record<string, string>) {
  if (modes[col.id]) return modes[col.id];
  const resolved = (node as SceneNode & { resolvedVariableModes?: Record<string, string> }).resolvedVariableModes;
  return (resolved && resolved[col.id]) || col.defaultModeId;
}

async function resolveColor(id: string, node: SceneNode, modes: Record<string, string>, depth = 0): Promise<{ color: RGBA; modeId: string } | null> {
  const v = await getVar(id);
  if (!v || depth > 10) return null;
  const col = await getCol(v.variableCollectionId);
  if (!col) return null;
  const modeId = await modeFor(node, col, modes);
  const value = v.valuesByMode[modeId] ?? v.valuesByMode[col.defaultModeId];
  if (isColor(value)) return { color: { r: value.r, g: value.g, b: value.b, a: 'a' in value ? value.a : 1 }, modeId };
  if (value && typeof value === 'object' && 'type' in value && value.type === 'VARIABLE_ALIAS') return resolveColor(value.id, node, modes, depth + 1);
  return null;
}

async function paintColor(p: SolidPaint, node: SceneNode, modes: Record<string, string>): Promise<RGBA> {
  const opacity = p.opacity ?? 1;
  const bound = p.boundVariables && p.boundVariables.color;
  if (bound) {
    const r = await resolveColor(bound.id, node, modes);
    if (r) return { ...r.color, a: r.color.a * opacity };
  }
  return { ...p.color, a: opacity };
}

// ---------- Finding the background ----------

interface Point {
  x: number;
  y: number;
}

function contains(node: SceneNode, pt: Point) {
  const b = node.absoluteBoundingBox;
  return !!b && pt.x >= b.x && pt.x <= b.x + b.width && pt.y >= b.y && pt.y <= b.y + b.height;
}

interface Stack {
  colors: RGBA[]; // top to bottom
  unsure: boolean;
  done: boolean;
}

async function pushFills(node: SceneNode, stack: Stack, modes: Record<string, string>) {
  if (!('fills' in node) || !Array.isArray(node.fills)) return;
  const paints = node.fills as Paint[];
  for (let i = paints.length - 1; i >= 0 && !stack.done; i--) {
    const p = paints[i];
    if (p.visible === false || (p.opacity ?? 1) === 0) continue;
    if (p.type === 'SOLID') {
      const c = await paintColor(p, node, modes);
      const a = c.a * ('opacity' in node ? node.opacity : 1);
      stack.colors.push({ ...c, a });
      if (a >= 0.999) stack.done = true;
    } else if (p.type === 'IMAGE' || p.type === 'VIDEO' || p.type.startsWith('GRADIENT')) {
      // Use a gradient's first stop as a stand-in; images are unknown.
      stack.unsure = true;
      if ('gradientStops' in p && p.gradientStops.length) stack.colors.push({ ...p.gradientStops[0].color });
      stack.done = true;
    }
  }
}

// Paints of `node` and its children at a point, topmost first (children paint above their parent).
async function visit(node: SceneNode, pt: Point, stack: Stack, modes: Record<string, string>) {
  if (!node.visible || stack.done) return;
  if ('children' in node) {
    const kids = node.children;
    for (let i = kids.length - 1; i >= 0 && !stack.done; i--) await visit(kids[i], pt, stack, modes);
  }
  if (!stack.done && contains(node, pt) && node.type !== 'TEXT') await pushFills(node, stack, modes);
}

async function background(text: TextNode, modes: Record<string, string>) {
  const b = text.absoluteBoundingBox!;
  const pt = { x: b.x + b.width / 2, y: b.y + b.height / 2 };
  const stack: Stack = { colors: [], unsure: false, done: false };
  let current: BaseNode = text;
  while (!stack.done && current.parent && current.parent.type !== 'PAGE' && current.parent.type !== 'DOCUMENT') {
    const parent = current.parent as SceneNode & ChildrenMixin;
    const kids = parent.children;
    for (let i = kids.indexOf(current as SceneNode) - 1; i >= 0 && !stack.done; i--) await visit(kids[i], pt, stack, modes);
    if (!stack.done && parent.type !== 'GROUP' && parent.type !== 'BOOLEAN_OPERATION') await pushFills(parent, stack, modes);
    current = parent;
  }
  // Top-level siblings below on the canvas, then the canvas colour.
  if (!stack.done && current.parent && current.parent.type === 'PAGE') {
    const kids = current.parent.children;
    for (let i = kids.indexOf(current as SceneNode) - 1; i >= 0 && !stack.done; i--) await visit(kids[i], pt, stack, modes);
  }
  let base: RGB = WHITE;
  if (!stack.done) {
    const pageBg = figma.currentPage.backgrounds.find((p) => p.type === 'SOLID') as SolidPaint | undefined;
    if (pageBg) base = pageBg.color;
  }
  const colors = [...stack.colors];
  if (stack.done && colors.length) base = blend(colors.pop()!, WHITE);
  for (let i = colors.length - 1; i >= 0; i--) base = blend(colors[i], base);
  return { color: base, unsure: stack.unsure };
}

// ---------- Checking ----------

function isLarge(size: number, weight: number) {
  // WCAG: 18pt (24px) regular, or 14pt (18.66px) bold.
  return size >= 24 || (size >= 18.66 && weight >= 700);
}

function required(level: Level, large: boolean) {
  if (level === 'AAA') return large ? 4.5 : 7;
  return large ? 3 : 4.5;
}

function shown(node: SceneNode) {
  let n: BaseNode | null = node;
  while (n && n.type !== 'PAGE') {
    if ('visible' in n && !n.visible) return false;
    n = n.parent;
  }
  return true;
}

function textNodes(scope: 'selection' | 'page'): TextNode[] {
  const roots = scope === 'selection' ? figma.currentPage.selection : figma.currentPage.children;
  const out: TextNode[] = [];
  for (const r of roots) {
    if (r.type === 'TEXT') out.push(r);
    if ('findAll' in r) out.push(...(r.findAll((n) => n.type === 'TEXT') as TextNode[]));
  }
  return out.filter((t) => shown(t) && t.characters.trim() !== '');
}

async function checkText(node: TextNode, o: ScanOptions): Promise<Result[]> {
  const out: Result[] = [];
  const bg = await background(node, o.modes);
  const segments = node.getStyledTextSegments(['fills', 'fontSize', 'fontWeight']);
  const seen = new Set<string>();
  for (const seg of segments) {
    const paint = [...seg.fills].reverse().find((p) => p.visible !== false && p.type === 'SOLID') as SolidPaint | undefined;
    if (!paint) continue;
    const c = await paintColor(paint, node, o.modes);
    const fg = blend({ ...c, a: c.a * node.opacity }, bg.color);
    const large = isLarge(seg.fontSize, seg.fontWeight);
    const need = required(o.level, large);
    const key = `${toHex(fg)}|${need}`;
    if (seen.has(key)) continue;
    seen.add(key);
    const ratio = contrast(fg, bg.color);
    const fixed = ratio < need ? fixContrast(fg, bg.color, need) : null;
    let variable: Result['variable'];
    const bound = paint.boundVariables && paint.boundVariables.color;
    if (bound) {
      const v = await getVar(bound.id);
      const col = v && (await getCol(v.variableCollectionId));
      if (v && col) {
        const modeId = await modeFor(node, col, o.modes);
        variable = { id: v.id, name: v.name, modeId, modeName: col.modes.find((m) => m.modeId === modeId)?.name ?? '' };
      }
    }
    out.push({
      id: node.id,
      name: node.name,
      text: seg.characters.trim().slice(0, 60),
      start: seg.start,
      end: seg.end,
      ratio: Math.round(ratio * 100) / 100,
      required: need,
      large,
      fg: toHex(fg),
      bg: toHex(bg.color),
      unsure: bg.unsure,
      fix: fixed ? toHex(fixed) : null,
      variable,
    });
  }
  return out;
}

async function scan(o: ScanOptions) {
  lastOptions = o;
  varCache.clear();
  colCache.clear();
  const nodes = textNodes(o.scope);
  const results: Result[] = [];
  for (const n of nodes) results.push(...(await checkText(n, o)));
  results.sort((a, b) => a.ratio / a.required - b.ratio / b.required);
  post({ type: 'results', results, layers: nodes.length });
}

// ---------- Fixing ----------

async function fixLayer(r: { id: string; start: number; end: number; fix: string }) {
  const node = await figma.getNodeByIdAsync(r.id);
  if (!node || node.type !== 'TEXT') return false;
  const c = fromHex(r.fix)!;
  const replace = (paints: readonly Paint[]) => {
    const list = [...paints];
    for (let i = list.length - 1; i >= 0; i--) {
      const p = list[i];
      if (p.type === 'SOLID' && p.visible !== false) {
        // Drop the variable link and opacity: the fix is the exact colour that passes.
        list[i] = { type: 'SOLID', color: { r: c.r, g: c.g, b: c.b }, opacity: 1, visible: true, blendMode: p.blendMode };
        break;
      }
    }
    return list;
  };
  if (r.start === 0 && r.end === node.characters.length && node.fills !== figma.mixed) node.fills = replace(node.fills);
  else {
    const fills = node.getRangeFills(r.start, r.end);
    if (fills === figma.mixed) return false;
    node.setRangeFills(r.start, r.end, replace(fills));
  }
  return true;
}

async function fixVariable(r: { variableId: string; modeId: string; fix: string }) {
  const v = await figma.variables.getVariableByIdAsync(r.variableId);
  if (!v) return false;
  const c = fromHex(r.fix)!;
  const old = v.valuesByMode[r.modeId];
  v.setValueForMode(r.modeId, { r: c.r, g: c.g, b: c.b, a: isColor(old) && 'a' in old ? old.a : 1 });
  return true;
}

async function selectLayer(id: string) {
  const n = await figma.getNodeByIdAsync(id);
  if (!n || !('visible' in n)) return;
  figma.currentPage.selection = [n as SceneNode];
  figma.viewport.scrollAndZoomIntoView([n as SceneNode]);
}

async function collections() {
  const cols = await figma.variables.getLocalVariableCollectionsAsync();
  return cols.filter((c) => c.modes.length > 1).map((c) => ({ id: c.id, name: c.name, modes: c.modes }));
}

figma.ui.onmessage = async (msg: any) => {
  try {
    switch (msg.type) {
      case 'ready':
        post({ type: 'init', collections: await collections(), selection: figma.currentPage.selection.length });
        break;
      case 'scan':
        await scan(msg.options);
        break;
      case 'select':
        await selectLayer(msg.id);
        break;
      case 'fix': {
        let n = 0;
        for (const item of msg.items) if (item.variableId ? await fixVariable(item) : await fixLayer(item)) n++;
        figma.notify(`Fixed ${n} item${n === 1 ? '' : 's'}`);
        if (lastOptions) await scan(lastOptions);
        break;
      }
    }
  } catch (e) {
    post({ type: 'error', message: e instanceof Error ? e.message : String(e) });
  }
};

figma.on('selectionchange', () => post({ type: 'selection', count: figma.currentPage.selection.length }));
