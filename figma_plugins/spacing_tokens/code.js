"use strict";
(() => {
  // spacing_tokens/src/scale.ts
  var FULL = 9999;
  var SPACING_SCALES = {
    4: [2, 4, 8, 12, 16, 20, 24, 28, 32, 40, 48, 56, 64, 80, 96, 128],
    8: [4, 8, 16, 24, 32, 40, 48, 64, 80, 96, 128]
  };
  var RADIUS_SCALE = [2, 4, 6, 8, 10, 12, 16, 20, 24, 32, FULL];
  function snap(value, scale) {
    const finite = scale.filter((v) => v !== FULL);
    const max = finite[finite.length - 1];
    if (value > max * 1.25) return Math.round(value);
    let best = finite[0];
    for (const v of finite) if (Math.abs(v - value) <= Math.abs(best - value)) best = v;
    return best;
  }
  function isPill(radius, width, height) {
    return radius >= Math.min(width, height) / 2 - 0.5;
  }
  var SIZES_UP = ["md", "lg", "xl", "2xl", "3xl", "4xl", "5xl", "6xl", "7xl", "8xl", "9xl"];
  var SIZES_DOWN = ["sm", "xs", "2xs", "3xs", "4xs", "5xs"];
  function tokenNames(kind, values, naming) {
    const names = /* @__PURE__ */ new Map();
    const sorted = [...new Set(values)].sort((a, b) => a - b);
    const finite = sorted.filter((v) => v !== FULL);
    if (sorted.includes(FULL)) names.set(FULL, `${kind}/full`);
    if (naming === "number" || !finite.length) {
      for (const v of finite) names.set(v, `${kind}/${String(v).replace(".", "_")}`);
      return names;
    }
    const middle = kind === "spacing" ? 16 : 8;
    let mid = 0;
    finite.forEach((v, i) => {
      if (Math.abs(v - middle) < Math.abs(finite[mid] - middle)) mid = i;
    });
    finite.forEach((v, i) => {
      var _a, _b;
      const d = i - mid;
      const label = d >= 0 ? (_a = SIZES_UP[d]) != null ? _a : `${d + 1}xl` : (_b = SIZES_DOWN[-d - 1]) != null ? _b : `${-d}xs`;
      names.set(v, `${kind}/${label}`);
    });
    return names;
  }

  // spacing_tokens/src/code.ts
  var PADDING = ["paddingTop", "paddingRight", "paddingBottom", "paddingLeft"];
  var CORNERS = ["topLeftRadius", "topRightRadius", "bottomLeftRadius", "bottomRightRadius"];
  var SCOPES = { spacing: ["GAP"], radius: ["CORNER_RADIUS"] };
  var tokens = /* @__PURE__ */ new Map();
  figma.showUI(__html__, { width: 420, height: 620, themeColors: true });
  var post = (msg) => figma.ui.postMessage(msg);
  function nodesIn(scope) {
    const roots = scope === "selection" ? figma.currentPage.selection : figma.currentPage.children;
    const out = [];
    for (const r of roots) {
      out.push(r);
      if ("findAll" in r) out.push(...r.findAll());
    }
    return out;
  }
  var bound = (node, field) => {
    const b = node.boundVariables;
    return !!(b && b[field]);
  };
  async function scan(o) {
    const found = /* @__PURE__ */ new Map();
    const stats = { layers: 0, alreadyBound: 0, snapped: 0 };
    const add = (kind, raw, node, field, target) => {
      var _a;
      const value = target != null ? target : o.snap ? snap(raw, kind === "spacing" ? SPACING_SCALES[o.base] : RADIUS_SCALE) : Math.round(raw * 100) / 100;
      if (target === void 0 && value !== raw) stats.snapped++;
      const key = `${kind}|${value}`;
      let t = found.get(key);
      if (!t) {
        t = { key, kind, value, name: "", from: /* @__PURE__ */ new Map(), usages: [] };
        found.set(key, t);
      }
      t.from.set(raw, ((_a = t.from.get(raw)) != null ? _a : 0) + 1);
      t.usages.push({ nodeId: node.id, field });
    };
    for (const node of nodesIn(o.scope)) {
      let used = false;
      if ("layoutMode" in node && node.layoutMode !== "NONE" && node.type !== "INSTANCE") {
        const fields = [...PADDING];
        if (node.primaryAxisAlignItems !== "SPACE_BETWEEN") fields.push("itemSpacing");
        if ("layoutWrap" in node && node.layoutWrap === "WRAP" && node.counterAxisSpacing !== null) fields.push("counterAxisSpacing");
        for (const f of fields) {
          const v = node[f];
          if (typeof v !== "number" || v <= 0) continue;
          if (bound(node, f)) stats.alreadyBound++;
          else {
            add("spacing", v, node, f);
            used = true;
          }
        }
      }
      if ("topLeftRadius" in node && node.type !== "INSTANCE") {
        for (const f of CORNERS) {
          const v = node[f];
          if (typeof v !== "number" || v <= 0) continue;
          if (bound(node, f)) stats.alreadyBound++;
          else {
            add("radius", v, node, f, isPill(v, node.width, node.height) ? FULL : void 0);
            used = true;
          }
        }
      }
      if (used) stats.layers++;
    }
    const all = [...found.values()];
    for (const kind of ["spacing", "radius"]) {
      const ofKind = all.filter((t) => t.kind === kind);
      const names = tokenNames(kind, ofKind.map((t) => t.value), o.naming);
      for (const t of ofKind) t.name = names.get(t.value);
    }
    await matchExisting(all);
    tokens = found;
    post({ type: "scan-result", rows: rows(), stats });
  }
  async function matchExisting(list) {
    const cols = new Map((await figma.variables.getLocalVariableCollectionsAsync()).map((c) => [c.id, c]));
    const vars = await figma.variables.getLocalVariablesAsync("FLOAT");
    for (const t of list) {
      const match = vars.find((v) => {
        const col = cols.get(v.variableCollectionId);
        if (!col || v.valuesByMode[col.defaultModeId] !== t.value) return false;
        return v.scopes.includes("ALL_SCOPES") || SCOPES[t.kind].some((s) => v.scopes.includes(s)) || v.name.toLowerCase().includes(t.kind === "spacing" ? "spac" : "radi");
      });
      if (match) t.existing = { id: match.id, name: match.name };
    }
  }
  function rows() {
    return [...tokens.values()].sort((a, b) => a.kind === b.kind ? a.value - b.value : a.kind === "spacing" ? -1 : 1).map((t) => ({
      key: t.key,
      kind: t.kind,
      value: t.value,
      name: t.name,
      count: t.usages.length,
      from: [...t.from.entries()].sort((a, b) => a[0] - b[0]).map(([value, count]) => ({ value, count })),
      existing: t.existing
    }));
  }
  async function apply(s) {
    var _a;
    let col = s.collectionId ? await figma.variables.getVariableCollectionByIdAsync(s.collectionId) : null;
    if (!col) col = figma.variables.createVariableCollection(s.collectionName.trim() || "Spacing");
    const local = (await figma.variables.getLocalVariablesAsync("FLOAT")).filter((v) => v.variableCollectionId === col.id);
    const byName = new Map(local.map((v) => [v.name, v]));
    const summary = { created: 0, updated: 0, linked: 0, bound: 0, failed: 0 };
    const taken = /* @__PURE__ */ new Set();
    for (const row of s.rows) {
      const t = tokens.get(row.key);
      if (!t || !row.enabled) continue;
      let v = null;
      if (row.link && t.existing) {
        v = await figma.variables.getVariableByIdAsync(t.existing.id);
        if (v) summary.linked++;
      }
      if (!v) {
        const base = (row.name || t.name).replace(/[.{}]/g, "-").trim() || `${t.kind}/${row.value}`;
        let name = base;
        for (let i = 2; taken.has(name); i++) name = `${base}-${i}`;
        taken.add(name);
        v = (_a = byName.get(name)) != null ? _a : null;
        if (v) summary.updated++;
        else {
          v = figma.variables.createVariable(name, col, "FLOAT");
          summary.created++;
        }
        const value = Number.isFinite(row.value) && row.value >= 0 ? row.value : t.value;
        for (const m of col.modes) v.setValueForMode(m.modeId, value);
        v.scopes = SCOPES[t.kind];
      }
      for (const u of t.usages) {
        const node = await figma.getNodeByIdAsync(u.nodeId);
        try {
          node.setBoundVariable(u.field, v);
          summary.bound++;
        } catch (e) {
          summary.failed++;
        }
      }
    }
    tokens = /* @__PURE__ */ new Map();
    post({ type: "applied", summary, collections: await collectionInfos(), collectionId: col.id });
    figma.notify(`Bound ${summary.bound} values to ${summary.created + summary.updated + summary.linked} tokens`);
  }
  async function collectionInfos() {
    return (await figma.variables.getLocalVariableCollectionsAsync()).map((c) => ({ id: c.id, name: c.name }));
  }
  async function select(key, from) {
    const t = tokens.get(key);
    if (!t) return;
    const nodes = [];
    const seen = /* @__PURE__ */ new Set();
    for (const u of t.usages) {
      if (seen.has(u.nodeId)) continue;
      const n = await figma.getNodeByIdAsync(u.nodeId);
      if (!n) continue;
      if (from !== void 0 && n[u.field] !== from) continue;
      seen.add(u.nodeId);
      nodes.push(n);
    }
    figma.currentPage.selection = nodes;
    if (nodes.length) figma.viewport.scrollAndZoomIntoView(nodes);
  }
  figma.ui.onmessage = async (msg) => {
    try {
      switch (msg.type) {
        case "ready":
          post({ type: "init", collections: await collectionInfos(), selection: figma.currentPage.selection.length });
          break;
        case "scan":
          await scan(msg.options);
          break;
        case "apply":
          await apply(msg.settings);
          break;
        case "select":
          await select(msg.key, msg.from);
          break;
      }
    } catch (e) {
      post({ type: "error", message: e instanceof Error ? e.message : String(e) });
    }
  };
  figma.on("selectionchange", () => post({ type: "selection", count: figma.currentPage.selection.length }));
})();
