"use strict";
(() => {
  var __defProp = Object.defineProperty;
  var __defProps = Object.defineProperties;
  var __getOwnPropDescs = Object.getOwnPropertyDescriptors;
  var __getOwnPropSymbols = Object.getOwnPropertySymbols;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __propIsEnum = Object.prototype.propertyIsEnumerable;
  var __defNormalProp = (obj, key, value) => key in obj ? __defProp(obj, key, { enumerable: true, configurable: true, writable: true, value }) : obj[key] = value;
  var __spreadValues = (a, b) => {
    for (var prop in b || (b = {}))
      if (__hasOwnProp.call(b, prop))
        __defNormalProp(a, prop, b[prop]);
    if (__getOwnPropSymbols)
      for (var prop of __getOwnPropSymbols(b)) {
        if (__propIsEnum.call(b, prop))
          __defNormalProp(a, prop, b[prop]);
      }
    return a;
  };
  var __spreadProps = (a, b) => __defProps(a, __getOwnPropDescs(b));

  // shared/color.ts
  var NEUTRAL_CHROMA = 0.04;
  var DEFAULT_DARK_BASE = 0.18;
  var clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
  var toLinear = (c) => c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  var fromLinear = (c) => c <= 31308e-7 ? c * 12.92 : 1.055 * Math.pow(c, 1 / 2.4) - 0.055;
  function rgbToOklch({ r, g, b }) {
    const lr = toLinear(r);
    const lg = toLinear(g);
    const lb = toLinear(b);
    const l_ = Math.cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb);
    const m_ = Math.cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb);
    const s_ = Math.cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb);
    const L = 0.2104542553 * l_ + 0.793617785 * m_ - 0.0040720468 * s_;
    const A = 1.9779984951 * l_ - 2.428592205 * m_ + 0.4505937099 * s_;
    const B = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.808675766 * s_;
    const c = Math.sqrt(A * A + B * B);
    let h = Math.atan2(B, A) * 180 / Math.PI;
    if (h < 0) h += 360;
    return { l: L, c, h };
  }
  function oklchToLinear({ l, c, h }) {
    const hr = h * Math.PI / 180;
    const A = c * Math.cos(hr);
    const B = c * Math.sin(hr);
    const l_ = Math.pow(l + 0.3963377774 * A + 0.2158037573 * B, 3);
    const m_ = Math.pow(l - 0.1055613458 * A - 0.0638541728 * B, 3);
    const s_ = Math.pow(l - 0.0894841775 * A - 1.291485548 * B, 3);
    return [
      4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_,
      -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_,
      -0.0041960863 * l_ - 0.7034186147 * m_ + 1.707614701 * s_
    ];
  }
  var inGamut = (rgb) => rgb.every((v) => v >= -1e-4 && v <= 1.0001);
  function oklchToRgb(color) {
    let { l, c, h } = color;
    l = clamp(l, 0, 1);
    let lin = oklchToLinear({ l, c, h });
    if (!inGamut(lin)) {
      let lo = 0;
      let hi = c;
      for (let i = 0; i < 24; i++) {
        const mid = (lo + hi) / 2;
        if (inGamut(oklchToLinear({ l, c: mid, h }))) lo = mid;
        else hi = mid;
      }
      lin = oklchToLinear({ l, c: lo, h });
    }
    const [r, g, b] = lin.map((v) => clamp(fromLinear(clamp(v, 0, 1)), 0, 1));
    return { r, g, b };
  }
  var hex2 = (v) => Math.round(clamp(v, 0, 1) * 255).toString(16).padStart(2, "0");
  function toHex(c, withAlpha = false) {
    const base = `#${hex2(c.r)}${hex2(c.g)}${hex2(c.b)}`.toUpperCase();
    return withAlpha && c.a !== void 0 && c.a < 1 ? base + hex2(c.a).toUpperCase() : base;
  }
  function fromHex(hex) {
    let h = hex.trim().replace(/^#/, "");
    if (h.length === 3 || h.length === 4) h = h.split("").map((ch) => ch + ch).join("");
    if (!/^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(h)) return null;
    const n = (i) => parseInt(h.slice(i, i + 2), 16) / 255;
    return { r: n(0), g: n(2), b: n(4), a: h.length === 8 ? n(6) : 1 };
  }
  function isNeutral(c) {
    return rgbToOklch(c).c < NEUTRAL_CHROMA;
  }
  function surfaceLightness(l, base, spread) {
    return clamp(base + (1 - l) * spread, 0, 0.6);
  }
  function foregroundLightness(l) {
    return clamp(0.96 - l * 0.45, 0.6, 0.97);
  }
  function darkVariant(color, role, darkBase2 = DEFAULT_DARK_BASE) {
    const { l, c, h } = rgbToOklch(color);
    const neutral = c < NEUTRAL_CHROMA;
    let L = l;
    let C = c;
    let a = color.a;
    switch (role) {
      case "background":
        if (neutral) {
          L = l >= 0.5 ? surfaceLightness(l, darkBase2, 1.5) : Math.max(l, darkBase2 + 0.12);
        } else if (l >= 0.85) {
          L = surfaceLightness(l, darkBase2, 1.5) + 0.06;
          C = Math.min(c * 1.4, 0.07);
        } else {
          L = clamp(l + 0.04, 0.45, 0.75);
          C = c * 0.9;
        }
        break;
      case "border":
        if (neutral) L = l >= 0.5 ? surfaceLightness(l, darkBase2, 1.6) : clamp(1 - l * 0.8, 0.6, 0.9);
        else {
          L = clamp(Math.max(l, 0.6), 0.6, 0.8);
          C = c * 0.85;
        }
        break;
      case "text":
      case "icon":
        if (neutral) {
          L = l > 0.6 ? l : foregroundLightness(l);
        } else if (l <= 0.85) {
          L = clamp(Math.max(l + 0.12, 0.72), 0.72, 0.88);
          C = c * 0.85;
        }
        break;
      case "shadow":
        L = Math.min(l, 0.1);
        a = clamp(color.a * 1.6, 0, 0.9);
        break;
    }
    return __spreadProps(__spreadValues({}, oklchToRgb({ l: L, c: C, h })), { a });
  }
  var HUES = [
    [20, "pink"],
    [45, "red"],
    [70, "orange"],
    [100, "yellow"],
    [150, "lime"],
    [175, "green"],
    [215, "teal"],
    [270, "blue"],
    [305, "indigo"],
    [345, "purple"],
    [360, "pink"]
  ];
  function hueName(c) {
    const { h } = rgbToOklch(c);
    for (const [limit, name] of HUES) if (h < limit) return name;
    return "pink";
  }
  var ORDINALS = ["primary", "secondary", "tertiary", "quaternary"];
  var ordinal = (i) => {
    var _a;
    return (_a = ORDINALS[i]) != null ? _a : `level-${i + 1}`;
  };
  function sanitizeName(name) {
    return name.replace(/[.{}]/g, "-").split("/").map((p) => p.trim()).filter(Boolean).join("/") || "color";
  }

  // dark_theme_automator/src/code.ts
  var SCOPES = {
    background: ["FRAME_FILL", "SHAPE_FILL"],
    text: ["TEXT_FILL"],
    icon: ["SHAPE_FILL", "STROKE_COLOR"],
    border: ["STROKE_COLOR"],
    shadow: ["EFFECT_COLOR"]
  };
  var ROLE_WORDS = {
    background: ["bg", "background", "surface", "fill"],
    text: ["text", "fg", "foreground", "content"],
    icon: ["icon", "fg", "foreground"],
    border: ["border", "stroke", "outline", "divider"],
    shadow: ["shadow", "elevation"]
  };
  var ICON_TYPES = /* @__PURE__ */ new Set(["VECTOR", "BOOLEAN_OPERATION", "STAR", "LINE", "POLYGON"]);
  var SMALL_SHAPE = 24 * 24;
  var groups = /* @__PURE__ */ new Map();
  var darkBase = DEFAULT_DARK_BASE;
  figma.showUI(__html__, { width: 460, height: 720, themeColors: true });
  var post = (msg) => figma.ui.postMessage(msg);
  function fillRole(node) {
    if (node.type === "TEXT") return "text";
    if (ICON_TYPES.has(node.type)) return "icon";
    if ((node.type === "RECTANGLE" || node.type === "ELLIPSE") && node.width * node.height < SMALL_SHAPE) return "icon";
    return "background";
  }
  function strokeRole(node) {
    return ICON_TYPES.has(node.type) && node.type !== "POLYGON" && node.type !== "STAR" ? "icon" : "border";
  }
  function collectNodes(scope) {
    const roots = scope === "selection" ? figma.currentPage.selection : figma.currentPage.children;
    const out = [];
    for (const root of roots) {
      out.push(root);
      if ("findAll" in root) out.push(...root.findAll());
    }
    return out;
  }
  function hasStyle(id) {
    return typeof id === "string" ? id !== "" : id === figma.mixed;
  }
  async function scan(scope, includeStyles) {
    const nodes = collectNodes(scope);
    const found = /* @__PURE__ */ new Map();
    const stats = { layers: nodes.length, colors: 0, alreadyBound: 0, styled: 0, gradients: 0 };
    const add = (role, color, usage) => {
      const solid = role === "shadow" ? color : __spreadProps(__spreadValues({}, color), { a: 1 });
      const key = `${role}|${toHex(solid, role === "shadow")}`;
      let g = found.get(key);
      if (!g) {
        g = { key, role, light: solid, usages: [], name: "" };
        found.set(key, g);
      }
      g.usages.push(usage);
    };
    const readPaints = (node, kind, paints, role, styled, range) => {
      paints.forEach((p, index) => {
        if (p.visible === false) return;
        if (p.type !== "SOLID") {
          if (p.type.startsWith("GRADIENT")) stats.gradients++;
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
        const usage = range ? { nodeId: node.id, kind: "text", index, start: range[0], end: range[1] } : { nodeId: node.id, kind, index };
        add(role, __spreadProps(__spreadValues({}, p.color), { a: 1 }), usage);
      });
    };
    for (const node of nodes) {
      if ("fills" in node) {
        if (node.type === "TEXT" && node.fills === figma.mixed) {
          for (const seg of node.getStyledTextSegments(["fills", "fillStyleId"])) {
            readPaints(node, "fills", seg.fills, "text", seg.fillStyleId !== "", [seg.start, seg.end]);
          }
        } else if (Array.isArray(node.fills)) {
          readPaints(node, "fills", node.fills, fillRole(node), hasStyle(node.fillStyleId));
        }
      }
      if ("strokes" in node && Array.isArray(node.strokes)) {
        readPaints(node, "strokes", node.strokes, strokeRole(node), hasStyle(node.strokeStyleId));
      }
      if ("effects" in node && Array.isArray(node.effects)) {
        const styled = hasStyle(node.effectStyleId);
        node.effects.forEach((e, index) => {
          if (e.type !== "DROP_SHADOW" && e.type !== "INNER_SHADOW" || e.visible === false) return;
          if (e.boundVariables && e.boundVariables.color) return void stats.alreadyBound++;
          if (styled && !includeStyles) return void stats.styled++;
          add("shadow", __spreadValues({}, e.color), { nodeId: node.id, kind: "effects", index });
        });
      }
    }
    nameGroups([...found.values()]);
    await matchExisting([...found.values()]);
    groups = found;
    stats.colors = found.size;
    post({ type: "scan-result", rows: rows(), stats });
  }
  function nameGroups(list) {
    const taken = /* @__PURE__ */ new Set();
    const unique = (base) => {
      let name = base;
      for (let i = 2; taken.has(name); i++) name = `${base}-${i}`;
      taken.add(name);
      return name;
    };
    const byUse = (a, b) => b.usages.length - a.usages.length;
    const roles = ["background", "text", "icon", "border", "shadow"];
    for (const role of roles) {
      const ofRole = list.filter((g) => g.role === role).sort(byUse);
      let n = 0;
      for (const g of ofRole) {
        const l = rgbToOklch(g.light).l;
        if (role === "shadow") g.name = unique(`shadow/${ordinal(n++)}`);
        else if (!isNeutral(g.light)) g.name = unique(`${role}/${hueName(g.light)}`);
        else if ((role === "text" || role === "icon") && l > 0.6) g.name = unique(`${role}/on-color`);
        else if (role === "background" && l < 0.5) g.name = unique("background/inverse");
        else g.name = unique(`${role}/${ordinal(n++)}`);
      }
    }
  }
  function sameColor(a, b) {
    return toHex(a, true) === toHex(b, true);
  }
  function isRGBA(v) {
    return typeof v === "object" && v !== null && "r" in v && "g" in v && "b" in v;
  }
  async function matchExisting(list) {
    const collections = await figma.variables.getLocalVariableCollectionsAsync();
    const byId = new Map(collections.map((c) => [c.id, c]));
    const vars = await figma.variables.getLocalVariablesAsync("COLOR");
    for (const g of list) {
      let best;
      for (const v of vars) {
        const col = byId.get(v.variableCollectionId);
        if (!col) continue;
        const value = v.valuesByMode[col.defaultModeId];
        if (!isRGBA(value) || !sameColor(__spreadProps(__spreadValues({}, value), { a: "a" in value ? value.a : 1 }), g.light)) continue;
        const scopes = v.scopes;
        let score = 0;
        if (scopes.includes("ALL_SCOPES") || SCOPES[g.role].some((s) => scopes.includes(s) || scopes.includes("ALL_FILLS"))) score += 2;
        if (ROLE_WORDS[g.role].some((w) => v.name.toLowerCase().includes(w))) score += 1;
        if (!best || score > best.score) best = { v, score };
      }
      if (best) g.existing = { id: best.v.id, name: best.v.name, collection: byId.get(best.v.variableCollectionId).name };
    }
  }
  function rows() {
    return [...groups.values()].map((g) => ({
      key: g.key,
      role: g.role,
      name: g.name,
      lightHex: toHex(g.light, g.role === "shadow"),
      darkHex: toHex(darkVariant(g.light, g.role, darkBase), g.role === "shadow"),
      count: g.usages.length,
      existing: g.existing
    }));
  }
  async function collectionInfos() {
    const cols = await figma.variables.getLocalVariableCollectionsAsync();
    return cols.map((c) => ({ id: c.id, name: c.name, modes: c.modes.map((m) => m.name) }));
  }
  var findMode = (col, name) => col.modes.find((m) => m.name.trim().toLowerCase() === name.trim().toLowerCase());
  async function prepareCollection(s) {
    var _a, _b;
    let col = s.collectionId ? await figma.variables.getVariableCollectionByIdAsync(s.collectionId) : null;
    if (!col) {
      col = figma.variables.createVariableCollection(s.collectionName.trim() || "Theme");
      col.renameMode(col.modes[0].modeId, s.lightName);
    }
    const light = (_a = findMode(col, s.lightName)) != null ? _a : col.modes.find((m) => m.modeId === col.defaultModeId);
    let darkId = (_b = findMode(col, s.darkName)) == null ? void 0 : _b.modeId;
    if (!darkId) {
      try {
        darkId = col.addMode(s.darkName);
      } catch (e) {
        throw new Error(
          `Figma did not allow a second mode in "${col.name}". Multiple modes need a paid Figma plan (Professional or above). (${String(e)})`
        );
      }
    }
    figma.root.setPluginData("collectionId", col.id);
    return { col, lightId: light.modeId, darkId };
  }
  function bindPaints(paints, edits) {
    return paints.map((p, i) => {
      const v = edits.get(i);
      return v && p.type === "SOLID" ? figma.variables.setBoundVariableForPaint(p, "color", v) : p;
    });
  }
  async function applyEdits(node, e) {
    if (e.fills.size && "fills" in node && Array.isArray(node.fills)) node.fills = bindPaints(node.fills, e.fills);
    if (e.strokes.size && "strokes" in node) node.strokes = bindPaints(node.strokes, e.strokes);
    if (e.effects.size && "effects" in node) {
      node.effects = node.effects.map((fx, i) => {
        const v = e.effects.get(i);
        return v ? figma.variables.setBoundVariableForEffect(fx, "color", v) : fx;
      });
    }
    if (e.text.length && node.type === "TEXT") {
      try {
        for (const t of e.text) setRange(node, t);
      } catch (e2) {
        const fonts = node.getRangeAllFontNames(0, node.characters.length);
        await Promise.all(fonts.map((f) => figma.loadFontAsync(f)));
        for (const t of e.text) setRange(node, t);
      }
    }
  }
  function setRange(node, t) {
    const paints = node.getRangeFills(t.start, t.end);
    if (paints === figma.mixed) return;
    node.setRangeFills(t.start, t.end, bindPaints(paints, /* @__PURE__ */ new Map([[t.index, t.v]])));
  }
  async function apply(s) {
    var _a, _b;
    const { col, lightId, darkId } = await prepareCollection(s);
    const local = await figma.variables.getLocalVariablesAsync("COLOR");
    const byName = new Map(local.filter((v) => v.variableCollectionId === col.id).map((v) => [v.name, v]));
    const usedNames = /* @__PURE__ */ new Set();
    const summary = { created: 0, updated: 0, linked: 0, layers: 0, failed: 0 };
    const edits = /* @__PURE__ */ new Map();
    for (const row of s.rows) {
      const g = groups.get(row.key);
      if (!g || !row.enabled) continue;
      const dark = (_a = fromHex(row.darkHex)) != null ? _a : darkVariant(g.light, g.role, darkBase);
      let v = null;
      if (row.link && g.existing) {
        v = await figma.variables.getVariableByIdAsync(g.existing.id);
        if (v && v.variableCollectionId === col.id) {
          const cur = v.valuesByMode[darkId];
          const base = v.valuesByMode[lightId];
          if (!cur || isRGBA(cur) && isRGBA(base) && sameColor(cur, base)) {
            v.setValueForMode(darkId, g.role === "shadow" ? dark : __spreadProps(__spreadValues({}, dark), { a: 1 }));
          }
        }
        if (v) summary.linked++;
      }
      if (!v) {
        let name = sanitizeName(row.name || g.name);
        for (let i = 2; usedNames.has(name); i++) name = `${sanitizeName(row.name || g.name)}-${i}`;
        v = (_b = byName.get(name)) != null ? _b : null;
        if (v) summary.updated++;
        else {
          v = figma.variables.createVariable(name, col, "COLOR");
          summary.created++;
        }
        usedNames.add(name);
        v.setValueForMode(lightId, g.light);
        v.setValueForMode(darkId, g.role === "shadow" ? dark : __spreadProps(__spreadValues({}, dark), { a: 1 }));
        v.scopes = SCOPES[g.role];
      }
      for (const u of g.usages) {
        let e = edits.get(u.nodeId);
        if (!e) {
          e = { fills: /* @__PURE__ */ new Map(), strokes: /* @__PURE__ */ new Map(), effects: /* @__PURE__ */ new Map(), text: [] };
          edits.set(u.nodeId, e);
        }
        if (u.kind === "text") e.text.push({ start: u.start, end: u.end, index: u.index, v });
        else e[u.kind].set(u.index, v);
      }
    }
    for (const [id, e] of edits) {
      const node = await figma.getNodeByIdAsync(id);
      if (!node || !("visible" in node)) {
        summary.failed++;
        continue;
      }
      try {
        await applyEdits(node, e);
        summary.layers++;
      } catch (e2) {
        summary.failed++;
      }
    }
    groups = /* @__PURE__ */ new Map();
    post({ type: "applied", summary, collectionId: col.id, collections: await collectionInfos() });
    figma.notify(`Bound ${summary.layers} layers to ${summary.created + summary.updated + summary.linked} colour variables`);
  }
  async function targetCollection(id) {
    const colId = id || figma.root.getPluginData("collectionId");
    const col = colId ? await figma.variables.getVariableCollectionByIdAsync(colId) : null;
    if (!col) throw new Error("Create the variables first, or pick a collection.");
    return col;
  }
  async function setMode(collectionId, modeName) {
    const col = await targetCollection(collectionId);
    const mode = findMode(col, modeName);
    if (!mode) throw new Error(`"${col.name}" has no mode called "${modeName}".`);
    const sel = figma.currentPage.selection;
    const targets = sel.length ? [...sel] : [figma.currentPage];
    for (const n of targets) n.setExplicitVariableModeForCollection(col, mode.modeId);
    figma.notify(`${mode.name} mode on ${sel.length ? `${sel.length} layer(s)` : "this page"}`);
  }
  function topLevel(node) {
    let n = node;
    while (n.parent && n.parent.type !== "PAGE" && n.parent.type !== "SECTION") n = n.parent;
    return n;
  }
  async function previewDark(collectionId, darkName) {
    const col = await targetCollection(collectionId);
    const mode = findMode(col, darkName);
    if (!mode) throw new Error(`"${col.name}" has no mode called "${darkName}".`);
    const roots = [...new Set(figma.currentPage.selection.map(topLevel))];
    if (!roots.length) throw new Error("Select the screens you want to preview.");
    const copies = roots.map((r) => {
      const copy = r.clone();
      copy.x = r.x + r.width + 120;
      copy.y = r.y;
      copy.name = `${r.name} \u2014 ${mode.name}`;
      copy.setExplicitVariableModeForCollection(col, mode.modeId);
      return copy;
    });
    figma.currentPage.selection = copies;
    figma.viewport.scrollAndZoomIntoView([...roots, ...copies]);
  }
  async function exportTokens(collectionId) {
    var _a, _b;
    const col = await targetCollection(collectionId);
    const vars = (await figma.variables.getLocalVariablesAsync("COLOR")).filter((v) => v.variableCollectionId === col.id);
    const names = new Map(vars.map((v) => [v.id, v.name.split("/").join(".")]));
    const out = {};
    for (const mode of col.modes) {
      const tree = {};
      for (const v of vars) {
        const value = v.valuesByMode[mode.modeId];
        let $value;
        if (isRGBA(value)) $value = toHex(value, true);
        else if (typeof value === "object" && value && "type" in value && value.type === "VARIABLE_ALIAS")
          $value = `{${(_a = names.get(value.id)) != null ? _a : value.id}}`;
        else continue;
        const parts = v.name.split("/");
        let node = tree;
        for (const p of parts.slice(0, -1)) node = (_b = node[p]) != null ? _b : node[p] = {};
        node[parts[parts.length - 1]] = { $type: "color", $value };
      }
      out[mode.name] = tree;
    }
    post({ type: "export-data", filename: `${col.name}.tokens.json`, json: JSON.stringify(out, null, 2) });
  }
  async function selectUsages(key) {
    const g = groups.get(key);
    if (!g) return;
    const ids = [...new Set(g.usages.map((u) => u.nodeId))];
    const nodes = [];
    for (const id of ids) {
      const n = await figma.getNodeByIdAsync(id);
      if (n && "visible" in n) nodes.push(n);
    }
    const here = nodes.filter((n) => {
      let p = n;
      while (p && p.type !== "PAGE") p = p.parent;
      return p === figma.currentPage;
    });
    figma.currentPage.selection = here;
    if (here.length) figma.viewport.scrollAndZoomIntoView(here);
  }
  figma.ui.onmessage = async (msg) => {
    try {
      switch (msg.type) {
        case "ready":
          post({
            type: "init",
            collections: await collectionInfos(),
            collectionId: figma.root.getPluginData("collectionId"),
            selection: figma.currentPage.selection.length
          });
          break;
        case "scan":
          await scan(msg.scope, msg.includeStyles);
          break;
        case "dark-base":
          darkBase = msg.value;
          post({ type: "regenerated", rows: rows() });
          break;
        case "apply":
          await apply(msg.settings);
          break;
        case "set-mode":
          await setMode(msg.collectionId, msg.mode);
          break;
        case "preview-dark":
          await previewDark(msg.collectionId, msg.darkName);
          break;
        case "export":
          await exportTokens(msg.collectionId);
          break;
        case "select":
          await selectUsages(msg.key);
          break;
        case "resize":
          figma.ui.resize(msg.width, msg.height);
          break;
      }
    } catch (e) {
      post({ type: "error", message: e instanceof Error ? e.message : String(e) });
    }
  };
  figma.on("selectionchange", () => post({ type: "selection", count: figma.currentPage.selection.length }));
})();
