// Data Filler — main thread.
// Fills layers named "#field" with values from a table: text, images (from URLs),
// colours, show/hide ("#field?") and component properties. One row per selected item,
// or repeat one selected card once per row.

import { Row, Table, isHexColor, isImageUrl, isTruthy, lookup, normKey, parseLayerName, parseTable, rowOrder, sampleRows } from './data';
import { fromHex } from '../../shared/color';

interface ApplyOptions {
  repeat: boolean;
  shuffle: boolean;
  start: number;
  gap: number;
}

interface Summary {
  items: number;
  fields: number;
  created: number;
  missing: string[];
  errors: string[];
}

const MAX_REPEAT = 500;
const STORAGE_KEY = 'last-data';

let table: Table = { columns: [], rows: [] };

figma.showUI(__html__, { width: 440, height: 640, themeColors: true });
const post = (msg: unknown) => figma.ui.postMessage(msg);

// ---------- Selection ----------

function fieldNodes(root: SceneNode): SceneNode[] {
  const out: SceneNode[] = [];
  if (parseLayerName(root.name)) out.push(root);
  if ('findAll' in root) out.push(...root.findAll((n) => parseLayerName(n.name) !== null));
  return out;
}

function instancesIn(root: SceneNode): InstanceNode[] {
  const out: InstanceNode[] = root.type === 'INSTANCE' ? [root] : [];
  if ('findAll' in root) out.push(...(root.findAll((n) => n.type === 'INSTANCE') as InstanceNode[]));
  return out;
}

const propBase = (key: string) => key.split('#')[0].trim();

// Field names found in the selection: "#layer" names plus component property names.
function selectionFields(): string[] {
  const fields = new Set<string>();
  for (const root of figma.currentPage.selection) {
    for (const n of fieldNodes(root)) fields.add(parseLayerName(n.name)!.field);
    for (const inst of instancesIn(root)) {
      try {
        for (const key of Object.keys(inst.componentProperties)) {
          if (inst.componentProperties[key].type !== 'INSTANCE_SWAP') fields.add(propBase(key));
        }
      } catch {
        // Instances of missing components have no properties.
      }
    }
  }
  return [...fields];
}

function selectionInfo() {
  return { type: 'selection', count: figma.currentPage.selection.length, fields: selectionFields() };
}

// Visual order: auto-layout order inside one parent, otherwise top-to-bottom, left-to-right.
function orderedSelection(): SceneNode[] {
  const sel = [...figma.currentPage.selection];
  const parent = sel[0] && sel[0].parent;
  if (parent && sel.every((n) => n.parent === parent) && 'children' in parent) {
    const kids = parent.children as readonly SceneNode[];
    if ('layoutMode' in parent && parent.layoutMode !== 'NONE') return sel.sort((a, b) => kids.indexOf(a) - kids.indexOf(b));
  }
  return sel.sort((a, b) => (Math.abs(a.y - b.y) > 4 ? a.y - b.y : a.x - b.x));
}

// ---------- Filling ----------

const imageCache = new Map<string, Promise<Image>>();
function image(url: string) {
  let p = imageCache.get(url);
  if (!p) {
    p = figma.createImageAsync(url);
    imageCache.set(url, p);
    p.catch(() => imageCache.delete(url));
  }
  return p;
}

async function setText(node: TextNode, value: string, s: Summary) {
  if (node.hasMissingFont) {
    s.errors.push(`"${node.name}": font is missing in this file`);
    return false;
  }
  const len = node.characters.length;
  const fonts = len ? node.getRangeAllFontNames(0, len) : [node.fontName as FontName];
  await Promise.all(fonts.map((f) => figma.loadFontAsync(f)));
  node.characters = value;
  return true;
}

async function fillNode(node: SceneNode, toggle: boolean, value: unknown, s: Summary): Promise<boolean> {
  if (toggle) {
    node.visible = isTruthy(value);
    return true;
  }
  // A nested object ("#user" holding "#name", "#email") is only a group, nothing to write.
  if (value && typeof value === 'object' && !Array.isArray(value)) return false;
  const text = value === null || value === undefined ? '' : Array.isArray(value) ? value.join(', ') : String(value);
  if (node.type === 'TEXT') return setText(node, text, s);
  if (isImageUrl(text) && 'fills' in node) {
    try {
      const img = await image(text.trim());
      node.fills = [{ type: 'IMAGE', scaleMode: 'FILL', imageHash: img.hash }];
      return true;
    } catch (e) {
      s.errors.push(`Image for "${node.name}" could not be loaded (${text.slice(0, 60)})`);
      return false;
    }
  }
  if (isHexColor(text) && 'fills' in node) {
    const c = fromHex(text)!;
    node.fills = [{ type: 'SOLID', color: { r: c.r, g: c.g, b: c.b } }];
    return true;
  }
  // "#price" on a frame or button: put the value in its first text layer.
  if ('findOne' in node || 'findAll' in node) {
    const t = (node as FrameNode).findAll((n) => n.type === 'TEXT')[0] as TextNode | undefined;
    if (t) return setText(t, text, s);
  }
  return false;
}

