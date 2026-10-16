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
  function luminance({ r, g, b }) {
    return 0.2126 * toLinear(r) + 0.7152 * toLinear(g) + 0.0722 * toLinear(b);
  }
  function contrast(a, b) {
    const la = luminance(a);
    const lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
  }
  function blend(top, bottom) {
    const a = clamp(top.a, 0, 1);
    return {
      r: top.r * a + bottom.r * (1 - a),
      g: top.g * a + bottom.g * (1 - a),
      b: top.b * a + bottom.b * (1 - a)
    };
  }
  function fixContrast(fg, bg, target) {
    if (contrast(fg, bg) >= target) return __spreadValues({}, fg);
    const { l, c, h } = rgbToOklch(fg);
    let best = null;
    for (let i = 0; i <= 400; i++) {
      const L = i / 400;
      const rgb = oklchToRgb({ l: L, c, h });
      if (contrast(rgb, bg) >= target + 0.02 && (!best || Math.abs(L - l) < best.dist)) best = { rgb, dist: Math.abs(L - l) };
    }
    return best ? best.rgb : null;
  }

  // contrast_checker/src/code.ts
  var WHITE = { r: 1, g: 1, b: 1 };
  var lastOptions = null;
  figma.showUI(__html__, { width: 420, height: 640, themeColors: true });
  var post = (msg) => figma.ui.postMessage(msg);
  var varCache = /* @__PURE__ */ new Map();
  var colCache = /* @__PURE__ */ new Map();
  async function getVar(id) {
    if (!varCache.has(id)) varCache.set(id, await figma.variables.getVariableByIdAsync(id));
    return varCache.get(id);
  }
  async function getCol(id) {
    if (!colCache.has(id)) colCache.set(id, await figma.variables.getVariableCollectionByIdAsync(id));
    return colCache.get(id);
  }
  function isColor(v) {
    return typeof v === "object" && v !== null && "r" in v;
  }
  async function modeFor(node, col, modes) {
    if (modes[col.id]) return modes[col.id];
    const resolved = node.resolvedVariableModes;
    return resolved && resolved[col.id] || col.defaultModeId;
  }
  async function resolveColor(id, node, modes, depth = 0) {
    var _a;
    const v = await getVar(id);
    if (!v || depth > 10) return null;
    const col = await getCol(v.variableCollectionId);
    if (!col) return null;
    const modeId = await modeFor(node, col, modes);
    const value = (_a = v.valuesByMode[modeId]) != null ? _a : v.valuesByMode[col.defaultModeId];
    if (isColor(value)) return { color: { r: value.r, g: value.g, b: value.b, a: "a" in value ? value.a : 1 }, modeId };
    if (value && typeof value === "object" && "type" in value && value.type === "VARIABLE_ALIAS") return resolveColor(value.id, node, modes, depth + 1);
    return null;
  }
  async function paintColor(p, node, modes) {
    var _a;
    const opacity = (_a = p.opacity) != null ? _a : 1;
    const bound = p.boundVariables && p.boundVariables.color;
    if (bound) {
      const r = await resolveColor(bound.id, node, modes);
      if (r) return __spreadProps(__spreadValues({}, r.color), { a: r.color.a * opacity });
    }
    return __spreadProps(__spreadValues({}, p.color), { a: opacity });
  }
  function contains(node, pt) {
    const b = node.absoluteBoundingBox;
    return !!b && pt.x >= b.x && pt.x <= b.x + b.width && pt.y >= b.y && pt.y <= b.y + b.height;
  }
  async function pushFills(node, stack, modes) {
    var _a;
    if (!("fills" in node) || !Array.isArray(node.fills)) return;
    const paints = node.fills;
    for (let i = paints.length - 1; i >= 0 && !stack.done; i--) {
      const p = paints[i];
      if (p.visible === false || ((_a = p.opacity) != null ? _a : 1) === 0) continue;
      if (p.type === "SOLID") {
        const c = await paintColor(p, node, modes);
        const a = c.a * ("opacity" in node ? node.opacity : 1);
        stack.colors.push(__spreadProps(__spreadValues({}, c), { a }));
        if (a >= 0.999) stack.done = true;
      } else if (p.type === "IMAGE" || p.type === "VIDEO" || p.type.startsWith("GRADIENT")) {
        stack.unsure = true;
        if ("gradientStops" in p && p.gradientStops.length) stack.colors.push(__spreadValues({}, p.gradientStops[0].color));
        stack.done = true;
      }
    }
  }
  async function visit(node, pt, stack, modes) {
    if (!node.visible || stack.done) return;
    if ("children" in node) {
      const kids = node.children;
      for (let i = kids.length - 1; i >= 0 && !stack.done; i--) await visit(kids[i], pt, stack, modes);
    }
    if (!stack.done && contains(node, pt) && node.type !== "TEXT") await pushFills(node, stack, modes);
  }
  async function background(text, modes) {
    const b = text.absoluteBoundingBox;
    const pt = { x: b.x + b.width / 2, y: b.y + b.height / 2 };
    const stack = { colors: [], unsure: false, done: false };
    let current = text;
    while (!stack.done && current.parent && current.parent.type !== "PAGE" && current.parent.type !== "DOCUMENT") {
      const parent = current.parent;
      const kids = parent.children;
      for (let i = kids.indexOf(current) - 1; i >= 0 && !stack.done; i--) await visit(kids[i], pt, stack, modes);
      if (!stack.done && parent.type !== "GROUP" && parent.type !== "BOOLEAN_OPERATION") await pushFills(parent, stack, modes);
      current = parent;
    }
    if (!stack.done && current.parent && current.parent.type === "PAGE") {
      const kids = current.parent.children;
      for (let i = kids.indexOf(current) - 1; i >= 0 && !stack.done; i--) await visit(kids[i], pt, stack, modes);
    }
    let base = WHITE;
    if (!stack.done) {
      const pageBg = figma.currentPage.backgrounds.find((p) => p.type === "SOLID");
      if (pageBg) base = pageBg.color;
    }
    const colors = [...stack.colors];
    if (stack.done && colors.length) base = blend(colors.pop(), WHITE);
    for (let i = colors.length - 1; i >= 0; i--) base = blend(colors[i], base);
    return { color: base, unsure: stack.unsure };
  }
  function isLarge(size, weight) {
    return size >= 24 || size >= 18.66 && weight >= 700;
  }
  function required(level, large) {
    if (level === "AAA") return large ? 4.5 : 7;
    return large ? 3 : 4.5;
  }
  function shown(node) {
    let n = node;
    while (n && n.type !== "PAGE") {
      if ("visible" in n && !n.visible) return false;
      n = n.parent;
    }
    return true;
  }
  function textNodes(scope) {
    const roots = scope === "selection" ? figma.currentPage.selection : figma.currentPage.children;
    const out = [];
    for (const r of roots) {
      if (r.type === "TEXT") out.push(r);
      if ("findAll" in r) out.push(...r.findAll((n) => n.type === "TEXT"));
    }
    return out.filter((t) => shown(t) && t.characters.trim() !== "");
  }
  async function checkText(node, o) {
    var _a, _b;
    const out = [];
    const bg = await background(node, o.modes);
    const segments = node.getStyledTextSegments(["fills", "fontSize", "fontWeight"]);
    const seen = /* @__PURE__ */ new Set();
    for (const seg of segments) {
      const paint = [...seg.fills].reverse().find((p) => p.visible !== false && p.type === "SOLID");
      if (!paint) continue;
      const c = await paintColor(paint, node, o.modes);
      const fg = blend(__spreadProps(__spreadValues({}, c), { a: c.a * node.opacity }), bg.color);
      const large = isLarge(seg.fontSize, seg.fontWeight);
      const need = required(o.level, large);
      const key = `${toHex(fg)}|${need}`;
      if (seen.has(key)) continue;
      seen.add(key);
      const ratio = contrast(fg, bg.color);
      const fixed = ratio < need ? fixContrast(fg, bg.color, need) : null;
      let variable;
      const bound = paint.boundVariables && paint.boundVariables.color;
      if (bound) {
        const v = await getVar(bound.id);
        const col = v && await getCol(v.variableCollectionId);
        if (v && col) {
          const modeId = await modeFor(node, col, o.modes);
          variable = { id: v.id, name: v.name, modeId, modeName: (_b = (_a = col.modes.find((m) => m.modeId === modeId)) == null ? void 0 : _a.name) != null ? _b : "" };
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
        variable
      });
    }
    return out;
  }
  async function scan(o) {
    lastOptions = o;
    varCache.clear();
    colCache.clear();
    const nodes = textNodes(o.scope);
    const results = [];
    for (const n of nodes) results.push(...await checkText(n, o));
    results.sort((a, b) => a.ratio / a.required - b.ratio / b.required);
    post({ type: "results", results, layers: nodes.length });
  }
  async function fixLayer(r) {
    const node = await figma.getNodeByIdAsync(r.id);
    if (!node || node.type !== "TEXT") return false;
    const c = fromHex(r.fix);
    const replace = (paints) => {
      const list = [...paints];
      for (let i = list.length - 1; i >= 0; i--) {
        const p = list[i];
        if (p.type === "SOLID" && p.visible !== false) {
          list[i] = { type: "SOLID", color: { r: c.r, g: c.g, b: c.b }, opacity: 1, visible: true, blendMode: p.blendMode };
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
  async function fixVariable(r) {
    const v = await figma.variables.getVariableByIdAsync(r.variableId);
    if (!v) return false;
    const c = fromHex(r.fix);
    const old = v.valuesByMode[r.modeId];
    v.setValueForMode(r.modeId, { r: c.r, g: c.g, b: c.b, a: isColor(old) && "a" in old ? old.a : 1 });
    return true;
  }
  async function selectLayer(id) {
    const n = await figma.getNodeByIdAsync(id);
    if (!n || !("visible" in n)) return;
    figma.currentPage.selection = [n];
    figma.viewport.scrollAndZoomIntoView([n]);
  }
  async function collections() {
    const cols = await figma.variables.getLocalVariableCollectionsAsync();
    return cols.filter((c) => c.modes.length > 1).map((c) => ({ id: c.id, name: c.name, modes: c.modes }));
  }
  figma.ui.onmessage = async (msg) => {
    try {
      switch (msg.type) {
        case "ready":
          post({ type: "init", collections: await collections(), selection: figma.currentPage.selection.length });
          break;
        case "scan":
          await scan(msg.options);
          break;
        case "select":
          await selectLayer(msg.id);
          break;
        case "fix": {
          let n = 0;
          for (const item of msg.items) if (item.variableId ? await fixVariable(item) : await fixLayer(item)) n++;
          figma.notify(`Fixed ${n} item${n === 1 ? "" : "s"}`);
          if (lastOptions) await scan(lastOptions);
          break;
        }
      }
    } catch (e) {
      post({ type: "error", message: e instanceof Error ? e.message : String(e) });
    }
  };
  figma.on("selectionchange", () => post({ type: "selection", count: figma.currentPage.selection.length }));
})();