function fillProps(inst: InstanceNode, row: Row, s: Summary) {
  let props: ComponentProperties;
  try {
    props = inst.componentProperties;
  } catch {
    return;
  }
  for (const [key, prop] of Object.entries(props)) {
    if (prop.type === 'INSTANCE_SWAP') continue;
    const value = lookup(row, propBase(key));
    if (value === undefined) continue;
    const next = prop.type === 'BOOLEAN' ? isTruthy(value) : String(value);
    try {
      inst.setProperties({ [key]: next });
      s.fields++;
    } catch {
      s.errors.push(`"${inst.name}": ${propBase(key)} has no option "${next}"`);
    }
  }
}

async function fillItem(root: SceneNode, row: Row, s: Summary) {
  // Component properties first: switching a variant replaces the layers inside it.
  for (const inst of instancesIn(root)) fillProps(inst, row, s);
  for (const node of fieldNodes(root)) {
    const parsed = parseLayerName(node.name)!;
    const value = lookup(row, parsed.field);
    if (value === undefined) {
      if (!s.missing.includes(parsed.field)) s.missing.push(parsed.field);
      continue;
    }
    try {
      if (await fillNode(node, parsed.toggle, value, s)) s.fields++;
    } catch (e) {
      s.errors.push(`"${node.name}": ${e instanceof Error ? e.message : String(e)}`);
    }
  }
}

// Copies of the selected item for the extra rows: inside auto layout they follow it,
// otherwise they are placed in a column below it.
function repeatItem(item: SceneNode, total: number, gap: number): SceneNode[] {
  const items = [item];
  const parent = item.parent;
  const auto = !!parent && 'layoutMode' in parent && parent.layoutMode !== 'NONE';
  for (let i = 1; i < total; i++) {
    const copy = item.clone();
    if (auto) {
      const p = parent as FrameNode;
      p.insertChild(p.children.indexOf(items[i - 1]) + 1, copy);
    } else {
      copy.x = item.x;
      copy.y = item.y + i * (item.height + gap);
    }
    items.push(copy);
  }
  return items;
}

async function apply(o: ApplyOptions) {
  if (!table.rows.length) throw new Error('Add some data first.');
  let items = orderedSelection();
  if (!items.length) throw new Error('Select the layers to fill.');
  const s: Summary = { items: 0, fields: 0, created: 0, missing: [], errors: [] };
  if (o.repeat && items.length === 1) {
    const count = Math.min(table.rows.length - Math.max(0, o.start), MAX_REPEAT);
    items = repeatItem(items[0], Math.max(1, count), o.gap);
    s.created = items.length - 1;
  }
  const order = rowOrder(table.rows.length, items.length, o.start, o.shuffle);
  for (let i = 0; i < items.length; i++) {
    await fillItem(items[i], table.rows[order[i]], s);
    s.items++;
  }
  if (s.created) figma.currentPage.selection = items;
  post({ type: 'applied', summary: s });
  figma.notify(`Filled ${s.items} item${s.items === 1 ? '' : 's'} · ${s.fields} fields${s.errors.length ? ` · ${s.errors.length} problems` : ''}`);
}

// ---------- Data ----------

function sendTable(source: string) {
  const fields = selectionFields();
  post({
    type: 'table',
    source,
    columns: table.columns,
    preview: table.rows.slice(0, 6),
    total: table.rows.length,
    matched: fields.filter((f) => table.columns.some((c) => normKey(c) === normKey(f) || c.toLowerCase().startsWith(f.toLowerCase() + '.'))),
    fields,
  });
}

figma.ui.onmessage = async (msg: any) => {
  try {
    switch (msg.type) {
      case 'ready': {
        post(selectionInfo());
        const saved = (await figma.clientStorage.getAsync(STORAGE_KEY)) as string | undefined;
        if (saved) {
          table = parseTable(saved);
          post({ type: 'restore', text: saved });
          sendTable('saved');
        }
        break;
      }
      case 'data':
        table = parseTable(msg.text);
        await figma.clientStorage.setAsync(STORAGE_KEY, String(msg.text).slice(0, 500000));
        sendTable(msg.source || 'pasted');
        break;
      case 'sample': {
        table = sampleRows(Math.max(1, Math.min(200, msg.count || 20)), msg.seed);
        const text = JSON.stringify(table.rows, null, 2);
        await figma.clientStorage.setAsync(STORAGE_KEY, text);
        post({ type: 'restore', text });
        sendTable('sample');
        break;
      }
      case 'apply':
        await apply(msg.options);
        post(selectionInfo());
        break;
    }
  } catch (e) {
    post({ type: 'error', message: e instanceof Error ? e.message : String(e) });
  }
};

figma.on('selectionchange', () => {
  post(selectionInfo());
  if (table.columns.length) sendTable('selection');
});
